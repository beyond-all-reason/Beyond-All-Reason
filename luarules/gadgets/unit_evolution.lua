

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Evolution",
		desc = "Evolves a unit permanently into another unit when certain criteria are met",
		author = "Xehrath",
		date = "2023-03-31",
		license = "None",
		layer = 50,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then

	local spCreateUnit            = Spring.CreateUnit
	local spDestroyUnit           = Spring.DestroyUnit
	local spGiveOrderToUnit       = Spring.GiveOrderToUnit
	local spSetUnitRulesParam     = Spring.SetUnitRulesParam
	local spGetUnitPosition       = Spring.GetUnitPosition
	local spGetUnitStates = Spring.GetUnitStates
	local spGetUnitHealth 		= Spring.GetUnitHealth

	local spGetTeamList			= Spring.GetTeamList
	local spGetUnitExperience	= Spring.GetUnitExperience
	local spGetUnitTeam 		= Spring.GetUnitTeam
	local spGetUnitDirection 	= Spring.GetUnitDirection
	local spGetUnitStockpile 	= Spring.GetUnitStockpile
	local spEcho = Spring.Echo
	local spSetUnitHealth = Spring.SetUnitHealth

	local spSetUnitExperience = Spring.SetUnitExperience
	local spSetUnitStockpile = Spring.SetUnitStockpile
	local spSetUnitDirection = Spring.SetUnitDirection
	local spGetGameSeconds = Spring.GetGameSeconds
	local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy

	local GAME_SPEED = Game.gameSpeed
	local PRIVATE = { private = true }

	local evolutionMetaList = {}
	local teamList = spGetTeamList()
	local neutralTeamNumber = tonumber(teamList[#teamList])
	local teamPowerList = {}
	local highestTeamPower = 0

	local lastTimerCheck = 0
	local lastPowerCheck = 0

	local TIMER_CHECK_FREQUENCY = 30 -- gameframes
	local POWER_CHECK_FREQUENCY = 45 -- gameframes

	include("luarules/configs/customcmds.h.lua")
	--messages[1] = textColor .. Spring.I18N('ui.raptors.wave1', {waveNumber = raptorEventArgs.waveCount})


	-- ZECRUS, values can be tuned in the unitdef file. Add the section below to the unitdef list in the unitdef file.
	--customparams = {
		--	-- Required:
		-- evolution_target = "unitname"    Name of the unit this unit will evolve into.


		--	-- Optional:
		-- evolution_announcement = "Unit Evolved", -- Announcement printed when the unit is evolved.
		-- evolution_announcement_size = 18.5, 		-- Size of the onscreen announcement

		--	-- Has a default value, as indicated, if not chosen:
		-- evolution_condition = "timer",    		-- condition type for the evolution. "timer", "timer_global", "health", or "power"
		-- evolution_timer = 600, 					-- set the timer used for the timer condition. Given in secons from when the unit was created.
		-- evolution_health_threshold = 0,			-- threshold for triggering the "health" evolution condition.
		-- evolution_power_threshold = 600,			-- threshold for triggering the "power" evolution condition.
		-- evolution_power_enemy_multiplier = 1,	-- Scales the power calculated based on the average enemy combined power.
		-- evolution_power_multiplier = 1,			-- Scales the power calculated based on your own combined power.
		-- combatradius = 1000,						-- Range for setting in-combat status if enemies are within range, and disabling evolution while in-combat.
		-- evolution_health_transfer = "flat",		-- "flat", "percentage", or "full"


		-- },






--------------------------------------------------------------------------------
--from Zero-K Morph
--------------------------------------------------------------------------------
-- This function is terrible. The data structure of commands does not lend itself to a fundamentally nicer system though.

	local unitTargetCommand = {
		[CMD.GUARD] = true,
		--[CMD_ORBIT] = true,
	}

	local singleParamUnitTargetCommand = {
		[CMD.REPAIR] = true,
		[CMD.ATTACK] = true,
	}

	local function ReAssignAssists(newUnit,oldUnit)
		local allUnits = Spring.GetAllUnits(newUnit)
		for _,unitID in pairs(allUnits) do
			--local unitID = allUnits[i]

			if GG.GetUnitTarget(unitID) == oldUnit and newUnit then
				GG.SetUnitTarget(unitID, newUnit)
			end

			local cmds = Spring.GetUnitCommands(unitID, -1)
			for j = 1, #cmds do
				local cmd = cmds[j]
				local params = cmd.params
				if (unitTargetCommand[cmd.id] or (singleParamUnitTargetCommand[cmd.id] and #params == 1)) and (params[1] == oldUnit) then
					params[1] = newUnit
					local opts = (cmd.options.meta and CMD.OPT_META or 0) + (cmd.options.ctrl and CMD.OPT_CTRL or 0) + (cmd.options.alt and CMD.OPT_ALT or 0)
					Spring.GiveOrderToUnit(unitID, CMD.INSERT, {cmd.tag, cmd.id, opts, params[1], params[2], params[3]}, 0)
					Spring.GiveOrderToUnit(unitID, CMD.REMOVE, cmd.tag, 0)
				end
			end
		end
	end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------






	function Evolve(unitID, newUnit)
		local x,y,z = spGetUnitPosition(unitID)
		if not z then
			return
		end
		local health, maxHealth = spGetUnitHealth(unitID)
		local experience = spGetUnitExperience(unitID)
		local team = spGetUnitTeam(unitID)
		local states = spGetUnitStates(unitID)
		local dx, dy, dz = spGetUnitDirection(unitID)
		local heading = Spring.GetUnitHeading(unitID)
		local face = Spring.GetFacingFromHeading(heading)
		local stockpile, stockpilequeued, stockpilebuildpercent = spGetUnitStockpile(unitID)
		local commandQueue = Spring.GetUnitCommands(unitID, -1)
		local transporter = Spring.GetUnitTransporter(unitID)

		local evolution = evolutionMetaList[unitID]
		if not evolution then
			return
		end

		local newUnitID = spCreateUnit(newUnit, x,y,z, face, team)

		if not newUnitID then
			return
		end

		local announcement = nil
		local announcementSize = nil
		if evolution.evolution_announcement then
			spEcho(evolution.evolution_announcement)
			announcement = evolution.evolution_announcement
			announcementSize = evolution.evolution_announcement_size
		end

		spSetUnitRulesParam(unitID, "unit_evolved", newUnitID, PRIVATE)

		SendToUnsynced("unit_evolve_finished", unitID, newUnitID, announcement,announcementSize)
		if evolution.evolution_health_transfer == "full" then
		elseif evolution.evolution_health_transfer == "percentage" then
			local _, newUnitMaxHealth = spGetUnitHealth(newUnitID)
			local pHealth = (health/maxHealth) * newUnitMaxHealth
			spSetUnitHealth(newUnitID, pHealth)
		else
			spSetUnitHealth(newUnitID, health)
		end

		spDestroyUnit(unitID, false, true)
		spSetUnitExperience(newUnitID, experience)
		spSetUnitStockpile(newUnitID, stockpile, stockpilebuildpercent)
		spSetUnitDirection(newUnitID, dx, dy, dz)

		spGiveOrderToUnit(newUnitID, CMD.FIRE_STATE, states.firestate, 						 {})
		spGiveOrderToUnit(newUnitID, CMD.MOVE_STATE, states.movestate, 						 {})
		-- TODO Untested
		spGiveOrderToUnit(newUnitID, CMD.TRAJECTORY, states.trajectory and 1 or 0, {})
		-- FIXME TODO Does not work. Could also use GiveOrderArrayToUnit.
		-- spGiveOrderToUnit(newUnitID, CMD.REPEAT, states["repeat"] and 1 or 0, {})
		-- spGiveOrderToUnit(newUnitID, CMD.CLOAK,  states.cloak and 1 or 0, 		 {})
		-- spGiveOrderToUnit(newUnitID, CMD.ONOFF,  1,                       		 {})

		ReAssignAssists(newUnitID,unitID)


		if commandQueue[1] then
			local teamID = Spring.GetUnitTeam(unitID)
			for _,command in pairs(commandQueue) do
				local coded = command.options.coded + (command.options.shift and 0 or CMD.OPT_SHIFT) -- orders without SHIFT can appear at positions other than the 1st due to CMD.INSERT; they'd cancel any previous commands if added raw
				if command.id < 0 then -- repair case for construction
					local units = CallAsTeam(teamID, Spring.GetUnitsInRectangle, command.params[1] - 16, command.params[3] - 16, command.params[1] + 16, command.params[3] + 16, -3)
					local notFound = true
					for j = 1, #units do
						local areaUnitID = units[j]
						if Spring.GetUnitDefID(areaUnitID) == -command.id then
							Spring.GiveOrderToUnit(newUnitID, CMD.REPAIR, areaUnitID, coded)
							notFound = false
							break
						end
					end
					if notFound then
						Spring.GiveOrderToUnit(newUnitID, command.id, command.params, coded)
					end
				else
					Spring.GiveOrderToUnit(newUnitID, command.id, command.params, coded)
				end
			end
		end

		if transporter then
			spGiveOrderToUnit(transporter, CMD.LOAD_UNITS, { newUnitID }, 0)
		end

	end


	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		local udcp = UnitDefs[unitDefID].customParams
		if udcp.evolution_target then
			local defaultTimer = 20 * GAME_SPEED
			evolutionMetaList[unitID] = {
				evolution_target = udcp.evolution_target,
				evolution_condition = udcp.evolution_condition or "timer",
				evolution_timer = tonumber(udcp.evolution_timer) or defaultTimer,
				evolution_power_threshold = tonumber(udcp.evolution_power_threshold) or 600,
				evolution_power_enemy_multiplier = tonumber(udcp.evolution_power_enemy_multiplier) or 1,
				evolution_power_multiplier = tonumber(udcp.evolution_power_multiplier) or 1,
				evolution_health_threshold = tonumber(udcp.evolution_health_threshold) or 0,
				evolution_disable_deathsequence = udcp.evolution_disable_deathsequence or true,
				evolution_announcement = udcp.evolution_announcement,
				evolution_announcement_size = tonumber(udcp.evolution_announcement_size),
				combatRadius = tonumber(udcp.combatradius) or 1000,
				evolution_health_transfer =  udcp.evolution_health_transfer or "flat",

				timeCreated = spGetGameSeconds(),
				combatTimer = spGetGameSeconds(),
				inCombat = false,
			}
		end
	end

	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if UnitDefs[unitDefID].power then
			if unitTeam < neutralTeamNumber then
				if teamPowerList[unitTeam] then
					teamPowerList[unitTeam] = teamPowerList[unitTeam] + UnitDefs[unitDefID].power
				else
					teamPowerList[unitTeam] = UnitDefs[unitDefID].power
				end
			end
		end

	end

	--function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	--	if evolutionMetaList[unitID] and (cmdID == CMD.STOP) then
	--		Evolve(unitID, evolutionMetaList[unitID].evolution_target)
	--	end
	--end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if evolutionMetaList[unitID] then
			evolutionMetaList[unitID] = nil
		end

		if unitTeam < neutralTeamNumber then
			if UnitDefs[unitDefID].power then
				if teamPowerList[unitTeam] then
					if teamPowerList[unitTeam] <= UnitDefs[unitDefID].power then
						teamPowerList[unitTeam] = nil
					else
						teamPowerList[unitTeam] = teamPowerList[unitTeam] - UnitDefs[unitDefID].power
					end
				else
					teamPowerList[unitTeam] = UnitDefs[unitDefID].power
				end
			end
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		local evolution = evolutionMetaList[unitID]
		if evolution then
			if evolution.evolution_condition == "health" then
				local h = spGetUnitHealth(unitID)
				if (h-damage) <= evolution.evolution_health_threshold then
						Evolve(unitID, evolution.evolution_target)
						return 0, 0
				end
			end
		end
	end


	function gadget:GameFrame(f)
		if f % GAME_SPEED ~= 0 then
			return
		end

		local currentTime =  spGetGameSeconds()
		if ((TIMER_CHECK_FREQUENCY + lastTimerCheck) < f) then
			lastTimerCheck = f
			for unitID, _ in pairs(evolutionMetaList) do
				local evolution = evolutionMetaList[unitID]
				if (evolution.evolution_condition == "timer" and (currentTime-evolution.timeCreated) >= evolution.evolution_timer) or
				   (evolution.evolution_condition == "timer_global" and currentTime >= evolution.evolution_timer) then
					local enemyNearby = spGetUnitNearestEnemy(unitID, evolution.combatRadius)
					local inCombat = false
					if enemyNearby then
						inCombat = true
						evolution.combatTimer = currentTime
					end

					if not inCombat and (currentTime-evolution.combatTimer) >= 5 then
						Evolve(unitID, evolution.evolution_target)
					end
				end
			end
		end

		if ((POWER_CHECK_FREQUENCY + lastPowerCheck) < f) then
			lastPowerCheck = f

			for unitID, _ in pairs(evolutionMetaList) do
				local teamID = spGetUnitTeam(unitID)
				local transporterID = Spring.GetUnitTransporter(unitID)
				local evolution = evolutionMetaList[unitID]

				for team, power in pairs(teamPowerList) do
					if team and teamID and power then
						if highestTeamPower < power then
							highestTeamPower = power * evolution.evolution_power_multiplier
						end
					end
				end
				if transporterID then
				elseif evolution.evolution_condition == "power" and highestTeamPower > evolution.evolution_power_threshold then
					local enemyNearby = spGetUnitNearestEnemy(unitID, evolution.combatRadius)
					local inCombat = false
					if enemyNearby then
						inCombat = true
						evolution.combatTimer = currentTime
					end
					if not inCombat and (currentTime-evolution.combatTimer) >= 5 then
						Evolve(unitID, evolution.evolution_target)
					end
				end
			end
		end
	end


else


	local spSelectUnitArray = Spring.SelectUnitArray
	local spGetSelectedUnits = Spring.GetSelectedUnits
	local spGetGameSeconds = Spring.GetGameSeconds

	local announcementStart = 0
	local announcementEnabled = false
	local announcement = nil
	local announcementSize = 18.5

	local displayList

	local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
	local vsx, vsy = Spring.GetViewGeometry()
	local fontfileScale = (0.5 + (vsx * vsy / 6200000))
	local fontfileSize = 50
	local fontfileOutlineSize = 10
	local fontfileOutlineStrength = 1.4
	local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)


	local function Draw(newAnnouncement, newAnnouncementSize)
		vsx, vsy = Spring.GetViewGeometry()
		local uiScale = (0.7 + (vsx * vsy / 6500000))
		displayList = gl.CreateList(function()
			font:Begin()
			font:SetTextColor(1, 1, 1)
			font:Print(newAnnouncement, vsx * 0.5, vsy * 0.67, newAnnouncementSize * uiScale, "co")
			font:End()
		end)

		gl.CallList(displayList)
	end

	local function EvolveFinished(cmd, oldID, newID, newAnnouncement, newAnnouncementSize)
		local selUnits = spGetSelectedUnits()
		local unitGroup = Spring.GetUnitGroup(oldID)
		if unitGroup then
			Spring.SetUnitGroup(newID, unitGroup)
		end
		for i=1,#selUnits do
		  local unitID = selUnits[i]
		  if (unitID == oldID) then
			selUnits[i] = newID
			spSelectUnitArray(selUnits)
			break
		  end
		end
		if newAnnouncement then
			announcement = newAnnouncement
			announcementSize = newAnnouncementSize
			announcementEnabled = true
			announcementStart = spGetGameSeconds()
		end
	end

	function gadget:DrawScreen()
		if Spring.IsGUIHidden() then
			return
		end
		if announcementEnabled then
			local currentTime = spGetGameSeconds()
			if currentTime-announcementStart < 3 then
				Draw(announcement, announcementSize)
			else
				announcementEnabled = false
				announcement = nil
				announcementSize = 18.5
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("unit_evolve_finished", EvolveFinished)
		local w = 300
		local h = 210
		displayList = gl.CreateList(function()
			gl.Blending(true)
			gl.Color(1, 1, 1, 1)
			gl.Texture(1, "LuaUI/images/gradient_alpha_2.png")
			gl.TexRect(0, 0, w, h)
		end)

	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("unit_evolve_finished")
		gl.DeleteList(displayList)
	end

end
