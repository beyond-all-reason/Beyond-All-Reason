--- Seven anger brackets, and how big a squad drawn from each may be.
---
--- The whole roster is indexed by these: a unit list names a tier, and the
--- tier says at what anger its units start appearing, when they stop, and how
--- many of them travel together. Special squads take double the size.
---
--- Data only. Names are strings, numbers are numbers, and nothing here calls
--- anything — modules/scavengers/lib/defs_build.lua is the only program.

return { -- Double maxSquadSize for special squads
	[1] = { minAnger = 0, maxAnger = 20, maxSquadSize = 1 },
	[2] = { minAnger = 5, maxAnger = 65, maxSquadSize = 10 },
	[3] = { minAnger = 15, maxAnger = 100, maxSquadSize = 10 },
	[4] = { minAnger = 30, maxAnger = 200, maxSquadSize = 10 },
	[5] = { minAnger = 40, maxAnger = 350, maxSquadSize = 8 },
	[6] = { minAnger = 55, maxAnger = 500, maxSquadSize = 5 },
	[7] = { minAnger = 65, maxAnger = 1000, maxSquadSize = 3 },
}
