TransportAnimator = {}

-- SPRING API LOCALS
local spGetGameFrame              = Spring.GetGameFrame
local spGetUnitPosition           = Spring.GetUnitPosition
local spGetUnitRotation           = Spring.GetUnitRotation
local spGetUnitPiecePosDir        = Spring.GetUnitPiecePosDir
local spSpawnCEG                  = Spring.SpawnCEG
local spMoveCtrlEnable            = Spring.MoveCtrl.Enable
local spMoveCtrlDisable           = Spring.MoveCtrl.Disable
local spMoveCtrlSetPosition       = Spring.MoveCtrl.SetPosition
local spMoveCtrlSetRotation       = Spring.MoveCtrl.SetRotation
local spMoveCtrlSetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData
local spUnitAttach                = Spring.UnitAttach
local spUnitDetach                = Spring.UnitDetach
local spValidUnitID               = Spring.ValidUnitID
local spGetUnitIsDead             = Spring.GetUnitIsDead
local spGetGroundHeight           = Spring.GetGroundHeight
local spGetGroundNormal           = Spring.GetGroundNormal
local spSetUnitRadiusAndHeight    = Spring.SetUnitRadiusAndHeight
local spGetUnitDefID              = Spring.GetUnitDefID
local spSetUnitRulesParam         = Spring.SetUnitRulesParam
local spSetUnitPhysicalStateBit   = Spring.SetUnitPhysicalStateBit
local spPos2BuildPos              = Spring.Pos2BuildPos
local spGetUnitCommands           = Spring.GetUnitCommands
local spUnitScript                = Spring.UnitScript
local spGetCOBScriptID            = Spring.GetCOBScriptID
local spCallCOBScript             = Spring.CallCOBScript

-- CONSTANTS
local PI              = math.pi
local SIG_WATCH       = 2 -- signal to stop the WatchBeam thread when cargo state changes
local SIG_LOAD        = 4 -- signal to kill all in-flight Load threads (used by ReorganizeAndLoad)

TransportAnimator.SIG_LOAD = SIG_LOAD

-- VARIABLES
local loadTime, cegScaleFactor, cegName
local progress         -- set in Init from precomputedProgress[unitDefID]
local beamsBySlotID = {}

local cachedFrame = -1
local currentTransporterPosX, currentTransporterPosY, currentTransporterPosZ, currentTransporterRotX, currentTransporterRotY, currentTransporterRotZ

---------------------------------------------------------------------------
-- LOCAL HELPERS
---------------------------------------------------------------------------
-- local function shortAngle(...)              -- Normalize angle to (-pi, pi]
-- local function getTransporterState()        -- Cache and return transporter pos/rot for the current frame
-- local function resetSlot(...)               -- Instantly zero all LUS Move/Turn offsets on a slot piece
-- local function isDead(...)                  -- Returns true if unit is no longer a valid live unit
-- local function callUnitScriptOnLoad(...)    -- Call BeingLoaded/StopMoving on the passenger's unit script
-- local function callUnitScriptOnUnload(...)  -- Call BeingUnloaded/StartMoving on the passenger's unit script

-- @param  a  number  angle in radians (any range)
-- @return    number  angle in (-pi, pi]
local function shortAngle(a)
	a = a % (2 * PI)
	if a > PI then a = a - 2 * PI end
	return a
end

---@return number posX, number posY, number posZ, number rotX, number rotY, number rotZ
local function getTransporterState()
	local f = spGetGameFrame()
	if f ~= cachedFrame then
		currentTransporterPosX, currentTransporterPosY, currentTransporterPosZ = spGetUnitPosition(transporterID)
		currentTransporterRotX, currentTransporterRotY, currentTransporterRotZ = spGetUnitRotation(transporterID)
		cachedFrame = f
	end
	return currentTransporterPosX, currentTransporterPosY, currentTransporterPosZ, currentTransporterRotX, currentTransporterRotY, currentTransporterRotZ
end

-- @param slotID  number  LUS piece ID of the cargo slot
local function resetSlot(slotID)
	Move(slotID, 1, 0)  Move(slotID, 2, 0)  Move(slotID, 3, 0)
	Turn(slotID, 1, 0)  Turn(slotID, 2, 0)  Turn(slotID, 3, 0)
end

-- Returns true if the unit is no longer a valid live unit.
-- @param  id  number  unitID
-- @return     boolean
local function isDead(id)
	return not spValidUnitID(id) or spGetUnitIsDead(id)
end

-- @param id  number  unitID of the passenger being loaded
local function callUnitScriptOnLoad(id)
	local lusEnv = spUnitScript.GetScriptEnv(id)
	if lusEnv and lusEnv["script"] then
		if lusEnv["script"]["BeingLoaded"] then
			spUnitScript.CallAsUnit(id, lusEnv["script"]["BeingLoaded"])
		elseif lusEnv["script"]["StopMoving"] then
			spUnitScript.CallAsUnit(id, lusEnv["script"]["StopMoving"])
		end
	else
		local cobFuncIDBeingLoaded = spGetCOBScriptID(id, "BeingLoaded")
		local cobFuncIDStopMoving = spGetCOBScriptID(id, "StopMoving")
		if cobFuncIDBeingLoaded then
			spCallCOBScript(id, cobFuncIDBeingLoaded, 1)
		elseif cobFuncIDStopMoving then
			spCallCOBScript(id, cobFuncIDStopMoving, 1)
		end
	end
end

-- @param id  number  unitID of the passenger being unloaded
local function callUnitScriptOnUnload(id)
	local lusEnv = spUnitScript.GetScriptEnv(id)
	if lusEnv and lusEnv["script"] then
		if lusEnv["script"]["BeingUnloaded"] then
			spUnitScript.CallAsUnit(id, lusEnv["script"]["BeingUnloaded"])
		elseif lusEnv["script"]["StartMoving"] then
			local Q = spGetUnitCommands(id, 1)
			if Q[1] then -- only call StartMoving if the unit has a move order queued, to avoid interrupting other scripts (e.g. building placement)
				spUnitScript.CallAsUnit(id, lusEnv["script"]["StartMoving"])
			end
		end
	else
		local cobFuncIDBeingUnloaded = spGetCOBScriptID(id, "BeingUnloaded")
		local cobFuncIDStartMoving = spGetCOBScriptID(id, "StartMoving")

		if cobFuncIDBeingUnloaded then
			spCallCOBScript(id, cobFuncIDBeingUnloaded, 1)
		elseif cobFuncIDStartMoving then
			local Q = spGetUnitCommands(id, 1)
			if Q[1] then -- only call StartMoving if the unit has a move order queued, to avoid interrupting other scripts (e.g. building placement)
				spCallCOBScript(id, cobFuncIDStartMoving, 1)
			end
		end
	end
end

---------------------------------------------------------------------------
-- MODULE FUNCTIONS
---------------------------------------------------------------------------
-- function TransportAnimator.Init(...)      -- Cache loadTime, CEG params, easing curve and beam piece IDs from unitDef and setup
-- function TransportAnimator.HasCargo(...)  -- Toggle dontLand flag and start/stop the WatchBeams CEG thread
-- function TransportAnimator.Snap(...)      -- Instantly position slot at carry height; used on save/load restore
-- function TransportAnimator.WatchBeams()   -- Per-frame coroutine: spawn tractor-beam CEGs between beam pieces and passengers
-- function TransportAnimator.Load(...)      -- Coroutine: animate a passenger from the ground into its slot via MoveCtrl
-- function TransportAnimator.Unload(...)    -- Coroutine: animate a passenger from its slot back to the ground

-- @param setup  table  per-unit anim/slot config loaded from <unitName>/setup.lua
function TransportAnimator.Init(setup)
	loadTime       = tonumber(UnitDefs[unitDefID].customParams.loadtime)
	cegScaleFactor = tonumber(UnitDefs[unitDefID].customParams.transportercegscale or 0.7)
	cegName        = UnitDefs[unitDefID].customParams.transportcegname or "tractorbeam"
	heightOffsetMult   = cegName == "armada_ion" and 1 or cegName == "cortex_grapple" and 0.5 or cegName == "legion_grav_distort" and 0.2 or 1
	radiusOffsetMult   = cegName == "armada_ion" and 0 or cegName == "cortex_grapple" and 0.85 or cegName == "legion_grav_distort" and 0 or 1

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

-- @param hasCargo  boolean  true when at least one passenger is registered
function TransportAnimator.HasCargo(hasCargo)
	Signal(SIG_WATCH)
	spMoveCtrlSetGunshipMoveTypeData(transporterID, "dontLand", hasCargo)
	if hasCargo then
		StartThread(TransportAnimator.WatchBeams)
	end
end

-- @param passengerData  table  passenger entry from cargo.passengers
function TransportAnimator.Snap(passengerData)
	passengerData.beamPieces = beamsBySlotID[passengerData.slotID]
	Move(passengerData.slotID, 1, 0)
	Move(passengerData.slotID, 2, -passengerData.height)
	Move(passengerData.slotID, 3, 0)
	Turn(passengerData.slotID, 1, 0)
	Turn(passengerData.slotID, 2, 0)
	Turn(passengerData.slotID, 3, 0)
end

function TransportAnimator.WatchBeams()
	SetSignalMask(SIG_WATCH)
	-- reusable local vars to avoid allocations in this hot loop
	local beamPieceX, beamPieceY, beamPieceZ
	local cegTopX, cegTopY, cegTopZ, cegDX, cegDY, cegDZ, cegLen, cegSpawnX, cegSpawnY, cegSpawnZ
	while true do
		for passengerID, passengerData in pairs(cargo.passengers) do
			if passengerData.beamPieces then
				if not passengerData.cachedPosX then
					passengerData.cachedPosX, passengerData.cachedPosY, passengerData.cachedPosZ = spGetUnitPosition(passengerID)
				end
				for _, beamPiece in ipairs(passengerData.beamPieces) do
					beamPieceX, beamPieceY, beamPieceZ = spGetUnitPiecePosDir(transporterID, beamPiece)
					if passengerData.cachedPosX then
						-- loading or unloading: beam originates from the unit surface toward the beam piece,
						-- offset by radius from the top-center so multi-beam pieces spread around the unit
						cegTopX = passengerData.cachedPosX
						cegTopY = passengerData.cachedPosY + passengerData.height * heightOffsetMult
						cegTopZ = passengerData.cachedPosZ
						cegDX = beamPieceX - cegTopX
						cegDY = beamPieceY - cegTopY
						cegDZ = beamPieceZ - cegTopZ
						cegLen = math.sqrt(cegDX * cegDX + cegDY * cegDY + cegDZ * cegDZ)
						if cegLen > 0.01 then
							cegSpawnX = cegTopX + cegDX * passengerData.radius * radiusOffsetMult / cegLen
							cegSpawnY = cegTopY + cegDY * passengerData.radius * radiusOffsetMult / cegLen
							cegSpawnZ = cegTopZ + cegDZ * passengerData.radius * radiusOffsetMult / cegLen
						else
							cegSpawnX, cegSpawnY, cegSpawnZ = cegTopX, cegTopY, cegTopZ
						end
						spSpawnCEG(cegName,
							cegSpawnX, cegSpawnY, cegSpawnZ,
							beamPieceX - cegSpawnX,
							beamPieceY - cegSpawnY,
							beamPieceZ - cegSpawnZ,
						cegScaleFactor, 0)
					end
				end
				passengerData.cachedPosX, passengerData.cachedPosY, passengerData.cachedPosZ = nil,nil,nil
			end
		end
		Sleep(66)
	end
end

---------------------------------------------------------------------------
-- script functions
---------------------------------------------------------------------------

-- @param passengerData  table    passenger entry from cargo.passengers
-- @param doAnim         boolean  if false, skip the tween and attach instantly  (default: true)
function TransportAnimator.Load(passengerData, doAnim)
	SetSignalMask(TransportAnimator.SIG_LOAD)
	passengerData.beamPieces = beamsBySlotID[passengerData.slotID]
	TransportAPI.DisablePassenger(passengerData.id)
	CargoHandler.BeginLoading(cargo)
	spSetUnitRulesParam(passengerData.id, "inLoadAnim", transporterID)

	local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerData.id)
	local passengerRotX, passengerRotY, passengerRotZ = spGetUnitRotation(passengerData.id)
	callUnitScriptOnLoad(passengerData.id)

	-- slot stays at rest position throughout; passenger moves up to meet it
	resetSlot(passengerData.slotID)
	Move(passengerData.slotID, 2, -passengerData.height)

	local count = CargoHandler.Register(passengerData.id, passengerData, cargo)
	if count == 1 then TransportAnimator.HasCargo(true) end

	local aborted = false
	-- reusable local vars to avoid allocations in this hot loop
	local newPassengerPosX, newPassengerPosY, newPassengerPosZ
	local newPassengerRotX, newPassengerRotY, newPassengerRotZ
	local normalizedProgress
	local slotPosX, slotPosY, slotPosZ
	local transporterRotX, transporterRotY, transporterRotZ

	if doAnim ~= false then
		spMoveCtrlEnable(passengerData.id)
		for frame = 0, loadTime - 1 do
			normalizedProgress = progress[frame]
			passengerData.animProgress = normalizedProgress

			slotPosX, slotPosY, slotPosZ = spGetUnitPiecePosDir(transporterID, passengerData.slotID)
			_, _, _, transporterRotX, transporterRotY, transporterRotZ = getTransporterState()

			newPassengerPosX = (1 - normalizedProgress) * passengerPosX + normalizedProgress * slotPosX
			newPassengerPosY = (1 - normalizedProgress) * passengerPosY + normalizedProgress * slotPosY
			newPassengerPosZ = (1 - normalizedProgress) * passengerPosZ + normalizedProgress * slotPosZ

			newPassengerRotX = passengerRotX + normalizedProgress * shortAngle(transporterRotX - passengerRotX)
			newPassengerRotY = passengerRotY + normalizedProgress * shortAngle(transporterRotY - passengerRotY)
			newPassengerRotZ = passengerRotZ + normalizedProgress * shortAngle(transporterRotZ - passengerRotZ)

			spMoveCtrlSetPosition(passengerData.id, newPassengerPosX, newPassengerPosY, newPassengerPosZ)
			spMoveCtrlSetRotation(passengerData.id, newPassengerRotX, newPassengerRotY, newPassengerRotZ)

			passengerData.cachedPosX, passengerData.cachedPosY, passengerData.cachedPosZ = newPassengerPosX, newPassengerPosY, newPassengerPosZ

			Sleep(33)
			if isDead(passengerData.id) then aborted = true ; break end
		end
		passengerData.cachedPosX = nil ; passengerData.cachedPosY = nil ; passengerData.cachedPosZ = nil
		spMoveCtrlDisable(passengerData.id)
	end

	if not aborted then
		passengerData.animProgress = 1
		spUnitAttach(transporterID,passengerData.id, passengerData.slotID)
	else
		passengerData.animProgress = nil
		local count = CargoHandler.Unregister(passengerData.id, cargo)
		if count == 0 then TransportAnimator.HasCargo(false) end
	end
	TransportAPI.EnablePassenger(passengerData.id)

	spSetUnitRulesParam(passengerData.id, "inLoadAnim", 0)
	CargoHandler.EndLoading(cargo)
end

-- @param passengerData  table    passenger entry from cargo.passengers
-- @param goalPosX       number   world-space X of the drop point
-- @param goalPosY       number   world-space Y hint (actual Y is clamped to ground height)
-- @param goalPosZ       number   world-space Z of the drop point
-- @param doAnim         boolean  if false, detach in-place only  (default: true)
function TransportAnimator.Unload(passengerData, goalPosX, goalPosY, goalPosZ, doAnim)
	if passengerData.unloading then return end
	TransportAPI.DisablePassenger(passengerData.id)
	passengerData.unloading = true
	CargoHandler.BeginUnloading(cargo)
	spUnitDetach(passengerData.id)

	if doAnim ~= false then
		spSetUnitRulesParam(passengerData.id, "inUnloadAnim", 1)
		local slotPosX, slotPosY, slotPosZ = spGetUnitPiecePosDir(transporterID, passengerData.slotID)
		local transporterPosX, _, transporterPosZ, startTransporterRotX, startTransporterRotY, startTransporterRotZ = getTransporterState()
		goalPosX, goalPosZ = goalPosX + (slotPosX - transporterPosX), goalPosZ + (slotPosZ - transporterPosZ)
		goalPosY = math.max(0,spGetGroundHeight(goalPosX, goalPosZ))
		local passengerDefID = spGetUnitDefID(passengerData.id)
		local startRotX, startRotY, startRotZ = spGetUnitRotation(passengerData.id)
		local goalRotX, goalRotY, goalRotZ
		if UnitDefs[passengerDefID] and UnitDefs[passengerDefID].speed == 0 then
			spSetUnitRadiusAndHeight(passengerData.id, slotPosY - spGetGroundHeight(slotPosX, slotPosZ) + 20, passengerData.height) -- reset radius/height in case we were transporting a building with custom values
			goalRotY = math.floor(startRotY/(PI/2) + 0.5) *(PI/2) -- cardinal facing
			goalPosX, goalPosY, goalPosZ = spPos2BuildPos(passengerDefID, goalPosX, goalPosY, goalPosZ) -- always align buildings on build grid
		else
			spSetUnitRadiusAndHeight(passengerData.id, 0, passengerData.height) -- reset radius/height in case we were transporting a building with custom values
		end
		
		if UnitDefs[passengerDefID] and UnitDefs[passengerDefID].upright then
			goalRotX, goalRotY, goalRotZ = 0, (goalRotY or startRotY), 0
		else
			local normalX, normalY, normalZ = spGetGroundNormal(goalPosX, goalPosZ)
			goalRotX, goalRotY, goalRotZ = math.atan2(-normalZ, normalY), startRotY, math.atan2(normalX, normalY)
		end

		spMoveCtrlEnable(passengerData.id) -- unlike Load(), Unload moves the unit via movectrl after detaching

		local aborted = false
		-- reusable local vars to avoid allocations in this hot loop
		local newPassengerPosX, newPassengerPosY, newPassengerPosZ
		local newPassengerRotX, newPassengerRotY, newPassengerRotZ
		local normalizedProgress
		local transporterRotX, transporterRotY, transporterRotZ
		for frame = 0, loadTime - 1 do
			normalizedProgress = progress[frame]

			passengerData.animProgress = 1 - normalizedProgress -- keep track of our progress for Killed() script

			slotPosX, slotPosY, slotPosZ = spGetUnitPiecePosDir(transporterID, passengerData.slotID)
			_,_,_, transporterRotX, transporterRotY, transporterRotZ = getTransporterState()

			newPassengerPosX, newPassengerPosY, newPassengerPosZ = 
				normalizedProgress * goalPosX + (1 - normalizedProgress) * slotPosX,
				normalizedProgress * goalPosY + (1 - normalizedProgress) * slotPosY,
				normalizedProgress * goalPosZ + (1 - normalizedProgress) * slotPosZ

			newPassengerRotX, newPassengerRotY, newPassengerRotZ = 
				goalRotX * normalizedProgress + (startRotX + shortAngle(transporterRotX - startTransporterRotX)) * (1 - normalizedProgress),
				goalRotY * normalizedProgress + (startRotY + shortAngle(transporterRotY - startTransporterRotY)) * (1 - normalizedProgress),
				goalRotZ * normalizedProgress + (startRotZ + shortAngle(transporterRotZ - startTransporterRotZ)) * (1 - normalizedProgress)
			
			spMoveCtrlSetPosition(passengerData.id,
				 newPassengerPosX, newPassengerPosY, newPassengerPosZ)
			spMoveCtrlSetRotation(passengerData.id,
				newPassengerRotX, newPassengerRotY,	newPassengerRotZ)

			passengerData.cachedPosX, passengerData.cachedPosY, passengerData.cachedPosZ = newPassengerPosX, newPassengerPosY, newPassengerPosZ

			Sleep(33)
			if isDead(passengerData.id) then aborted = true ; break end
		end
		passengerData.cachedPosX = nil ; passengerData.cachedPosY = nil ; passengerData.cachedPosZ = nil -- invalidate cache
		-- Spring.SetUnitRadiusAndHeight(passengerData.id, radius, height) -- reset radius/height in case we were transporting a building with custom values

		if not aborted then -- unload anim completed, ensure unit is at final position/rotation
			local groundHeight = spGetGroundHeight(goalPosX, goalPosZ)
			spMoveCtrlSetPosition(passengerData.id, goalPosX, math.max(0, groundHeight), goalPosZ)
			spMoveCtrlSetRotation(passengerData.id, goalRotX, goalRotY, goalRotZ)
			spMoveCtrlDisable(passengerData.id)
			if groundHeight < 0 then
				spSetUnitPhysicalStateBit(passengerData.id, 512 + 256) -- ensure correct water/land state after unloading
			end
			callUnitScriptOnUnload(passengerData.id)
		end
	end

	resetSlot(passengerData.slotID)
	local count = CargoHandler.Unregister(passengerData.id, cargo)
	spSetUnitRulesParam(passengerData.id, "inUnloadAnim", 0)
	TransportAPI.EnablePassenger(passengerData.id)
	spSetUnitRadiusAndHeight(passengerData.id, passengerData.radius, passengerData.height) -- reset radius/height in case we were transporting a building with custom values
	if count == 0 then TransportAnimator.HasCargo(false) end
	CargoHandler.EndUnloading(cargo)
end
