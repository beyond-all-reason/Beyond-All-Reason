local function communityBalanceTweaks(name, uDef, modOptions)

	local communityBalancePatchDisabled = modOptions.community_balance_patch == "disabled"
	if not communityBalancePatchDisabled then
		local all = modOptions.community_balance_patch == "enabled"
		local custom = modOptions.community_balance_patch == "custom"

		if all or (custom and modOptions.community_balance_corspy) then
			if name == "corspy" then
				uDef.energycost = 8800
				uDef.metalcost = 135
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

		if all or (custom and modOptions.community_balance_corkarg) then
			if name == "corkarg" then
				uDef.sightdistance = 515
				uDef.maxacc = 0.18
				uDef.turnrate = 515
				uDef.turninplacespeedlimit = 1.25
				uDef.strafetoattack = true
				uDef.metalcost = 2650
				uDef.buildtime = 100000
				if uDef.weapondefs and uDef.weapondefs.super_missile then
					uDef.weapondefs.super_missile.trajectoryheight = 0.25
				end
			end
		end

		if all or (custom and modOptions.community_balance_armkam) then
			if name == "armkam" then
				uDef.maxacc = 0.35
				if uDef.weapondefs and uDef.weapondefs.emg then
					local weaponDef = uDef.weapondefs.emg
					weaponDef.burst = nil
					weaponDef.burstrate = nil
					weaponDef.areaofeffect = 32
					weaponDef.edgeeffectiveness = 0.25
					weaponDef.explosiongenerator = "custom:genericshellexplosion-small-bomb"
					weaponDef.impulsefactor = 2.5
					weaponDef.range = 425
					weaponDef.reloadtime = 3.0
					weaponDef.soundstart = "mavgun4"
					weaponDef.weaponvelocity = 900
					weaponDef.damage = {
						default = 116,
						vtol = 3,
					}
				end
			end
		end

		if all or (custom and modOptions.community_balance_armblade) then
			if name == "armblade" then
				uDef.maxacc = 0.28
				uDef.maxdec = 0.55
				uDef.speed = 165
				uDef.turninplaceanglelimit = 120
				uDef.turnrate = 420
				uDef.sightdistance = 720
				uDef.weapondefs.vtol_sabot = {
					areaofeffect = 24,
					avoidfeature = false,
					burst = 2,
					burstrate = 0.15,
					cegtag = "impulse-trail",
					craterareaofeffect = 0,
					craterboost = 0,
					cratermult = 0,
					cylindertargeting = 1,
					edgeeffectiveness = 0.25,
					explosiongenerator = "custom:genericshellexplosion-medium-bomb",
					firestarter = 70,
					gravityaffected = "true",
					impulsefactor = 2.33,
					name = "Medium-range precision gauss rifle",
					noselfdamage = true,
					range = 1100,
					reloadtime = 5.5,
					soundhit = "xplomed2",
					soundhitwet = "splshbig",
					soundstart = "mavgun5",
					turret = true,
					weapontype = "Cannon",
					weaponvelocity = 1090,
					customparams = {
						noattackrangearc = 1,
					},
					damage = {
						default = 410,
					},
				}
				uDef.weapons[1].maindir = "0 0 1"
				uDef.weapons[1].maxangledif = 45
			end
		end
	end

	return uDef
end

return {
	communityBalanceTweaks = communityBalanceTweaks,
}
