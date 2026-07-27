--- Construction's actions, declared once for every grammar that names them.
---
--- What a builder may do for an ally: assist their build, reclaim their
--- units, resurrect their wrecks, and build at all. None of them move
--- anything between teams — that is transfer's domain — which is why they
--- live here and not there.
---
--- No Perform on any of them yet: nothing performs a construction action from
--- a trigger. They are grantable, which is what a mode needs.

local Actions = {}

Actions.Construction = {
	--- Building alongside an ally's own builders.
	Assist = { domain = "assist" },
	--- Reclaiming an ally's units and wrecks.
	Reclaim = { domain = "reclaim" },
	--- Resurrecting from wreckage, whole or partial.
	Resurrect = { domain = "resurrect" },
	--- Building at all. The delay a mode sets is served here, on the builder.
	Build = { domain = "build" },
}

return Actions
