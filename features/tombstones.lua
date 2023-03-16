local object = {
	blocking = false,
	collisionvolumeoffsets = "0 0 0",
	collisionvolumescales = "0 0 0",
	collisionvolumetype = "SPHERE",
	description = "Commander Tombstone",
	footprintx = 1,
	footprintz = 1,
	height = 10,
	indestructible = true,
	noselect = true,
	object = "armstone.s3o",
	reclaimable = false,
	customparams = {
		model_author = "Beherith",
		normaltex = "unittextures/Arm_normal.dds",
	}
}
local tombstones = {
	armstone = table.copy(object),
	corstone = table.copy(object),
}
tombstones.corstone.object = "corstone.s3o"
tombstones.corstone.customparams.normaltex = "unittextures/Cor_normal.dds"

return tombstones
