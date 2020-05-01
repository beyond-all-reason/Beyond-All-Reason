shard_include( "behaviour" )
shard_include( "taskqueuebehaviour" )
shard_include( "attackerbehaviour" )
shard_include( "pointcapturerbehaviour" )
shard_include( "bootbehaviour" )

BehaviourFactory = class(AIBase)

shard_include( "behaviours" )
function BehaviourFactory:Init()
	self.behaviours = shard_include( "behaviours" )
end

function BehaviourFactory:AddBehaviours(unit)
	if unit == nil then
		self.game:SendToConsole("Warning: Shard BehaviourFactory:AddBehaviours was asked to provide behaviours to a nil unit")
		return
	end
	-- add behaviours here
	local b = self.behaviours[unit:Internal():Name()]
	if b == nil then
		b = self:DefaultBehaviours(unit)
	end
	for i,behaviour in ipairs(b) do
		t = behaviour()
		t:SetAI(ai)
		t:SetUnit(unit)
		t:Init()
		unit:AddBehaviour(t)
	end
end

function BehaviourFactory:DefaultBehaviours(unit, ai)
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