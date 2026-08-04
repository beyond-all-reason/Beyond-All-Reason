--------------------------------------------------------------------------------
-- Dummy Projectile Unit written by Steel December 2025
--
-- Overview:
--   This unit definition exists solely to support game_volcano_pyroclastic.lua
--   This dummy unit launches the fireballs from the volcano on Forge v2.3

return {
	volcano_projectile_unit = {

		--------------------------------------------------------------------------
		-- REQUIRED BY BAR (DO NOT REMOVE)
		--------------------------------------------------------------------------
		customparams     = {
			faction = "NONE",
			is_volcano_launcher = 1,
		},

		--------------------------------------------------------------------------
		-- Give it non-zero power (prevents XP / division warnings)
		--------------------------------------------------------------------------
		metalcost        = 100,
		energycost       = 100,
		buildtime        = 1,
		health           = 1000000,
		power            = 1,

		--------------------------------------------------------------------------
		-- No wreckage
		--------------------------------------------------------------------------
		corpse           = "",
		leavetracks      = false,

		--------------------------------------------------------------------------
		-- Real combat unit (engine requirement)
		--------------------------------------------------------------------------
		canmove          = true,
		movementclass    = "BOT3",
		speed            = 0.0001,

		canattack        = true,
		canattackground  = true,
		category         = "SURFACE",

		--------------------------------------------------------------------------
		-- Invisible & non-interactive
		--------------------------------------------------------------------------
		drawtype         = 0,
		selectable       = false,
		blocking         = false,
		yardmap          = "o",

		canstop          = false,
		canpatrol        = false,
		canrepeat        = false,

		-- invisible in-game without removing the model/script pipeline
		initcloaked      = true,
		cloakcost        = 0,
		cloakcostmoving  = 0,
		mincloakdistance = 0,
		stealth          = true,
		sonarstealth     = true,

		--------------------------------------------------------------------------
		-- Known-good firing pipeline
		--------------------------------------------------------------------------
		objectname       = "Units/CORTHUD.s3o",
		script           = "Units/CORTHUD.cob",

		footprintx       = 2,
		footprintz       = 2,

		sightdistance    = 0,
		radardistance    = 0,
		seismicsignature = 0,

		--------------------------------------------------------------------------------
		-- WEAPON
		--------------------------------------------------------------------------------
		weapondefs       = {
			volcano_fireball = {
				name               = "Volcano Fireball",
				weapontype         = "Cannon",

				model              = "Raptors/greyrock2.s3o",
				cegtag             = "volcano_rock_trail",
				explosiongenerator = "custom:volcano_rock_impact",

				gravityaffected    = true,
				hightrajectory     = 1,
				trajectoryheight   = 1.1,
				mygravity          = 0.16,

				range              = 32000,
				reloadtime         = 5,
				weaponvelocity     = 780,
				impulsefactor      = 3,
				impulseboost       = 400,
				turret             = true,
				tolerance          = 5000,
				areaofeffect       = 220,
				edgeeffectiveness  = 0.9,

				collideground      = true,
				avoidfriendly      = false,
				avoidfeature       = false,

				soundhit           = "xplolrg1",
				soundhitvolume     = 75,

				damage             = {
					default = 100,
				},

			},
		},

		weapons          = {
			[1] = {
				def = "VOLCANO_FIREBALL",
				onlyTargetCategory = "SURFACE",
			},
		},
	},
}
