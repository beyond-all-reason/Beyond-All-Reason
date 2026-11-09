local buildOptionReplacements = {
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
	armch = "armnavaldefturret",
	armbeaver = "armnavaldefturret",
	armcsa = "armnavaldefturret",

	corcs = "cornavaldefturret",
	corch = "cornavaldefturret",
	cormuskrat = "cornavaldefturret",
	corcsa = "cornavaldefturret",

	legnavyconship = "legnavaldefturret",
	legch = "legnavaldefturret",
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
