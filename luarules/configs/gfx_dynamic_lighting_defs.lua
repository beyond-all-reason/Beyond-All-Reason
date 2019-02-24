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


local rgbSpecMults = {0.2, 0.2, 0.2} -- specular RGB scales
local copyLightDefs = {
	["BA"] = {
		--Dgun
		["armcom_disintegrator"  ] = "disintegrator",
		["corcom_disintegrator"  ] = "disintegrator",
		["armdecom_disintegrator"  ] = "disintegrator",
		["cordecom_disintegrator"  ] = "disintegrator",

		--Self-D , Explosion for large units eg corkrog and commanders etc
		--["commanderexplosion"           ] = "commander_explosion",
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
		["armjuno_juno_pulse"          ] = "juno",
		["corjuno_juno_pulse"          ] = "juno",
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
			["disintegrator"] = {
				projectileLightDef = {
					diffuseColor      = {0.66,                   0.34,                   0.025                  },
					specularColor     = {0.66 * rgbSpecMults[1], 0.34 * rgbSpecMults[2], 0.025 * rgbSpecMults[3]},
					radius            = 180.0,
					priority          = 2 * 10,
					ttl               = 100000,
					ignoreLOS         = false,
				},
			},

			-- explodeas/selfdestructas lights for various large units
			["commander_explosion"] = {
				explosionLightDef = {
					diffuseColor      = {1.0,                   1.0,                   1.0                  },
					specularColor     = {1.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 1.0 * rgbSpecMults[3]},
					priority          = 15 * 10,
					radius            = 800.0,
					ttl               = 7 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
					ignoreLOS         = false,
				},
			},

			["nuke_crblmssl_blast"] = {
				explosionLightDef = {
					diffuseColor      = {1.0,                   1.0,                   1.0                  },
					specularColor     = {1.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 1.0 * rgbSpecMults[3]},
					priority          = 15 * 10,
					radius            = 960.0,
					ttl               = 4.0 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
				},
			},

			["nuke_missile_blast"] = {
				explosionLightDef = {
					diffuseColor      = {1.0,                   1.0,                   1.0                  },
					specularColor     = {1.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 1.0 * rgbSpecMults[3]},
					priority          = 15 * 10,
					radius            = 840.0,
					ttl               = 4.0 * Game.gameSpeed,
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
					diffuseColor      = {0.7,                  0.4,                   0.4                  },
					specularColor     = {0.7 * rgbSpecMults[1], 0.4 * rgbSpecMults[2], 0.4 * rgbSpecMults[3]},
					priority        = 20 * 10,
					radius          = 360.0,
					ttl             = 100000,
					ignoreLOS       = false,
				},

				explosionLightDef = {
					diffuseColor      = {0.5,                  0.5,                   0.5                  },
					specularColor     = {0.5 * rgbSpecMults[1], 0.5 * rgbSpecMults[2], 0.5 * rgbSpecMults[3]},
					priority          = 20 * 10 + 1,
					radius            = 960.0,
					ttl               = 15 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
				},
			},

			["nuke_missile"] = {
				projectileLightDef = {
					diffuseColor      = {0.7,                  0.4,                   0.4                  },
					specularColor     = {0.7 * rgbSpecMults[1], 0.4 * rgbSpecMults[2], 0.4 * rgbSpecMults[3]},
					priority        = 20 * 10,
					radius          = 330.0,
					ttl             = 100000,
					ignoreLOS       = false,
				},

				explosionLightDef = {
					diffuseColor      = {0.5,                  0.5,                   0.5                  },
					specularColor     = {0.5 * rgbSpecMults[1], 0.5 * rgbSpecMults[2], 0.5 * rgbSpecMults[3]},
					priority          = 20 * 10 + 1,
					radius            = 840.0,
					ttl               = 2.2 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 250.0,
				},
			},

			-- Arm Stunner / Core Neutron (small nuke) projectiles
			["emp_weapon"] = {
				projectileLightDef = {
					diffuseColor      = {0.7,                  0.4,                   0.4                  },
					specularColor     = {0.7 * rgbSpecMults[1], 0.4 * rgbSpecMults[2], 0.4 * rgbSpecMults[3]},
					priority        = 8 * 10,
					radius          = 250.0,
					ttl             = 100000,
					ignoreLOS       = false,
				},
				explosionLightDef = {
					diffuseColor      = {0,                  0.2,                   1                 },
					specularColor     = {0 * rgbSpecMults[1], 0.2 * rgbSpecMults[2], 1 * rgbSpecMults[3]},
					priority          = 8 * 10 + 1,
					radius            = 250.0,
					ttl               = 9 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 125.0,
				},
			},

			["tron_weapon"] = {
				projectileLightDef = {
					diffuseColor    = {1.0,                   0.7,                   0.7                  },
					specularColor   = {1.0 * rgbSpecMults[1], 0.7 * rgbSpecMults[2], 0.7 * rgbSpecMults[3]},
					priority        = 8 * 10,
					radius          = 200.0,
					ttl             = 100000,
					ignoreLOS       = false,
				},
				explosionLightDef = {
					diffuseColor      = {1.0,                   1.0,                   0.7                  },
					specularColor     = {1.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 0.7 * rgbSpecMults[3]},
					priority          = 8 * 10 + 1,
					radius            = 530.0,
					ttl               = 3 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 125.0,
				},
			},
			-- Arm Bertha / Core Intimidator (main barrel) projectiles
			-- NOTE:
			--   No lol cannon here way to many lights needed
			["berthacannon"] = {
				projectileLightDef = {
					diffuseColor    = {0.8,                   0.6,                   0.0                  },
					specularColor   = {1.9 * rgbSpecMults[1], 0.9 * rgbSpecMults[2], 0.0 * rgbSpecMults[3]},
					priority        = 5 * 10,
					radius          = 105.0,
					ttl             = 1000,
					ignoreLOS       = false,
				},
				explosionLightDef = {
					diffuseColor      = {1.7,                   1.2,                   0.0                  },
					specularColor     = {1.7 * rgbSpecMults[1], 1.2 * rgbSpecMults[2], 0.0 * rgbSpecMults[3]},
					priority          = 2 * 10 + 1,
					radius            = 220.0,
					ttl               = 2 * Game.gameSpeed,
					decayFunctionType = {0.0, 0.0, 0.0},
					altitudeOffset    = 150.0,
				},
			},
			-- Juno Weapon
			["juno"] = {
				projectileLightDef = {
					diffuseColor    = {1,                   0.7,                   0.1                  },
					specularColor   = {1 * rgbSpecMults[1], 0.7 * rgbSpecMults[2], 0.1 * rgbSpecMults[3]},
					priority        = 5 * 10,
					radius          = 180.0,
					ttl             = 1000,
					ignoreLOS       = false,
				},
				explosionLightDef = {
					diffuseColor      = {1.0,                   1.0,                   0.5                  },
					specularColor     = {1.0 * rgbSpecMults[1], 1.0 * rgbSpecMults[2], 0.5 * rgbSpecMults[3]},
					priority          = 3 * 10 + 1,
					radius            = 960.0,
					ttl               = 8 * Game.gameSpeed,
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

