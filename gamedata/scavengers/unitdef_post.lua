-- -- UnitDef postprocessing specific to Scavenger units only

local function scavUnitDef_Post(name, uDef)
	uDef.category = uDef.category .. ' SCAVENGER'
	uDef.customparams.isscavenger = true
	uDef.capturable = false
	uDef.decloakonfire = true
	uDef.hidedamage = true
	if uDef.decoyfor and not string.find(uDef.decoyfor, "_scav") then
		uDef.decoyfor = uDef.decoyfor .. "_scav"
	end
	if uDef.icontype and not string.find(uDef.icontype, "_scav") then
		uDef.icontype = uDef.icontype .. "_scav"
	end

	-- replaced uniticons
	if uDef.buildpic then
		--Spring.Echo("FILEEXISTS", VFS.FileExists("unitpics/scavengers/"..uDef.buildpic))
		--local nonScavName = string.sub(uDef.unitname, 1, string.len(uDef.unitname)-5)
		if (not string.find(uDef.buildpic, "scavengers"))
			and (not string.find(uDef.buildpic, "raptor"))
			and (not string.find(uDef.buildpic, "critters"))
			and (not string.find(uDef.buildpic, "lootboxes"))
			and (not string.find(uDef.buildpic, "other"))
			and (not string.find(uDef.buildpic, "alternative"))
			and (VFS.FileExists("unitpics/scavengers/" .. uDef.buildpic)) then
			uDef.buildpic = "scavengers/" .. uDef.buildpic
		end
	end

	-- add model vertex displacement
	uDef.customparams.healthlookmod = 0.40

	-- make barrelshot purple
	if uDef.customparams.firingceg then
		if string.find(uDef.customparams.firingceg, 'barrelshot') then
			uDef.customparams.firingceg = uDef.customparams.firingceg .. '-purple'
		end
	end

	if uDef.sfxtypes then
		-- make barrelshot purple
		if uDef.sfxtypes.explosiongenerators then
			for k, v in pairs(uDef.sfxtypes.explosiongenerators) do
				if string.find(v, 'barrelshot') then
					uDef.sfxtypes.explosiongenerators[k] = v .. '-purple'
				end
			end
		end
		-- make deathcegs purple
		if uDef.sfxtypes.pieceexplosiongenerators then
			for k, v in pairs(uDef.sfxtypes.pieceexplosiongenerators) do
				if string.find(v, 'deathceg') then
					uDef.sfxtypes.pieceexplosiongenerators[k] = v .. '-purple'
				end
			end
		end
	end

	-- make unit explosion purple
	if uDef.explodeas then
		if string.find(string.lower(uDef.explodeas), 'explosiongeneric') or
			string.find(string.lower(uDef.explodeas), 'buildingexplosiongeneric') or
			string.find(string.lower(uDef.explodeas), 'explosiont3') or
			string.find(string.lower(uDef.explodeas), 'bantha') or
			string.find(string.lower(uDef.explodeas), 'lootbox')
		then
			uDef.explodeas = uDef.explodeas .. '-purple'
		end
	end

	if uDef.selfdestructas then
		if string.find(string.lower(uDef.selfdestructas), 'explosiongeneric') or
			string.find(string.lower(uDef.selfdestructas), 'buildingexplosiongeneric') or
			string.find(string.lower(uDef.selfdestructas), 'explosiont3') or
			string.find(string.lower(uDef.selfdestructas), 'bantha') or
			string.find(string.lower(uDef.selfdestructas), 'lootbox')
		then
			uDef.selfdestructas = uDef.selfdestructas .. '-purple'
		end
	end

	-- replace buildlists with _scav units
	if uDef.buildoptions then
		for k, v in pairs(uDef.buildoptions) do
			if UnitDefs[v .. '_scav'] then
				uDef.buildoptions[k] = v .. '_scav'
			end
		end
	end


	-- Remove wrecks of units you shouldn't be able to capture
	-- if uDef.featuredefs and uDef.corpse and (uDef.buildoptions or (not uDef.canmove)) then
	-- 	if uDef.corpse == "DEAD" and uDef.featuredefs.heap then
	-- 		uDef.corpse = "HEAP"
	-- 	elseif uDef.corpse then
	-- 		uDef.corpse = nil
	-- 	end
	-- end

	-- Set autoheal of scav units
	if uDef.health then
		if not string.find(name, "armscavengerbossv2") or string.find(name, "scavengerbossv4") then
			if not string.find(name, "scavbeacon") then
				uDef.health = uDef.health * 1.25
				if uDef.metalcost then uDef.metalcost = uDef.metalcost * 1.1 end
				if uDef.energycost then uDef.energycost = uDef.energycost * 1.1 end
				if uDef.buildtime then uDef.buildtime = uDef.buildtime * 1.1 end
			end
			uDef.autoheal = math.ceil(math.sqrt(uDef.health * 0.1))
			uDef.idleautoheal = math.ceil(math.sqrt(uDef.health * 0.1))
		end
	end

	-- Buff _scav units turnrate
	if uDef.turnrate then
		uDef.turnrate = uDef.turnrate * 1.2
	end
	if uDef.turninplaceanglelimit then
		uDef.turninplaceanglelimit = 360
	end

	-- Buff _scav builders
	if uDef.builder then
		if uDef.canmove == true then
			uDef.cancapture = true
			uDef.canresurrect = true
			if uDef.turnrate then
				uDef.turnrate = uDef.turnrate * 1.5
			end
			if uDef.maxdec then
				uDef.maxdec = uDef.maxdec * 1.5
			end
		end
		if uDef.builddistance then
			uDef.builddistance = uDef.builddistance * 1.25
		end
		if uDef.workerspeed then
			uDef.resurrectspeed = uDef.workerspeed * 4
			uDef.capturespeed = uDef.workerspeed * 4
			uDef.reclaimspeed = uDef.workerspeed * 2

			if uDef.metalcost then uDef.metalcost = uDef.metalcost * 1.5 end
			if uDef.energycost then uDef.energycost = uDef.energycost * 1.5 end
			if uDef.buildtime then uDef.buildtime = uDef.buildtime * 1.5 end
		end
	end

	-- Remove commander and evocom customparams from _scav commanders
	uDef.customparams.evolution_condition = nil
	uDef.customparams.evolution_target = nil
	uDef.customparams.respawn_condition = nil
	uDef.customparams.effigy = nil
	if uDef.buildoptions then
		for index, name in pairs(uDef.buildoptions) do
			if string.find(name, "comeffigylvl") then
				uDef.buildoptions[index] = nil
			end
		end
	end

	if uDef.customparams.iscommander then
		uDef.customparams.iscommander = nil
		uDef.customparams.isscavcommander = true
	end

	if uDef.customparams.isdecoycommander then
		uDef.customparams.isdecoycommander = nil
		uDef.customparams.isscavdecoycommander = true
	end

	if name == "armcom_scav" or name == "corcom_scav" or name == "legcom_scav" or string.find(name, "armcomlvl") or string.find(name, "corcomlvl") or string.find(name, "legcomlvl") then
		uDef.explodeas = "advmetalmaker"
		uDef.selfdestructas = "advmetalmakerSelfd"
	end

	-- Economy Boost
	if uDef.energystorage then
		uDef.energystorage = uDef.energystorage * 1.1
	end
	if uDef.energyupkeep and uDef.energyupkeep < 0 then
		uDef.energyupkeep = uDef.energyupkeep * 1.1
	end
	if uDef.energymake then
		uDef.energymake = uDef.energymake * 1.1
	end
	if uDef.metalstorage then
		uDef.metalstorage = uDef.metalstorage * 1.2
	end
	if (uDef.extractsmetal and uDef.extractsmetal > 0) then
		uDef.extractsmetal = uDef.extractsmetal * 1.2
	end
	if (uDef.customparams.metal_extractor and uDef.customparams.metal_extractor > 0) then
		uDef.customparams.metal_extractor = uDef.customparams.metal_extractor * 1.2
	end
	if uDef.customparams.energyconv_capacity then
		uDef.customparams.energyconv_capacity = uDef.customparams.energyconv_capacity * 1.2
	end
	if uDef.windgenerator then
		uDef.windgenerator = uDef.windgenerator*1.1
		if uDef.customparams.energymultiplier then
			uDef.customparams.energymultiplier = uDef.customparams.energymultiplier * 1.1
		else
			uDef.customparams.energymultiplier = 1.1
		end
	end

	if uDef.metalcost then uDef.metalcost = math.ceil(uDef.metalcost) end
	if uDef.energycost then uDef.energycost = math.ceil(uDef.energycost) end
	if uDef.buildtime then uDef.buildtime = math.ceil(uDef.buildtime) end

	if uDef.featuredefs and uDef.health then
		-- wrecks
		if uDef.featuredefs.dead then
			uDef.featuredefs.dead.damage = uDef.health
			if uDef.metalcost and uDef.energycost then
				uDef.featuredefs.dead.metal = math.floor(uDef.metalcost * 0.6)
			end
		end
		-- heaps
		if uDef.featuredefs.heap then
			uDef.featuredefs.heap.damage = uDef.health
			if uDef.metalcost and uDef.energycost then
				uDef.featuredefs.heap.metal = math.floor(uDef.metalcost * 0.25)
			end
		end
	end

	-- Extra Units ----------------------------------------------------------------------------------------------------------------------------------
		-- Armada T1 Land Constructors
		if name == "armca_scav" or name == "armck_scav" or name == "armcv_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Sea Constructors
		if name == "armcs_scav" or name == "armcsa_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armgplat_scav" -- Gun Platform - Light Plasma Defense
			uDef.buildoptions[numBuildoptions + 2] = "armfrock_scav" -- Scumbag - Anti Air Missile Battery
		end

		-- Armada T1 Vehicle Factory
		if name == "armvp_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armzapper_scav" -- Zapper - Light EMP Vehicle
		end

		-- Armada T1 Aircraft Plant
		if name == "armap_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armfify_scav" -- Firefly - Resurrection Aircraft
		end

		-- Armada T2 Land Constructors
		if name == "armaca_scav" or name == "armack_scav" or name == "armacv_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armshockwave_scav" -- Shockwave - T2 EMP Armed Metal Extractor
			uDef.buildoptions[numBuildoptions + 2] = "armwint2_scav" -- T2 Wind Generator
			uDef.buildoptions[numBuildoptions + 3] = "armnanotct2_scav" -- T2 Constructor Turret
			uDef.buildoptions[numBuildoptions + 4] = "armlwall_scav" -- Dragon's Fury - T2 Pop-up Wall Turret
			uDef.buildoptions[numBuildoptions + 5] = "armgatet3_scav" -- Asylum - Advanced Shield Generator
		end

		-- Armada T2 Sea Constructors
		if name == "armacsub_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armfgate_scav" -- Aurora - Floating Plasma Deflector
			uDef.buildoptions[numBuildoptions + 2] = "armnanotc2plat_scav" -- Floating T2 Constructor Turret
		end

		-- Armada T2 Shipyard
		if name == "armasy_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armexcalibur_scav" -- Excalibur - Coastal Assault Submarine
			uDef.buildoptions[numBuildoptions + 2] = "armseadragon_scav" -- Seadragon - Nuclear ICBM Submarine
		end

		-- Armada T3 Gantry
		if name == "armshltx_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armmeatball_scav" -- Meatball - Amphibious Assault Mech
			uDef.buildoptions[numBuildoptions + 2] = "armassimilator_scav" -- Assimilator - Battle Mech
		end

		-- Armada T3 Underwater Gantry
		if name == "armshltxuw_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armmeatball_scav" -- Meatball - Amphibious Assault Mech
			uDef.buildoptions[numBuildoptions + 2] = "armassimilator_scav" -- Assimilator - Battle Mech
		end

		-- Cortex T1 Land Constructors
		if name == "corca_scav" or name == "corck_scav" or name == "corcv_scav" then
			local numBuildoptions = #uDef.buildoptions
		end
	
		-- Cortex T1 Sea Constructors
		if name == "corcs_scav" or name == "corcsa_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corgplat_scav" -- Gun Platform - Light Plasma Defense
			uDef.buildoptions[numBuildoptions + 2] = "corfrock_scav" -- Janitor - Anti Air Missile Battery
		end

		-- Cortex T1 Bots Factory 
		if name == "corlab_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Land Constructors
		if name == "coraca_scav" or name == "corack_scav" or name == "coracv_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corwint2_scav" -- T2 Wind Generator
			uDef.buildoptions[numBuildoptions + 2] = "cornanotct2_scav" -- T2 Constructor Turret
			uDef.buildoptions[numBuildoptions + 3] = "cormwall_scav" -- Dragon's Rage - T2 Pop-up Wall Turret
			uDef.buildoptions[numBuildoptions + 4] = "corgatet3_scav" -- Sanctuary - Advanced Shield Generator
		end

		-- Cortex T2 Sea Constructors
		if name == "coracsub_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corfgate_scav" -- Atoll - Floating Plasma Deflector
			uDef.buildoptions[numBuildoptions + 2] = "cornanotc2plat_scav" -- Floating T2 Constructor Turret
		end

		-- Cortex T2 Bots Factory 
		if name == "coralab_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "cordeadeye_scav"
		end

		-- Cortex T2 Vehicle Factory
		if name == "coravp_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corvac_scav" -- Printer - Armored Field Engineer
			uDef.buildoptions[numBuildoptions + 2] = "corphantom_scav" -- Phantom - Amphibious Stealth Scout
			uDef.buildoptions[numBuildoptions + 3] = "corsiegebreaker_scav" -- Siegebreaker - Heavy Long Range Destroyer
			uDef.buildoptions[numBuildoptions + 4] = "corforge_scav" -- Forge - Flamethrower Combat Engineer
			uDef.buildoptions[numBuildoptions + 5] = "cortorch_scav" -- Torch - Fast Flamethrower Tank
		end

		-- Cortex T2 Aircraft Plant
		if name == "coraap_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Shipyard
		if name == "corasy_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "coresuppt3_scav" -- Adjudictator - Ultra Heavy Heatray Battleship
			uDef.buildoptions[numBuildoptions + 2] = "coronager_scav" -- Onager - Coastal Assault Submarine
			uDef.buildoptions[numBuildoptions + 3] = "cordesolator_scav" -- Desolator - Nuclear ICBM Submarine
			uDef.buildoptions[numBuildoptions + 4] = "CorPrince_scav" -- Black Prince - Shore bombardment battleship
		end

		-- Cortex T3 Gantry
		if name == "corgant_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T3 Underwater Gantry
		if name == "corgantuw_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Legion T1 Land Constructors
		if name == "legca_scav" or name == "legck_scav" or name == "legcv_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Legion T2 Land Constructors
		if name == "legaca_scav" or name == "legack_scav" or name == "legacv_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legmohocon_scav" -- Advanced Metal Fortifier - Metal Extractor with Constructor Turret
			uDef.buildoptions[numBuildoptions + 2] = "legwint2_scav" -- T2 Wind Generator
			uDef.buildoptions[numBuildoptions + 3] = "legnanotct2_scav" -- T2 Constructor Turret
			uDef.buildoptions[numBuildoptions + 4] = "legrwall_scav" -- Dragon's Constitution - T2 (not Pop-up) Wall Turret
			uDef.buildoptions[numBuildoptions + 5] = "leggatet3_scav" -- Elysium - Advanced Shield Generator
		end

		-- Legion T3 Gantry
		if name == "leggant_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legbunk_scav" -- Pilum - Fast Assault Mech
		end

	-- Scavengers Units ------------------------------------------------------------------------------------------------------------------------
		-- Armada T1 Land Constructors
		if name == "armca_scav" or name == "armck_scav" or name == "armcv_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Sea Constructors
		if name == "armcs_scav" or name == "armcsa_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Vehicle Factory
		if name == "armvp_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T1 Aircraft Plant
		if name == "armap_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Armada T2 Constructors
		if name == "armaca_scav" or name == "armack_scav" or name == "armacv_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armapt3_scav" -- T3 Aircraft Gantry
			uDef.buildoptions[numBuildoptions + 2] = "armminivulc_scav" -- Mini Ragnarok
			uDef.buildoptions[numBuildoptions + 3] = "armbotrail_scav" -- Pawn Launcher
			uDef.buildoptions[numBuildoptions + 4] = "armannit3_scav" -- Epic Pulsar
			uDef.buildoptions[numBuildoptions + 5] = "armafust3_scav" -- Epic Fusion Reactor
			uDef.buildoptions[numBuildoptions + 6] = "armmmkrt3_scav" -- Epic Energy Converter
		end

		-- Armada T2 Shipyard
		if name == "armasy_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armdronecarry_scav" -- Nexus - Drone Carrier
			uDef.buildoptions[numBuildoptions + 2] = "armptt2_scav" -- Epic Skater
			uDef.buildoptions[numBuildoptions + 3] = "armdecadet3_scav" -- Epic Dolphin
			uDef.buildoptions[numBuildoptions + 4] = "armpshipt3_scav" -- Epic Ellysaw
			uDef.buildoptions[numBuildoptions + 5] = "armserpt3_scav" -- Epic Serpent
			uDef.buildoptions[numBuildoptions + 6] = "armtrident_scav" -- Trident - Depth Charge Drone Carrier
		end

		-- Armada T3 Gantry
		if name == "armshltx_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armrattet4_scav" -- Ratte - Very Heavy Tank
			uDef.buildoptions[numBuildoptions + 2] = "armsptkt4_scav" -- Epic Recluse
			uDef.buildoptions[numBuildoptions + 3] = "armpwt4_scav" -- Epic Pawn
			uDef.buildoptions[numBuildoptions + 4] = "armvadert4_scav" -- Epic Tumbleweed - Nuclear Rolling Bomb
			uDef.buildoptions[numBuildoptions + 5] = "armdronecarryland_scav" -- Nexus Terra - Drone Carrier
		end

		-- Armada T3 Underwater Gantry
		if name == "armshltxuw_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "armrattet4_scav" -- Ratte - Very Heavy Tank
			uDef.buildoptions[numBuildoptions + 2] = "armsptkt4_scav" -- Epic Recluse
			uDef.buildoptions[numBuildoptions + 3] = "armpwt4_scav" -- Epic Pawn
			uDef.buildoptions[numBuildoptions + 4] = "armvadert4_scav" -- Epic Tumbleweed - Nuclear Rolling Bomb
		end

		-- Cortex T1 Bots Factory 
		if name == "corlab_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corkark_scav" -- Archaic Karkinos
		end

		-- Cortex T2 Land Constructors
		if name == "coraca_scav" or name == "corack_scav" or name == "coracv_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corapt3_scav" -- T3 Aircraft Gantry
			uDef.buildoptions[numBuildoptions + 2] = "corminibuzz_scav" -- Mini Calamity
			uDef.buildoptions[numBuildoptions + 3] = "corhllllt_scav" -- Quad Guard - Quad Light Laser Turret
			uDef.buildoptions[numBuildoptions + 4] = "cordoomt3_scav" -- Epic Bulwark
			uDef.buildoptions[numBuildoptions + 5] = "corafust3_scav" -- Epic Fusion Reactor
			uDef.buildoptions[numBuildoptions + 6] = "cormmkrt3_scav" -- Epic Energy Converter
		end

		-- Cortex T2 Sea Constructors
		if name == "coracsub_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Bots Factory
		if name == "coralab_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Cortex T2 Vehicle Factory
		if name == "coravp_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corgatreap_scav" -- Laser Tiger
			uDef.buildoptions[numBuildoptions+2] = "corftiger_scav" -- Heat Tiger
		end

		-- Cortex T2 Aircraft Plant
		if name == "coraap_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions+1] = "corcrw_scav" -- Archaic Dragon
		end

		-- Cortex T2 Shipyard
		if name == "corasy_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "cordronecarry_scav" -- Dispenser - Drone Carrier
			uDef.buildoptions[numBuildoptions + 2] = "corslrpc_scav" -- Leviathan - LRPC Ship
			uDef.buildoptions[numBuildoptions + 3] = "corsentinel_scav" -- Sentinel - Depth Charge Drone Carrier
		end

		-- Cortex T3 Gantry
		if name == "corgant_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corkarganetht4_scav" -- Epic Karganeth
			uDef.buildoptions[numBuildoptions + 2] = "corgolt4_scav" -- Epic Tzar
			uDef.buildoptions[numBuildoptions + 3] = "corakt4_scav" -- Epic Grunt
			uDef.buildoptions[numBuildoptions + 4] = "corthermite_scav" -- Thermite/Epic Termite
			uDef.buildoptions[numBuildoptions + 5] = "cormandot4_scav" -- Epic Commando
		end

		-- Cortex T3 Underwater Gantry
		if name == "corgantuw_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corkarganetht4_scav" -- Epic Karganeth
			uDef.buildoptions[numBuildoptions + 2] = "corgolt4_scav" -- Epic Tzar
			uDef.buildoptions[numBuildoptions + 3] = "corakt4_scav" -- Epic Grunt
			uDef.buildoptions[numBuildoptions + 4] = "cormandot4_scav" -- Epic Commando
		end

		-- Legion T1 Land Constructors
		if name == "legca_scav" or name == "legck_scav" or name == "legcv_scav" then
			local numBuildoptions = #uDef.buildoptions
		end

		-- Legion T2 Land Constructors
		if name == "legaca_scav" or name == "legack_scav" or name == "legacv_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legapt3_scav" -- T3 Aircraft Gantry
			uDef.buildoptions[numBuildoptions + 2] = "legministarfall_scav" -- Mini Starfall
			uDef.buildoptions[numBuildoptions + 3] = "legafust3_scav" -- Epic Fusion Reactor
			uDef.buildoptions[numBuildoptions + 4] = "legadveconvt3_scav" -- Epic Energy Converter
		end

		-- Legion T3 Gantry
		if name == "leggant_scav" then
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "legsrailt4_scav" -- Epic Arquebus
			uDef.buildoptions[numBuildoptions + 2] = "leggobt3_scav" -- Epic Goblin
			uDef.buildoptions[numBuildoptions + 3] = "legpede_scav" -- Mukade - Heavy Multi Weapon Centipede
		end

	-- Release candidate units --------------------------------------------------------------------------------------------------------------------------------------------------------
	-- there's nothing here!
	--------------------------------------------------------------------------------------------------------------------------------------------------------

	return uDef
end

return {
	ScavUnitDef_Post = scavUnitDef_Post
}
