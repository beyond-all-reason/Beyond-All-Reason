local buildOptionReplacements = {
	armch = { armfhlt = "armnavaldefturret" },
	corch = { corfhlt = "cornavaldefturret" },
	legch = { legfmg = "legnavaldefturret" },

	armacsub = { armkraken = "armanavaldefturret" },
	armmls = {
		armfhlt = "armnavaldefturret",
		armkraken = "armanavaldefturret",
	},
	coracsub = { corfdoom = "coranavaldefturret" },
	cormls = {
		corfhlt = "cornavaldefturret",
		corfdoom = "coranavaldefturret",
	},
	-- legion t2 sea con already has their extra turret.
	leganavyengineer = {
		legfmg = "legnavaldefturret",
	},
}

local buildOptionAdditions = {
	armcs = "armnavaldefturret",
	armbeaver = "armnavaldefturret",
	armcsa = "armnavaldefturret",

	corcs = "cornavaldefturret",
	cormuskrat = "cornavaldefturret",
	corcsa = "cornavaldefturret",

	legnavyconship = "legnavaldefturret",
	legotter = "legnavaldefturret",
	legspcon = "legnavaldefturret",
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

	if buildOptionAdditions[name] then
		local buildoptions = unitDef.buildoptions
		buildoptions[#buildoptions + 1] = buildOptionAdditions[name]
	end

	if sightRanges[name] then
		unitDef.sightdistance = sightRanges[name]
	end
end

return {
	Tweaks = navalBalanceTweaks,
}
