shard_include("behaviour")
BehaviourFactory = class(AIBase)

function BehaviourFactory:Init()
	-- mirrors STAI/behaviourfactory.lua: shard_include returns the behaviours
	-- table (currently always {}), AddBehaviours falls through to
	-- defaultBehaviours() for every unit. Without this assignment the
	-- bare-global `behaviours[...]` lookup below crashes at runtime with
	-- "attempt to index a nil value (global 'behaviours')".
	self.behaviours = shard_include("behaviours")
end

function BehaviourFactory:AddBehaviours(unit)
	if unit == nil then
		self.game:SendToConsole("Warning: Shard BehaviourFactory:AddBehaviours was asked to provide behaviours to a nil unit")
		return
	end
	-- add behaviours here
	-- unit:AddBehaviour(behaviour)
	local b = self.behaviours[unit:Internal():Name()]
	if b == nil then
		b = defaultBehaviours(unit, ai)
	end
	for i, behaviour in ipairs(b) do
		t = behaviour()
		t:SetAI(ai)
		t:SetUnit(unit)
		t:Init()
		unit:AddBehaviour(t)
	end
end
