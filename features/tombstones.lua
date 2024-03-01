local object = {
	blocking = false,
	collisionvolumeoffsets = "0 0 0",
	collisionvolumescales = "1 1 1",
	collisionvolumetype = "SPHERE",
	description = "Commander Tombstone",
	footprintx = 0,
	footprintz = 0,
	height = 10,
	indestructible = true,
	noselect = true,
	object = "armada_tombstone.s3o",
	reclaimable = false,
	customparams = {
		model_author = "Beherith",
		normaltex = "unittextures/Arm_normal.dds",
	}
}
local tombstones = {
	armada_tombstone = table.copy(object),
	cortex_tombstone = table.copy(object),
}
tombstones.cortex_tombstone.object = "cortex_tombstone.s3o"
tombstones.cortex_tombstone.customparams.normaltex = "unittextures/cor_normal.dds"

return tombstones
