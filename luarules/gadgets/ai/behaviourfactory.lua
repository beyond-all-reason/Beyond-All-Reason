shard_include( "behaviour" )
BehaviourFactory = class(AIBase)

shard_include( "behaviours" )
function BehaviourFactory:Init()
	--
end

function BehaviourFactory:AddBehaviours(unit)
	if unit == nil then
		self.game:SendToConsole("Warning: Shard BehaviourFactory:AddBehaviours was asked to provide behaviours to a nil unit")
		return
	end
	-- add behaviours here
	-- unit:AddBehaviour(behaviour)
	local b = behaviours[unit:Internal():Name()]
	if b == nil then
		b = defaultBehaviours(unit, ai)
	end
	for i,behaviour in ipairs(b) do
		t = behaviour()
		t:SetAI(ai)
		t:SetUnit(unit)
		t:Init()
		unit:AddBehaviour(t)
	end
end

