local object = {
	blocking = false,
	collisionvolumeoffsets = "0 0 0",
	collisionvolumescales = "12 24 12",
	collisionvolumetype = "CylY",
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
