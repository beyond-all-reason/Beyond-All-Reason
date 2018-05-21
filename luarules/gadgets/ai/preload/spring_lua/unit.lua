
ShardSpringUnit = class(function(a)
   --
end)

function ShardSpringUnit:Init( id )
	self.id = id
	self.className = "unit"
end

function ShardSpringUnit:ID()
	return self.id
end

function ShardSpringUnit:Team()
	return Spring.GetUnitTeam(self.id)
end


function ShardSpringUnit:Name()
	if not self.name then
		self.name = UnitDefs[Spring.GetUnitDefID(self.id)].name
	end
	return self.name
end


function ShardSpringUnit:IsAlive()
	return not Spring.GetUnitIsDead(self.id)
end


function ShardSpringUnit:IsCloaked()
	return Spring.GetUnitIsCloaked(self.id)
end


function ShardSpringUnit:Forget()
	return 0
end


function ShardSpringUnit:Forgotten()
	return false
end


function ShardSpringUnit:Type()
	if not self.type then
		-- local ai = Shard.AIs[1]
		-- self.type = ai.game:GetTypeByName( self:Name() )
		self.type = game:GetTypeByName( self:Name() )
	end
	return self.type
end


function ShardSpringUnit:CanMove()
	return self:Type():CanMove()
end


function ShardSpringUnit:CanDeploy()
	return self:Type():CanDeploy()
end

function ShardSpringUnit:IsBeingBuilt()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return buildProgress < 1
end


function ShardSpringUnit:CanAssistBuilding( unit )-- IUnit* unit) -- the unit that is under construction to help with
	return true -- not sure when this would not be true in Spring
	-- return false
end


function ShardSpringUnit:CanMoveWhenDeployed()
	-- what does deployed mean in the case of Spring?
	return false
end


function ShardSpringUnit:CanFireWhenDeployed()
	return false
end


function ShardSpringUnit:CanBuildWhenDeployed()
	return false
end


function ShardSpringUnit:CanBuildWhenNotDeployed()
	return false
end


function ShardSpringUnit:Stop()
	Spring.GiveOrderToUnit( self.id, CMD.STOP, {}, {} )
	return true
end


function ShardSpringUnit:Move(p)
	Spring.GiveOrderToUnit( self.id, CMD.MOVE, { p.x, p.y, p.z }, {} )
	return true
end


function ShardSpringUnit:MoveAndFire(p)
	Spring.GiveOrderToUnit( self.id, CMD.FIGHT, { p.x, p.y, p.z }, {} )
	return true
end

function ShardSpringUnit:MoveAndPatrol(p)
	Spring.GiveOrderToUnit( self.id, CMD.PATROL, { p.x, p.y, p.z }, {} )
	return true
end


function ShardSpringUnit:Build(t, p) -- IUnitType*
	if type(t) == "string" then
		-- local ai = Shard.AIs[1]
		-- t = ai.game:GetTypeByName(t)
		t = game:GetTypeByName(t)
	end
	if not p then
		p = self:GetPosition()
	end
	p.y = Spring.GetGroundHeight( p.x,p.z )
	Spring.GiveOrderToUnit( self.id, -t:ID(), { p.x, p.y, p.z }, {} )
	return true
end

function ShardSpringUnit:AreaReclaim( p, radius )--Position p, double radius)
	Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { p.x, p.y, p.z, radius }, {} )
	return true
end


function ShardSpringUnit:Reclaim( thing )--IMapFeature* mapFeature)
	if not thing then return end
	if thing.className == "feature" then
		Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { thing:ID() + Game.maxUnits }, {} )
	elseif thing.className == "unit" then
		Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { thing:ID() }, {} )
	end
	return true
end

function ShardSpringUnit:Attack( unit )
	Spring.GiveOrderToUnit( self.id, CMD.ATTACK, { unit:ID() }, {} )
	return true
end


function ShardSpringUnit:Repair( unit )
	Spring.GiveOrderToUnit( self.id, CMD.REPAIR, { unit:ID() }, {} )
	return true
end


function ShardSpringUnit:MorphInto( type )
	-- how?
	return false
end


function ShardSpringUnit:GetPosition()
	local bpx, bpy, bpz = Spring.GetUnitPosition(self.id)
	if not bpx then
		Spring.Echo(self:Name(), self.id, "nil position")
		return
	end
	return {
		x=bpx,
		y=bpy,
		z=bpz,
	}
end


function ShardSpringUnit:GetHealth()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return health
end


function ShardSpringUnit:GetMaxHealth()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return maxHealth
end


function ShardSpringUnit:WeaponCount()
	return self:Type():WeaponCount()
end


function ShardSpringUnit:MaxWeaponsRange()
	return Spring.GetUnitMaxRange(self.id)
end


function ShardSpringUnit:CanBuild( type )
	return self:Type():CanBuild(type)
end


function ShardSpringUnit:GetResourceUsage( idx )
	local metalMake, metalUse, energyMake, energyUse = Spring.GetUnitResources(self.id)
	local SResourceTransfer = { gameframe = Spring.GameFrame(), rate = 1 }
	if Shard.resourceIds[idx] == "metal" then
		SResourceTransfer.generation = metalMake
		SResourceTransfer.consumption = metalUse
	elseif Shard.resourceIds[idx] == "energy" then
		SResourceTransfer.generation = energyMake
		SResourceTransfer.consumption = energyUse
	end
	return SResourceTransfer
end


function ShardSpringUnit:ExecuteCustomCommand(  cmdId, params_list, options, timeOut )
	params_list = params_list or {}
	options = options or {}
	if params_list and params_list.push_back then
		-- handle fake vectorFloat object
		params_list = params_list.values
	end
	Spring.GiveOrderToUnit(self.id, cmdId, params_list, options)
	return 0
end

function ShardSpringUnit:DrawHighlight( color, label, channel )
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawAddUnit', self.id, color[1], color[2], color[3], color[4], label, ai.game:GetTeamID(), channel)
end

function ShardSpringUnit:EraseHighlight( color, label, channel )
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawEraseUnit', self.id, color[1], color[2], color[3], color[4], label, ai.game:GetTeamID(), channel)
end

--[[
IUnit/ engine unit objects
	int ID()
	int Team()
	std::string Name()

	bool IsAlive()

	bool IsCloaked()

	void Forget() // makes the interface forget about this unit and cleanup
	bool Forgotten() // for interface/debugging use

	IUnitType* Type()

	bool CanMove()
	bool CanDeploy()
	bool CanBuild()
	bool IsBeingBuilt()

	bool CanAssistBuilding(IUnit* unit)

	bool CanMoveWhenDeployed()
	bool CanFireWhenDeployed()
	bool CanBuildWhenDeployed()
	bool CanBuildWhenNotDeployed()

	void Stop()
	void Move(Position p)
	void MoveAndFire(Position p)

	bool Build(IUnitType* t)
	bool Build(std::string typeName)
	bool Build(std::string typeName, Position p)
	bool Build(IUnitType* t, Position p)

	bool AreaReclaim(Position p, double radius)
	bool Reclaim(IMapFeature* mapFeature)
	bool Reclaim(IUnit* unit)
	bool Attack(IUnit* unit)
	bool Repair(IUnit* unit)
	bool MorphInto(IUnitType* t)

	Position GetPosition()
	float GetHealth()
	float GetMaxHealth()

	int WeaponCount()
	float MaxWeaponsRange()

	bool CanBuild(IUnitType* t)

	SResourceTransfer GetResourceUsage(int idx)

	void ExecuteCustomCommand(int cmdId, std::vector<float> params_list, short options = 0, int timeOut = INT_MAX)
--]]