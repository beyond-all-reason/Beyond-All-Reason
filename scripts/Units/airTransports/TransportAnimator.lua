TransportAnimator = {}

local SIG_WATCH           = 2 -- signal to stop the WatchBeam thread when cargo state changes
TransportAnimator.SIG_LOAD = 4 -- signal to kill all in-flight Load threads (used by ReorganizeAndLoad)
local defaultPiecePos  = {} -- [pieceID] = {x,y,z} rest position in unit-local space, cached on first use
local pi = math.pi

local function shortAngle(a)
	a = a % (2 * pi)
	if a > pi then a = a - 2 * pi end
	return a
end

-- move and rotate a slot piece to match a world-space position/rotation, converting through unit-local space
local function MovePieceWS(pieceNum, 
    wantedWorldSpacePosX, wantedWorldSpacePosY, wantedWorldSpacePosZ, 
    wantedWorldSpaceRotX, wantedWorldSpaceRotY, wantedWorldSpaceRotZ, 
    speed, passengerHeight, normalizedProgress,
    transporterPosX, transporterPosY, transporterPosZ, 
    transporterRotX, transporterRotY, transporterRotZ)

	local wantedUnitSpacePosX, wantedUnitSpacePosY, wantedUnitSpacePosZ,
	    wantedUnitSpaceRotX, wantedUnitSpaceRotY, wantedUnitSpaceRotZ = 
		    TransportAPI.WorldToUnitSpace(transporterID,
			    wantedWorldSpacePosX, wantedWorldSpacePosY, wantedWorldSpacePosZ,
			    wantedWorldSpaceRotX, wantedWorldSpaceRotY, wantedWorldSpaceRotZ,
			    transporterPosX, transporterPosY, transporterPosZ,
			    transporterRotX, transporterRotY, transporterRotZ)

	-- Move() offsets are relative to the piece's own rest position, not the unit origin.
	-- Subtract the rest position so the piece ends up at the correct unit-local coordinates.
	if not defaultPiecePos[pieceNum] then
		Move(pieceNum, 1, 0)  Move(pieceNum, 2, 0)  Move(pieceNum, 3, 0) -- move piece to rest pos and read it to cache the default position
		local defaultPieceUnitSpacePosX, defaultPieceUnitSpacePosY, defaultPieceUnitSpacePosZ = Spring.GetUnitPiecePosition(transporterID, pieceNum)
		defaultPiecePos[pieceNum] = { defaultPieceUnitSpacePosX, defaultPieceUnitSpacePosY, defaultPieceUnitSpacePosZ }
	end
	local defaultPiecePosition =    defaultPiecePos[pieceNum]
	Move(pieceNum, 1, (wantedUnitSpacePosX + (1-normalizedProgress) * defaultPiecePosition[1]),speed)
	Move(pieceNum, 2, wantedUnitSpacePosY - passengerHeight - (1-normalizedProgress) * defaultPiecePosition[2], speed)
	Move(pieceNum, 3, wantedUnitSpacePosZ - (1-normalizedProgress) * defaultPiecePosition[3],speed)
	Turn(pieceNum, 1, wantedUnitSpaceRotX, speed)
	Turn(pieceNum, 2, wantedUnitSpaceRotY, speed)
	Turn(pieceNum, 3, wantedUnitSpaceRotZ, speed)
end

local loadTime, ratio, ratioY, cegScaleFactor, cegName
local progress         -- set in Init from precomputedProgress[unitDefID]
local beamsBySlotID = {}

local cachedFrame = -1
local currentTransporterPosX, currentTransporterPosY, currentTransporterPosZ, currentTransporterRotX, currentTransporterRotY, currentTransporterRotZ

-- returns transporter position and rotation, memoized per game frame to avoid redundant API calls
local function getTransporterState() -- caching helper: get the position only once per frame when multiple threads are running.
	local f = SpGetGameFrame()
	if f ~= cachedFrame then
		currentTransporterPosX, currentTransporterPosY, currentTransporterPosZ = SpGetUnitPosition(transporterID)
		currentTransporterRotX, currentTransporterRotY, currentTransporterRotZ = SpGetUnitRotation(transporterID)
		cachedFrame = f
	end
	return currentTransporterPosX, currentTransporterPosY, currentTransporterPosZ, currentTransporterRotX, currentTransporterRotY, currentTransporterRotZ
end

-- zero out all transforms on a slot piece (called after animation completes or is aborted)
local function resetSlot(slotID) -- Instantly move slot to its default pos/rotation
	Move(slotID, 1, 0)  Move(slotID, 2, 0)  Move(slotID, 3, 0)
	Turn(slotID, 1, 0)  Turn(slotID, 2, 0)  Turn(slotID, 3, 0)
end

-- returns true if a unit is no longer valid or has been marked dead
local function isDead(id) -- helper to check if a unit is dead or invalid.
	return not SpValidUnitID(id) or SpGetUnitIsDead(id)
end

-- initialise loadTime, CEG params, velocity damping ratios, easing curve, and beam pieces from setup
function TransportAnimator.Init(setup)
	loadTime       = tonumber(UnitDefs[unitDefID].customParams.loadtime)
	cegScaleFactor = setup.cegScaleFactor
	cegName        = setup.cegName

	local def    = UnitDefs[unitDefID]
	local vmax   = def.speed/30 -- it's in elmos/sec, not per frame (unlike Spring.GetUnitVelocity)
	local a      = math.max(0.01, def.maxAcc)
	local vmax_y = def.verticalSpeed
	-- velocity damping ratio: tuned to unit speed and acceleration so the aircraft slows to near-stop during
	-- load/unload; applied as ratio^2 per 66ms tick in WatchBeams
	ratio  = (0.30 * vmax)   / (0.30 * vmax   + a)
	ratioY = (0.1 * vmax_y) / (0.1 * vmax_y + a)

	progress = GG.TransportAPI.precomputedProgress[unitDefID]

	-- resolve beam piece name strings from setup into piece IDs, keyed by slot piece ID
	if setup.beams then
		for slotName, beamNames in pairs(setup.beams) do
			local slotID = piece(slotName)
			beamsBySlotID[slotID] = {}
			for i, bname in ipairs(beamNames) do
				beamsBySlotID[slotID][i] = piece(bname)
			end
		end
	end
end

-- called when cargo count changes: toggles dontLand move type and starts/stops the beam-watch thread
function TransportAnimator.HasCargo(hasCargo)
	Signal(SIG_WATCH)
	SpMoveCtrl.SetGunshipMoveTypeData(transporterID, "dontLand", hasCargo)
	if hasCargo then
		StartThread(TransportAnimator.WatchBeams)
	end
end

-- instantly position the slot piece at load height without animation; used when restoring from save/load
function TransportAnimator.Snap(passengerData)
	passengerData.beamPieces = beamsBySlotID[passengerData.slotID]
	Move(passengerData.slotID, 1, 0)
	Move(passengerData.slotID, 2, -passengerData.height)
	Move(passengerData.slotID, 3, 0)
	Turn(passengerData.slotID, 1, 0)
	Turn(passengerData.slotID, 2, 0)
	Turn(passengerData.slotID, 3, 0)
end

-- per-frame loop: damps transporter velocity during active animations and spawns tractor-beam CEGs
-- we can only use cached pos during unload,
-- during loading, the WorldSpaceToUnitSpace conversion induces a visible offset 
function TransportAnimator.WatchBeams()
	SetSignalMask(SIG_WATCH)
	-- reusable local vars to avoid allocations in this hot loop
	local velocityX, velocityY, velocityZ
	local beamPieceX, beamPieceY, beamPieceZ
	local slotPosX, slotPosY, slotPosZ
	while true do
		if (cargo.loadingCount + cargo.unloadingCount) > 0 then
			velocityX, velocityY, velocityZ = SpGetUnitVelocity(unitID)
			SpSetUnitVelocity(unitID, velocityX * ratio * ratio, velocityY * ratioY * ratioY, velocityZ * ratio * ratio)
		end
		for passengerID, passengerData in pairs(cargo.passengers) do
			if passengerData.beamPieces then
				for _, beamPiece in ipairs(passengerData.beamPieces) do
					beamPieceX, beamPieceY, beamPieceZ = SpGetUnitPiecePosDir(transporterID, beamPiece)
					if passengerData.loading then
						-- passenger is attached to slot: use actual slot world position as beam target
						-- is it more efficient to use passenger GetUnitPosition() instead?
						slotPosX, slotPosY, slotPosZ = SpGetUnitPiecePosDir(transporterID, passengerData.slotID)
						SpSpawnCEG(cegName,
							slotPosX, slotPosY + passengerData.height, slotPosZ,
							(beamPieceX - slotPosX) * cegScaleFactor,
							(beamPieceY - (slotPosY + passengerData.height)) * cegScaleFactor,
							(beamPieceZ - slotPosZ) * cegScaleFactor,
							1, 0)
					elseif passengerData.cachedPosX then
						-- unloading: passenger is detached and moved via MoveCtrl, use cached position
						SpSpawnCEG(cegName,
							passengerData.cachedPosX, passengerData.cachedPosY + passengerData.height, passengerData.cachedPosZ,
							(beamPieceX - passengerData.cachedPosX) * cegScaleFactor,
							(beamPieceY - (passengerData.cachedPosY + passengerData.height)) * cegScaleFactor,
							(beamPieceZ - passengerData.cachedPosZ) * cegScaleFactor,
							1, 0)
					else
						-- idle: simple downward beam from the anchor piece
						SpSpawnCEG(cegName,
							beamPieceX, beamPieceY, beamPieceZ,
							0, -10, 0,
							1, 0)
					end
				end
			end
		end
		Sleep(66)
	end
end

-- Load logic for attaching and moving the passenger
function TransportAnimator.Load(passengerData, doAnim)
	SetSignalMask(TransportAnimator.SIG_LOAD)
	passengerData.beamPieces = beamsBySlotID[passengerData.slotID]
	CargoHandler.BeginLoading(cargo)

	local passengerPosX, passengerPosY, passengerPosZ = SpGetUnitPosition(passengerData.id)
	local passengerRotX, passengerRotY, passengerRotZ = SpGetUnitRotation(passengerData.id)
	local transporterPosX, transporterPosY, transporterPosZ, transporterRotX, transporterRotY, transporterRotZ = getTransporterState()
	MovePieceWS(passengerData.slotID,
	passengerPosX, passengerPosY, passengerPosZ,
	passengerRotX, passengerRotY, passengerRotZ,
	nil, 0, 0,
	transporterPosX, transporterPosY, transporterPosZ,
	transporterRotX, transporterRotY, transporterRotZ) -- snap slot to passenger position at start of load anim

	SpUnitAttach(transporterID, passengerData.id, passengerData.slotID)

	local count = CargoHandler.Register(passengerData.id, passengerData, cargo)
	if count == 1 then TransportAnimator.HasCargo(true) end

	local aborted = false
	-- reusable local vars to avoid allocations in this hot loop
	local newPassengerPosX, newPassengerPosY, newPassengerPosZ
	local newPassengerRotX, newPassengerRotY, newPassengerRotZ
	local normalizedProgress

	if doAnim ~= false then
		passengerData.loading = true -- flag for WatchBeams; passenger is attached so slot pos is authoritative
		for frame = 0, loadTime - 1 do
			normalizedProgress = progress[frame]
			passengerData.animProgress = normalizedProgress -- keep track of the progress for Killed() script
			transporterPosX, transporterPosY, transporterPosZ, transporterRotX, transporterRotY, transporterRotZ = getTransporterState()

			newPassengerPosX, newPassengerPosY, newPassengerPosZ =
				normalizedProgress * transporterPosX   + (1 - normalizedProgress) * passengerPosX,
				normalizedProgress * transporterPosY   + (1 - normalizedProgress) * passengerPosY,
				normalizedProgress * transporterPosZ   + (1 - normalizedProgress) * passengerPosZ

			newPassengerRotX, newPassengerRotY, newPassengerRotZ = 
				passengerRotX + normalizedProgress * shortAngle(transporterRotX - passengerRotX),
				passengerRotY + normalizedProgress * shortAngle(transporterRotY - passengerRotY),
				passengerRotZ + normalizedProgress * shortAngle(transporterRotZ - passengerRotZ)

			MovePieceWS(passengerData.slotID,
				newPassengerPosX, newPassengerPosY, newPassengerPosZ,
				newPassengerRotX, newPassengerRotY, newPassengerRotZ,
				nil, passengerData.height * normalizedProgress, normalizedProgress,
				transporterPosX, transporterPosY, transporterPosZ,
				transporterRotX, transporterRotY, transporterRotZ)

			Sleep(33)
			if isDead(passengerData.id) then aborted = true ; break end
		end
		-- clear loading flag
		passengerData.loading = nil
	end
	resetSlot(passengerData.slotID)
	if not aborted then -- finished the anim smoothly
		passengerData.animProgress = 1
		Move(passengerData.slotID, 2, -passengerData.height)
	else -- something went wrong (unit was killed?)
		passengerData.animProgress = nil
		local count = CargoHandler.Unregister(passengerData.id, cargo)
		if count == 0 then TransportAnimator.HasCargo(false) end
	end
	CargoHandler.EndLoading(cargo)
end

-- Unload logic for detaching and moving the passenger.
-- When doAnim == false, the unit is only detached in-place with no position change.
function TransportAnimator.Unload(passengerData, goalPosX, goalPosY, goalPosZ, doAnim)
	if passengerData.unloading then return end
	passengerData.unloading = true
	CargoHandler.BeginUnloading(cargo)
	SpUnitDetach(passengerData.id)

	if doAnim ~= false then
		Spring.SetUnitRulesParam(passengerData.id, "inTransportAnim", 1)
		local slotPosX, slotPosY, slotPosZ = SpGetUnitPiecePosDir(transporterID, passengerData.slotID)
		local radius, height = Spring.GetUnitRadius(passengerData.id), Spring.GetUnitHeight(passengerData.id)
		Spring.SetUnitRadiusAndHeight(passengerData.id, slotPosY - Spring.GetGroundHeight(slotPosX, slotPosZ) + 20, height) -- reset radius/height in case we were transporting a building with custom values
		local transporterPosX, _, transporterPosZ, startTransporterRotX, startTransporterRotY, startTransporterRotZ = getTransporterState(transporterID)
		goalPosX, goalPosZ = goalPosX + (slotPosX - transporterPosX), goalPosZ + (slotPosZ - transporterPosZ)
		goalPosY = SpGetGroundHeight(goalPosX, goalPosZ)	
		local passengerDefID = SpGetUnitDefID(passengerData.id)
		local passengerTeamID = Spring.GetUnitTeam(passengerData.id)

		local startRotX, startRotY, startRotZ = SpGetUnitRotation(passengerData.id)
		local goalRotX, goalRotY, goalRotZ
		local passengerDefID = SpGetUnitDefID(passengerData.id)
		if UnitDefs[passengerDefID] and UnitDefs[passengerDefID].speed == 0 then
			goalRotY = math.floor(startRotY/(pi/2) + 0.5) *(pi/2) -- cardinal facing
		end
		
		if UnitDefs[passengerDefID] and UnitDefs[passengerDefID].upright then
			goalRotX, goalRotY, goalRotZ = 0, (goalRotY or startRotY), 0
		else
			local normalX, normalY, normalZ = SpGetGroundNormal(goalPosX, goalPosZ)
			goalRotX, goalRotY, goalRotZ = math.atan2(-normalZ, normalY), startRotY, math.atan2(normalX, normalY)
		end

		SpMoveCtrl.Enable(passengerData.id) -- unlike Load(), Unload moves the unit via movectrl after detaching

		local aborted = false
		-- reusable local vars to avoid allocations in this hot loop
		local newPassengerPosX, newPassengerPosY, newPassengerPosZ
		local newPassengerRotX, newPassengerRotY, newPassengerRotZ
		local normalizedProgress
		local transporterRotX, transporterRotY, transporterRotZ
		for frame = 0, loadTime - 1 do
			normalizedProgress = progress[frame]

			passengerData.animProgress = 1 - normalizedProgress -- keep track of our progress for Killed() script

			slotPosX, slotPosY, slotPosZ = SpGetUnitPiecePosDir(transporterID, passengerData.slotID)
			_,_,_, transporterRotX, transporterRotY, transporterRotZ = getTransporterState(transporterID)

			newPassengerPosX, newPassengerPosY, newPassengerPosZ = 
				normalizedProgress * goalPosX + (1 - normalizedProgress) * slotPosX,
				normalizedProgress * goalPosY + (1 - normalizedProgress) * slotPosY,
				normalizedProgress * goalPosZ + (1 - normalizedProgress) * slotPosZ

			newPassengerRotX, newPassengerRotY, newPassengerRotZ = 
				goalRotX * normalizedProgress + (startRotX + shortAngle(transporterRotX - startTransporterRotX)) * (1 - normalizedProgress),
				goalRotY * normalizedProgress + (startRotY + shortAngle(transporterRotY - startTransporterRotY)) * (1 - normalizedProgress),
				goalRotZ * normalizedProgress + (startRotZ + shortAngle(transporterRotZ - startTransporterRotZ)) * (1 - normalizedProgress)
			
			SpMoveCtrl.SetPosition(passengerData.id,
				 newPassengerPosX, newPassengerPosY, newPassengerPosZ)
			SpMoveCtrl.SetRotation(passengerData.id,
				newPassengerRotX, newPassengerRotY,	newPassengerRotZ)

			passengerData.cachedPosX, passengerData.cachedPosY, passengerData.cachedPosZ = newPassengerPosX, newPassengerPosY, newPassengerPosZ

			Sleep(33)
			if isDead(passengerData.id) then aborted = true ; break end
		end
		passengerData.cachedPosX = nil ; passengerData.cachedPosY = nil ; passengerData.cachedPosZ = nil -- invalidate cache
		Spring.SetUnitRadiusAndHeight(passengerData.id, radius, height) -- reset radius/height in case we were transporting a building with custom values

		if not aborted then -- unload anim completed, ensure unit is at final position/rotation
			SpMoveCtrl.SetPosition(passengerData.id, goalPosX, goalPosY, goalPosZ)
			SpMoveCtrl.SetRotation(passengerData.id, goalRotX, goalRotY, goalRotZ)
			SpMoveCtrl.Disable(passengerData.id)
			Spring.SetUnitPosition(passengerData.id, goalPosX, goalPosY, goalPosZ) -- for transportable buildings, this is recquired after releasing movectrl
		end
	end

	resetSlot(passengerData.slotID)
	local count = CargoHandler.Unregister(passengerData.id, cargo)
	Spring.SetUnitRulesParam(passengerData.id, "inTransportAnim", 0)
	if count == 0 then TransportAnimator.HasCargo(false) end
	CargoHandler.EndUnloading(cargo)
end
