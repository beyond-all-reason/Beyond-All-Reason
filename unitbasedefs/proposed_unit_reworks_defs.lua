local function proposed_unit_reworksTweaks(name, uDef)
		if name == "corbw" then
			uDef.weapondefs.bladewing_lyzer.damage.default = 600
			uDef.weapons[1].onlytargetcategory = "SURFACE"
		end
		if name == "armdfly" then
			uDef.weapondefs.armdfly_paralyzer.damage.default = 10500
			uDef.weapondefs.armdfly_paralyzer.paralyzetime = 6
			uDef.weapondefs.armdfly_paralyzer.beamtime = 0.2
			uDef.weapons[1].onlytargetcategory = "SURFACE"
		end
		if name == "armspid" then
			uDef.weapons[1].onlytargetcategory = "SURFACE"
		end
		if name == "corgator" then
			uDef.weapondefs.gator_laserx.damage.vtol = 14
		end
		if name == "corak" then
			uDef.weapondefs.gator_laser.damage.vtol = 7
		end
		if name == "armpw" then
			uDef.weapondefs.emg.damage.vtol = 3
		end
		if name == "armsh" then
			uDef.weapondefs.armsh_weapon.damage.vtol = 7
		end
		if name == "corsh" then
			uDef.weapondefs.armsh_weapon.damage.vtol = 7
		end
		if uDef.customparams.paralyzemultiplier then
			if uDef.customparams.paralyzemultiplier < 0.03 then
				uDef.customparams.paralyzemultiplier = 0
			elseif uDef.customparams.paralyzemultiplier < 0.5 then
				uDef.customparams.paralyzemultiplier = 0.2
			else
				uDef.customparams.paralyzemultiplier = 1
			end
		end	

		if uDef.mass == 200000 or  uDef.mass == 2000000 or uDef.mass == 100000 or uDef.mass == 999999995904 then
			uDef.mass = uDef.metalcost
			uDef.cantbetransported = true
		end
		if uDef.mass then
			if uDef.mass > 4899 and uDef.mass < 5002 then
				uDef.mass = uDef.metalcost
			end
		end

		if name == "armliche" then
			uDef.weapondefs.arm_pidr.impulsefactor = 1
		end

		if name == "corvalk" then
			uDef.transportmass = 750
			uDef.energycost = 1450
			uDef.buildtime = 4120
		end
		if name == "armatlas" then
			uDef.transportmass = 750
			uDef.energycost = 1300
			uDef.buildtime = 3850
		end
		if name == "corseah" then
			uDef.speed = 235
		    uDef.sightdistance = 500
			uDef.transportcapacity = 1
			uDef.buildtime = 10000
		end
		if name == "armdfly" then
			uDef.transportcapacity = 1
		end
        if name == "armap" then
            uDef.buildoptions[7] = "armhvytrans"
		end
        if name == "corap" then
            uDef.buildoptions[7] = "corhvytrans"
		end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
