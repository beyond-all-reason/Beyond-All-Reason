local function blue_burst_lasersTweaks(name, uDef)

    if name == "armwar" then
		uDef.weapondefs.armwar_laser.name = "Close-Range g2g Burst Laser"
		uDef.weapondefs.armwar_laser.rgbcolor = "0.3 0.1 0.6"
		uDef.weapondefs.armwar_laser.burst = 3
		uDef.weapondefs.armwar_laser.burstrate = 0.175
		uDef.weapondefs.armwar_laser.thickness = 3
		uDef.weapondefs.armwar_laser.reloadtime = 1.35
		uDef.weapondefs.armwar_laser.soundstart = "lasrlit3"
		uDef.weapondefs.armwar_laser.soundtrigger = false
		uDef.weapondefs.armwar_laser.explosiongenerator = "custom:laserhit-medium-blue"
		uDef.weapondefs.armwar_laser.damage = {
			default = 27.5,
			vtol = 4.5
		}

	elseif name == "armllt" then
		uDef.weapondefs.arm_lightlaser.name = "Light g2g Burst Laser"
		uDef.weapondefs.arm_lightlaser.rgbcolor = "0.3 0.1 0.6"
		uDef.weapondefs.arm_lightlaser.beamburst = true
		uDef.weapondefs.arm_lightlaser.burst = 3
		uDef.weapondefs.arm_lightlaser.explosiongenerator = "custom:laserhit-medium-blue"
		uDef.weapondefs.arm_lightlaser.burstrate = 0.175
		uDef.weapondefs.arm_lightlaser.thickness = 3
		uDef.weapondefs.arm_lightlaser.reloadtime = 0.7
		uDef.weapondefs.arm_lightlaser.soundstart = "lasrlit3"
		uDef.weapondefs.arm_lightlaser.soundtrigger = false
		uDef.weapondefs.arm_lightlaser.energypershot = 10
		uDef.weapondefs.arm_lightlaser.damage = {
			commanders = 56.25,
			default = 37.5,
			subs = 2.5,
			vtol = 2.5,
			}

	elseif name == "armamph" then
		uDef.weapondefs.armamph_weapon1.name = "Light g2g Burst Laser"
		uDef.weapondefs.armamph_weapon1.rgbcolor = "0.3 0.1 0.6"
		uDef.weapondefs.armamph_weapon1.burst = 3
		uDef.weapondefs.armamph_weapon1.beamburst = true
		uDef.weapondefs.armamph_weapon1.burstrate = 0.175
		uDef.weapondefs.armamph_weapon1.thickness = 3
		uDef.weapondefs.armamph_weapon1.reloadtime = 1.1
		uDef.weapondefs.armamph_weapon1.explosiongenerator = "custom:laserhit-medium-blue"
		uDef.weapondefs.armamph_weapon1.soundstart = "lasrlit3"
		uDef.weapondefs.armamph_weapon1.soundtrigger = false
		uDef.weapondefs.armamph_weapon1.damage = {
			default = 40,
			vtol = 7.5
		}
	elseif name == "armhlt" then
		uDef.weapondefs = {
			arm_laserh1 = {
				areaofeffect = 14,
				avoidfeature = false,
				beamtime = 0.15,
				corethickness = 0.25,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				energypershot = 75,
				explosiongenerator = "custom:laserhit-armmedium-green",
				firestarter = 90,
				impactonly = 1,
				impulsefactor = 0,
				laserflaresize = 9.9,
				name = "Heavy g2g high energy laser",
				noselfdamage = true,
				range = 620,
				reloadtime = 1.8,
				rgbcolor = "0 1 0",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundstart = "Lasrmas2",
				soundtrigger = 1,
				thickness = 3,
				tolerance = 10000,
				turret = true,
				weapontype = "BeamLaser",
				weaponvelocity = 2250,
				damage = {
					commanders = 580.5,
					default = 387,
					vtol = 35,
				},
			},
		}
			
    elseif name == "armcom" then
        uDef.weapondefs.armcomlaser.name = "Light g2g/g2a Burst Laser"
        uDef.weapondefs.armcomlaser.rgbcolor = "0.3 0.1 0.6"
        uDef.weapondefs.armcomlaser.beamburst = true
        uDef.weapondefs.armcomlaser.burst = 3
        uDef.weapondefs.armcomlaser.burstrate = 0.175
        uDef.weapondefs.armcomlaser.thickness = 3
        uDef.weapondefs.armcomlaser.reloadtime = 0.6
        uDef.weapondefs.armcomlaser.soundstart = "lasrlit3"
        uDef.weapondefs.armcomlaser.explosiongenerator = "custom:laserhit-medium-blue"
        uDef.weapondefs.armcomlaser.soundtrigger = false
        uDef.weapondefs.armcomlaser.damage = {
            default = 37.5,
            subs = 2.5,
        }

	elseif name == "armcrus" then
		uDef.weapondefs.laser.name = "Light close-quarters g2g burst laser"
		uDef.weapondefs.laser.rgbcolor = "0.3 0.1 0.6"
		uDef.weapondefs.laser.beamburst = true
		uDef.weapondefs.laser.burst = 3
		uDef.weapondefs.laser.burstrate = 0.175
		uDef.weapondefs.laser.thickness = 3
		uDef.weapondefs.laser.reloadtime = 0.5
		uDef.weapondefs.laser.soundstart = "lasrlit3"
		uDef.weapondefs.laser.explosiongenerator = "custom:laserhit-medium-blue"
		uDef.weapondefs.laser.soundtrigger = false
		uDef.weapondefs.laser.damage = {
			default = 37.5,
			vtol = 4
		}

	elseif name == "armfhlt" then
		uDef.weapondefs.armfhlt_laser.name = "High-Energy g2g Burst Laser"
		uDef.weapondefs.armfhlt_laser.rgbcolor = "0.1 0.0 0.9"
		uDef.weapondefs.armfhlt_laser.beamburst = true
		uDef.weapondefs.armfhlt_laser.burst = 3
		uDef.weapondefs.armfhlt_laser.burstrate = 0.175
		uDef.weapondefs.armfhlt_laser.thickness = 6
		uDef.weapondefs.armfhlt_laser.reloadtime = 1.35
		uDef.weapondefs.armfhlt_laser.soundstart = "lasrlit3"
		uDef.weapondefs.armfhlt_laser.explosiongenerator = "custom:laserhit-medium-blue"
		uDef.weapondefs.armfhlt_laser.soundtrigger = false
		uDef.weapondefs.armfhlt_laser.energypershot = 13.33
		uDef.weapondefs.armfhlt_laser.damage = {
			commanders = 150,
			default = 105,
			vtol = 26,
		}

	elseif name == "armraz" then
		uDef.weapondefs.mech_rapidlaser.rgbcolor = "0.0 0.0 1.0"

    end

    return uDef
end

return {
    blue_burst_lasersTweaks = blue_burst_lasersTweaks,
}