local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Airbase Manager",
		desc = "Automated and manual use of air repair pads",
		author = "ashdnazg, Bluestone",
		date = "February 2016",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

local CMD_LAND_AT_AIRBASE = 35430
local CMD_LAND_AT_SPECIFIC_AIRBASE = 35431

CMD.LAND_AT_AIRBASE = CMD_LAND_AT_AIRBASE
CMD[CMD_LAND_AT_AIRBASE] = "LAND_AT_AIRBASE"
CMD.LAND_AT_SPECIFIC_AIRBASE = CMD_LAND_AT_SPECIFIC_AIRBASE
CMD[CMD_LAND_AT_SPECIFIC_AIRBASE] = "LAND_AT_SPECIFIC_AIRBASE"

local tractorDist = 100 ^ 2 -- default sqr tractor distance
local isAirbase = {}
local isAirUnit = {}
local isAirCon = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.isairbase then
		isAirbase[unitDefID] = { tractorDist, unitDef.buildSpeed }
	end
	if unitDef.isAirUnit and unitDef.canFly then
		isAirUnit[unitDefID] = true
		if unitDef.isBuilder then
    		isAirCon[unitDefID] = true
		end
	end
end

if gadgetHandler:IsSyncedCode() then

	local airbases = {} -- airbaseID = { int pieceNum = unitID reservedFor }
	local planes = {}

	local pendingLanders = {} -- unitIDs of planes that want repair and are waiting to be assigned airbases
	local landingPlanes = {} -- planes that are in the process of landing on (including flying towards) airbases; [1]=airbaseID, [2]=pieceNum
	local tractorPlanes = {} -- planes in the final stage of landing, are "tractor beamed" with movectrl into place
	local landedPlanes = {} -- unitIDs of planes that are currently landed in airbases

	local toRemove = {} -- planes waiting to be removed (but which have to wait because we are in the middle of a pairs() interation over their info tables)
	local previousHealFrame = 0

	local tractorSpeed = 3
	local rotTractorSpeed = 0.07
	local math_sqrt = math.sqrt
	local math_pi = math.pi
	local math_sin = math.sin
	local math_cos = math.cos
	local math_huge = math.huge
	local math_random = math.random
	local math_min = math.min

	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
	local spGetUnitSeparation = Spring.GetUnitSeparation
	local spGetUnitHealth = Spring.GetUnitHealth
	local spGetUnitStates = Spring.GetUnitStates
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
	local spValidUnitID = Spring.ValidUnitID
	local spGetUnitRadius = Spring.GetUnitRadius
	local spGetUnitRotation = Spring.GetUnitRotation
	local spGetUnitTeam = Spring.GetUnitTeam

	local CMD_INSERT = CMD.INSERT
	local CMD_REMOVE = CMD.REMOVE
	local CMD_MOVE = CMD.MOVE
	local CMD_WAIT = CMD.WAIT

	local toRemoveCount

	local unitBuildtime = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		unitBuildtime[unitDefID] = unitDef.buildTime
	end

	---------------------------
	-- custom commands

	local landAtAnyAirbaseCmd = {
		id = CMD_LAND_AT_AIRBASE,
		name = "Land At Airbase",
		action = "landatairbase",
		cursor = 'landatairbase',
		type = CMDTYPE.ICON,
		tooltip = "Airbase: Tells the unit to land at the nearest available airbase for repairs",
		hidden = true,
		queueing = true,
	}

	local landAtSpecificAirbaseCmd = {
		id = CMD_LAND_AT_SPECIFIC_AIRBASE,
		name = "Land At Specific Airbase",
		action = "landatspecificairbase",
		cursor = 'landatspecificairbase',
		type = CMDTYPE.ICON_UNIT,
		tooltip = "Airbase: Tells the unit to land at an airbase for repairs ",
		hidden = true,
		queueing = true,
	}

	function InsertLandAtAirbaseCommands(unitID)
		Spring.InsertUnitCmdDesc(unitID, landAtAnyAirbaseCmd)
		Spring.InsertUnitCmdDesc(unitID, landAtSpecificAirbaseCmd)
	end

	---------------------------------------
	-- helper funcs (pads)

	function AddAirBase(unitID)
		-- add the pads of this airbase to our register
		local airbasePads = {}
		local pieceMap = Spring.GetUnitPieceMap(unitID)
		for pieceName, pieceNum in pairs(pieceMap) do
			if pieceName:find("pad", nil, true) then
				airbasePads[pieceNum] = false -- value is whether or not the pad is reserved
			end
		end
		airbases[unitID] = airbasePads
	end

	function FindAirBase(unitID)
		-- find the nearest airbase with a free pad
		local minDist = math_huge
		local closestAirbaseID
		local closestPieceNum
		for airbaseID, _ in pairs(airbases) do
			local pieceNum = CanLandAt(unitID, airbaseID)
			if pieceNum then
				local dist = spGetUnitSeparation(unitID, airbaseID)
				if dist < minDist then
					minDist = dist
					closestAirbaseID = airbaseID
					closestPieceNum = pieceNum
				end
			end
		end

		return closestAirbaseID, closestPieceNum
	end

	function CanLandAt(unitID, airbaseID)
		-- return either false (-> cannot land at this airbase) or the piece number of a free pad within this airbase

		-- check that this airbase has pads (needed?)
		local airbasePads = airbases[airbaseID]
		if not airbasePads then
			return false
		end

		-- check that this airbase is on our team
		local unitTeamID = spGetUnitTeam(unitID)
		local airbaseTeamID = spGetUnitTeam(airbaseID)
		if not unitTeamID or not airbaseTeamID or not Spring.AreTeamsAllied(unitTeamID, airbaseTeamID) then
			return false
		end

		-- try to find a vacant pad within this airbase
		local padPieceNum = false
		for pieceNum, reservedBy in pairs(airbasePads) do
			if reservedBy == false then
				padPieceNum = pieceNum
				break
			end
		end
		return padPieceNum
	end

	---------------------------------------
	-- helper funcs (main)

	function RemovePlane(unitID)
		-- remove this plane from our bookkeeping
		pendingLanders[unitID] = nil
		if landingPlanes[unitID] then
			RemoveLandingPlane(unitID)
		end
		if tractorPlanes[unitID] then
			RemoveTractorPlane(unitID)
		end
		landedPlanes[unitID] = nil

		RemoveOrderFromQueue(unitID, CMD_LAND_AT_SPECIFIC_AIRBASE)
		RemoveOrderFromQueue(unitID, CMD_LAND_AT_AIRBASE)
	end

	function RemoveLandingPlane(unitID)
		-- free up the pad that this landingPlane had reserved
		local airbaseID, pieceNum = landingPlanes[unitID][1], landingPlanes[unitID][2]
		local airbasePads = airbases[airbaseID]
		if airbasePads then
			airbasePads[pieceNum] = false
		end
		landingPlanes[unitID] = nil
	end

	function RemoveTractorPlane(unitID)
		-- free up the pad that this tractorPlane had reserved
		local airbaseID, pieceNum = tractorPlanes[unitID][1], tractorPlanes[unitID][2]
		local airbasePads = airbases[airbaseID]
		if airbasePads then
			airbasePads[pieceNum] = false
		end
		tractorPlanes[unitID] = nil
		-- release its move ctrl
		Spring.MoveCtrl.Disable(unitID)
	end

	function AttachToPad(unitID, airbaseID, padPieceNum)
		Spring.UnitAttach(airbaseID, unitID, padPieceNum)
	end

	function DetachFromPad(unitID)
		-- if this unitID was in a pad, detach the unit and free that pad
		local airbaseID = Spring.GetUnitTransporter(unitID)
		if not airbaseID then
			return
		end
		local airbasePads = airbases[airbaseID]
		if not airbasePads then
			return
		end
		for pieceNum, reservedBy in pairs(airbasePads) do
			if reservedBy == unitID then
				airbasePads[pieceNum] = false
			end
		end
		Spring.UnitDetach(unitID)
	end

	---------------------------------------
	-- helper funcs (other)

	function NeedsRepair(unitID)
		-- check if this unitID (which is assumed to be a plane) would want to land
		local health, maxHealth, _, _, buildProgress = spGetUnitHealth(unitID)
		if maxHealth then
			local landAtState = select(3, spGetUnitStates(unitID, false, true, true)) -- autorepairlevel
			if buildProgress and buildProgress < 1 then
				return false
			end
			return health < maxHealth * landAtState
		else
			return false
		end
	end

	function CheckAll()
		-- check all units to see if any need healing
		for unitID, _ in pairs(planes) do
			if not landingPlanes[unitID] and not landedPlanes[unitID] and not tractorPlanes[unitID] and NeedsRepair(unitID) then
				pendingLanders[unitID] = true
			end
		end
	end

	function FlyAway(unitID, airbaseID)
		-- hack, after detaching units don't always continue with their command q
		GiveWaitWaitOrder(unitID)

		-- if the unit has no orders, tell it to move a little away from the airbase
		local q = Spring.GetUnitCommandCount(unitID)
		if q == 0 then
			local px, _, pz = spGetUnitPosition(airbaseID)
			local theta = math_random() * 2 * math_pi
			local r = 2.5 * spGetUnitRadius(airbaseID)
			local tx, tz = px + r * math_sin(theta), pz + r * math_cos(theta)
			local ty = Spring.GetGroundHeight(tx, tz)
			--local uDID = Spring.GetUnitDefID(unitID)
			--local cruiseAlt = UnitDefs[uDID].cruiseAltitude
			Spring.GiveOrderToUnit(unitID, CMD_MOVE, { tx, ty, tz }, 0)
		end
	end

	function HealUnit(unitID, airbaseID, resourceFrames, h, mh)
		if resourceFrames <= 0 then
			return
		end
		local airbaseDefID = spGetUnitDefID(airbaseID)
		local unitDefID = spGetUnitDefID(unitID)
		--local healthGain = (mh * (isAirbase[airbaseDefID][2] / unitBuildtime[unitDefID])) * resourceFrames
		local healthGain = (unitBuildtime[unitDefID] / isAirbase[airbaseDefID][2]) / resourceFrames
		local newHealth = math_min(h + healthGain, mh)
		if mh < newHealth then
			newHealth = mh
		end
		Spring.SetUnitHealth(unitID, newHealth)
	end

	function RemoveOrderFromQueue(unitID, cmdID)
		if not spValidUnitID(unitID) then
			return
		end
		Spring.GiveOrderToUnit(unitID, CMD_REMOVE, { cmdID }, { "alt" })
	end

	function GiveWaitWaitOrder(unitID)
		-- hack
		Spring.GiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
		Spring.GiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
	end

	---------------------------------------
	-- unit creation, destruction, etc

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if isAirUnit[unitDefID] then
			planes[unitID] = true
			InsertLandAtAirbaseCommands(unitID)
		end

		if not Spring.GetUnitIsBeingBuilt(unitID) then
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end

	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if isAirbase[unitDefID] then
			AddAirBase(unitID)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if not planes[unitID] and not airbases[unitID] then
			return
		end

		if planes[unitID] then
			RemovePlane(unitID)
			planes[unitID] = nil
		end

		if airbases[unitID] then
			for pieceNum, planeID in pairs(airbases[unitID]) do
				if planeID then
					RemovePlane(planeID)
				end
			end
			airbases[unitID] = nil
		end
	end

	---------------------------------------
	-- custom command handling

	function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		if not isAirUnit[unitDefID] then
			return false
		end

		-- handle our two custom commands
		if cmdID == CMD_LAND_AT_SPECIFIC_AIRBASE then
			if landedPlanes[unitID] then
				-- this order is now completed
				return true, true
			end

			if landingPlanes[unitID] or tractorPlanes[unitID] then
				-- this order is not yet completed, call CommandFallback again
				return true, false
			end

			-- this order has just reached the top of the command queue and we are not a landingPlane
			-- process the order and make us into a landing plane!

			-- find out if the desired airbase has a free pad
			local airbaseID = cmdParams[1]
			local pieceNum = CanLandAt(unitID, airbaseID)
			if not pieceNum then
				return true, false  -- its not possible to land here
			end

			-- reserve pad
			airbases[airbaseID][pieceNum] = unitID
			landingPlanes[unitID] = { airbaseID, pieceNum }
			--SendToUnsynced("SetUnitLandGoal", unitID, airbaseID, pieceNum)
			return true, false
		end

		if cmdID == CMD_LAND_AT_AIRBASE then
			if landingPlanes[unitID] or tractorPlanes[unitID] or landedPlanes[unitID] then
				-- finished processing
				return true, true
			end

			pendingLanders[unitID] = true
			return true, false
		end

		return false
	end

	--function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	--	return true
	--end

	function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		if cmdID ~= CMD_LAND_AT_SPECIFIC_AIRBASE then
			return
		end

		Spring.ClearUnitGoal(unitID)
	end

	function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		-- if a plane is given a command, assume the user wants that command to be actioned and release control
		-- (unless its one of our custom commands, etc)
		if not planes[unitID] then
			return
		end
		if cmdID == CMD_LAND_AT_AIRBASE then
			return
		end
		if cmdID == CMD_LAND_AT_SPECIFIC_AIRBASE then
			return
		end --fixme: case of wanting to force land at a different pad than current reserved
		if cmdID == CMD_INSERT and cmdParams[2] == CMD_LAND_AT_AIRBASE then
			return
		end
		if cmdID == CMD_INSERT and cmdParams[2] == CMD_LAND_AT_SPECIFIC_AIRBASE then
			return
		end
		if cmdID == CMD_REMOVE then
			return
		end

		-- release control of this plane
		if landingPlanes[unitID] then
			RemoveLandingPlane(unitID)
		elseif landedPlanes[unitID] then
			DetachFromPad(unitID)
		end

		-- and remove it from our book-keeping
		-- (in many situations, unless the user changes the RepairAt level, it will be quickly reinserted, but we have to assume that's what they want!)
		landingPlanes[unitID] = nil
		landedPlanes[unitID] = nil
		pendingLanders[unitID] = nil
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID)
		-- when a plane is damaged, check to see if it needs repair, move to pendingLanders if so
		--Spring.Echo("damaged", unitID)
		if planes[unitID] and not landingPlanes[unitID] and not landedPlanes[unitID] and NeedsRepair(unitID) then
			pendingLanders[unitID] = true
		end
	end

	function gadget:GameFrame(n)
		-- main loop --
		-- in all cases, planes/pads may die at any time, and UnitDestroyed will take care of the book-keeping
		toRemove = {}
		toRemoveCount = 0
		-- very occasionally, check all units to see if any planes (outside of our records) that need repair
		-- add them to pending landers, if so
		if n % 72 == 0 then
			CheckAll()
		end

		-- assign airbases & pads to planes in pendingLanders, if possible
		-- once done, move into landingPlanes
		if n % 16 == 0 then
			for unitID, _ in pairs(pendingLanders) do
				--Spring.Echo("pending", unitID)
				local h, mh = spGetUnitHealth(unitID)
				if h == mh then
					toRemoveCount = toRemoveCount + 1
					toRemove[toRemoveCount] = unitID
				end

				local airbaseID, pieceNum = FindAirBase(unitID)
				if airbaseID then
					-- reserve pad, give landing order to unit
					airbases[airbaseID][pieceNum] = unitID
					landingPlanes[unitID] = { airbaseID, pieceNum }
					pendingLanders[unitID] = nil
					Spring.SetUnitLoadingTransport(unitID, airbaseID)
					RemoveOrderFromQueue(unitID, CMD_LAND_AT_AIRBASE)
					Spring.GiveOrderToUnit(unitID, CMD_INSERT, { 0, CMD_LAND_AT_SPECIFIC_AIRBASE, 0, airbaseID }, { "alt" })
				end
			end
		end

		-- fly towards pad
		-- once 'close enough' snap into pads, then move into landedPlanes
		if n % 2 == 0 then
			for unitID, t in pairs(landingPlanes) do
				if not spValidUnitID(unitID) or spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
					toRemoveCount = toRemoveCount + 1
					toRemove[toRemoveCount] = unitID
				else
					--Spring.Echo("landing", unitID)
					local h, mh = spGetUnitHealth(unitID)
					if h == mh then
						toRemoveCount = toRemoveCount + 1
						toRemove[toRemoveCount] = unitID
					end

					local airbaseID, padPieceNum = t[1], t[2]
					local px, py, pz = spGetUnitPiecePosDir(airbaseID, padPieceNum)
					local ux, uy, uz = spGetUnitPosition(unitID)
					local sqrDist = (ux and px) and (ux - px) * (ux - px) + (uy - py) * (uy - py) + (uz - pz) * (uz - pz)
					if sqrDist and h < mh then
						-- check if we're close enough, move into tractorPlanes if so
						local airbaseDefID = spGetUnitDefID(airbaseID)
						if airbaseDefID and sqrDist < isAirbase[airbaseDefID][1] then
							-- land onto pad
							landingPlanes[unitID] = nil
							tractorPlanes[unitID] = { airbaseID, padPieceNum }
							Spring.MoveCtrl.Enable(unitID)
						elseif px then
							-- fly towards pad (the pad may move!)
							local radius = spGetUnitRadius(unitID)
							if radius then
								local unitDefID = Spring.GetUnitDefID(unitID)
								if isAirUnit[unitDefID] and uy > Spring.GetGroundHeight(ux,uz)+10 then -- maybe landed planes are "not a flying unit" so lets try checking ground height
									local moveTypeData = Spring.GetUnitMoveTypeData(unitID)

									if moveTypeData.aircraftState and moveTypeData.aircraftState ~= "crashing" then --#attempt 12
										-- crashing aircraft probably dont count as 'flying units', attempt #10 at fixing "not a flying unit"
										Spring.SetUnitLandGoal(unitID, px, py, pz, radius)	-- sometimes this gives an error: "not a flying unit"
									end

								end
							end
						end
					end
				end
			end
		end

		-- move ctrl for final stage of landing
		for unitID, t in pairs(tractorPlanes) do
			--Spring.Echo("tractor", unitID)
			local airbaseID, padPieceNum = t[1], t[2]
			local px, py, pz = spGetUnitPiecePosDir(airbaseID, padPieceNum)
			local ux, uy, uz = spGetUnitPosition(unitID)
			local upitch, uyaw, uroll = spGetUnitRotation(unitID)
			local ppitch, pyaw, proll = spGetUnitRotation(airbaseID)
			local sqrDist = (ux and px) and (ux - px) * (ux - px) + (uy - py) * (uy - py) + (uz - pz) * (uz - pz)
			local rotSqrDist = (upitch and ppitch) and (upitch - ppitch) * (upitch - ppitch) + (uyaw - pyaw) * (uyaw - pyaw) + (uroll - proll) * (uroll - proll)
			if sqrDist and rotSqrDist then
				if sqrDist < tractorSpeed and rotSqrDist < rotTractorSpeed/2 then
					-- snap into place
					tractorPlanes[unitID] = nil
					landedPlanes[unitID] = airbaseID
					AttachToPad(unitID, airbaseID, padPieceNum)
					Spring.MoveCtrl.Disable(unitID)
					Spring.SetUnitLoadingTransport(unitID, nil)
					RemoveOrderFromQueue(unitID, CMD_LAND_AT_SPECIFIC_AIRBASE) -- also clears the move goal by triggering widget:UnitCmdDone
				else
					-- tractor towards pad
					if sqrDist >= tractorSpeed then
						local dx, dy, dz = px - ux, py - uy, pz - uz
						local velNormMult = tractorSpeed / math_sqrt(dx * dx + dy * dy + dz * dz)
						local vx, vy, vz = dx * velNormMult, dy * velNormMult, dz * velNormMult
						Spring.MoveCtrl.SetPosition(unitID, ux + vx, uy + vy, uz + vz)
					end
					if rotSqrDist >= rotTractorSpeed/2 then
						local dpitch, dyaw, droll = ppitch - upitch, pyaw - uyaw, proll - uroll
						local rotNormMult = rotTractorSpeed / math_sqrt(dpitch * dpitch + dyaw * dyaw + droll * droll)
						local rpitch, ryaw, rroll = dpitch * rotNormMult, dyaw * rotNormMult, droll * rotNormMult
						Spring.MoveCtrl.SetRotation(unitID, upitch + rpitch, uyaw + ryaw, uroll + rroll)
					end
				end
			else
				tractorPlanes[unitID] = nil
			end
		end

		-- heal landedPlanes
		-- release if fully healed
		if n % 8 == 0 then
			local resourceFrames = (n - previousHealFrame) / 30
			for unitID, airbaseID in pairs(landedPlanes) do
				--Spring.Echo("landed", unitID)
				local h, mh = spGetUnitHealth(unitID)
				if h and h == mh then
					-- fully healed
					landedPlanes[unitID] = nil
					DetachFromPad(unitID)
					FlyAway(unitID, airbaseID)
					--Spring.Echo("released", unitID)
				elseif h then
					-- still needs healing
					HealUnit(unitID, airbaseID, resourceFrames, h, mh)
				end
			end
			previousHealFrame = n
		end


		-- get rid of planes that have (auto-)healed themselves before reaching the pad
		for _, unitID in ipairs(toRemove) do
			RemovePlane(unitID)
		end
	end

	function gadget:Initialize()
		-- dummy UnitCreated events for existing units, to handle luarules reload
		-- release any planes currently attached to anything else
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			local unitDefID = spGetUnitDefID(unitID)
			--local teamID = spGetUnitTeam(unitID)
			gadget:UnitCreated(unitID, unitDefID)

			local transporterID = Spring.GetUnitTransporter(unitID)
			if transporterID and isAirUnit[unitDefID] then
				Spring.UnitDetach(unitID)
			end
		end

	end

	function gadget:ShutDown()
		for unitID, _ in pairs(tractorPlanes) do
			Spring.MoveCtrl.Disable(unitID)
		end
	end


else	-- Unsynced


	local landAtAirBaseCmdColor = { 0.50, 1.00, 1.00, 0.8 } -- same colour as repair

	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetSelectedUnits = Spring.GetSelectedUnits

	local myTeamID = Spring.GetMyTeamID()

	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_LAND_AT_SPECIFIC_AIRBASE, "landatairbase", landAtAirBaseCmdColor, false)
		Spring.SetCustomCommandDrawData(CMD_LAND_AT_AIRBASE, "landatspecificairbase", landAtAirBaseCmdColor, false)
		Spring.AssignMouseCursor("landatspecificairbase", "cursorrepair", false, false)
	end

	function gadget:PlayerChanged()
		myTeamID = Spring.GetMyTeamID()
	end

	function gadget:DefaultCommand(type, id, cmd)
		if type == "unit" and isAirbase[spGetUnitDefID(id)] then
			if Spring.GetUnitIsBeingBuilt(id) or not spAreTeamsAllied(myTeamID, spGetUnitTeam(id)) then
				return
			end

			local units = spGetSelectedUnits()

			for i = 1, #units do
				local unitDefID = spGetUnitDefID(units[i])

				if isAirUnit[unitDefID] and not isAirCon[unitDefID] then
					return CMD_LAND_AT_SPECIFIC_AIRBASE
				end
			end
		end
	end

end
