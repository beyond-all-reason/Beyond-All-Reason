function gadget:GetInfo()
    return {
        name      = "Idle Behaviours",
        desc      = "Generates internal commands for idle behaviours",
        author    = "Doo",
        date      = "July 2025",
        license   = "GNU GPL, v2 or later",
        layer     = math.huge,
        enabled   = true
    }
end


-- This gadget is applied to idle units that have a predefined sets of idle behaviours;
-- Those idle behaviours consist of an internal command that are issued to said units, when they have reached an empty queue.
-- They should not affect the "idle" state of a unit, but simply keep it busy while it's considered idle.
-- This proof of concept version will only handle constructors and rezzers "patrol" behaviours on idling.
-- But this could be open to giving even offensive or defensive unit a certain set of commands, if this was desired


-- The logic will be as such:
-- Part 1: behaviours setup
-- We process all unit Defs and extract the defs that should trigger an Idle behaviour.
-- For the purpose of this proof of concept, these behaviours will be hardcoded here; but there will be the possibility to either include them in unitDefs or in a separate config file.
-- Upon unitCreated, we add a custom command to that unit: an Idle Behaviour toggle to cycle through all available behaviours for this unitDef
-- We handle this custom command so that enabled behaviours can be processed.

-- Part 2: Apply the Behaviours
-- When a unit goes idle; apply its active Idle Behaviour cmd as an internal command (not showing in queue); while making sure this doesn't actually count as a command and it remains considered as idle for other gadgets and widgets.



if (not gadgetHandler:IsSyncedCode()) then



else -- SYNCED
	local hashes = {}
	local jobs = {}
	local function GiveIdleOrderToUnit(unitID, cmdID, cmdParams, cmdOptions)
		-- local hash = Spring.GetGameFrame()*unitID*cmdID
		-- hashes[unitID] = hash
		Spring.GiveOrderToUnit(unitID, cmdID, cmdParams, cmdOptions)
		-- There is probably a way to get another form of tag that doesn't depend on GameFrame(), in order to remove from Q when getting out of idle state when this happens on another gameFrame
		-- Figured out how to use CMD.OPT_INTERNAL, so it's unneeded now
	end
		
	-- Part 1.1: Process all unit Defs
	local idleBehaviours = {
		RepairAndAssist = {
			testFunc = function (defs)
				if defs.canRepair or defs.canAssist then
					return true
				else
					return false
				end
				end,
			applyFunc = function (uid)
				local ux,uy,uz = Spring.GetUnitPosition(uid)
				local cmd = {
				ID = CMD.PATROL,
				pos = {x = ux + 16, y = uy, z = uz + 16},
				modifiers = CMD.OPT_META + CMD.OPT_INTERNAL,-- not exactly a no reclaim, but rather a reclaim enemy units only modifier; which means it wont reclaim wrecks
				}
				GiveIdleOrderToUnit(uid, cmd.ID, {cmd.pos.x, cmd.pos.y, cmd.pos.z}, cmd.modifiers)
				end,
			name = "Repair and Assist",
		},
		
		
		ReclaimRepairAndAssist = {
			testFunc = function (defs)
				if defs.canReclaim and (defs.canRepair or defs.canAssist) then
					return true
				else
					return false
				end
				end,
			applyFunc = function (uid)
				local ux,uy,uz = Spring.GetUnitPosition(uid)
				local cmd = {
				ID = CMD.PATROL,
				pos = {x = ux + 16, y = uy, z = uz + 16},
				modifiers = CMD.OPT_INTERNAL,
				}
				GiveIdleOrderToUnit(uid, cmd.ID, {cmd.pos.x, cmd.pos.y, cmd.pos.z}, cmd.modifiers)
				end,
			name = "Reclaim, Repair and Assist",
		},
		
		
		RezReclaimRepairAndAssist = {
			testFunc = function (defs)
				if defs.canResurrect and defs.canReclaim and (defs.canRepair or defs.canAssist) then
					return true
				else
					return false
				end
				end,
			applyFunc = function (uid)
				local ux,uy,uz = Spring.GetUnitPosition(uid)
				local cmd = {
				ID = CMD.PATROL,
				pos = {x = ux + 16, y = uy, z = uz + 16},
				modifiers = CMD.OPT_ALT + CMD.OPT_INTERNAL,
				}
				GiveIdleOrderToUnit(uid, cmd.ID, {cmd.pos.x, cmd.pos.y, cmd.pos.z}, cmd.modifiers)
				end,
			name = "Rez, Reclaim, Repair and Assist",
		},	
		}
	
	local defsBehaviours = {} -- defsBehaviours[UnitDefID] = {[1] = idleBehaviours[name_of_the_behaviour],...}
	local unitBehaviour = {} -- unitBehaviour[unitID] = defsBehaviours[UnitDefID][idlebehcmdstate]
	local CMD_IDLE_BEHAVIOURS = 37384
	local idleStates = {}
	
	
	function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_IDLE_BEHAVIOURS)
		for unitDefID, defs in pairs (UnitDefs) do
			for name,funcs in pairs(idleBehaviours) do
				if funcs.testFunc(defs) == true then
					defsBehaviours[unitDefID] = defsBehaviours[unitDefID] or {}
					defsBehaviours[unitDefID][#defsBehaviours[unitDefID]+1] = funcs
				end
			end
		end
	for k,v in pairs (Spring.GetAllUnits()) do
		local defID = Spring.GetUnitDefID(v)
		if defsBehaviours[defID] then
			gadget:UnitCreated(v, defID)
		end
	end
		
	end
	
	-- Part 1.2 - Create the custom command when the unit is created
	
	local IdleBehavioursToggleCmdDesc = {
		id = CMD_IDLE_BEHAVIOURS,
		type = CMDTYPE.ICON_MODE,
		name = 'Idle Behaviours',
		action = 'idlebehaviours',
		cursor = 'idlebehaviours',
		tooltip = "Controls the wanted behaviours for selected unit",
		params = {},
	}

	
	local function CreateCommand(unitId, unitDefID, behaviours)
		local editedDesc = IdleBehavioursToggleCmdDesc
		editedDesc.params[1] = 0
		for i = 1, #behaviours do
			editedDesc.params[1+i] = behaviours[i].name
		end
		Spring.InsertUnitCmdDesc(unitId, editedDesc)
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if defsBehaviours[unitDefID] then -- You'd probably want either an ignorelist for units that should not benefit, or better check functions for idleBehaviours into defsBehaviours pregame process
			CreateCommand(unitID, unitDefID, defsBehaviours[unitDefID])
			unitBehaviour[unitID] = defsBehaviours[unitDefID][1]
			gadget:UnitIdle(unitID, unitDefID)
		end
	end
	
	function gadget:UnitDestroyed(unitID)
		idleStates[unitID] = nil
	end

	local function AddIdleTag(unitID) -- We need this function to communicate to unsynced widgets now, so the idlebuilders list can properly get updated in real time
		idleStates[unitID] = 1
		Spring.SetUnitRulesParam(unitID, "idlestate", 1)
	end
	local function RemoveIdleTag(unitID) -- We need this function to communicate to unsynced widgets now, so the idlebuilders list can properly get updated in real time
		idleStates[unitID] = 0
		Spring.SetUnitRulesParam(unitID, "idlestate", 0)
	end
	
	-- Part 1.3: apply behaviours changes when the command is used
	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
		if not defsBehaviours[unitDefID] then
			return true
		end
		if cmdID == CMD_IDLE_BEHAVIOURS then
			local cmdIdx = Spring.FindUnitCmdDesc(unitID, CMD_IDLE_BEHAVIOURS)
		    local cmdDesc = Spring.GetUnitCmdDescs(unitID, cmdIdx, cmdIdx)[1]
            cmdDesc.params[1] = cmdParams[1]
			Spring.EditUnitCmdDesc(unitID, cmdIdx, cmdDesc)
			unitBehaviour[unitID] = defsBehaviours[unitDefID][cmdParams[1]+1]
			return false
		end
		return true
	end
	
	local function RemoveFromQueue(unitID, tag)
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {tag}, {})
	end
		
	
	function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if not defsBehaviours[unitDefID] then
			return
		end
		if cmdOptions.internal == true and cmdID == CMD.PATROL then
			return
		end
		
		if cmdID == CMD.REMOVE then
			return
		end
		if idleStates[unitID] == 1 then
			local Q = Spring.GetUnitCommands(unitID, 10)
			if Q then
				for position,cmdData in pairs (Q) do
					if cmdData.options.internal == true then
						local tag = cmdData.tag
						RemoveFromQueue(unitID, tag)
					end
				end
			end
			RemoveIdleTag(unitID)
		end
	end
	
	-- part 2: apply the behaviour when the unit is idle
	function gadget:UnitIdle(unitID, unitDefID, unitTeam)
		if not defsBehaviours[unitDefID] then
			return
		end
		AddIdleTag(unitID)
		if unitBehaviour[unitID] then
			-- quote this out if you want instantaneous cmd
			local job = {
			func = unitBehaviour[unitID].applyFunc,
			unitID = unitID,
			frame = (Spring.GetGameFrame() + 90)
			}
			table.insert(jobs, job)
			-- unitBehaviour[unitID].applyFunc(unitID) -- use this if you want instantaneous
		end
	end
	
	-- quote this out if you want instantaneous cmd
	function gadget:GameFrame(f)
		if f%30 == 0 then
			if #jobs > 0 then
				for i, job in pairs (jobs) do
					if job.frame >= f then
						if idleStates[job.unitID] and idleStates[job.unitID] == 1 then
							job.func(job.unitID)
						end
						table.remove(jobs,i)
					end
				end
			end
		end
	end
end
