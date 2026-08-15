--- Manifest for the economy module: how a shared pool is distributed.
---
--- Waterfill answers a question that is not about allies at all — given a
--- pool, a set of claimants and their capacities, how much does each get —
--- so it sits under the modules that have a reason to ask. Transfer asks it
--- for allied resource sharing; anything else that splits a pool can ask the
--- same solver rather than growing its own.
---@type ModuleManifestFile
return {
	name = "economy",
	description = "Resource pool distribution: the waterfill solver",
}
