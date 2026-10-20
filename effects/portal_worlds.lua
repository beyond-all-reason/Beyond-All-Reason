-- SPDX-License-Identifier: GPL-2.0-or-later
local function particles(count, life, size, speed)
	return {
		class = "CSimpleParticleSystem",
		count = 1,
		air = true,
		ground = true,
		water = true,
		underwater = true,
		properties = {
			airdrag = 0.95,
			alwaysvisible = true,
			directional = false,
			colormap = "0.4 1 1 0.04   0.05 0.5 1 0.02   0 0.1 0.2 0",
			emitrot = 15,
			emitrotspread = 70,
			emitvector = "0,1,0",
			gravity = "0,0.02,0",
			numparticles = count,
			particlelife = life,
			particlelifespread = 8,
			particlesize = size,
			particlesizespread = 4,
			particlespeed = speed,
			particlespeedspread = 1,
			pos = "0,10,0",
			sizegrowth = -0.05,
			sizemod = 1,
			texture = "flare",
		},
	}
end
return {
	["portal-transit"] = { sparks = particles(36, 24, 12, 4) },
	["portal-idle"] = { sparks = particles(6, 24, 6, 1) },
}
