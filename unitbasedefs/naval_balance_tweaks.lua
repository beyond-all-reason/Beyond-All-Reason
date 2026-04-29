local buildOptionReplacements = {
	-- t1 arm cons
	armcs = { armfhlt = "armnavaldefturret" },
	armch = { armfhlt = "armnavaldefturret" },
	armbeaver = { armfhlt = "armnavaldefturret" },
	armcsa = { armfhlt = "armnavaldefturret" },

	-- t1 cor cons
	corcs = { corfhlt = "cornavaldefturret" },
	corch = { corfhlt = "cornavaldefturret" },
	cormuskrat = { corfhlt = "cornavaldefturret" },
	corcsa = { corfhlt = "cornavaldefturret" },

	-- t1 leg cons
	legnavyconship = { legfmg = "legnavaldefturret" },
	legch = { legfmg = "legnavaldefturret" },
	legotter = { legfmg = "legnavaldefturret" },
	legspcon = { legfmg = "legnavaldefturret" },

	-- t2 arm cons
	armacsub = { armkraken = "armanavaldefturret" },
	armmls = {
		armfhlt   = "armnavaldefturret",
		armkraken = "armanavaldefturret",
	},

	-- t2 cor cons
	coracsub = { corfdoom = "coranavaldefturret" },
	cormls = {
		corfhlt  = "cornavaldefturret",
		corfdoom = "coranavaldefturret",
	},

	-- t2 leg cons
	leganavyengineer = {
		legfmg = "legnavaldefturret",
	},
}

local sightRanges = {
	armfrad = 800,
	corfrad = 800,
	legfrad = 800,
}

local function navalBalanceTweaks(name, unitDef)
	if buildOptionReplacements[name] then
		local buildoptions = unitDef.buildoptions
		local replacements = buildOptionReplacements[name]
		for i, buildOption in ipairs(buildoptions) do
			if replacements[buildOption] then
				buildoptions[i] = replacements[buildOption]
			end
		end
	end

	if sightRanges[name] then
		unitDef.sightdistance = sightRanges[name]
	end
end

return {
	Tweaks = navalBalanceTweaks,
}