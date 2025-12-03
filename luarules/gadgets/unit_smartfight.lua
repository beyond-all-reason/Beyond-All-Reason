local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Smart Fight",
		desc = "Stable Release. Robust nil-checks. Global Capture Safety. Purple Visuals.",
		author = "Slouse",
		date = "03-12-2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local CMD_SMARTFIGHT = 39955
local CMD_INSERT     = CMD.INSERT
local CMD_MOVE       = CMD.MOVE
local CMD_ATTACK     = CMD.ATTACK
local CMD_REMOVE     = CMD.REMOVE
local CMD_CAPTURE    = CMD.CAPTURE
local OPT_INTERNAL   = {"alt", "internal"} -- Hide from UI

--------------------------------------------------------------------------------
-- SYNCED CODE
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	local spGetUnitPosition     = Spring.GetUnitPosition
	local spGetUnitCommands     = Spring.GetUnitCommands
	local spGiveOrderToUnit     = Spring.GiveOrderToUnit
	local spGetUnitTeam         = Spring.GetUnitTeam
	local spGetUnitAllyTeam     = Spring.GetUnitAllyTeam
	local spValidUnitID         = Spring.ValidUnitID
	local spGetUnitSeparation   = Spring.GetUnitSeparation
	local spGetUnitHealth       = Spring.GetUnitHealth
	local spGetGaiaTeamID       = Spring.GetGaiaTeamID
	local spGetUnitNeutral      = Spring.GetUnitNeutral
	local spGetGroundHeight     = Spring.GetGroundHeight
	local spGetUnitStates       = Spring.GetUnitStates
	
	local gaiaTeamID = spGetGaiaTeamID()
	
	local commandUpdateQueue = {}
	local activeUnits = {}
	
	-- Global Safety Registries
	local activeCapturers = {}
	local protectedTargets = {}

	--------------------------------------------------------------------------------
	-- INITIALIZATION
	--------------------------------------------------------------------------------
	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_SMARTFIGHT)
		
		-- Watch weapons for mobile units only (Optimization)
		for unitDefID, unitDef in pairs(UnitDefs) do
			if unitDef.canMove and (not unitDef.isBuilding) and unitDef.weapons then
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

	-- CRASH-PROOF ALLOW WEAPON TARGET
	function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defaultPriority)
		-- 1. Safety Checks (Nil Handling)
		if not targetID or not attackerID then return true, defaultPriority end

		-- 2. Fast Lookup: Is this target protected?
		local capturingTeam = protectedTargets[targetID]
		if not capturingTeam then return true, defaultPriority end

		-- 3. Anti-Grief: Only block if Attacker & Capturer are SAME TEAM
		local attackerTeam = spGetUnitTeam(attackerID)
		if not attackerTeam then return true, defaultPriority end -- Safety
		
		if attackerTeam ~= capturingTeam then return true, defaultPriority end
		
		-- 5. Block Fire
		return false
	end

	--------------------------------------------------------------------------------
	-- SMART FIGHT LOGIC
	--------------------------------------------------------------------------------
	-- Line Ax, Az - Bx, Bz. 
	-- Unit Position Px, Pz
	-- Returns closest point and progress along line `t`
	local function GetClosestPointOnLine(Ax, Az, Bx, Bz, Px, Pz)
		-- Nil Check inputs to be safe
		if not Ax or not Az or not Bx or not Bz or not Px or not Pz then return 0,0,0 end
		
		local APx, APz = Px - Ax, Pz - Az
		local ABx, ABz = Bx - Ax, Bz - Az
		local ab2 = ABx*ABx + ABz*ABz
		local ap_ab = APx*ABx + APz*ABz
		if ab2 <= 0.001 then return Ax, Az, 0 end
		local t = ap_ab / ab2
		if t < 0 then t = 0 end
		if t > 1 then t = 1 end
		return Ax + ABx * t, Az + ABz * t, t
	end

	local function GetBestTarget(unitID)
		local teamID = spGetUnitTeam(unitID)
		local allyTeamID = spGetUnitAllyTeam(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)
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
				local unitInLOS = Spring.IsUnitInLos(targetID, allyTeamID)

				if unitInLOS then
					local capturingTeam = protectedTargets[targetID]
					local isProtectedFromMe = (capturingTeam == teamID)
					
					if not isProtectedFromMe then
						local targetTeam = spGetUnitTeam(targetID)
						local isGaia = (targetTeam == gaiaTeamID)
						local isNeutral = spGetUnitNeutral(targetID)
						
						if (not isGaia) and (not isNeutral) and (not Spring.AreTeamsAllied(teamID, targetTeam)) then
							local dist = spGetUnitSeparation(unitID, targetID, true) or math.huge
							if dist < bestDist then
								bestDist = dist
								bestTarget = targetID
							end
						end
					end
				end -- End LOS check
			end
		end
		return bestTarget
	end

	function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		if cmdID ~= CMD_SMARTFIGHT then return false end
		if commandUpdateQueue[unitID] then return true, false end

		-- Validate Params
		if not cmdParams or #cmdParams < 3 then
			-- Fallback to unit click
			if cmdParams and #cmdParams == 1 and spValidUnitID(cmdParams[1]) then
				spGiveOrderToUnit(unitID, CMD_ATTACK,cmdParams[1])
			end
			return true, true -- Finish command
		end

		local targetX, targetY, targetZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local unitX, _, unitZ = spGetUnitPosition(unitID)
		
		-- Safety check: Unit might have died this frame
		if not unitX then return true, false end

		local distSq = (unitX - targetX)^2 + (unitZ - targetZ)^2
		-- We've arrived at the destination, end the command
		if distSq < 10000 then
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
					-- INTERNAL OPTION: Hides lines from engine drawer
					spGiveOrderToUnit(unitID, CMD_INSERT, {0, CMD_MOVE, 0, pos[1], pos[2], pos[3]}, OPT_INTERNAL)
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
						if cmd1.id == CMD_MOVE then
							local target = GetBestTarget(unitID)

							if target then
								local unitX, _, unitZ = spGetUnitPosition(unitID)
								
								if unitX and pathData then

								-- 1. Insert ATTACK command (Slot 0 - Immediate)
									spGiveOrderToUnit(unitID, CMD_INSERT, {0, CMD_ATTACK, 0, target}, OPT_INTERNAL)
								
									-- 2. Calculate return point on line based on CURRENT position
									local returnX, returnZ, _ = GetClosestPointOnLine(
										pathData.startX, pathData.startZ,
										pathData.endX, pathData.endZ,
										unitX, unitZ
									)
									local returnY = spGetGroundHeight(returnX, returnZ)
									
									-- 3. Insert Return MOVE command (Slot 1 - After the Attack)
									spGiveOrderToUnit(unitID, CMD_INSERT, {1, CMD_MOVE, 0, returnX, returnY, returnZ}, OPT_INTERNAL)
								end
							end
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
								Spring.Echo("Stopping Attack")
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
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if UnitDefs[unitDefID].canFight then
			local cmdDesc = {
				id      = CMD_SMARTFIGHT,
				type    = CMDTYPE.ICON_UNIT_OR_MAP,
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
	local glLineWidth        = gl.LineWidth
	local glColor            = gl.Color
	local glBeginEnd         = gl.BeginEnd
	local glVertex           = gl.Vertex
	local GL_LINE_STRIP      = GL.LINE_STRIP

	-- Fight Purple
	local LINE_COLOR = {0.6, 0.2, 0.9, 0.7} 

	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_SMARTFIGHT, CMDTYPE.ICON_UNIT_OR_MAP, LINE_COLOR, true)
	end

	function gadget:DrawWorld()
		local selectedUnits = spGetSelectedUnits()
		if #selectedUnits == 0 then return end
		
		glLineWidth(1.5)
		glColor(LINE_COLOR)

		for _, unitID in ipairs(selectedUnits) do
			local cmds = spGetUnitCommands(unitID, -1)
			
			local hasSmartFight = false
			if cmds then
				for _, cmd in ipairs(cmds) do
					if cmd.id == CMD_SMARTFIGHT then hasSmartFight = true break end
				end
			end

			if hasSmartFight then
				local unitX, unitY, unitZ = spGetUnitPosition(unitID)
				
				if unitX and unitY and unitZ then
					glBeginEnd(GL_LINE_STRIP, function()
						glVertex(unitX, unitY, unitZ)
						for _, cmd in ipairs(cmds) do
							-- Move Command
							if cmd.id == CMD.MOVE then
								if cmd.params and #cmd.params >= 3 then
									glVertex(cmd.params[1], cmd.params[2], cmd.params[3])
								end
							-- Attack Command
							elseif cmd.id == CMD.ATTACK then
								if cmd.params then
									if #cmd.params == 1 then 
										local targetID = cmd.params[1]
										if Spring.ValidUnitID(targetID) then
											local targetX, targetY, targetZ = Spring.GetUnitPosition(targetID)
											if targetX then glVertex(targetX, targetY, targetZ) end
										end
									elseif #cmd.params >= 3 then
										glVertex(cmd.params[1], cmd.params[2], cmd.params[3])
									end
								end
							-- Main SmartFight Command
							elseif cmd.id == CMD_SMARTFIGHT then
								if cmd.params and #cmd.params >= 3 then
									glVertex(cmd.params[1], cmd.params[2], cmd.params[3])
								end
								break -- End line here
							end
						end
					end)
				end
			end
		end
		
		glColor(1, 1, 1, 1)
		glLineWidth(1.0)
	end
end