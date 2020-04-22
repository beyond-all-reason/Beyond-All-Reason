
shard_include(  "taskqueues" )
shard_include(  "taskqueuebehaviour" )
shard_include(  "attackerbehaviour" )
shard_include(  "pointcapturerbehaviour" )
shard_include(  "bootbehaviour" )

behaviours = { }

function defaultBehaviours(unit, ai)
	b = {}
	if unit == nil then
		return b
	end
	u = unit:Internal()
	table.insert(b, BootBehaviour )
	if u:CanBuild() then
		table.insert(b,TaskQueueBehaviour)
	else
		if IsPointCapturer(unit, ai) then
			table.insert(b,PointCapturerBehaviour)
		end
		if IsAttacker(unit) then
			table.insert(b,AttackerBehaviour)
		end
	end
	return b
end
