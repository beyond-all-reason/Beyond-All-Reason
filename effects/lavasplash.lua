-- lavasplash.lua
-- Lava versions of water splash CEGs, used when Water Is Lava modoption is active
-- Lava splashes are smaller/denser than water counterparts (lava is more viscous)

-- Lava color palettes (derived from effects/lava.lua)
local C = {
	pool   = [[0 0 0 0   0.65 0.48 0.1 .25   0.45 .22 0.08 .15   0.2 .08 0.04 .08   0 0 0 0.01]],
	waves  = [[0 0 0 0  0.5 0.3 0.1 .01   0.4 .22 0.08 .006   0.2 .08 0.04 .003   0 0 0 0.01]],
	rush   = [[0 0 0 0  0.7 0.5 0.1 .01   0.6 .33 0.12 .005   0.25 .12 0.05 .004   0 0 0 0.01]],
	embers = [[0.8 0.8 0.2 0.015   1 0.4 0.1 0.01   0 0 0 0.005]],
	chunks = [[1 0.89 0.3 0.8   0.95 0.5 0.2 0.6   1 0.4 0.1 0.3   0 0 0 0.01]],
	smoke  = [[0.95 0.77 0.28 0.7   0.8 0.5 0.2 0.45   0.5 0.2 0.08 0.18   0.025 0.025 0.025 0.07   0 0 0 0.01]],
	flare  = [[0.95 0.77 0.28 0.8   0.8 0.45 0.15 0.5   0 0 0 0]],
	glow   = [[0 0 0 0   0.65 0.48 0.1 0.6   0.35 0.15 0.06 0.2   0 0 0 0]],
	gflash = [[0.8 0.5 0.1 0.6   0.5 0.25 0.08 0.4   0.2 0.08 0.04 0.15   0 0 0 0.01]],
	shock  = [[0.65 0.48 0.1 0.013   0.45 .22 0.08 0.01   0.2 .08 0.04 0.006   0 0 0 0.01]],
	ball   = [[0 0 0 0  0.7 0.5 0.1 .08   0.5 .3 0.1 .04   0 0 0 0.01]],
}

-- Component builder: expanding lava pool on surface (replaces waterring)
local function lavapool(size, ttl, rotParams)
	return {
		air = true, class = [[CBitmapMuzzleFlame]], count = 1,
		ground = true, underwater = 1, water = true,
		properties = {
			colormap      = C.pool,
			dir           = [[0, 1, 0]],
			frontoffset   = 0,
			fronttexture  = [[dirt]],
			length        = 35,
			sidetexture   = [[none]],
			size          = size,
			sizegrowth    = 1.5,
			ttl           = ttl,
			rotParams     = rotParams,
			pos           = [[0.5, 3, 0.0]],
			alwaysvisible = true,
		},
	}
end

-- Component builder: circular ripple waves on lava surface (replaces circlewaves)
local function lavawaves(numparticles, particlesize, speed, lifespread)
	return {
		air = true, class = [[CSimpleParticleSystem]], count = 1,
		ground = true, underwater = 1, water = true,
		properties = {
			airdrag            = 0.93,
			colormap           = C.waves,
			directional        = true,
			emitrot            = 90,
			emitrotspread      = 0,
			emitvector         = [[0, 1, 0]],
			gravity            = [[0, 0, 0]],
			numparticles       = numparticles,
			particlelife       = 4,
			particlelifespread = lifespread,
			particlesize       = particlesize,
			particlesizespread = 0,
			particlespeed      = speed,
			particlespeedspread = 0,
			pos                = [[0 r-8 r8, 4, 0 r-8 r8]],
			sizegrowth         = [[0.6]],
			sizemod            = 1.0,
			texture            = [[wave]],
			alwaysvisible      = true,
		},
	}
end

-- Component builder: rising lava smoke column (replaces waterrush)
local function lavarush(count, numparticles, particlesize, sizespread, speed, speedspread, life, lifespread, pos, emitvector)
	return {
		air = true, class = [[CSimpleParticleSystem]], count = count,
		ground = true, underwater = 1, water = true,
		properties = {
			airdrag            = 0.97,
			colormap           = C.rush,
			directional        = false,
			emitrot            = 1,
			emitrotspread      = 0,
			emitvector         = emitvector or [[0, 1, 0]],
			gravity            = [[0, -0.04, 0]],
			numparticles       = numparticles,
			particlelife       = life,
			particlelifespread = lifespread,
			particlesize       = particlesize,
			particlesizespread = sizespread,
			particlespeed      = speed,
			particlespeedspread = speedspread or 0,
			pos                = pos or [[0, 80 r20, 0]],
			sizegrowth         = [[0.7]],
			sizemod            = 1,
			texture            = [[flashside3]],
			alwaysvisible      = true,
		},
	}
end

-- Component builder: glowing lava ember particles (replaces sparks)
local function lavaembers(numparticles, particlesize, sizespread, speed, speedspread, life, lifespread)
	return {
		air = true, class = [[CSimpleParticleSystem]], count = 1,
		ground = true, water = true, underwater = true,
		properties = {
			airdrag            = 0.93,
			colormap           = C.embers,
			directional        = true,
			emitrot            = 5,
			emitrotspread      = 10,
			emitvector         = [[0, 1, 0]],
			gravity            = [[0, -0.09, 0]],
			numparticles       = numparticles,
			particlelife       = life,
			particlelifespread = lifespread,
			particlesize       = particlesize,
			particlesizespread = sizespread,
			particlespeed      = speed,
			particlespeedspread = speedspread,
			pos                = [[0 r-8 r8, -24, 0 r-8 r8]],
			sizegrowth         = -0.35,
			sizemod            = 0.99,
			texture            = [[lavasplats]],
			alwaysvisible      = true,
		},
	}
end

-- Component builder: thrown lava chunks (replaces waterexplosion)
local function lavachunks(numparticles, particlesize, sizespread, speed, speedspread, life, lifespread, rotParams)
	return {
		air = true, class = [[CSimpleParticleSystem]], count = 1,
		ground = true, underwater = 1, water = true,
		properties = {
			airdrag            = 0.95,
			colormap           = C.chunks,
			directional        = true,
			emitrot            = 16,
			emitrotspread      = [[15 r-15 r15]],
			emitvector         = [[0, 1, 0]],
			gravity            = [[0, -0.1, 0]],
			numparticles       = numparticles,
			particlelife       = life,
			particlelifespread = lifespread,
			particlesize       = particlesize,
			particlesizespread = sizespread,
			particlespeed      = speed,
			particlespeedspread = speedspread,
			pos                = [[0, 12, 0]],
			rotParams          = rotParams,
			sizegrowth         = -0.21,
			sizemod            = 1.0,
			texture            = [[lavachunk]],
			alwaysvisible      = true,
		},
	}
end

-- Component builder: thick lava smoke trails (for large impacts)
local function lavasmoke(count, size, sizegrowth, length, ttl, rotParams, pos)
	return {
		air = true, class = [[CBitmapMuzzleFlame]], count = count,
		ground = true, underwater = 1, water = true,
		properties = {
			colormap      = C.smoke,
			dir           = [[-0.2 r0.4, 0.8 r0.2, -0.2 r0.4]],
			frontoffset   = 0.065,
			fronttexture  = [[none]],
			length        = length,
			sidetexture   = [[megaparticle2]],
			size          = size,
			sizegrowth    = sizegrowth,
			ttl           = ttl,
			rotParams     = rotParams,
			pos           = pos or [[-2 r4, -15, -2 r4]],
			drawOrder     = 0,
			alwaysvisible = true,
		},
	}
end

-- Component builder: expanding lava glow pool (replaces brightwakefoam)
local function lavaglow(size, ttl, rotParams)
	return {
		air = true, class = [[CBitmapMuzzleFlame]], count = 1,
		ground = true, underwater = true, water = true,
		properties = {
			colormap      = C.glow,
			dir           = [[0, 1, 0]],
			frontoffset   = 0,
			fronttexture  = [[dirt]],
			length        = 35,
			sidetexture   = [[none]],
			size          = size,
			sizegrowth    = [[0.12 r0.5]],
			ttl           = ttl,
			rotParams     = rotParams,
			pos           = [[0, 5, 0]],
			alwaysvisible = true,
		},
	}
end

-- Component builder: bright lava flash (replaces brightflare)
local function lavaflare(size, ttl)
	return {
		air = true, class = [[CBitmapMuzzleFlame]], count = 1,
		ground = true, underwater = true, water = true,
		properties = {
			colormap      = C.flare,
			dir           = [[0, 1, 0]],
			frontoffset   = 0,
			fronttexture  = [[exploflare]],
			length        = 35,
			sidetexture   = [[none]],
			size          = size,
			sizegrowth    = [[0.1 r0.2]],
			ttl           = ttl,
			pos           = [[0, 50, 0]],
			alwaysvisible = true,
		},
	}
end

-- Component builder: lava shockwave ring
local function lavashockwave(size, sizegrowth, ttl)
	return {
		air = true, class = [[CBitmapMuzzleFlame]], count = 1,
		ground = true, underwater = true, water = true,
		properties = {
			colormap      = C.shock,
			dir           = [[0, 1, 0]],
			frontoffset   = 0,
			fronttexture  = [[blastwave]],
			length        = 35,
			sidetexture   = [[none]],
			size          = size,
			sizegrowth    = sizegrowth,
			ttl           = ttl,
			pos           = [[0, 0, 0]],
			alwaysvisible = true,
		},
	}
end

-- Component builder: ground flash from lava impact
local function lavagroundflash(size, sizegrowth, ttl)
	return {
		class = [[CSimpleGroundFlash]], count = 1,
		air = false, ground = true, water = true, underwater = true,
		properties = {
			colormap      = C.gflash,
			size          = size,
			sizegrowth    = sizegrowth,
			ttl           = ttl,
			texture       = [[groundflashwhite]],
			alwaysvisible = true,
		},
	}
end


-- Assemble lava splash definitions from components
-- Sizes are ~65-70% of water counterparts

local definitions = {}

definitions["lavasplash-torpedo"] = {
	lavapool    = lavapool(4, 40),
	circlewaves = lavawaves(1, [[0.4 r0.5]], [[0.8 i0.2]], 18),
	embers      = lavaembers(2, 3, 8, 0.5, 5, 5, 10),
	lavachunks  = lavachunks(4, 0.8, 8, [[1.2 i0.2]], 1.5, 8, 8),
}

definitions["lavasplash-tiny"] = {
	lavapool    = lavapool(7, 45, [[-2 r4, -0.5 r1, -180 r360]]),
	circlewaves = lavawaves(1, [[0.5 r0.7]], [[1.0 i0.2]], 20),
	embers      = lavaembers(3, 3, 8, 0.6, 6, 6, 12),
	lavachunks  = lavachunks(5, 1, 8, [[1.3 i0.2]], 1.5, 9, 9),
}

definitions["lavasplash-small"] = {
	lavapool    = lavapool(8, 45, [[-6 r12, -1.5 r3, -180 r360]]),
	circlewaves = lavawaves(2, [[0.7 r1.4]], [[0.8 i0.2]], 20),
	embers      = lavaembers(5, 4, 12, 0.7, 6, 8, 15),
	lavachunks  = lavachunks(7, 1.4, 11, [[1.4 i0.2]], 1.5, 11, 11),
}

definitions["lavasplash-medium"] = {
	lavapool    = lavapool(11, 55, [[-2 r4, -0.5 r1, -180 r360]]),
	circlewaves = lavawaves(3, [[0.7 r2]], [[1.4 i0.2]], 24),
	lavarush    = lavarush(1, 1, [[3 r10]], 12, [[3.5 i0.5]], 0, 11, 28),
	embers      = lavaembers(7, 5, 15, 1.2, 8, 13, 21),
	lavachunks  = lavachunks(7, 2, 14, [[1.8 i0.2]], 1.5, 11, 11),
}

definitions["lavasplash-large"] = {
	lavapool    = lavapool(15, 65, [[-7 r14, -1.5 r3, -180 r360]]),
	circlewaves = lavawaves(3, [[1.3 r2.8]], [[2.1 i0.2]], 25),
	lavarush    = lavarush(1, 1, [[8 r17]], 21, [[3.5 i0.5]], 0, 28, 50),
	embers      = lavaembers(12, 5.5, 17, 1.3, 8, 16, 23),
	lavachunks  = lavachunks(8, 2.5, 16, [[2 i0.2]], 1.5, 13, 13,
		[[-70 r140, -0.4 r0.8, -180 r360]]),
}

definitions["lavasplash-huge"] = {
	lavapool    = lavapool(22, 85, [[-7 r14, -1.5 r3, -180 r360]]),
	lavaglow    = lavaglow([[32 r20]], [[85 r30]], [[-4 r8, -0.4 r0.8, -180 r360]]),
	circlewaves = lavawaves(4, [[1.4 r3.5]], [[2.1 i0.2]], 28),
	lavarush    = lavarush(2, 1, [[10 r20]], 21, [[4.8 i1.2]], 0, 32, 53,
		nil, [[r0.08, 1, r0.08]]),
	embers      = lavaembers(16, 6, 19, 1.3, 8, 18, 25),
	lavachunks  = lavachunks(8, 2.7, 17, [[2.8 i0.2]], 1.5, 17, 15,
		[[-70 r140, -0.4 r0.8, -180 r360]]),
}

definitions["lavasplash-gigantic"] = {
	lavapool    = lavapool(40, 85, [[-8 r16, -1.5 r3, -180 r360]]),
	lavaglow    = lavaglow([[70 r42]], [[85 r30]], [[-4 r8, -0.4 r0.8, -180 r360]]),
	circlewaves = lavawaves(7, [[4 r12]], [[1.3 i0.8]], 56),
	lavarush    = lavarush(2, 2, [[28 r48]], 68, [[10.5 i0.7]], 6, 35, 56,
		[[-70 r140, 70 r35, -70 r140]], [[r0.1, 0.7, r0.1]]),
	lavasmoke   = lavasmoke(1, [[15 r23]], 1.7, [[44 r55]], [[28 r14]],
		[[-17 r34, -7 r14, 0 r65]]),
	embers      = lavaembers(6, 20, 25, 5.6, 11, 45, 38),
	lavachunks  = lavachunks(8, 15, 38, [[4.2 i0.7]], 5, 35, 29,
		[[-70 r140, -7 r14, -180 r360]]),
	lavashockwave  = lavashockwave(6, [[-18 r4]], 17),
	lavagroundflash = lavagroundflash(140, 2, 85),
}

definitions["lavasplash-nuke"] = {
	lavapool    = lavapool(95, 115),
	lavaflare   = lavaflare(630, 12),
	lavaglow    = lavaglow([[200 r72]], [[78 r28]], [[-1.5 r3, -0.4 r0.8, -180 r360]]),
	circlewaves = lavawaves(14, [[6 r17]], [[2.2 i1.2]], 75),
	lavarush    = lavarush(3, 2, [[66 r84]], 84, [[13 i0.7]], 7, 70, 84,
		[[-91 r182, 77 r42, -91 r182]], [[r0.1, 0.7, r0.1]]),
	lavasmoke   = lavasmoke(2, [[24 r38]], 1.9, [[62 r78]], [[38 r18]],
		[[-35 r70, -7 r14, 0 r65]]),
	embers      = lavaembers(18, 24, 27, 9, 17, 56, 45),
	lavachunks  = lavachunks(14, 30, 63, [[5.6 i0.7]], 5.6, 63, 28,
		[[-35 r70, -5 r10, -180 r360]]),
	lavashockwave  = lavashockwave(22, [[-13 r3.5]], 115),
	lavagroundflash = lavagroundflash(195, 2, 100),
}

definitions["lavasplash-nukexl"] = {
	lavapool    = lavapool(130, 125),
	lavaflare   = lavaflare(770, 12),
	lavaglow    = lavaglow([[275 r82]], [[85 r28]], [[-1.5 r3, -0.4 r0.8, -180 r360]]),
	circlewaves = lavawaves(14, [[8 r19]], [[2.5 i1.3]], 78),
	lavarush    = lavarush(3, 2, [[84 r98]], 98, [[18 i0.7]], 10, 70, 98,
		[[-91 r182, 77 r42, -91 r182]], [[r0.1, 0.7, r0.1]]),
	lavasmoke   = lavasmoke(3, [[28 r48]], 2.1, [[72 r96]], [[46 r23]],
		[[-35 r70, -7 r14, 0 r65]]),
	embers      = lavaembers(18, 56, 56, 12, 18, 63, 45),
	lavachunks  = lavachunks(17, 42, 105, [[7.7 i1.4]], 7, 77, 31,
		[[-35 r70, -5 r10, -180 r360]]),
	lavashockwave  = lavashockwave(14, [[-15 r4]], 15),
	lavagroundflash = lavagroundflash(360, 3.5, 155),
}


-- Lava versions of old watersplash effects (used by unit_water_depth_damage.lua)

definitions["lavasplash_small"] = {
	lavaball = {
		air = true, class = [[CSimpleParticleSystem]], count = 1,
		ground = true, underwater = 1, water = true,
		properties = {
			airdrag            = 1,
			colormap           = C.ball,
			directional        = true,
			emitrot            = 30,
			emitrotspread      = [[0 r-360 r360]],
			emitvector         = [[0, 1, 0]],
			gravity            = [[0, 0, 0]],
			numparticles       = 14,
			particlelife       = 2,
			particlelifespread = 14,
			particlesize       = 0.4,
			particlesizespread = 1.4,
			particlespeed      = [[0 r2 i-0.04]],
			particlespeedspread = 1.5,
			pos                = [[0 r-7 r7, 2 r4, 0 r-7 r7]],
			sizegrowth         = [[0.12 r0.7 r-0.7]],
			sizemod            = 1.0,
			texture            = [[dirt]],
			alwaysvisible      = true,
		},
	},
	embers      = lavaembers(4, 3.5, 3.5, 2, 1.4, 28, 8),
	lavachunks  = lavachunks(5, 1, 3, [[2 i0.2]], 1.5, 11, 8),
}

definitions["lavasplash_large"] = {
	lavapool    = lavapool(12, 55),
	circlewaves = lavawaves(3, [[1 r2.5]], [[1.8 i0.2]], 22),
	lavarush    = lavarush(1, 1, [[6 r14]], 16, [[3 i0.5]], 0, 22, 42),
	embers      = lavaembers(10, 5, 14, 1, 7, 14, 18),
	lavachunks  = lavachunks(7, 2, 14, [[2 i0.2]], 1.5, 13, 11),
}


return definitions
