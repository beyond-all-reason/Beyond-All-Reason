local baseCommanderDefs = {
	armcom = true,
	corcom = true,
	legcom = true,
}

local function evolvingCommanders(unitDef, modOptions)
	local name = unitDef.name
	local customparams = unitDef.customparams

	if customparams.evocomlvl or baseCommanderDefs[unitDef.name] then
		local comLevel = customparams.evocomlvl

		if modOptions.comrespawn == "all" or modOptions.comrespawn == "evocom" then --add effigy respawning, if enabled
			customparams.respawn_condition = "health"

			local buildoptions = unitDef.buildoptions
			local numBuildoptions = #buildoptions

			if comLevel == 2 then
				buildoptions[numBuildoptions + 1] = "comeffigylvl1"
			elseif comLevel == 3 or comLevel == 4 then
				buildoptions[numBuildoptions + 1] = "comeffigylvl2"
			elseif comLevel == 5 or comLevel == 6 then
				buildoptions[numBuildoptions + 1] = "comeffigylvl3"
			elseif comLevel == 7 or comLevel == 8 then
				buildoptions[numBuildoptions + 1] = "comeffigylvl4"
			elseif comLevel == 9 or comLevel == 10 then
				buildoptions[numBuildoptions + 1] = "comeffigylvl5"
			end
		end

		customparams.combatradius = 0
		customparams.evolution_health_transfer = "percentage"

		if unitDef.power then
			unitDef.power = unitDef.power / modOptions.evocomxpmultiplier
		else
			unitDef.power = ((unitDef.metalcost + (unitDef.energycost / 60)) / modOptions.evocomxpmultiplier)
		end

		if name == "armcom" then
			customparams.evolution_target = "armcomlvl2"
			customparams.inheritxpratemultiplier = 0.5
			customparams.childreninheritxp = "TURRET MOBILEBUILT"
			customparams.parentsinheritxp = "TURRET MOBILEBUILT"
			customparams.evocomlvl = 1
		elseif name == "corcom" then
			customparams.evolution_target = "corcomlvl2"
			customparams.evocomlvl = 1
		elseif name == "legcom" then
			customparams.evolution_target = "legcomlvl2"
			customparams.evocomlvl = 1
		end

		if modOptions.evocomlevelupmethod == "dynamic" then
			customparams.evolution_condition = "power"
			customparams.evolution_power_multiplier = 1                             -- Scales the power calculated based on your own combined power.
			local evolutionPowerThreshold = customparams.evolution_power_threshold or
			10000                                                                   --sets threshold for level 1 commanders
			customparams.evolution_power_threshold = evolutionPowerThreshold * modOptions.evocomlevelupmultiplier
		elseif modOptions.evocomlevelupmethod == "timed" then
			customparams.evolution_timer = modOptions.evocomleveluptime * 60 * customparams.evocomlvl
			customparams.evolution_condition = "timer_global"
		end

		if comLevel and modOptions.evocomlevelcap <= comLevel then
			customparams.evolution_health_transfer = nil
			customparams.evolution_target = nil
			customparams.evolution_condition = nil
			customparams.evolution_timer = nil
			customparams.evolution_power_threshold = nil
			customparams.evolution_power_multiplier = nil
		end
	end
end

return {
	Tweaks = evolvingCommanders,
}