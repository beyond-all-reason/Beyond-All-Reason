
ShardUnit = class(function(a, id)
	a.id = id
	a.className = "unit"
	a.type = nil
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
	return 1
end

function ShardUnit:Radius()
	return 10
end

function ShardUnit:AllyTeam()
	return 1
end

function ShardUnit:Neutral()
	return false
end

function ShardUnit:Stunned()
	return false
end

function ShardUnit:Name()
	return 'nullunit'
end


function ShardUnit:IsAlive()
	return true
end


function ShardUnit:IsCloaked()
	return self:Cloaked()
end

function ShardUnit:Cloaked()
	return false
end


function ShardUnit:CurrentStockpile()
	return 0
end


function ShardUnit:Type()
	return nil
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
	return false
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
	return true
end

function ShardUnit:Stockpile()
	return true
end

function ShardUnit:SelfDestruct()
	return true
end

function ShardUnit:Cloak()
	return true
end

function ShardUnit:UnCloak()
	return true
end

function ShardUnit:TurnOn()
	return true
end

function ShardUnit:TurnOff()
	return true
end

function ShardUnit:Guard( unit )
	return true
end

function ShardUnit:Repair( unit )
	return true
end

function ShardUnit:DGun(p)
	return self:AltAttack( p )
end

function ShardUnit:ManualFire(p)
	return true
end

function ShardUnit:Move(p)
	return true
end

function ShardUnit:AttackMove(p)
	return self:MoveAndFire(p)
end

function ShardUnit:MoveAndFire(p)
	return true
end

function ShardUnit:Patrol(p)
	return self:MoveAndPatrol(p)
end

function ShardUnit:MoveAndPatrol(p)
	return true
end

function ShardUnit:Build(t, p)
	return true
end


function ShardUnit:Reclaim( thing )
	return true
end

function ShardUnit:AreaReclaim( p, radius )
	return true
end


function ShardUnit:Ressurect( thing )
	return true
end

function ShardUnit:AreaResurrect( p, radius )
	return true
end

function ShardUnit:Attack( unit )
	return true
end

function ShardUnit:AreaAttack(p,radius)
	return true
end

function ShardUnit:Repair( unit )
	return true
end

function ShardUnit:AreaRepair( p, radius )
	return true
end

function ShardUnit:RestoreTerrain( p, radius )
	return true
end

function ShardUnit:Capture( unit )
	return true
end

function ShardUnit:AreaCapture( p, radius )
	return true
end

function ShardUnit:MorphInto( type )
	return true
end

function ShardUnit:HoldFire()
	return true
end

function ShardUnit:ReturnFire()
	return true
end

function ShardUnit:FireAtWill()
	return true
end

function ShardUnit:HoldPosition()
	return true
end

function ShardUnit:Manoeuvre()
	return true
end

function ShardUnit:Roam()
	return true
end

function ShardUnit:GetPosition()
	return nil
end


function ShardUnit:GetHealth()
	return 1
end


function ShardUnit:GetMaxHealth()
	return 1
end

function ShardUnit:ParalysisDamage()
	return 0
end

function ShardUnit:CaptureProgress()
	return 0
end

function ShardUnit:BuildProgress()
	return 0
end


function ShardUnit:WeaponCount()
	return 0
end


function ShardUnit:MaxWeaponsRange()
	return 0
end


function ShardUnit:CanBuild( type )
	return false
end


function ShardUnit:GetResourceUsage( idx )
	return nil
end


function ShardUnit:ExecuteCustomCommand(  cmdId, params_list, options, timeOut )
	return nil
end

function ShardUnit:DrawHighlight( color, label, channel )
	return nil
end

function ShardUnit:EraseHighlight( color, label, channel )
	return nil
end