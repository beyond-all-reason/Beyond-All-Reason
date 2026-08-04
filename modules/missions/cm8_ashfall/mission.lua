--- CM8 "Ashfall": the mission's own manifest — what a lobby needs to set the
--- table before the game exists. Sides speak gamedata/sides_enum.lua — the
--- player commands Cortex; the derelicts, the enclave and the commander to
--- kill are Armada.

local SIDES = VFS.Include("gamedata/sides_enum.lua")

return {
	title = "CM8 — Ashfall",
	sides = {
		player = SIDES.CORTEX,
		enemy = SIDES.ARMADA,
	},
}
