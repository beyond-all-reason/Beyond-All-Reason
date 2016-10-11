shard_include( "behaviour" )
BehaviourFactory = class(AIBase)

shard_include( "behaviours" )

local behaviourNames = {}

function BehaviourFactory:Init()
	--
	-- if ai.EnableDebugTimers then
	-- 	for k, v in pairs(getfenv()) do
	-- 		if string.find(k, 'Behaviour') then
	-- 			behaviourNames[v] = k
	-- 			game:SendToConsole(k)
	-- 			break
	-- 		end
	-- 	end
	-- end
end

function BehaviourFactory:AddBehaviours(unit, ai)
	if unit == nil then
		return
	end
	-- add behaviours here
	-- unit:AddBehaviour(behaviour)
	local b = behaviours[unit:Internal():Name()]
	if b == nil then
		b = defaultBehaviours(unit, ai)
	end
	for i,behaviour in ipairs(b) do
		-- if ai.EnableDebugTimers then
		-- 	ai:AddDebugTimers(behaviour, behaviourNames[behaviour])
		-- end
		t = behaviour()
		t:SetUnit(unit)
		t:SetAI(ai)
		t:Init()
		unit:AddBehaviour(t)
	end
end

