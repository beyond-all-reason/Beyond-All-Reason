--[[   Morph Definition File

Morph parameters description
local morphDefs = {		--beginig of morphDefs
	unitname = {		--unit being morphed
		into = 'newunitname',		--unit in that will morphing unit morph into
		time = 12,			--time required to complete morph process (in seconds)
		require = 'requnitname',	--unit requnitname must be present in team for morphing to be enabled
		metal = 10,			--required metal for morphing process     note: if you ommit M and/or E costs, morph costs the
		energy = 10,			--required energy for morphing process		difference in costs between unitname and newunitname
		xp = 0.07,			--required experience for morphing process (will be deduced from unit xp after morph, default=0)
		rank = 1,			--required unit rank for morphing to be enabled, if ommited, morph doesn't require rank
		tech = 2,			--required tech level of a team for morphing to be enabled (1,2,3), if ommited, morph doesn't require tech
		cmdname = 'Ascend',		--if ommited will default to "Upgrade"
		texture = 'MyIcon.dds',		--if ommited will default to [newunitname] buildpic, textures should be in "LuaRules/Images/Morph"
		text = 'Description',		--if ommited will default to "Upgrade into a [newunitname]", else it's "Description"
						--you may use "$$unitname" and "$$into" in 'text', both will be replaced with human readable unit names 
	},
}				--end of morphDefs
--]]
--------------------------------------------------------------------------------


local devolution = (-1 > 0)

local modOptions = Spring.GetModOptions()
local requiredTechLevel = tonumber(modOptions.requiredtechlevel) or 1
local morphPenalty = tonumber(modOptions.morphpenalty) or 1.25

local morphDefs = {

	armmex = 	{
		{
			into = 'armmoho',
			time = 59.7 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 600 * morphPenalty,
			energy = 8000 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into an Advanced Metal Extractor / Storage. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	cormex = 	{
		{
			into = 'cormoho',
			time = 56.5 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 600 * morphPenalty,
			energy = 8500 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into an Advanced Metal Extractor / Storage. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	armck = 	{
		{
			into = 'armack',
			time = 31.44 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 340 * morphPenalty,
			energy = 6500 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	armcv = 	{
		{
			into = 'armacv',
			time = 41.32 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 550 * morphPenalty,
			energy = 6700 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	armca = 	{
		{
			into = 'armaca',
			time = 88.81 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 282 * morphPenalty,
			energy = 11642 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	armcs = 	{
		{
			into = 'armacsub',
			time = 59.75 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 850 * morphPenalty,
			energy = 11500 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	
	corck = 	{
		{
			into = 'corack',
			time = 32.36 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 410 * morphPenalty,
			energy = 7000 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	corcv = 	{
		{
			into = 'coracv',
			time = 42.94 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 580 * morphPenalty,
			energy = 7000 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	corca = 	{
		{
			into = 'coraca',
			time = 90 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 295 * morphPenalty,
			energy = 11294 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	corcs = 	{
		{
			into = 'coracsub',
			time = 60.51 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 840 * morphPenalty,
			energy = 11500 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into a Level 2 Constructor. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	
	armsolar = 	{
		{
			into = 'armadvsol',
			time = 88.27 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 360 * morphPenalty,
			energy = 5050 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into an Advanced Solar Collector. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
	corsolar = 	{
		{
			into = 'coradvsol',
			time = 90.47 * morphPenalty,
			cmdname = [[Upgrade]],
			metal = 370 * morphPenalty,
			energy = 4000 * morphPenalty,
			tech = requiredTechLevel,
			text = 'Morph into an Advanced Solar Collector. +' .. morphPenalty * 100 .. '% of normal buildtime, metal and energy costs.',
		},
	},
}

--
-- Here's an example of why active configuration
-- scripts are better then static TDF files...
--

--
-- devolution, babe  (useful for testing)
--
if (devolution) then
  local devoDefs = {}
  for src,data in pairs(morphDefs) do
    devoDefs[data.into] = { into = src, time = 10, metal = 1, energy = 1 }
  end
  for src,data in pairs(devoDefs) do
    morphDefs[src] = data
  end
end


return morphDefs

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
