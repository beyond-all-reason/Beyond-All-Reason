local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Smart Fight",
		desc = "Fight command with smart filtering to avoid attacking capture targets",
		author = "Slouse",
		date = "03-12-2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local CMD_SMARTFIGHT = GameCMD.SMARTFIGHT
local CMD_REPOSITION = GameCMD.REPOSITION
local CMD_INSERT     = CMD.INSERT
local CMD_MOVE       = CMD.MOVE
local CMD_ATTACK     = CMD.ATTACK
local CMD_REMOVE     = CMD.REMOVE
local CMD_CAPTURE    = CMD.CAPTURE

--------------------------------------------------------------------------------
-- SYNCED CODE
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	local spAreTeamsAllied		= Spring.AreTeamsAllied
	local spGetUnitPosition     = Spring.GetUnitPosition
	local spGetUnitCommands     = Spring.GetUnitCommands
	local spGiveOrderToUnit     = Spring.GiveOrderToUnit
	local spGetUnitTeam         = Spring.GetUnitTeam
	local spGetUnitAllyTeam     = Spring.GetUnitAllyTeam
	local spValidUnitID         = Spring.ValidUnitID
	local spGetUnitDefID		= Spring.GetUnitDefID
	local spGetUnitSeparation   = Spring.GetUnitSeparation
	local spGetUnitHealth       = Spring.GetUnitHealth
	local spGetGaiaTeamID       = Spring.GetGaiaTeamID
	local spGetUnitNeutral      = Spring.GetUnitNeutral
	local spGetGroundHeight     = Spring.GetGroundHeight
	local spGetUnitStates       = Spring.GetUnitStates
	local spIsUnitInLos 		= Spring.IsUnitInLos
	local spSetUnitMoveGoal		= Spring.SetUnitMoveGoal
	
	local gaiaTeamID = spGetGaiaTeamID()

	local goalRadius = 100
	
	local commandUpdateQueue = {}
	local activeUnits = {}
	
	local activeCapturers = {}
	local protectedTargets = {}

	--------------------------------------------------------------------------------
	-- INITIALIZATION
	--------------------------------------------------------------------------------
	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_SMARTFIGHT)
		
		-- Watch all weapons for target filtering
		for _, unitDef in pairs(UnitDefs) do
			if unitDef.weapons then
				for _, weapon in ipairs(unitDef.weapons) do
					if weapon.weaponDef then
						Script.SetWatchWeapon(weapon.weaponDef, true)
					end
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	-- GLOBAL SAFETY
	--------------------------------------------------------------------------------
	function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		if cmdID == CMD_CAPTURE then activeCapturers[unitID] = teamID end
	end

	function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdTag, cmdParams, cmdOptions)
		if cmdID == CMD_CAPTURE then activeCapturers[unitID] = nil end
	end

	local function UpdateProtectedTargets()
		protectedTargets = {}
		for builderID, teamID in pairs(activeCapturers) do
			local isCapturing = false
			-- Ensure builder still exists and is still capturing
			if spValidUnitID(builderID) then
				local cmd = spGetUnitCommands(builderID, 1)
				if cmd and cmd[1].id == CMD_CAPTURE then
					local targetID = cmd[1].params[1]
					if targetID then
						protectedTargets[targetID] = teamID
						isCapturing = true
					end
				end
			end
			if not isCapturing then activeCapturers[builderID] = nil end
		end
	end

	function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defaultPriority)
		-- 1. Safety Checks (Nil Handling)
		if not targetID or not attackerID then return true, defaultPriority end

		-- 2. Fast Lookup: Is this target protected?
		local capturingTeam = protectedTargets[targetID]
		if not capturingTeam then return true, defaultPriority end

		-- 3. Anti-Grief: Only block if Attacker & Capturer are SAME TEAM
		local attackerTeam = spGetUnitTeam(attackerID)
		if not attackerTeam then return true, defaultPriority end
		
		if attackerTeam ~= capturingTeam then return true, defaultPriority end
		
		-- 5. Block Fire
		return false
	end

	--------------------------------------------------------------------------------
	-- SMART FIGHT LOGIC
	--------------------------------------------------------------------------------

	local function GetBestTarget(unitID)
		local teamID = spGetUnitTeam(unitID)
		local allyTeamID = spGetUnitAllyTeam(unitID)
		local unitDefID = spGetUnitDefID(unitID)
		if not unitDefID then return nil end
		
		local unitDef = UnitDefs[unitDefID]
		local unitStates = spGetUnitStates(unitID)
		local moveState = unitStates.movestate
		local searchRadius = 0
		
		if moveState == 2 then
			searchRadius = 1000
		elseif moveState == 1 then
			searchRadius = (unitDef.maxWeaponRange) + unitDef.radius
		elseif moveState == 0 then
			return nil
		end
		
		local x, _, z = spGetUnitPosition(unitID)
		if not x then return nil end

		local potentialTargets = Spring.GetUnitsInCylinder(x, z, searchRadius)
		local bestTarget = nil
		local bestDist = math.huge

			for _, targetID in ipairs(potentialTargets) do
			if spValidUnitID(targetID) then
				
				-- LOS CHECK: Is this unit visible to my ALLYTEAM? (Visual OR Radar)
				local unitInLOS = spIsUnitInLos(targetID, allyTeamID)

				if unitInLOS then
					local capturingTeam = protectedTargets[targetID]
					local isProtectedFromMe = (capturingTeam == teamID)
					
					if not isProtectedFromMe then
						local targetTeam = spGetUnitTeam(targetID)
						local isGaia = (targetTeam == gaiaTeamID)
						local isNeutral = spGetUnitNeutral(targetID)
						
						if (not isGaia) and (not isNeutral) and (not spAreTeamsAllied(teamID, targetTeam)) then
							local dist = spGetUnitSeparation(unitID, targetID, true) or math.huge
							if dist < bestDist then
								bestDist = dist
								bestTarget = targetID
							end
						end
					end
				end
			end
		end
		return bestTarget
	end

	function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		if cmdID == CMD_REPOSITION then
			-- Logic: Read coordinates from Lua Table, Drive Unit manually.
			local data = activeUnits[unitID]
			
			-- If lost data, abort command
			if not data or not data.returnPos then return true, true end

			local targetX, targetY, targetZ = data.returnPos.x, data.returnPos.y, data.returnPos.z
			local unitX, _, unitZ = spGetUnitPosition(unitID)

			spSetUnitMoveGoal(unitID, targetX, targetY, targetZ, 16)
			local dist = math.diag(unitX - targetX, unitZ - targetZ)
			if dist < 100 then
				-- We arrived! Remove returnPos to be clean
				data.returnPos = nil
				SendToUnsynced("SMARTFIGHT_CLEAR", unitID)
				return true, true -- Command Finished
			end

			return true, false
		end
		
		if cmdID ~= CMD_SMARTFIGHT then return false end
		if commandUpdateQueue[unitID] then return true, false end

		if not cmdParams or #cmdParams < 3 then
			if cmdParams and #cmdParams == 1 and spValidUnitID(cmdParams[1]) then
				spGiveOrderToUnit(unitID, CMD_ATTACK,cmdParams[1])
			end
			return true, true
		end

		local targetX, targetY, targetZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local unitX, _, unitZ = spGetUnitPosition(unitID)
		
		-- Safety check: Unit might have died this frame
		if not unitX then return true, false end

		local dist = math.diag(unitX - targetX, unitZ - targetZ)
		-- We've arrived at the destination, end the command
		if dist < goalRadius then
			activeUnits[unitID] = nil
			return true, true
		end

		local path = activeUnits[unitID]
		if not path or math.abs(path.endX - targetX) > 1 or math.abs(path.endZ - targetZ) > 1 then
			path = { startX = unitX, startZ = unitZ, endX = targetX, endZ = targetZ}
			activeUnits[unitID] = path
		end

		local ey = spGetGroundHeight(path.endX, path.endZ)
		
		commandUpdateQueue[unitID] = { type = "GENERATE_PATH", moves = {} }
		table.insert(commandUpdateQueue[unitID].moves, {path.endX, ey, path.endZ})
		return true, false
	end

	function gadget:GameFrame(n)
		-- Process Queued Path Commands
		for unitID, task in pairs(commandUpdateQueue) do
			if spValidUnitID(unitID) and task.type == "GENERATE_PATH" then
				for _, pos in ipairs(task.moves) do
					spSetUnitMoveGoal(unitID, pos[1], pos[2], pos[3], 16)
				end
			end
			commandUpdateQueue[unitID] = nil
		end

		if n % 15 == 0 then
			UpdateProtectedTargets()
			for unitID, pathData in pairs(activeUnits) do
				if spValidUnitID(unitID) then
					local cmds = spGetUnitCommands(unitID, 6)
					local sfFound = false
					if cmds then
						for i, c in ipairs(cmds) do
							if c.id == CMD_SMARTFIGHT then sfFound = true break end
						end
					end
					
					if not sfFound then
						activeUnits[unitID] = nil
					else
						local cmd1 = cmds[1]
						
						-- STATE: MOVING (Searching for targets)
						if cmd1.id ~= CMD_ATTACK then
							local target = GetBestTarget(unitID)
							if target then
								local unitStates = spGetUnitStates(unitID)
								local isHoldPos = (unitStates and unitStates.movestate == 0)

								if not isHoldPos then
									local unitX, _, unitZ = spGetUnitPosition(unitID)
									
									if unitX and pathData then
										-- 1. Insert ATTACK command (Slot 0)
										spGiveOrderToUnit(unitID, CMD_INSERT, {0, CMD_ATTACK, 0, target}, {"alt"})
										
										-- 2. Calculate return point and STORE IN LUA
										local returnX, returnZ, _ = math.getClosestPositionOnLine(
											pathData.startX, pathData.startZ,
											pathData.endX, pathData.endZ,
											unitX, unitZ
										)
										local returnY = spGetGroundHeight(returnX, returnZ)
										
										-- Store for Fallback usage
										pathData.returnPos = {x=returnX, y=returnY, z=returnZ}
										SendToUnsynced("SMARTFIGHT_RET_POS", unitID, returnX, returnY, returnZ)
										
										-- 3. Insert DUMMY REPOSITION Command (Slot 1)
										-- No params passed to engine = No lines drawn.
										spGiveOrderToUnit(unitID, CMD_INSERT, {1, CMD_REPOSITION, 0}, {"alt"})
									end
								end
							end
						-- STATE: ATTACKING (Found target)
						elseif cmd1.id == CMD_ATTACK then
							local targetID = cmd1.params[1]
							local unitMoveState = spGetUnitStates(unitID).movestate
							local stopAttack = false
							
							if not spValidUnitID(targetID) or (spGetUnitHealth(targetID) == nil) or unitMoveState == 0 then
								stopAttack = true
							else
								local captureTeam = protectedTargets[targetID]
								if captureTeam and captureTeam == spGetUnitTeam(unitID) then
									stopAttack = true
								end
							end

							if stopAttack then
								spGiveOrderToUnit(unitID, CMD_REMOVE, CMD_ATTACK, {"alt"})
							end
						end
					end
				else
					activeUnits[unitID] = nil
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID)
		activeUnits[unitID] = nil
		commandUpdateQueue[unitID] = nil
		if activeCapturers[unitID] then activeCapturers[unitID] = nil end
		SendToUnsynced("SMARTFIGHT_CLEAR", unitID)
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if UnitDefs[unitDefID].canFight then
			local cmdDesc = {
				id      = CMD_SMARTFIGHT,
				type    = CMDTYPE.ICON_MAP,
				name    = 'Smart Fight',
				action  = 'smartfight',
				tooltip = 'Fight command. Ignores captured units.',
				cursor  = 'Fight',
			}
			Spring.InsertUnitCmdDesc(unitID, cmdDesc)
		end
	end

--------------------------------------------------------------------------------
-- UNSYNCED CODE (Visuals)
--------------------------------------------------------------------------------
else
	local spGetUnitCommands  = Spring.GetUnitCommands
	local spGetSelectedUnits = Spring.GetSelectedUnits
	local spGetUnitPosition  = Spring.GetUnitPosition
	local spGetUnitDefID     = Spring.GetUnitDefID
	local glLineWidth        = gl.LineWidth
	local glColor            = gl.Color
	local glBeginEnd         = gl.BeginEnd
	local glVertex           = gl.Vertex
	local GL_LINE_STRIP      = GL.LINE_STRIP

	local LINE_COLOR = {0.5, 0.5, 1.0, 0.55}

	local returnPositions = {}

	function gadget:RecvFromSynced(event, unitID, x, y, z)
		if event == "SMARTFIGHT_RET_POS" then
			returnPositions[unitID] = {x, y, z}
		elseif event == "SMARTFIGHT_CLEAR" then
			returnPositions[unitID] = nil
		end
	end

		function gadget:DrawWorld()
		local selectedUnits = spGetSelectedUnits()
		if #selectedUnits == 0 then return end
		
		-- 1. DATA GATHERING PHASE
		local linesToDraw = {} 
		
		for _, unitID in ipairs(selectedUnits) do
			local cmds = spGetUnitCommands(unitID, -1)
			
			local hasSmartFight = false
			if cmds then
				for _, cmd in ipairs(cmds) do
					if cmd.id == CMD_SMARTFIGHT then hasSmartFight = true break end
				end
			end

			if hasSmartFight then
				local linePoints = {}
				local unitX, unitY, unitZ = spGetUnitPosition(unitID)
				
				if unitX then
					local udID = spGetUnitDefID(unitID)
					local yOffset = 0
					if udID then yOffset = (UnitDefs[udID].height or 0) * 0.5 end

					linePoints[#linePoints+1] = {unitX, unitY + yOffset, unitZ}
					
					for _, cmd in ipairs(cmds) do
						-- Attacks
						if cmd.id == CMD.ATTACK then
							if cmd.params then
								if #cmd.params == 1 then 
									local targetID = cmd.params[1]
									if Spring.ValidUnitID(targetID) then
										local targetX, targetY, targetZ = Spring.GetUnitPosition(targetID)
										if targetX then 
											local tUD = spGetUnitDefID(targetID)
											local tOff = 0
											if tUD then tOff = (UnitDefs[tUD].height or 0) * 0.5 end
											linePoints[#linePoints+1] = {targetX, targetY + tOff, targetZ}
										end
									end
								elseif #cmd.params >= 3 then 
									linePoints[#linePoints+1] = {cmd.params[1], cmd.params[2], cmd.params[3]}
								end
							end
						
						-- Smart Fight
						elseif cmd.id == CMD_SMARTFIGHT then
							if cmd.params and #cmd.params >= 3 then
								linePoints[#linePoints+1] = {cmd.params[1], cmd.params[2], cmd.params[3]}
							end
							break
						
						-- REPOSITION
						elseif cmd.id == CMD_REPOSITION then
							local returnPos = returnPositions[unitID]
							if returnPos then
								linePoints[#linePoints+1] = {returnPos[1], returnPos[2], returnPos[3]}
							end
						end
					end
					
					if #linePoints > 1 then
						linesToDraw[#linesToDraw+1] = linePoints
					end
				end
			end
		end
		
		-- 2. DRAWING PHASE
		if #linesToDraw > 0 then
			glLineWidth(1.5)
			glColor(LINE_COLOR)

			for _, points in ipairs(linesToDraw) do
				glBeginEnd(GL_LINE_STRIP, function()
					for i = 1, #points do
						local p = points[i]
						glVertex(p[1], p[2], p[3])
					end
				end)
			end
			
			glColor(1, 1, 1, 1)
			glLineWidth(1.0)
		end
	end
end