
shard_include(  "taskqueues")
shard_include(  "taskqueuebehaviour")
shard_include(  "raiderbehaviour")
shard_include(  "skirmisherbehaviour")
shard_include(  "artillerybehaviour")
shard_include(  "bomberbehaviour")
--shard_include(  "pointcapturerbehaviour" )
shard_include(  "bootbehaviour")
shard_include(  "stockpilebehavior")
shard_include(  "mexupgradebehaviour")
shard_include(  "scoutsbehaviour")
shard_include(  "staticweaponbehaviour")
shard_include(  "nukebehaviour")
shard_include(  "fighterbehaviour")

return {
	--CoreNanoTurret
	cornanotc = {
		TaskQueueBehaviour,
	},
	--ArmNanoTurret
	armnanotc = {
		TaskQueueBehaviour,
	},
	armfark = {
		TaskQueueBehaviour,
	},
	armconsul = {
		TaskQueueBehaviour,
	},
	corfast = {
		TaskQueueBehaviour,
	},
	corfmd = {
		StockpileBehavior,
	},

	armamd = {
		StockpileBehavior,
	},
	corscreamer = {
		StockpileBehavior,
	},

	armmercury = {
		StockpileBehavior,
	},
	armrectr = {
		SkirmisherBehaviour,
	},
	cornecro = {
		SkirmisherBehaviour,
	},
	armdecom = {
		TaskQueueBehaviour,
	},
	cordecom = {
		TaskQueueBehaviour,
	},
	corack = {
		TaskQueueBehaviour,
		-- MexUpgradeBehavior,
		},
	coracv = {
		TaskQueueBehaviour,
		-- MexUpgradeBehavior,
		},
	coraca = {
		TaskQueueBehaviour,
		-- MexUpgradeBehavior,
		},
	armack = {
		TaskQueueBehaviour,
		-- MexUpgradeBehavior,
		},
	armacv = {
		TaskQueueBehaviour,
		-- MexUpgradeBehavior,
		},
	armaca = {
		TaskQueueBehaviour,
		-- MexUpgradeBehavior,
		},
	armsilo = {
		NukeBehaviour,
		},
	corsilo = {
		NukeBehaviour,
		},
	armvulc = {
		StaticWeaponBehaviour,
		},
	corbuzz = {
		StaticWeaponBehaviour,
		},
}
