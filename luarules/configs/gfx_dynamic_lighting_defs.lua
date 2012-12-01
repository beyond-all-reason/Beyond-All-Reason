local function CopyTable(srcTbl, dstTbl)
	assert(dstTbl ~= nil)

	for key, val in pairs(srcTbl) do
		assert(type(key) ~= type({}))

		if (type(val) == type({})) then
			dstTbl[key] = {}

			srcSubTbl = val
			dstSubTbl = dstTbl[key]

			CopyTable(srcSubTbl, dstSubTbl)
		else
			dstTbl[key] = val
		end
	end
end

--for decayfunctiontype see http://springrts.com/phpbb/viewtopic.php?p=532643#p532643


local rgbSpecMults = {0.25, 0.25, 0.25} -- specular RGB scales
local copyLightDefs = {
	["BA"] = {
		--Dgun
		["armcom_arm_disintegrator"  ] = "arm_disintegrator",
		["corcom_arm_disintegrator"  ] = "arm_disintegrator",

		--Self-D , Explosion for large units eg corkrog and commanders etc
		["commander_blast"           ] = "commander_blast",
		["crblmssl"                  ] = "nuke_crblmssl_blast",
		["nuclear_missile"           ] = "nuke_missile_blast",
		
		--Nukes
		["corsilo_crblmssl"          ] = "nuke_crblmssl",
		["armsilo_nuclear_missile"   ] = "nuke_missile",
		
		--Emp
		["armemp_armemp_weapon"      ] = "emp_weapon",

		--Tacnuke
		["cortron_cortron_weapon"    ] = "tron_weapon",
		
		--Brthas
		["corint_core_intimidator"   ] = "berthacannon",
		["armbrtha_arm_berthacannon" ] = "berthacannon",

		--Juno
		["ajuno_juno_pulse"          ] = "juno",
		["cjuno_juno_pulse"          ] = "juno",
	},
}
local dynLightDefs = {
	["BA"] = {
		weaponLightDefs = {
			-- Arm & Core Commander (dgun) projectiles
			-- NOTE:
			--   no explosion light defs, because a dgun
			--   projectile triggers a new explosion for
			--   every frame it is alive (which consumes
			--   too many light slots)
			["arm_disintegrator"] = {
				projectileLightDef = {
					diffuseColor      = {2.8,                   1.0,                   0.1                  },
					specularColor     = {2.8 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 0.1 * rgbSpecMults[3]},
					radius            = 100.0,
					priority          = 2 * 10,
					ttl               = 2 * Game.gameSpeed,
				},
			},

			-- explodeas/selfdestructas lights for various large units
			["commander_blast"] = { 
				explosionLightDef = {
					diffuseColor      = {6.0,                   6.0,                   6.0                  },
					specularColor     = {6.0 * rgbSpecMults[1], 6.0 * rgbSpecMults[2], 6.0 * rgbSpecMults[3]},
					priority          = 15 * 10,
					radius            = 720.0,
					ttl               = 2 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 65.0,
				},
			},

			["nuke_crblmssl_blast"] = {
				explosionLightDef = {
					diffuseColor      = {2.0,                   1.0,                   1.0                  },
					specularColor     = {2.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 1.0 * rgbSpecMults[3]},
					priority          = 15 * 10,
					radius            = 1500.0,
					ttl               = 1.3 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
				},
			},

			["nuke_missile_blast"] = {
				explosionLightDef = {
					diffuseColor      = {2.0,                   2.0,                   1.0                  },
					specularColor     = {2.0 * rgbSpecMults[1], 2.0 * rgbSpecMults[2], 1.0 * rgbSpecMults[3]},
					priority          = 15 * 10,
					radius            = 900.0,
					ttl               = 1.2 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
				},
			},

			-- Arm Retaliator / Core Silencer (large nuke) projectiles
			-- NOTE:
			--   uses a vertical offset to simulate an
			--   airburst, since the actual projectile
			--   detonates on ground impact
			--   ttl value roughly matches CEG duration
			["nuke_crblmssl"] = {
				projectileLightDef = {
					diffuseColor    = {3.0,                   2.0,                   2.0                  },
					specularColor   = {3.0 * rgbSpecMults[1], 2.0 * rgbSpecMults[2], 2.0 * rgbSpecMults[3]},
					priority        = 20 * 10,
					radius          = 170.0,
					ttl             = 100,
				},

				explosionLightDef = {
					diffuseColor      = {1.0,                   1.0,                   0.5                  },
					specularColor     = {1.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 0.5 * rgbSpecMults[3]},
					priority          = 20 * 10 + 1,
					radius            = 1250.0,
					ttl               = 1.6 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
				},
			},

			["nuke_missile"] = {
				projectileLightDef = {
					diffuseColor    = {3.0,                   2.0,                   2.0                  },
					specularColor   = {3.0 * rgbSpecMults[1], 2.0 * rgbSpecMults[2], 2.0 * rgbSpecMults[3]},
					priority        = 20 * 10,
					radius          = 170.0,
					ttl             = 100,
				},
				
				explosionLightDef = {
					diffuseColor      = {1.0,                   1.0,                   0.5                  },
					specularColor     = {1.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 0.5 * rgbSpecMults[3]},
					priority          = 20 * 10 + 1,
					radius            = 800.0,
					ttl               = 1.6 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
				},
			},
		
			-- Arm Stunner / Core Neutron (small nuke) projectiles
			["tron_weapon"] = {
				projectileLightDef = {
					diffuseColor    = {0.6,                   0.6,                   0.3                  },
					specularColor   = {0.6 * rgbSpecMults[1], 0.6 * rgbSpecMults[2], 0.3 * rgbSpecMults[3]},
					priority        = 8 * 10,
					radius          = 100.0,
					ttl             = 125,
				},
				explosionLightDef = {
					diffuseColor      = {3.0,                   2.0,                   2.0                  },
					specularColor     = {3.0 * rgbSpecMults[1], 2.0 * rgbSpecMults[2], 2.0 * rgbSpecMults[3]},
					priority          = 8 * 10 + 1,
					radius            = 400.0,
					ttl               = 2 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 125.0,
				},
			},

			["emp_weapon"] = {
				projectileLightDef = {
					diffuseColor    = {0.0,                   0.0,                   0.25                  },
					specularColor   = {0.0 * rgbSpecMults[1], 0.0 * rgbSpecMults[2], 0.25 * rgbSpecMults[3]},
					priority        = 8 * 10,
					radius          = 110.0,
					ttl             = 125,
				},
				explosionLightDef = {
					diffuseColor      = {0.0,                   0.25,                   0.75                  },
					specularColor     = {0.0 * rgbSpecMults[1], 0.25 * rgbSpecMults[2], 0.75 * rgbSpecMults[3]},
					priority          = 8 * 10 + 1,
					radius            = 256.0,
					ttl               = 2 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 125.0,
				},
			},
			-- Arm Bertha / Core Intimidator (main barrel) projectiles
			-- NOTE:
			--   No lol cannon (here way to many lights needed)
			["berthacannon"] = {
				projectileLightDef = {
					diffuseColor    = {2.9,                   1.9,                   0.2                  },
					specularColor   = {2.9 * rgbSpecMults[1], 1.9 * rgbSpecMults[2], 0.2 * rgbSpecMults[3]},
					priority        = 5 * 10,
					radius          = 115.0,
					ttl             = 10,
				},
			},
			-- Juno Weapon
			["juno"] = {
				projectileLightDef = {
					diffuseColor    = {0.0,                   0.5,                   0.4                 },
					specularColor   = {0.0 * rgbSpecMults[1], 0.5 * rgbSpecMults[2], 0.4 * rgbSpecMults[3]},
					priority        = 5 * 10,
					radius          = 120.0,
					ttl             = 125,
				},
				explosionLightDef = {
					diffuseColor      = {0.0,                   0.2,                   0.15                  },
					specularColor     = {0.0 * rgbSpecMults[1], 0.2 * rgbSpecMults[2], 0.15 * rgbSpecMults[3]},
					priority          = 3 * 10 + 1,
					radius            = 1400.0,
					ttl               = 70,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 150.0,
				},
			},
		},
	},
}

local modLightDefs = dynLightDefs[Game.modShortName]
local modCopyDefs = copyLightDefs[Game.modShortName]

-- insert copy-definitions for each light that has one
if (modLightDefs ~= nil and modCopyDefs ~= nil) then
	for dstWeaponDef, srcWeaponDef in pairs(modCopyDefs) do
		modLightDefs.weaponLightDefs[dstWeaponDef] = {}

		srcLightDefTbl = modLightDefs.weaponLightDefs[srcWeaponDef]
		dstLightDefTbl = modLightDefs.weaponLightDefs[dstWeaponDef]

		CopyTable(srcLightDefTbl, dstLightDefTbl)
	end
end

return dynLightDefs

