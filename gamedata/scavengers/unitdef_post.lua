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

	-- Extra Units for Scavs
	if name == "armshltx_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armrattet4_scav"
		uDef.buildoptions[numBuildoptions + 2] = "armsptkt4_scav"
		uDef.buildoptions[numBuildoptions + 3] = "armpwt4_scav"
		uDef.buildoptions[numBuildoptions + 4] = "armvadert4_scav"
		-- uDef.buildoptions[numBuildoptions+5] = "armlunchbox"
		uDef.buildoptions[numBuildoptions + 6] = "armmeatball_scav"
		uDef.buildoptions[numBuildoptions + 7] = "armassimilator_scav"
		uDef.buildoptions[numBuildoptions + 8] = "armdronecarryland_scav"
	elseif name == "armshltxuw_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armrattet4_scav"
		uDef.buildoptions[numBuildoptions + 2] = "armpwt4_scav"
		uDef.buildoptions[numBuildoptions + 3] = "armvadert4_scav"
		uDef.buildoptions[numBuildoptions + 4] = "armmeatball_scav"
	elseif name == "armap_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armfify_scav"
	elseif name == "corgantuw_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corgolt4_scav"
		uDef.buildoptions[numBuildoptions + 2] = "corakt4_scav"
	elseif name == "armvp_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armzapper_scav"
	elseif name == "corlab_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corkark_scav"
	elseif name == "legavp_scav" then
		local numBuildoptions = #uDef.buildoptions
	elseif name == "coravp_scav" then
		local printerpresent = false

		for ix, UnitName in pairs(uDef.buildoptions) do
			if UnitName == "corvac_scav" then
				printerpresent = true
			end
		end

		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corgatreap_scav"
		uDef.buildoptions[numBuildoptions + 2] = "corforge_scav"
		uDef.buildoptions[numBuildoptions + 3] = "corftiger_scav"
		uDef.buildoptions[numBuildoptions + 4] = "cortorch_scav"
		uDef.buildoptions[numBuildoptions + 5] = "corsiegebreaker_scav"
		uDef.buildoptions[numBuildoptions + 6] = "corphantom_scav"
		if (printerpresent == false) then               -- assuming sala and vac stay paired, this is tidiest solution
			local numBuildoptions = #uDef.buildoptions
			uDef.buildoptions[numBuildoptions + 1] = "corvac_scav" --corprinter
		end
	elseif name == "coralab_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "cordeadeye_scav"
	elseif name == "coraap_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corcrw_scav"
	elseif name == "corgant_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corkarganetht4_scav"
		uDef.buildoptions[numBuildoptions + 2] = "corgolt4_scav"
		uDef.buildoptions[numBuildoptions + 3] = "corakt4_scav"
		uDef.buildoptions[numBuildoptions + 4] = "corthermite_scav"
		uDef.buildoptions[numBuildoptions + 5] = "cormandot4_scav"
	elseif name == "leggant_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "legsrailt4_scav"
		uDef.buildoptions[numBuildoptions + 2] = "leggobt3_scav"
		uDef.buildoptions[numBuildoptions + 3] = "legpede_scav"
		uDef.buildoptions[numBuildoptions + 4] = "legbunk_scav"
	elseif name == "armca_scav" or name == "armck_scav" or name == "armcv_scav" then
		--local numBuildoptions = #uDef.buildoptions
	elseif name == "corca_scav" or name == "corck_scav" or name == "corcv_scav" then
		--local numBuildoptions = #uDef.buildoptions
	elseif name == "legca_scav" or name == "legck_scav" or name == "legcv_scav" then
		--local numBuildoptions = #uDef.buildoptions
	elseif name == "corcs_scav" or name == "corcsa_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corgplat_scav"
		uDef.buildoptions[numBuildoptions + 2] = "corfrock_scav"
	elseif name == "armcs_scav" or name == "armcsa_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armgplat_scav"
		uDef.buildoptions[numBuildoptions + 2] = "armfrock_scav"
	elseif name == "coracsub_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corfgate_scav"
		uDef.buildoptions[numBuildoptions + 2] = "cornanotc2plat_scav"
	elseif name == "armacsub_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armfgate_scav"
		uDef.buildoptions[numBuildoptions + 2] = "armnanotc2plat_scav"
	elseif name == "armaca_scav" or name == "armack_scav" or name == "armacv_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armapt3_scav"
		uDef.buildoptions[numBuildoptions + 2] = "armminivulc_scav"
		uDef.buildoptions[numBuildoptions + 3] = "armwint2_scav"
		uDef.buildoptions[numBuildoptions + 5] = "armbotrail_scav"
		uDef.buildoptions[numBuildoptions + 6] = "armannit3_scav"
		uDef.buildoptions[numBuildoptions + 7] = "armnanotct2_scav"
		uDef.buildoptions[numBuildoptions + 8] = "armlwall_scav"
		uDef.buildoptions[numBuildoptions + 9] = "armshockwave_scav"
		uDef.buildoptions[numBuildoptions + 10] = "armgatet3_scav"
		uDef.buildoptions[numBuildoptions + 11] = "armafust3_scav"
		uDef.buildoptions[numBuildoptions + 12] = "armmmkrt3_scav"
	elseif name == "coraca_scav" or name == "corack_scav" or name == "coracv_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corapt3_scav"
		uDef.buildoptions[numBuildoptions + 2] = "corminibuzz_scav"
		uDef.buildoptions[numBuildoptions + 3] = "corwint2_scav"
		uDef.buildoptions[numBuildoptions + 4] = "corhllllt_scav"
		uDef.buildoptions[numBuildoptions + 6] = "cordoomt3_scav"
		uDef.buildoptions[numBuildoptions + 7] = "cornanotct2_scav"
		uDef.buildoptions[numBuildoptions + 8] = "cormwall_scav"
		uDef.buildoptions[numBuildoptions + 9] = "corgatet3_scav"
		uDef.buildoptions[numBuildoptions + 10] = "corafust3_scav"
		uDef.buildoptions[numBuildoptions + 11] = "cormmkrt3_scav"
	elseif name == "legaca_scav" or name == "legack_scav" or name == "legacv_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "legapt3_scav"
		uDef.buildoptions[numBuildoptions + 2] = "legministarfall_scav"
		uDef.buildoptions[numBuildoptions + 3] = "legwint2_scav"
		uDef.buildoptions[numBuildoptions + 4] = "legnanotct2_scav"
		uDef.buildoptions[numBuildoptions + 5] = "legrwall_scav"
		uDef.buildoptions[numBuildoptions + 6] = "leggatet3_scav"
		uDef.buildoptions[numBuildoptions + 7] = "legafust3_scav"
		uDef.buildoptions[numBuildoptions + 8] = "legadveconvt3_scav"
	elseif name == "armasy_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armptt2_scav"
		uDef.buildoptions[numBuildoptions + 2] = "armdecadet3_scav"
		uDef.buildoptions[numBuildoptions + 3] = "armpshipt3_scav"
		uDef.buildoptions[numBuildoptions + 4] = "armserpt3_scav"
		uDef.buildoptions[numBuildoptions + 5] = "armtrident_scav"
		uDef.buildoptions[numBuildoptions + 6] = "armdronecarry_scav"
		uDef.buildoptions[numBuildoptions + 7] = "armexcalibur_scav"
		uDef.buildoptions[numBuildoptions + 8] = "armseadragon_scav"
	elseif name == "corasy_scav" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corslrpc_scav"
		uDef.buildoptions[numBuildoptions + 2] = "coresuppt3_scav"
		uDef.buildoptions[numBuildoptions + 3] = "corsentinel_scav"
		uDef.buildoptions[numBuildoptions + 4] = "cordronecarry_scav"
		uDef.buildoptions[numBuildoptions + 5] = "coronager_scav"
		uDef.buildoptions[numBuildoptions + 6] = "cordesolator_scav"
	end

	return uDef
end

return {
	ScavUnitDef_Post = scavUnitDef_Post
}
