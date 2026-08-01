local commanderLevel1 = {
	armcom = true,
	corcom = true,
	legcom = true,
}

local commanderEffigies = {
	[1]  = nil, -- already set up by the effigy modoption
	[2]  = "comeffigylvl1",
	[3]  = "comeffigylvl2",
	[4]  = "comeffigylvl2",
	[5]  = "comeffigylvl3",
	[6]  = "comeffigylvl3",
	[7]  = "comeffigylvl4",
	[8]  = "comeffigylvl4",
	[9]  = "comeffigylvl5",
	[10] = "comeffigylvl5",
}

local function evolvingCommanders(name, unitDef, modOptions)
	local customparams = unitDef.customparams

	if customparams.evocomlvl or commanderLevel1[name] then
		local comLevel = customparams.evocomlvl

		if modOptions.comrespawn == "all" or modOptions.comrespawn == "evocom" then --add effigy respawning, if enabled
			customparams.respawn_condition = "health"
			if comLevel then
				local buildoptions = unitDef.buildoptions
				local numBuildoptions = #buildoptions
				buildoptions[numBuildoptions + 1] = commanderEffigies[comLevel]
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
			local evolutionPowerThreshold = customparams.evolution_power_threshold or 10000 --sets threshold for level 1 commanders
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