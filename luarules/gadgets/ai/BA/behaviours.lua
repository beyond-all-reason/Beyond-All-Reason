
shard_include(  "taskqueues" )
shard_include(  "taskqueuebehaviour" )
shard_include(  "attackerbehaviour" )
--shard_include(  "pointcapturerbehaviour" )
shard_include(  "bootbehaviour" )
shard_include(  "stockpilebehavior" )
shard_include(  "mexupgradebehaviour" )
shard_include(  "scoutsbehaviour" )

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


}

function defaultBehaviours(unit)
	b = {}
	u = unit:Internal()
	table.insert(b, BootBehaviour )
	if u:CanBuild() then
		table.insert(b,TaskQueueBehaviour)
	end
	if IsAttacker(unit) then
		table.insert(b,AttackerBehaviour)
	end
	if IsScouts(unit) then
		table.insert(b,ScoutsBehaviour)
	end
	--if IsPointCapturer(unit) then
		--table.insert(b,PointCapturerBehaviour)
	--end
	return b
end