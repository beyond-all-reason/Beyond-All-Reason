-- SPDX-License-Identifier: GPL-2.0-or-later
return {
	portal_gate = {
		name = "Portal", description = "Right click with mobile units to travel",
		objectname = "Units/ARMGATE.s3o", script = "portal_gate.lua", buildpic = "ARMGATE.DDS",
		footprintx = 4, footprintz = 4, yardmap = "oooooooooooooooo",
		power = 1, health = 100000, metalcost = 0, energycost = 0, buildtime = 1,
		canattack = false, canmove = false, canrepeat = false,
		blocking = false, reclaimable = false, capturable = false,
		sightdistance = 0, seismicsignature = 0, maxslope = 90, maxwaterdepth = 100000,
		explodeas = "", selfdestructas = "",
		customparams = {decoration = true, portal_gate = true, normaltex = "unittextures/Arm_normal.dds"},
	},
}
