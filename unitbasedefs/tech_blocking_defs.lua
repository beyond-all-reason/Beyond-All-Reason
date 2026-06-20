-- Tech Blocking modoption tweaks, applied from alldefs_post when modOptions.tech_blocking is set.
--   1. Cheaper / faster T2 labs so the Tech Core path is viable.
--   2. Inject the faction Keystone into T1 mobile constructor build menus.

local cheaperT2Labs = {
	armalab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	coralab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	legalab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	armavp  = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	coravp  = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	legavp  = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	armaap  = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
	coraap  = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
	legaap  = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
}

local function techBlockingTweaks(name, uDef)
	-- Cheaper T2 labs
	local labStats = cheaperT2Labs[name]
	if labStats then
		for key, value in pairs(labStats) do
			uDef[key] = value
		end
	end

	-- Inject Keystone into T1 mobile constructor build menus
	if uDef.buildoptions and uDef.speed and uDef.speed > 0 and not (uDef.customparams and uDef.customparams.iscommander) then
		local techLevel = tonumber(uDef.customparams and uDef.customparams.techlevel) or 1
		if techLevel == 1 then
			local keystone
			if name:sub(1, 3) == "arm" then
				keystone = "armkeystone"
			elseif name:sub(1, 3) == "cor" then
				keystone = "corkeystone"
			elseif name:sub(1, 3) == "leg" then
				keystone = "legkeystone"
			end
			if keystone then
				uDef.buildoptions[#uDef.buildoptions + 1] = keystone
			end
		end
	end
end

return {
	Tweaks = techBlockingTweaks,
}
