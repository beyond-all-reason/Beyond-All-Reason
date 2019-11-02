
shard_include(  "taskqueues", "base-ai")
shard_include(  "taskqueuebehaviour", "base-ai")
shard_include(  "raiderbehaviour", "base-ai")
shard_include(  "skirmisherbehaviour", "base-ai")
shard_include(  "artillerybehaviour", "base-ai")
shard_include(  "bomberbehaviour", "base-ai")
--shard_include(  "pointcapturerbehaviour", "base-ai")
shard_include(  "bootbehaviour", "base-ai")
shard_include(  "stockpilebehavior", "base-ai")
shard_include(  "mexupgradebehaviour", "base-ai")
shard_include(  "scoutsbehaviour", "base-ai")
shard_include(  "staticweaponbehaviour", "base-ai")
shard_include(  "nukebehaviour", "base-ai")
shard_include(  "fighterbehaviour", "base-ai")

behaviours = {
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
	armbeaver = {
		SkirmisherBehaviour,
	},
	cormuskrat = {
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

function defaultBehaviours(unit)
	b = {}
	u = unit:Internal()
	table.insert(b, BootBehaviour )
	if unit:Internal():Name() == "corak" then
		if math.random(1,5) == 1 then
			table.insert(b,ScoutsBehaviour)
		else
			table.insert(b,RaiderBehaviour)
		end
		return b
	end
	if u:CanBuild() then
		table.insert(b,TaskQueueBehaviour)
	end
	if IsSkirmisher(unit) then
		table.insert(b,SkirmisherBehaviour)
	end
	if IsRaider(unit) then
		table.insert(b,RaiderBehaviour)
	end
	if IsFighter(unit) then
		table.insert(b,FighterBehaviour)
	end
	if IsBomber(unit) then
		table.insert(b,BomberBehaviour)
	end
	if IsArtillery(unit) then
		table.insert(b,ArtilleryBehaviour)
	end
	if IsScouts(unit) then
		table.insert(b,ScoutsBehaviour)
	end
	if IsStaticWeapon(unit) then
		table.insert(b,StaticWeaponBehaviour)
	end
	--if IsPointCapturer(unit) then
		--table.insert(b,PointCapturerBehaviour)
	--end
	return b
end
