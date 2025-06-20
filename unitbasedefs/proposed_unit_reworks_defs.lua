local function proposed_unit_reworksTweaks(name, uDef)









		if name == "armspy" then
		uDef.script = "Units/ARMSPY2.cob"
		uDef.selfdestructas = "smallExplosionGeneric"
		uDef.weapondefs.crawl_dummy = {
				areaofeffect = 32,
				avoidfeature = false,
				beamdecay = 0.5,
				beamtime = 1,
				beamttl = 1,
				collidefriendly = false,
				corethickness = 0.4,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				duration = 0.01,
				edgeeffectiveness = 0.15,
				energypershot = 500,
				explosiongenerator = "custom:laserhit-emp",
				impulsefactor = 0,
				laserflaresize = 6.05,
				name = "Heavy EMP beam",
				noselfdamage = true,
				paralyzer = true,
				paralyzetime = 10,
				range = 210,
				reloadtime = 20,
				rgbcolor = "0.7 0.7 1",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundstart = "hackshotxl3",
				soundtrigger = 1,
				thickness = 3.5,
				tolerance = 6000,
				turret = false,
				weapontype = "BeamLaser",
				weaponvelocity = 1000,
				damage = {
					default = 18000,
				},
			}
		end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
