--- Ground units by role and tier. The number is a WEIGHT: how many times
--- this unit's squad goes into the draw relative to its neighbours.
---
--- Roles carry behaviour. Raid gets none — it rushes in and dies usefully.
--- Assault gets berserk, so it closes on whatever hit it. Support gets
--- skirmish and cowardice, so it keeps its distance. Healer resurrects and
--- repairs. Never list the same unit twice.

return {
	Raid = {
		[1] = {
			--Armada
			armflea_scav = 4,
			armpw_scav = 3,
			armfav_scav = 3,
			armsh_scav = 3,
			--Cortex
			corak_scav = 3,
			corfav_scav = 4,
			corsh_scav = 2,
			--Legion
			leggob_scav = 4,
			legsh_scav = 2,
			legscout_scav = 3,
		},
		[2] = {
			--Armada
			armflea_scav = 3,
			armpw_scav = 4,
			armfav_scav = 3,
			armsh_scav = 3,
			--Cortex
			corak_scav = 4,
			corfav_scav = 3,
			corsh_scav = 3,
			--Legion
			leggob_scav = 4,
			legsh_scav = 3,
			leghades_scav = 4,
		},
		[3] = {
			--Armada
			armflash_scav = 4,
			armzapper_scav = 4,
			--Cortex
			corgator_scav = 3,
			--Legion
			legamphtank_scav = 3,
		},
		[4] = {
			--Armada
			armlatnk_scav = 4,
			armamph_scav = 3,
			armfast_scav = 4,
			--Cortex
			cortorch_scav = 3,
			corsala_scav = 3,
			corpyro_scav = 4,
			corseal_scav = 3,
			coramph_scav = 3,
			corphantom_scav = 3,
			--Legion
			legmrv_scav = 4,
			legstr_scav = 4,
		},
		[5] = {
			--Armada

			--Cortex

			--Legion
		},
		[6] = {
			--Armada
			armpwt4_scav = 3,
			armmar_scav = 4,
			--Cortex
			corakt4_scav = 3,
			--Legion
			legjav_scav = 3,
			--N/A
		},
		[7] = {
			--Armada
			armraz_scav = 3,
			--Cortex
			cordemon_scav = 3,
			--Legion
			--N/A
		},
	},
	Assault = {
		[1] = {
			--Armada
			--Cortex
			--Legion
		},
		[2] = {
			--Armada
			armham_scav = 4,
			armpincer_scav = 2,
			--Cortex
			corthud_scav = 3,
			corgarp_scav = 2,
			--Legion
			legcen_scav = 3,
			leglob_scav = 3,
		},
		[3] = {
			--Armada
			armwar_scav = 3,
			armstump_scav = 4,
			armjanus_scav = 2,
			armanac_scav = 4,
			--Cortex
			corraid_scav = 4,
			corlevlr_scav = 4,
			corsnap_scav = 2,
			--Legion
			leggat_scav = 4,
			legkark_scav = 4,
			corkark_scav = 4,
			legner_scav = 4,
		},
		[4] = {
			--Armada
			armzeus_scav = 4,
			--Cortex
			corcan_scav = 4,
			corhal_scav = 4,
			--Legion
			legshot_scav = 4,
		},
		[5] = {
			--Armada
			armsnipe_scav = 2,
			armvader_scav = 4,
			armsptk_scav = 2,
			armbull_scav = 4,
			armcroc_scav = 4,
			--Cortex
			corparrow_scav = 2,
			cordeadeye_scav = 2,
			corftiger_scav = 4,
			corgol_scav = 2,
			corroach_scav = 4,
			corsktl_scav = 2,
			cortermite_scav = 4,
			corsumo_scav = 2,
			correap_scav = 2,
			corgatreap_scav = 4,
			--Legion
			legaheattank_scav = 4,
			legamph_scav = 3,
			leginc_scav = 2,
			legfloat_scav = 4,
		},
		[6] = {
			--Armada
			armassimilator_scav = 4,
			armmeatball_scav = 4,
			armlun_scav = 4,
			--Cortex
			corshiva_scav = 4,
			corkarg_scav = 4,
			corthermite = 4,
			corsok_scav = 2,
			--Legion
			legpede_scav = 1,
			legkeres_scav = 4,
			legeallterrainmech_scav = 4,
			legerailtank_scav = 2,
			legbunk_scav = 2,
			legehovertank_scav = 2,
		},
		[7] = {
			--Armada
			armthor_scav = 3,
			armbanth_scav = 4,
			armrattet4_scav = 2,
			armvadert4_scav = 2,
			armsptkt4_scav = 2,
			--Cortex
			corjugg_scav = 2,
			corkorg_scav = 2,
			corkarganetht4_scav = 2,
			corgolt4_scav = 1,
			corves_scav = 2,
			--Legion
			leegmech_scav = 2,
			legeshotgunmech_scav = 3,
			legerailtank_scav = 4,
			legeheatraymech_scav = 1,
			legeheatraymech_old_scav = 3,
			legelrpcmech_scav = 3,
			legapollyon_scav = 3,
		},
	},
	Support = {
		[1] = {
			--Armada
			--Cortex
			--Legion
		},
		[2] = {
			--Armada
			armrock_scav = 2,
			armjeth_scav = 2,
			armah_scav = 2,
			--Cortex
			corstorm_scav = 2,
			corcrash_scav = 2,
			corah_scav = 2,
			--Legion
			legbal_scav = 2,
		},
		[3] = {
			--Armada
			armart_scav = 2,
			armsam_scav = 2,
			armmh_scav = 2,
			--Cortex
			corwolv_scav = 2,
			cormist_scav = 2,
			cormh_scav = 2,
			--Legion
			leghelios_scav = 2,
			legbar_scav = 2,
			legrail_scav = 2,
			legmh_scav = 2,
			legah_scav = 2,
		},
		[4] = {
			--Armada
			armfido_scav = 2,
			armaak_scav = 2,
			armmav_scav = 2,
			armyork_scav = 2,
			armmart_scav = 2,
			--Cortex
			cormart_scav = 2,
			corsent_scav = 2,
			coraak_scav = 2,
			cormort_scav = 2,
			--Legion
			legaskirmtank_scav = 2,
			legamcluster_scav = 2,
			legvcarry_scav = 2,
			legbart_scav = 2,
			legsrail_scav = 2,
			legvflak_scav = 2,
		},
		[5] = {
			--Armada
			armfboy_scav = 2,
			armmanni_scav = 2,
			armmerl_scav = 2,
			--Cortex
			corban_scav = 2,
			corvroc_scav = 2,
			cortrem_scav = 2,
			corhrk_scav = 2,
			corsiegebreaker_scav = 2,
			--Legion
			legavroc_scav = 2,
			leginf_scav = 2,
			legmed_scav = 2,
		},
		[6] = {
			--Armada
			armvang_scav = 2,
			armdronecarryland_scav = 2,
			armscab_scav = 2,
			--Cortex
			corcat_scav = 2,
			cormabm_scav = 2,
			--Legion
			leggobt3_scav = 3,
		},
		[7] = {
			--Armada

			--Cortex
			CorPrince_scav = 2,
			--Legion
			legsrailt4_scav = 2,
		},
	},
	Healer = {
		[1] = {
			--Armada
			armck_scav = 2,
			armrectr_scav = 40,
			armcv_scav = 2,
			armch_scav = 2,
			--Cortex
			corck_scav = 2,
			cornecro_scav = 40,
			corcv_scav = 2,
			corch_scav = 2,
			--Legion
			legcv_scav = 2,
			legck_scav = 2,
			legch_scav = 2,
			legotter_scav = 2,
		},
		[2] = {
			--Armada
			armck_scav = 2,
			armrectr_scav = 40,
			armcv_scav = 2,
			armch_scav = 2,
			--Cortex
			corck_scav = 2,
			cornecro_scav = 40,
			corcv_scav = 2,
			corch_scav = 2,
			--Legion
			legcv_scav = 2,
			legck_scav = 2,
			legch_scav = 2,
			legotter_scav = 2,
		},
		[3] = {
			--Armada
			armck_scav = 2,
			armrectr_scav = 40,
			armcv_scav = 2,
			armch_scav = 2,
			--Cortex
			corck_scav = 2,
			cornecro_scav = 40,
			corcv_scav = 2,
			corch_scav = 2,
			--Legion
			legcv_scav = 2,
			legck_scav = 2,
			legch_scav = 2,
			legotter_scav = 2,
		},
		[4] = {
			--Armada
			armrectr_scav = 40,
			armack_scav = 2,
			armacv_scav = 2,
			armfark_scav = 2,
			armconsul_scav = 2,
			--Cortex
			cornecro_scav = 40,
			corack_scav = 2,
			coracv_scav = 2,
			corfast_scav = 2,
			cormando_scav = 2,
			corforge_scav = 2,
			--Legion
			legacv_scav = 2,
			legack_scav = 2,
			legaceb_scav = 2,
		},
		[5] = {
			--Armada
			armrectr_scav = 40,
			armack_scav = 2,
			armacv_scav = 2,
			armfark_scav = 2,
			armconsul_scav = 2,
			--Cortex
			cornecro_scav = 40,
			corack_scav = 2,
			coracv_scav = 2,
			corfast_scav = 2,
			cormando_scav = 2,
			corforge_scav = 2,
			--Legion
			legacv_scav = 2,
			legack_scav = 2,
			legaceb_scav = 2,
		},
		[6] = {
			--Armada
			armrectr_scav = 40,
			armack_scav = 2,
			armacv_scav = 2,
			armfark_scav = 2,
			armconsul_scav = 2,
			--Cortex
			cornecro_scav = 40,
			corack_scav = 2,
			coracv_scav = 2,
			corfast_scav = 2,
			cormando_scav = 2,
			corforge_scav = 2,
			--Legion
			legacv_scav = 2,
			legack_scav = 2,
			legaceb_scav = 2,
		},
		[7] = {
			--Armada
			armrectr_scav = 40,
			armack_scav = 2,
			armacv_scav = 2,
			armfark_scav = 2,
			armconsul_scav = 2,
			--Cortex
			cornecro_scav = 40,
			corack_scav = 2,
			coracv_scav = 2,
			corfast_scav = 2,
			cormando_scav = 2,
			corforge_scav = 2,
			--Legion
			legacv_scav = 2,
			legack_scav = 2,
			legaceb_scav = 2,
		},
	},
}
