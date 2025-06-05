

ShardUnit = class(function(a, id)
	a.id = id
	a.className = "unit"
	local udefid = Spring.GetUnitDefID(id)
	a.UnitDefID = udefid
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

function ShardUnit:isNeutral()
	return Spring.GetUnitNeutral(self.id)
end

function ShardUnit:IsMine( myTeam )
	return ( myTeam == self:Team() )
end

function ShardUnit:IsNotMine( myTeam )
	return ( myTeam ~= self:Team() )
end

function ShardUnit:IsFriendly( myAllyTeam )
	return ( myAllyTeam == self:AllyTeam() )
end

function ShardUnit:IsEnemy( myAllyTeam )
	return ( myAllyTeam ~= self:AllyTeam() )
end

function ShardUnit:Stunned()
	local stunned_or_inbuild, stunned, inbuild = Spring.GetUnitIsStunned(self.id)
	return stunned
end

function ShardUnit:Name()
	return self.type:Name()
end

function ShardUnit:InList( unitTypeNames )
	for i,name in ipairs(unitTypeNames) do
		if name == self:Name() then
			return true
		end
		if name == self:ID() then
			return true
		end
		if name == self:Type() then
			return true
		end
	end
	return false
end

function ShardUnit:IsAlive()
	if Spring.GetUnitIsDead(self.id) == false then
		return true
	else
		return false -- cause return true for a short period and then nil
	end
end

function ShardUnit:GetLos(bitmask)
	bitmask = bitmask or true
	return Spring.GetUnitLosState(self.id ,self:GetUnitAllyTeam(),bitmask)
end

function ShardUnit:IsCloaked()
	return self:Cloaked()
end

function ShardUnit:Cloaked()
	return Spring.GetUnitIsCloaked(self.id)
end

function ShardUnit:GetUnitIsBuilding()
	return Spring.GetUnitIsBuilding(self.id)
end

function ShardUnit:GetCurrentBuildPower()
	return Spring.GetUnitCurrentBuildPower(self.id)
end

function ShardUnit:IsBlocking()
	return Spring.GetUnitBlocking(self.unitid)
end

function ShardUnit:CurrentStockpile()
	local numStockpiled, numStockpileQued, buildPercent = Spring.GetUnitStockpile(self.id)
	return numStockpiled, numStockpileQued, buildPercent
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
	return Spring.GetUnitIsBeingBuilt( self.id )
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

function ShardUnit:FactoryWait()
	local topQueue = Spring.GetFactoryCommands(self.id,1)[1]
	if topQueue and topQueue.id ~= CMD.WAIT then
		local order = self:SyncOrder( self.id, CMD.WAIT, {0}, 0 )
		--Spring.GiveOrderToUnit( self.id, CMD.WAIT, {}, 0 )
	end
end

function ShardUnit:FactoryUnWait()
	local topQueue = Spring.GetFactoryCommands(self.id,1)[1]
	if topQueue and topQueue.id == CMD.WAIT then
		local order = self:SyncOrder( self.id, CMD.WAIT, {0}, 0 )
		--Spring.GiveOrderToUnit( self.id, CMD.WAIT, {}, 0 )
	end
end

function ShardUnit:IsWaiting()
	local topQueue = Spring.GetFactoryCommands(self.id,1)[1]
	if topQueue and topQueue.id == CMD.WAIT then
		return true
	end
end

 function ShardUnit:getFactoryCommands()
 	return Spring.GetFactoryCommands(self.id,1)
end

--[[
function ShardUnit:FactoryWait()
	local order = self:SyncOrder( self.id, CMD.WAIT, { 0 }, 0 )

end

function ShardUnit:FactoryUnWait()
	local order = self:SyncOrder( self.id, CMD.WAIT, { 1 }, 0 )

end
]]
--[[
function ShardUnit:GetUnitCommands(count)
	count = count or 1
	local currentOrder = Spring.GetUnitCommands(self.id,count)
	return currentOrder
end
]]

function ShardUnit:GetUnitCommands(count)
    if count == 0 then
		Spring.Echo(self:Name(), self.id, "Get Unit Commands received 0 as parameter index")
        return {} -- FIXME: Why am I receiving 0 count?
    end

    count = count or 1
    local currentOrder = Spring.GetUnitCommands(self.id,count)
    return currentOrder
end

function ShardUnit:Stop()
	local order = self:SyncOrder( self.id, CMD.STOP, {}, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.STOP, {}, 0 )
end

function ShardUnit:Stockpile()
	local order = self:SyncOrder( self.id, CMD.STOCKPILE, {0}, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.STOCKPILE, {}, 0 )
end

function ShardUnit:SelfDestruct()
	local order = self:SyncOrder( self.id, CMD.SELFD, {}, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.SELFD, {}, 0 )
end

function ShardUnit:Cloak()
	local order = self:SyncOrder( self.id, CMD.CLOAK, { 1 }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.CLOAK, { 1 }, 0 )
end

function ShardUnit:UnCloak()
	local order = self:SyncOrder( self.id, CMD.CLOAK, { 0 }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.CLOAK, { 0 }, 0 )
end

function ShardUnit:TurnOn()
	local order = self:SyncOrder( self.id, CMD.ONOFF, { 1 }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.ONOFF, { 1 }, 0 )
end

function ShardUnit:TurnOff()
	local order = self:SyncOrder( self.id, CMD.ONOFF, { 0 }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.ONOFF, { 0 }, 0 )
end

function ShardUnit:Guard( unit )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.GUARD, { gid }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.GUARD, { gid }, 0 )
end

function ShardUnit:Repair( unit )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.REPAIR, { gid }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.REPAIR, { gid }, 0 )
end

function ShardUnit:DGun(p)
	return self:AltAttack( p )
end

function ShardUnit:ManualFire(p)
	local order = self:SyncOrder( self.id, CMD.DGUN, { p.x, p.y, p.z }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.DGUN, { p.x, p.y, p.z }, 0 )
end

function ShardUnit:Move(p,opts)
	local opts = opts or 0
	local order = self:SyncOrder( self.id, CMD.MOVE, { p.x, p.y, p.z }, opts )
	--return Spring.GiveOrderToUnit( self.id, CMD.MOVE, { p.x, p.y, p.z }, 0 )
end

function ShardUnit:AttackMove(p)
	return self:MoveAndFire(p)
end

function ShardUnit:MoveAndFire(p)
	self:SyncOrder( self.id, CMD.FIGHT, { p.x, p.y, p.z }, 0 )
	--return Spring.GiveOrderToUnit( self.id, CMD.FIGHT, { p.x, p.y, p.z }, 0 )
end

function ShardUnit:Patrol(p)
	--local order = self:SyncOrder(self.id, CMD.PATROL, p, 0)
 	return self:MoveAndPatrol(p)
end

function ShardUnit:MoveAndPatrol(p)
	local order = self:SyncOrder(self.id, CMD.PATROL, p, 0)
	--return Spring.GiveOrderToUnit( self.id, CMD.PATROL, { p.x, p.y, p.z }, 0 )
end



function ShardUnit:Build(t, p, f, opts ) -- IUnitType* , timeout????
 	if type(t) == "string" then
 		t = game:GetTypeByName(t)
 	end
	
-- 	if type(opts) == 'table' then
-- 		opts = table.concat(opts,',')
-- 	end
	opts = opts or {0}
	f = f or 0
	p = p or self:GetPosition()
	--if not p then p = self:GetPosition() end
	timeout = timeout or 2000
	local order = self:SyncOrder(self.id,-t:ID(),{p.x, p.y, p.z, f},opts,timeout)
end



function ShardUnit:Reclaim( thing )--IMapFeature* mapFeature)
	if not thing then return end
	local gid = self:Unit_to_id( thing )
	if thing.className == "feature" then
		local order = self:SyncOrder( self.id, CMD.RECLAIM, { gid + Game.maxUnits }, 0 )
		--return Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { gid + Game.maxUnits }, 0 )
	elseif thing.className == "unit" then
		local order = self:SyncOrder( self.id, CMD.RECLAIM, { gid }, 0 )
		--return Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { gid }, 0 )
	end
end

function ShardUnit:AreaReclaim( p, radius )--Position p, double radius)
	local order = self:SyncOrder( self.id, CMD.RECLAIM, { p.x, p.y, p.z, radius }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.RECLAIM, { p.x, p.y, p.z, radius }, 0 )
end


function ShardUnit:Ressurect( thing )--IMapFeature* mapFeature)
	if not thing then return end
	local gid = self:Unit_to_id( thing )
	if thing.className == "feature" then
		local order = self:SyncOrder( self.id, CMD.RESURRECT, { gid + Game.maxUnits }, 0 )
-- 		return Spring.GiveOrderToUnit( self.id, CMD.RESURRECT, { gid + Game.maxUnits }, 0 )
	elseif thing.className == "unit" then
		local order = self:SyncOrder( self.id, CMD.RESURRECT, { gid }, 0 )
-- 		return Spring.GiveOrderToUnit( self.id, CMD.RESURRECT, { gid }, 0 )
	end
	return false
end

function ShardUnit:AreaResurrect( p, radius )--Position p, double radius)
	local order = self:SyncOrder( self.id, CMD.RESURRECT, { p.x, p.y, p.z, radius }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.RESURRECT, { p.x, p.y, p.z, radius }, 0 )
end

function ShardUnit:AreaRESURRECT( p, radius )--Position p, double radius)
	return self:AreaResurrect( p, radius )
end

function ShardUnit:AttackPos( pos )
	local order = self:SyncOrder( self.id, CMD.ATTACK, { pos.x, pos.y, pos.z }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.ATTACK, { gid }, 0 )
end

function ShardUnit:Attack( unit )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.ATTACK, { gid }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.ATTACK, { gid }, 0 )
end

function ShardUnit:AreaAttack(p,radius)
	local order = self:SyncOrder( self.id, CMD.AREA_ATTACK, { p.x, p.y, p.z, radius }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.AREA_ATTACK, { p.x, p.y, p.z, radius }, 0 )
end

function ShardUnit:Repair( unit )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.REPAIR, { gid }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.REPAIR, { gid }, 0 )
end

function ShardUnit:AreaRepair( p, radius )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.REPAIR, { p.x, p.y, p.z, radius }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.REPAIR, { p.x, p.y, p.z, radius }, 0 )
end

function ShardUnit:RestoreTerrain( p, radius )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.RESTORE, { p.x, p.y, p.z, radius }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.RESTORE, { p.x, p.y, p.z, radius }, 0 )
end

function ShardUnit:Capture( unit )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.CAPTURE, { gid }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.CAPTURE, { gid }, 0 )
end

function ShardUnit:AreaCapture( p, radius )
	local gid = self:Unit_to_id( unit )
	local order = self:SyncOrder( self.id, CMD.CAPTURE, { p.x, p.y, p.z, radius }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.CAPTURE, { p.x, p.y, p.z, radius }, 0 )
end

function ShardUnit:MorphInto( type )
	local order = self:SyncOrder( self.id, GameCMD.MORPH, { self.id }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, GameCMD.MORPH, { self.id }, 0 )
end

function ShardUnit:HoldFire()
	local order = self:SyncOrder( self.id, CMD.FIRE_STATE, { 0 }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.FIRE_STATE, { 0 }, 0 )
end

function ShardUnit:ReturnFire()
	local order = self:SyncOrder( self.id, CMD.FIRE_STATE, { 1 }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.FIRE_STATE, { 1 }, 0 )
end

function ShardUnit:FireAtWill()
	local order = self:SyncOrder( self.id, CMD.FIRE_STATE, { 2 }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.FIRE_STATE, { 2 }, 0 )
end

function ShardUnit:HoldPosition()
	local order = self:SyncOrder( self.id, CMD.MOVE_STATE, { 0 }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.MOVE_STATE, { 0 }, 0 )
end

function ShardUnit:Manoeuvre()
	local order = self:SyncOrder( self.id, CMD.MOVE_STATE, { 1 }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.MOVE_STATE, { 1 }, 0 )
end

function ShardUnit:Roam()
	local order = self:SyncOrder( self.id, CMD.MOVE_STATE, { 2 }, 0 )
-- 	return Spring.GiveOrderToUnit( self.id, CMD.MOVE_STATE, { 2 }, 0 )
end

function ShardUnit:IdleModeFly()
	local order = self:SyncOrder( self.id, CMD.IDLEMODE, { 0 }, 0 )
end

function ShardUnit:IdleModeLand()
	local order = self:SyncOrder( self.id, CMD.IDLEMODE, { 1 }, 0 )
end

function ShardUnit:CurrentCommand()
	return Spring.GetUnitCurrentCommand(self.id)
end

function ShardUnit:GetPosition()
	local bpx, bpy, bpz = Spring.GetUnitPosition(self.id)
	local isDead = Spring.GetUnitIsDead(self.id)
	if not bpx then
		--Spring.Echo(self:Name(), self.id, "Get Position return nil position")
		return
	end
	if self.position == nil then
		self.position = {}
	end
	local position = self.position
	position.x = bpx
	position.y = bpy
	position.z = bpz

	return position
end

function ShardUnit:GetRawPos()
	local bpx, bpy, bpz = Spring.GetUnitPosition(self.id)
	return bpx, bpy, bpz
end

function ShardUnit:GetHealtsParams()
	local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth( self.id )
	return health, maxHealth, paralyzeDamage, captureProgress, buildProgress, health/maxHealth
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
	local isBuilding, buildProgress = Spring.GetUnitIsBeingBuilt( self.id )
	return buildProgress
end


function ShardUnit:WeaponCount()
	return self:Type():WeaponCount()
end


function ShardUnit:MaxWeaponsRange()
	return Spring.GetUnitMaxRange(self.id)
end


function ShardUnit:CanBuild( uType )
	if type(uType ) == 'string' then
		uType = game:GetTypeByName(uType)
	end
	return self:Type():CanBuild(uType)
end

function ShardUnit:GetFacing(id)
	return Spring.GetUnitBuildFacing ( id )
-- 	0, "s", "south"
--     1, "e", "east"
--     2, "n", "north"
--     3, "w", "west"
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

function ShardUnit:TestMoveOrder( p )
	return Spring.TestMoveOrder( self.UnitDefID, p.x, p.y, p.z, nil, nil, nil, true, true,false )
end

function ShardUnit:SyncOrder(id,cmd,pos,opts--[[,timeout]])
	self:Warn('STAI syncOrder is unsupported please use GiveOrder instead')
end

--- Issue an arbitrary command to the spring engine
--
-- If you know the ID etc you can issue a command directly.
-- If the engine accepts the command, true will be returned.
-- This should not be interpreted as a succesful command
-- however. A failed command might trigger Unit Idle.
--
-- If you do not control this unit, and the engine decides
-- you are not allowed to issue it commands, false will be
-- returned.
--
-- @param cmdId       the ID number of the command to issue
-- @param params_list the parameters of that command, e.g. target ID, position, etc
-- @param options     various options such as shift etc
-- @param timeOut     how many frames before the command times out and the unit idle is triggered?
--
-- @return boolean was the command accepted
--                 false if we can't issue a command to this unit
-- function ShardUnit:ExecuteCustomCommand( cmdId, params_list, options, timeOut )
-- 	params_list = params_list or {}
-- 	options = options or {}
-- 	if params_list and params_list.push_back then
-- 		-- handle fake vectorFloat object
-- 		params_list = params_list.values
-- 	end
-- 	return Spring.GiveOrderToUnit(self.id, cmdId, params_list, options, timeOut )
-- end

function ShardUnit:DrawHighlight( color, label, channel )
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawAddUnit')) then
		Script.LuaUI.ShardDrawAddUnit(self.id, { color[1], color[2], color[3], color[4] }, label, ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawAddUnit', self.id, color[1], color[2], color[3], color[4], label, ai.game:GetTeamID(), channel)
end

function ShardUnit:EraseHighlight( color, label, channel )
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawEraseUnit')) then
		Script.LuaUI.ShardDrawEraseUnit(self.id, { color[1], color[2], color[3], color[4] }, label, ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawEraseUnit', self.id, color[1], color[2], color[3], color[4], label, ai.game:GetTeamID(), channel)
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
