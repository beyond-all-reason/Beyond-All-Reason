local function communityBalanceTweaks(name, uDef, modOptions)

	local communityBalancePatchDisabled = modOptions.community_balance_patch == "disabled"
	if not communityBalancePatchDisabled then
		local all = modOptions.community_balance_patch == "enabled"
		local custom = modOptions.community_balance_patch == "custom"
		if all or (custom and modOptions.community_balance_commando) then
			if name == "cormando" then
				-- +130 jammer range (150 -> 280)
				uDef.radardistancejam = 280
				-- +300 radar and LoS (900 -> 1200, 600 -> 900)
				uDef.radardistance = 1200
				uDef.sightdistance = 900
				-- Add light and heavy mines to build options
				local numBuildoptions = #uDef.buildoptions
				uDef.buildoptions[numBuildoptions + 1] = "cormine1"
				uDef.buildoptions[numBuildoptions + 2] = "cormine3"
				-- 80% EMP resist
				uDef.customparams.paralyzemultiplier = 0.2
				-- 2s self-destruct timer
				uDef.selfdestructcountdown = 2
				-- x2 autoheal (9 -> 18)
				uDef.autoheal = 18
				uDef.idleautoheal = 18

				-- Allow attacking air
				if uDef.weapons then
					for _, weapon in ipairs(uDef.weapons) do
						if weapon.def == "COMMANDO_BLASTER" then
							weapon.badtargetcategory = "VTOL"
							weapon.onlytargetcategory = "NOTSUB"
						end
					end
				end

				-- Weapon changes: Cannon -> Laser
				if uDef.weapondefs then
					for weaponName, weaponDef in pairs(uDef.weapondefs) do
						if weaponName == "commando_blaster" then
							weaponDef.accuracy = 0
							weaponDef.areaofeffect = 8
							weaponDef.avoidfeature = false
							weaponDef.beamtime = 0.2
							weaponDef.beamttl = 1
							weaponDef.tolerance = 10000
							weaponDef.thickness = 3
							weaponDef.corethickness = 0.2
							weaponDef.laserflaresize = 4
							weaponDef.impactonly = 1
							weaponDef.craterareaofeffect = 0
							weaponDef.craterboost = 0
							weaponDef.cratermult = 0
							weaponDef.energypershot = 20
							weaponDef.edgeeffectiveness = 0.15
							weaponDef.explosiongenerator = "custom:laserhit-small-red"
							weaponDef.firestarter = 100
							weaponDef.gravityaffected = false
							weaponDef.impulsefactor = 0
							weaponDef.name = "CommandoBlaster"
							weaponDef.noselfdamage = true
							weaponDef.predictboost = 0
							weaponDef.proximitypriority = nil
							weaponDef.range = 450
							weaponDef.reloadtime = 0.5
							weaponDef.rgbcolor = "0.85 0.3 0.2"
							weaponDef.soundhit = "xplosml5"
							weaponDef.soundhitwet = "sizzle"
							weaponDef.soundstart = "lasrfir5"
							weaponDef.turret = true
							weaponDef.weapontype = "BeamLaser"
							weaponDef.weaponvelocity = 1000
							weaponDef.damage = {
								default = 100,
								vtol = 50,
							}
						end
					end
				end
			end
		end

		if all or (custom and modOptions.community_balance_corkorg) then
			if name == "corkorg" then
				uDef.airsightdistance = 1600
				uDef.metalcost = 26000
			end
		end

		if all or (custom and modOptions.community_balance_corspy) then
			if name == "corspy" then
				uDef.energycost = 8800
				uDef.metalcost = 135
			end
		end

		if all or (custom and modOptions.community_balance_corjamt) then
			if name == "corjamt" then
				uDef.buildtime = 9950
				uDef.energycost = 8500
				uDef.energyupkeep = 40
				uDef.health = 790
				uDef.metalcost = 240
				uDef.radardistancejam = 500
			end
		end

		if all or (custom and modOptions.community_balance_armmav) then
			if name == "armmav" then
				uDef.metalcost = 520
				uDef.energycost = 6500
			end
		end

		if all or (custom and modOptions.community_balance_corcan) then
			if name == "corcan" then
				if uDef.weapondefs and uDef.weapondefs.cor_canlaser then
					uDef.weapondefs.cor_canlaser.range = 300
					uDef.weapondefs.cor_canlaser.beamtime = 0.24
				end
			end
		end
	end

	return uDef
end

return {
	communityBalanceTweaks = communityBalanceTweaks,
}
