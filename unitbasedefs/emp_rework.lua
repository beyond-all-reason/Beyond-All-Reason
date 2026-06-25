local function empReworkUnitTweaks(name, unitDef)
	local weapondefs = unitDef.weapondefs

	if name == "armstil" then
		weapondefs.stiletto_bomb.areaofeffect = 250
		weapondefs.stiletto_bomb.burst = 3
		weapondefs.stiletto_bomb.burstrate = 0.3333
		weapondefs.stiletto_bomb.edgeeffectiveness = 0.30
		weapondefs.stiletto_bomb.damage.default = 3000
		weapondefs.stiletto_bomb.paralyzetime = 1
	end

	if name == "armspid" then
		weapondefs.spider.paralyzetime = 2
		weapondefs.spider.damage.vtol = 100
		weapondefs.spider.damage.default = 600
		weapondefs.spider.reloadtime = 1.495
	end

	if name == "armdfly" then
		weapondefs.armdfly_paralyzer.paralyzetime = 1
		weapondefs.armdfly_paralyzer.beamdecay = 0.05--testing
		weapondefs.armdfly_paralyzer.beamtime = 0.1--testing
		weapondefs.armdfly_paralyzer.areaofeffect = 8--testing
		weapondefs.armdfly_paralyzer.targetmoveerror = 0.05--testing




		--mono beam settings
		--weapondefs.armdfly_paralyzer.reloadtime = 0.05--testing
		--weapondefs.armdfly_paralyzer.damage.default = 150--testing (~2800/s for parity with live)
		--weapondefs.armdfly_paralyzer.beamdecay = 0.95
		--weapondefs.armdfly_paralyzer.duration = 200--should be unused?
		--weapondefs.armdfly_paralyzer.beamttl = 2--frames visible.just leads to laggy ghosting if raised too high.

		--burst testing within monobeam
		--weapondefs.armdfly_paralyzer.damage.default = 125
		--weapondefs.armdfly_paralyzer.reloadtime = 1--testing
		--weapondefs.armdfly_paralyzer.beamttl = 3--frames visible.just leads to laggy ghosting if raised too high.
		--weapondefs.armdfly_paralyzer.beamBurst = true--testing
		--weapondefs.armdfly_paralyzer.burst = 10--testing
		--weapondefs.armdfly_paralyzer.burstRate = 0.1--testing

	end

	if name == "armemp" then
		weapondefs.armemp_weapon.areaofeffect = 512
		weapondefs.armemp_weapon.burstrate = 0.3333
		weapondefs.armemp_weapon.edgeeffectiveness = -0.10
		weapondefs.armemp_weapon.paralyzetime = 22
		weapondefs.armemp_weapon.damage.default = 60000

	end
	if name == "armshockwave" then
		weapondefs.hllt_bottom.areaofeffect = 150
		weapondefs.hllt_bottom.edgeeffectiveness = 0.15
		weapondefs.hllt_bottom.reloadtime = 1.4
		weapondefs.hllt_bottom.paralyzetime = 5
		weapondefs.hllt_bottom.damage.default = 800
	end

	if name == "armthor" then
		weapondefs.empmissile.areaofeffect = 250
		weapondefs.empmissile.edgeeffectiveness = -0.50
		weapondefs.empmissile.damage.default = 20000
		weapondefs.empmissile.paralyzetime = 5
		weapondefs.emp.damage.default = 200
		weapondefs.emp.reloadtime = .5
		weapondefs.emp.paralyzetime = 1
	end

	if name == "corbw" then
		--weapondefs.bladewing_lyzer.burst = 4--shotgun mode, outdated but worth keeping
		--weapondefs.bladewing_lyzer.reloadtime = 0.8
		--weapondefs.bladewing_lyzer.beamburst = true
		--weapondefs.bladewing_lyzer.sprayangle = 2100
		--weapondefs.bladewing_lyzer.beamdecay = 0.5
		--weapondefs.bladewing_lyzer.beamtime = 0.03
		--weapondefs.bladewing_lyzer.beamttl = 0.4

		weapondefs.bladewing_lyzer.damage.default = 300
		weapondefs.bladewing_lyzer.paralyzetime = 1
	end

	local customparams = unitDef.customparams

	if (name =="corfmd" or name =="armamd" or name =="cormabm" or name =="armscab") then
		customparams.paralyzemultiplier = 1.5
	end

	if (name == "armvulc" or name == "corbuzz" or name == "legstarfall" or name == "corsilo" or name == "armsilo") then
		customparams.paralyzemultiplier = 2
	end

	--if name == "corsumo" then
		--customparams.paralyzemultiplier = 0.9
	--end

	if name == "armmar" then
		customparams.paralyzemultiplier = 0.8
	end

	if name == "armbanth" then
		customparams.paralyzemultiplier = 1.6
	end

	--if name == "armraz" then
		--customparams.paralyzemultiplier = 1.2
	--end
	--if name == "armvang" then
		--customparams.paralyzemultiplier = 1.1
	--end

	--if name == "armlun" then
		--customparams.paralyzemultiplier = 1.05
	--end

	--if name == "corshiva" then
		--customparams.paralyzemultiplier = 1.1
	--end

	--if name == "corcat" then
		--customparams.paralyzemultiplier = 1.05
	--end

	--if name == "corkarg" then
		--customparams.paralyzemultiplier = 1.2
	--end
	--if name == "corsok" then
		--customparams.paralyzemultiplier = 1.1
	--end
	--if name == "cordemont4" then
		--customparams.paralyzemultiplier = 1.2
	--end
end

local function empReworkWeaponTweaks(name, wDef)
	if name == 'empblast' then
		wDef.areaofeffect = 350
		wDef.edgeeffectiveness = 0.6
		wDef.paralyzetime = 12
		wDef.damage.default = 50000
	end
	if name == 'spybombx' then
		wDef.areaofeffect = 350
		wDef.edgeeffectiveness = 0.4
		wDef.paralyzetime = 20
		wDef.damage.default = 16000
	end
	if name == 'spybombxscav' then
		wDef.edgeeffectiveness = 0.50
		wDef.paralyzetime = 12
		wDef.damage.default = 35000
	end
end

return {
	UnitTweaks = empReworkUnitTweaks,
	WeaponTweaks = empReworkWeaponTweaks,
}
