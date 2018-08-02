
ShardUnit = class(function(a, id)
	a.id = id
	a.className = "unit"
	local udefid = Spring.GetUnitDefID(id)
	a.type = ShardUnitType(udefid)
end)

function ShardUnit:Unit_to_id( unit )
	local gid = unit
	if type( unit ) == 'table' then
		if unit['id'] ~= nil then
			gid = unit.id
		else
			-- error!
			return false
		end
	end
	return gid
end

function ShardUnit:ID()
	return self.id
end

function ShardUnit:Team()
	return Spring.GetUnitTeam(self.id)
end

function ShardUnit:Radius()
	return Spring.GetUnitRadius(self.id)
end

function ShardUnit:AllyTeam()
	return Spring.GetUnitAllyTeam(self.id)
end

function ShardUnit:Neutral()
	return Spring.GetUnitNeutral(self.id)
end

function ShardUnit:Stunned()
	local stunned_or_inbuild, stunned, inbuild = Spring.GetUnitIsStunned(self.id)
	return stunned
end

function ShardUnit:Name()
	return self.type:Name()
end


function ShardUnit:IsAlive()
	return not Spring.GetUnitIsDead(self.id)
end


function ShardUnit:IsCloaked()
	return self:Cloaked()
end

function ShardUnit:Cloaked()
	return Spring.GetUnitIsCloaked(self.id)
end


function ShardUnit:CurrentStockpile()
	local numStockpiled, numStockpileQued, buildPercent = Spring.GetUnitStockpile(self.id)
	return numStockpiled
end


function ShardUnit:Type()
	return self.type
end


function ShardUnit:CanMove()
	return self:Type():CanMove()
end


function ShardUnit:CanDeploy()
	return self:Type():CanDeploy()
end

function ShardUnit:CanMorph()
	return self:Type():CanMorph()
end

function ShardUnit:IsBeingBuilt()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return buildProgress < 1
end

function ShardUnit:IsMorphing()
	return false
end


function ShardUnit:CanAssistBuilding( unit )-- IUnit* unit) -- the unit that is under construction to help with
	return true -- not sure when this would not be true in Spring
	-- return false
end


function ShardUnit:CanMoveWhenDeployed()
	-- what does deployed mean in the case of Spring?
	return false
end


function ShardUnit:CanFireWhenDeployed()
	return false
end

function ShardUnit:CanMorphWhenDeployed()
	return false
end

function ShardUnit:CanBuildWhenDeployed()
	return false
end


function ShardUnit:CanBuildWhenNotDeployed()
	return false
end

function ShardUnit:Stop()
	Spring.GiveOrderToUnit( self.id, CMD.STOP, {}, {} )
	return true
end

function ShardUnit:Stockpile()
	Spring.GiveOrderToUnit( self.id, CMD.STOCKPILE, {}, {} )
	return true
end

function ShardUnit:SelfDestruct()
	Spring.GiveOrderToUnit( self.id, CMD.SELFD, {}, {} )
	return true
end

function ShardUnit:Cloak()
	Spring.GiveOrderToUnit( self.id, CMD.CLOAK, { 1 }, {} )
	return true
end

function ShardUnit:UnCloak()
	Spring.GiveOrderToUnit( self.id, CMD.CLOAK, { 0 }, {} )
	return true
end

function ShardUnit:TurnOn()
	Spring.GiveOrderToUnit( self.id, CMD.ONOFF, { 1 }, {} )
	return true
end

function ShardUnit:TurnOff()
	Spring.GiveOrderToUnit( self.id, CMD.ONOFF, { 0 }, {} )
	return true
end

function ShardUnit:Guard( unit )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.GUARD, { gid }, {} )
	return true
end

function ShardUnit:Repair( unit )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.REPAIR, { gid }, {} )
	return true
end

function ShardUnit:DGun(p)
	return self:AltAttack( p )
end

function ShardUnit:ManualFire(p)
	Spring.GiveOrderToUnit( self.id, CMD.DGUN, { p.x, p.y, p.z }, {} )
	return true
end

function ShardUnit:Move(p)
	Spring.GiveOrderToUnit( self.id, CMD.MOVE, { p.x, p.y, p.z }, {} )
	return true
end

function ShardUnit:AttackMove(p)
	return self:MoveAndFire(p)
end

function ShardUnit:MoveAndFire(p)
	Spring.GiveOrderToUnit( self.id, CMD.FIGHT, { p.x, p.y, p.z }, {} )
	return true
end

function ShardUnit:Patrol(p)
	return self:MoveAndPatrol(p)
end

function ShardUnit:MoveAndPatrol(p)
	Spring.GiveOrderToUnit( self.id, CMD.PATROL, { p.x, p.y, p.z }, {} )
	return true
end

function ShardUnit:Build(t, p, f, opts) -- IUnitType*
	if type(t) == "string" then
		-- local ai = Shard.AIs[1]
		-- t = ai.game:GetTypeByName(t)
		t = game:GetTypeByName(t)
	end
	opts = opts or {}
	f = f or 0
	if not p then p = self:GetPosition() end
	Spring.GiveOrderToUnit( self.id, -t:ID(), { p.x, p.y, p.z, f}, opts )
	return true
end


function ShardUnit:Reclaim( thing )--IMapFeature* mapFeature)
	if not thing then return end
	local gid = self:Unit_to_id( unit )
	if thing.className == "feature" then
		Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { gid + Game.maxUnits }, {} )
	elseif thing.className == "unit" then
		Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { gid }, {} )
	end
	return true
end

function ShardUnit:AreaReclaim( p, radius )--Position p, double radius)
	Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { p.x, p.y, p.z, radius }, {} )
	return true
end


function ShardUnit:Ressurect( thing )--IMapFeature* mapFeature)
	if not thing then return end
	local gid = self:Unit_to_id( unit )
	if thing.className == "feature" then
		Spring.GiveOrderToUnit( self.id, CMD.RESURRECT, { gid + Game.maxUnits }, {} )
	elseif thing.className == "unit" then
		Spring.GiveOrderToUnit( self.id, CMD.RESURRECT, { gid }, {} )
	end
	return true
end

function ShardUnit:AreaRESURRECT( p, radius )--Position p, double radius)
	Spring.GiveOrderToUnit( self.id, CMD.RESURRECT, { p.x, p.y, p.z, radius }, {} )
	return true
end

function ShardUnit:Attack( unit )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.ATTACK, { gid }, {} )
	return true
end

function ShardUnit:AreaAttack(p,radius)
	Spring.GiveOrderToUnit( self.id, CMD.AREA_ATTACK, { p.x, p.y, p.z, radius }, {} )
	return true
end

function ShardUnit:Repair( unit )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.REPAIR, { gid }, {} )
	return true
end

function ShardUnit:AreaRepair( p, radius )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.REPAIR, { p.x, p.y, p.z, radius }, {} )
	return true
end

function ShardUnit:RestoreTerrain( p, radius )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.RESTORE, { p.x, p.y, p.z, radius }, {} )
	return true
end

function ShardUnit:Capture( unit )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.CAPTURE, { gid }, {} )
	return true
end

function ShardUnit:AreaCapture( p, radius )
	local gid = self:Unit_to_id( unit )
	Spring.GiveOrderToUnit( self.id, CMD.CAPTURE, { p.x, p.y, p.z, radius }, {} )
	return true
end

function ShardUnit:MorphInto( type )
	Spring.GiveOrderToUnit( self.id, CMD.MORPH, { self.id }, {} )
	return true
end

function ShardUnit:HoldFire()
	Spring.GiveOrderToUnit( self.id, CMD.FIRE_STATE, { 0 }, {} )
	return true
end

function ShardUnit:ReturnFire()
	Spring.GiveOrderToUnit( self.id, CMD.FIRE_STATE, { 1 }, {} )
	return true
end

function ShardUnit:FireAtWill()
	Spring.GiveOrderToUnit( self.id, CMD.FIRE_STATE, { 2 }, {} )
	return true
end

function ShardUnit:HoldPosition()
	Spring.GiveOrderToUnit( self.id, CMD.MOVE_STATE, { 0 }, {} )
	return true
end

function ShardUnit:Manoeuvre()
	Spring.GiveOrderToUnit( self.id, CMD.MOVE_STATE, { 1 }, {} )
	return true
end

function ShardUnit:Roam()
	Spring.GiveOrderToUnit( self.id, CMD.MOVE_STATE, { 2 }, {} )
	return true
end

function ShardUnit:GetPosition()
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


function ShardUnit:GetHealth()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return health
end


function ShardUnit:GetMaxHealth()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return maxHealth
end

function ShardUnit:ParalysisDamage()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return paralyzeDamage
end

function ShardUnit:CaptureProgress()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return captureProgress
end

function ShardUnit:BuildProgress()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return buildProgress
end


function ShardUnit:WeaponCount()
	return self:Type():WeaponCount()
end


function ShardUnit:MaxWeaponsRange()
	return Spring.GetUnitMaxRange(self.id)
end


function ShardUnit:CanBuild( type )
	return self:Type():CanBuild(type)
end


function ShardUnit:GetResourceUsage( idx )
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


function ShardUnit:ExecuteCustomCommand(  cmdId, params_list, options, timeOut )
	params_list = params_list or {}
	options = options or {}
	if params_list and params_list.push_back then
		-- handle fake vectorFloat object
		params_list = params_list.values
	end
	Spring.GiveOrderToUnit(self.id, cmdId, params_list, options)
	return 0
end

function ShardUnit:DrawHighlight( color, label, channel )
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawAddUnit', self.id, color[1], color[2], color[3], color[4], label, ai.game:GetTeamID(), channel)
end

function ShardUnit:EraseHighlight( color, label, channel )
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
