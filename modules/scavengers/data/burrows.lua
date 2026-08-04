--- The beacons waves come out of, and the anger window each is available in.
---
--- Tier references instead of numbers: a beacon's window is stated as "from
--- tier 1's floor to tier 2's ceiling", so retuning tiers.lua retunes these
--- with it. defs_build resolves them.

return {
	["scavbeacon_t1_scav"] = { minAngerTier = 1, maxAngerTier = 2 },
	["scavbeacon_t2_scav"] = { minAngerTier = 2, maxAngerTier = 3 },
	["scavbeacon_t3_scav"] = { minAngerTier = 3, maxAngerTier = 5 },
	["scavbeacon_t4_scav"] = { minAngerTier = 4, maxAngerTier = 7 },
}
