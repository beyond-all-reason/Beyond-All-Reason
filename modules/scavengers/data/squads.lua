--- Hand-written squads: the combinations the generated per-unit squads cannot
--- express, because they mix units.
---
--- Everything else in the roster is one unit repeated. These are the squads
--- somebody composed — a rezzer pair, a rover screen, a bomber flight — and
--- they are what makes a wave read as a force rather than a stack.
---
--- Anger windows are stated as tier references (minAngerTier) where they
--- follow a tier, and as plain numbers where they do not.

return {
	------Tier 1 0-25% (Land and Air)
	{
		type = "healerLand",
		minAngerTier = 2,
		maxAnger = 1000,
		units = {
			{ count = 5, unit = "armrectr_scav" },
			{ count = 5, unit = "cornecro_scav" },
		},
	}, --Rezzers
	{
		type = "healerLand",
		weight = 20,
		minAngerTier = 4,
		maxAnger = 1000,
		units = {
			{ count = 10, unit = "armrectr_scav" },
			{ count = 10, unit = "cornecro_scav" },
		},
	}, --Rezzers
	{
		type = "healerLand",
		weight = 40,
		minAngerTier = 6,
		maxAnger = 1000,
		units = {
			{ count = 20, unit = "armrectr_scav" },
			{ count = 20, unit = "cornecro_scav" },
		},
	}, --Rezzers
	--Land
	{
		type = "specialLand",
		weight = 6,
		maxAngerTier = 2,
		minAngerTier = 2,
		units = {
			{ count = 13, unit = "armfav_scav" },
			{ count = 13, unit = "corfav_scav" },
			{ count = 13, unit = "legscout_scav" },
		},
	}, --Rovers/Whole Tier Length
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 2,
		minAngerTier = 2,
		units = {
			{ count = 6, unit = "armflash_scav" },
			{ count = 6, unit = "corgator_scav" },
			{ count = 6, unit = "leghelios_scav" },
			{ count = 6, unit = "leghades_scav" },
		},
	}, --T1 Veh Raid
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 3,
		minAngerTier = 3,
		units = {
			{ count = 5, unit = "armstump_scav" },
			{ count = 5, unit = "corraid_scav" },
			{ count = 5, unit = "leggat_scav" },
			{ count = 5, unit = "leghades_scav" },
		},
	}, --T1 Veh Assault
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 3,
		minAngerTier = 3,
		units = {
			{ count = 2, unit = "armjanus_scav" },
			{ count = 2, unit = "corlevlr_scav" },
			{ count = 2, unit = "legrail_scav" },
			{ count = 6, unit = "leghades_scav" },
		},
	}, --T1 Veh Unique
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 3,
		minAngerTier = 3,
		units = {
			{ count = 1, unit = "armart_scav" },
			{ count = 2, unit = "armsam_scav" },
			{ count = 1, unit = "corwolv_scav" },
			{ count = 2, unit = "cormist_scav" },
			{ count = 2, unit = "legbar_scav" },
			{ count = 8, unit = "leghades_scav" },
		},
	}, --T1 Arty/AA
	--air
	{
		type = "specialAirLand",
		weight = 4,
		minAngerTier = 2,
		maxAnger = 1000,
		units = {
			{ count = 3, unit = "armpeep_scav" },
			{ count = 3, unit = "corfink_scav" },
			{ count = 9, unit = "legfig_scav" },
		},
	}, --T1 Air Scouts
	{
		type = "specialAirLand",
		weight = 4,
		maxAnger = 1000,
		minAngerTier = 3,
		units = {
			{ count = 12, unit = "corbw_scav" },
		},
	}, --Bladewings
	{
		type = "specialAirLand",
		weight = 4,
		maxAnger = 1000,
		minAngerTier = 3,
		units = {
			{ count = 20, unit = "armfig_scav" },
			{ count = 20, unit = "corveng_scav" },
		},
	}, --Fighters
	{
		type = "specialAirSea",
		weight = 5,
		maxAnger = 1000,
		minAngerTier = 3,
		units = {
			{ count = 20, unit = "armsfig_scav" },
			{ count = 20, unit = "corsfix_scav" },
		},
	}, --T2 Fighters
	{
		type = "specialAirLand",
		weight = 4,
		maxAnger = 1000,
		minAngerTier = 3,
		units = {
			{ count = 12, unit = "armthund_scav" },
			{ count = 12, unit = "corshad_scav" },
			{ count = 5, unit = "legcib_scav" },
		},
	}, --Bombers
	------Tier 2 25-60%
	{
		type = "specialLand",
		weight = 6,
		maxAngerTier = 4,
		minAngerTier = 4,
		units = {
			{ count = 10, unit = "armfav_scav" },
			{ count = 10, unit = "corfav_scav" },
			{ count = 25, unit = "armzapper_scav" },
		},
	}, --Rover and EMP Rover/Whole Tier Length
	--Land
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 4,
		minAngerTier = 4,
		units = {
			{ count = 6, unit = "armlatnk_scav" },
			{ count = 6, unit = "cortorch_scav" },
			{ count = 6, unit = "legmrv_scav" },
		},
	}, --T2 Veh Raid
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 4,
		minAngerTier = 4,
		units = {
			{ count = 6, unit = "armbull_scav" },
			{ count = 6, unit = "correap_scav" },
			{ count = 1, unit = "corgol_scav" },
			{ count = 2, unit = "legaheattank_scav" },
			{ count = 2, unit = "armyork_scav" },
			{ count = 2, unit = "corsent_scav" },
			{ count = 2, unit = "legvflak_scav" },
		},
	}, --T2 Veh Assault/AA
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 5,
		minAngerTier = 5,
		units = {
			{ count = 2, unit = "armmanni_scav" },
			{ count = 2, unit = "corban_scav" },
			{ count = 1, unit = "legvcarry_scav" },
		},
	}, --T2 Veh Unique
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 5,
		minAngerTier = 5,
		units = {
			{ count = 3, unit = "armmart_scav" },
			{ count = 1, unit = "armmerl_scav" },
			{ count = 1, unit = "armyork_scav" },
			{ count = 3, unit = "cormart_scav" },
			{ count = 1, unit = "corvroc_scav" },
			{ count = 1, unit = "corsent_scav" },
			{ count = 2, unit = "legvflak_scav" },
			{ count = 1, unit = "leginf_scav" },
		},
	}, --T2 Arty/AA
	--air
	{
		type = "specialAirLand",
		weight = 4,
		minAngerTier = 5,
		maxAnger = 1000,
		units = {
			{ count = 3, unit = "armawac_scav" },
			{ count = 3, unit = "corawac_scav" },
		},
	}, --T2 Air Scouts
	{
		type = "specialAirLand",
		weight = 4,
		minAngerTier = 5,
		maxAnger = 1000,
		units = {
			{ count = 2, unit = "armstil_scav" },
		},
	}, --EMP Bombers
	{
		type = "specialAirLand",
		weight = 4,
		minAngerTier = 5,
		maxAnger = 1000,
		units = {
			{ count = 20, unit = "armhawk_scav" },
			{ count = 20, unit = "corvamp_scav" },
		},
	}, --Fighters
	{
		type = "specialAirSea",
		weight = 5,
		minAngerTier = 5,
		maxAnger = 1000,
		units = {
			{ count = 20, unit = "armsfig_scav" },
			{ count = 20, unit = "corsfix_scav" },
		},
	}, --T2 Fighters

	{
		type = "specialAirLand",
		weight = 4,
		minAngerTier = 5,
		maxAnger = 1000,
		units = {
			{ count = 15, unit = "armblade_scav" },
			{ count = 15, unit = "armbrawl_scav" },
			{ count = 1, unit = "legfort_scav" },
			{ count = 1, unit = "corcrw_scav" },
			{ count = 1, unit = "corcrwh_scav" },
			{ count = 15, unit = "corape_scav" },
		},
	}, --T2 Gunships
	------Tier 3 60-80%
	--Dilluters
	{
		type = "specialLand",
		weight = 8,
		minAngerTier = 6,
		maxAngerTier = 6,
		units = {
			{ count = 15, unit = "armfav_scav" },
			{ count = 15, unit = "corfav_scav" },
			{ count = 15, unit = "legscout_scav" },
		},
	}, --Rover Whole Tier Length

	{
		type = "specialLand",
		weight = 3,
		minAngerTier = 6,
		maxAngerTier = 6,
		units = {
			{ count = 6, unit = "cortorch_scav" },
			{ count = 6, unit = "legmrv_scav" },
		},
	}, --T2 Veh Raid
	--Land
	{
		type = "specialLand",
		weight = 3,
		minAngerTier = 6,
		maxAngerTier = 6,
		units = {
			{ count = 12, unit = "armmar_scav" },
		},
	}, --T3 Raid

	{
		type = "specialLand",
		weight = 4,
		minAngerTier = 6,
		maxAngerTier = 6,
		units = {
			{ count = 6, unit = "armmeatball_scav" },
			{ count = 6, unit = "armassimilator_scav" },
			{ count = 2, unit = "armyork_scav" },
			{ count = 2, unit = "corsent_scav" },
			{ count = 2, unit = "legvflak_scav" },
		},
	}, --T3 Assault/AA
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 6,
		minAngerTier = 6,
		units = {
			{ count = 6, unit = "corshiva_scav" },
			{ count = 2, unit = "armraz_scav" },
			{ count = 1, unit = "legpede_scav" },
			{ count = 1, unit = "armyork_scav" },
			{ count = 1, unit = "corsent_scav" },
			{ count = 2, unit = "legvflak_scav" },
		},
	}, --T3 Assault/AA
	{
		type = "specialLand",
		weight = 4,
		maxAngerTier = 6,
		minAngerTier = 6,
		units = {
			{ count = 2, unit = "armvang_scav" },
			{ count = 2, unit = "corcat_scav" },
			{ count = 1, unit = "armyork_scav" },
			{ count = 1, unit = "corsent_scav" },
			{ count = 2, unit = "legvflak_scav" },
		},
	}, --T3 Arty/AA
	{
		type = "specialLand",
		weight = 3,
		maxAnger = 1000,
		minAngerTier = 6,
		units = {
			{ count = 5, unit = "armvadert4_scav" },
		},
	}, --Epic Tumbleweeds
	{
		type = "specialSea",
		weight = 3,
		maxAnger = 1000,
		minAngerTier = 6,
		units = {
			{ count = 5, unit = "armvadert4_scav" },
		},
	}, --Epic Tumbleweeds
	--air
	{
		type = "specialAirLand",
		weight = 4,
		maxAnger = 1000,
		minAngerTier = 6,
		units = {
			{ count = 40, unit = "armfig_scav" },
			{ count = 40, unit = "corveng_scav" },
		},
	}, --T2 Fighters
	{
		type = "specialAirSea",
		weight = 5,
		maxAnger = 1000,
		minAngerTier = 6,
		units = {
			{ count = 40, unit = "armsfig_scav" },
			{ count = 40, unit = "corsfix_scav" },
		},
	}, --T2 Fighters
	{
		type = "specialAirLand",
		weight = 2,
		maxAnger = 1000,
		minAngerTier = 6,
		units = {
			{ count = 15, unit = "armblade_scav" },
			{ count = 15, unit = "armbrawl_scav" },
			{ count = 1, unit = "legfort_scav" },
			{ count = 1, unit = "corcrw_scav" },
			{ count = 1, unit = "corcrwh_scav" },
			{ count = 15, unit = "corape_scav" },
		},
	}, --T2 Gunships
	------Tier 4 80%+
	{
		type = "specialLand",
		weight = 3,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 10, unit = "armvadert4_scav" },
		},
	}, --Epic Tumbleweeds
	{
		type = "specialSea",
		weight = 3,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 10, unit = "armvadert4_scav" },
		},
	}, --Epic Tumbleweeds
	{
		type = "specialAirLand",
		weight = 5,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 80, unit = "armfig_scav" },
			{ count = 80, unit = "corveng_scav" },
		},
	}, --T2 Fighters
	{
		type = "specialAirLand",
		weight = 1,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 10, unit = "armfepocht4_scav" },
		},
	}, --Armada Flying Flagships
	{
		type = "specialAirLand",
		weight = 1,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 10, unit = "corfblackhyt4_scav" },
		},
	}, --Cortex Flying Flagships
	{
		type = "specialAirSea",
		weight = 5,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 80, unit = "armsfig_scav" },
			{ count = 80, unit = "corsfix_scav" },
		},
	}, --T2 Fighters
	{
		type = "specialAirSea",
		weight = 1,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 10, unit = "armfepocht4_scav" },
		},
	}, --Armada Flying Flagships
	{
		type = "specialAirSea",
		weight = 1,
		maxAnger = 1000,
		minAngerTier = 7,
		units = {
			{ count = 10, unit = "corfblackhyt4_scav" },
		},
	}, --Cortex Flying Flagships
}
