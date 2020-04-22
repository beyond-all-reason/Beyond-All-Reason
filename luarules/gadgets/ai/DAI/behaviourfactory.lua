shard_include( "behaviour" )
BehaviourFactory = class(AIBase)

function BehaviourFactory:Init()
	self.behaviours = shard_include( "behaviours" )
	self.scoutslist = shard_include( "scouts" )
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

function BehaviourFactory:DefaultBehaviours(unit)
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
	if IsScouts(unit, self.scoutslist) then
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

function IsScouts(unit, scoutslist)
	for i,name in ipairs(scoutslist) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end