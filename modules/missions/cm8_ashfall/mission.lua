local SIDES = VFS.Include("gamedata/sides_enum.lua")

return {
	title = "CM8 — Ashfall",
	sides = {
		player = SIDES.CORTEX,
		enemy = SIDES.ARMADA,
	},
}
