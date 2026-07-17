-- Tech Blocking tweaks (from alldefs_post when tech_blocking set): cheaper T2 labs + Keystone in T1 con menus.

---@type table<string, table<string, any>|nil> sparse: only discounted labs appear
local cheaperT2Labs = {
	armalab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	coralab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	legalab = { energycost = 10000, metalcost = 1700, buildtime = 15000, health = 3500, maxslope = 15, workertime = 200 },
	armavp = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	coravp = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	legavp = { energycost = 10000, metalcost = 1850, buildtime = 16500, health = 3600, maxslope = 15, workertime = 200 },
	armaap = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
	coraap = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
	legaap = { energycost = 11000, metalcost = 2000, buildtime = 20000, health = 3500, maxslope = 15, workertime = 200 },
}

---@type table<string, string|nil>
local keystoneByPrefix = { arm = "armkeystone", cor = "corkeystone", leg = "legkeystone" }
local mexByPrefix = { arm = "armmex", cor = "cormex", leg = "legmex" }

-- cons that should build the Keystone but lack the faction mex, so allowlisted explicitly.
---@type table<string, boolean|nil>
local extraKeystoneBuilders = { armvoussoir = true, corvoussoir = true, legvoussoir = true }

local function buildsUnit(buildoptions, target)
	for i = 1, #buildoptions do
		if buildoptions[i] == target then
			return true
		end
	end
	return false
end

local function techBlockingTweaks(name, uDef)
	local labStats = cheaperT2Labs[name]
	if labStats then
		for key, value in pairs(labStats) do
			uDef[key] = value
		end
	end

	-- Inject Keystone into T1 con menus, gating on mex-building to exclude specialised builders.
	if uDef.buildoptions and uDef.speed and uDef.speed > 0 and not (uDef.customparams and uDef.customparams.iscommander) then
		local techLevel = tonumber(uDef.customparams and uDef.customparams.techlevel) or 1
		local keystone = keystoneByPrefix[name:sub(1, 3)]
		if techLevel == 1 and keystone then
			local isGeneralCon = extraKeystoneBuilders[name] or buildsUnit(uDef.buildoptions, mexByPrefix[name:sub(1, 3)])
			if isGeneralCon then
				uDef.buildoptions[#uDef.buildoptions + 1] = keystone
			end
		end
	end
end

return {
	Tweaks = techBlockingTweaks,
}
