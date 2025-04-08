
ShardUnitType = class(function(a, id)
	a.id = id
	a.def = UnitDefs[id]
end)

function ShardUnitType:ID()
	return self.id
end

function ShardUnitType:Name()
	return self.def.name
end

function ShardUnitType:Source()
	return self.def
end

function ShardUnitType:IsBuilder()
	return self.def.isBuilder
end

function ShardUnitType:BuildRange()
	return self.def.buildDistance
end

function ShardUnitType:CanMove()
	return self.def.canMove
end
function ShardUnitType:MoveName()
	return self.def.moveDef.name
end

function ShardUnitType:CanDeploy()
	-- what does deploy mean for Spring?
	return false
end

function ShardUnitType:CanMorph()
	-- what does deploy mean for Spring?
	return false
end

function ShardUnitType:IsFactory()
	-- what does deploy mean for Spring?
	return self.def.isFactory
end

function ShardUnitType:CanBuild(uType)
	if not uType then
		return self.def.buildOptions and #self.def.buildOptions > 0
	end
	if not self.canBuildType then
		self.canBuildType = {}
		for _, defID in pairs(self.def.buildOptions) do
			self.canBuildType[defID] = true
		end
	end
	return self.canBuildType[uType:ID()]
end

function ShardUnitType:WeaponCount()
	return #self.def.weapons -- test this. not sure the weapons table will give its length by the # operator
end

function ShardUnitType:Extractor()
	return self.def.extractsMetal > 0
end

function ShardUnitType:Geothermal()
	return self.def.needGeo
end

function ShardUnitType:ExtractorEfficiency()
	return self.def.extractsMetal
end


function ShardUnitType:CanAttack()
	return self.def.canAttack
end

function ShardUnitType:CanCloak()
	return self.def.canCloak
end

function ShardUnitType:CanAttackMove()
	return self:CanFight()
end

function ShardUnitType:CanFight()
	return self.def.canFight
end

function ShardUnitType:CanPatrol()
	return self.def.canPatrol
end

function ShardUnitType:CanGuard()
	return self.def.canGuard
end

function ShardUnitType:CanCloak()
	return self.def.canCloak
end

function ShardUnitType:CanSelfDestruct()
	return self.def.canSelfDestruct
end

function ShardUnitType:CanCloak()
	return self.def.canCloak
end

function ShardUnitType:CanRestore()
	return self.def.canRestore
end

function ShardUnitType:CanRepair()
	return self.def.canCloak
end

function ShardUnitType:CanReclaim()
	return self.def.canReclaim
end

function ShardUnitType:CanResurrect()
	return self.def.canResurrect
end

function ShardUnitType:CanCapture()
	return self.def.canCloak
end

function ShardUnitType:CanAssist()
	return self.def.canAssist
end

function ShardUnitType:CanBeAssisted()
	return self.def.canBeAssisted
end

function ShardUnitType:CanSelfRepair()
	return self.def.canSelfRepair
end

function ShardUnitType:IsAirbase()
	return self.def.customParams.isairbase
end

function ShardUnitType:CanHover()
	return self.def.canHover
end

function ShardUnitType:CanFly()
	return self.def.canFly
end

function ShardUnitType:CanSubmerge()
	return self.def.canSubmerge
end

function ShardUnitType:CanBeTransported()
	return not self.def.cantBeTransported
end

function ShardUnitType:CanKamikaze()
	return self.def.canKamikaze
end

function ShardUnitType:OnOffable()
	return self.def.onOffable
end

function ShardUnitType:HasStealth()
	return self.def.stealth
end

function ShardUnitType:HasSonarStealth()
	return self.def.sonarStealth
end

function ShardUnitType:LosRadius()
	return self.def.sightDistance
end

function ShardUnitType:RadarRadius()
	return self.def.radarDistance
end

function ShardUnitType:SonarRadius()
	return self.def.sonarDistance
end

function ShardUnitType:SeismicRadius()
	return self.def.seismicDistance
end

function ShardUnitType:CanManualFire()
	return self.def.canManualFire
end

function ShardUnitType:isFeatureOnBuilt()
	return self.def.isFeature
end

function ShardUnitType:TargetingPriority()
	return self.def.power -- buildCostMetal + (buildCostEnergy / 60.0) in spring engine
end

function ShardUnitType:BuildOptionsByName()
	return self.def.buildOptions
end

function ShardUnitType:Repairable()
	return self.def.repairable
end

function ShardUnitType:Capturable()
	return self.def.capturable
end

function ShardUnitType:ReclaimSpeed()
	return self.def.reclaimSpeed
end

function ShardUnitType:RepairSpeed()
	return self.def.repairSpeed
end

function ShardUnitType:MaxRepairSpeed()
	return self.def.maxRepairSpeed
end

function ShardUnitType:ResurrectSpeed()
	return self.def.resurrectSpeed
end

function ShardUnitType:CaptureSpeed()
	return self.def.captureSpeed
end

function ShardUnitType:TerraformSpeed()
	return self.def.terraformSpeed
end

function ShardUnitType:FootprintX()
	return self.def.footprintX
end

function ShardUnitType:FootprintZ()
	return self.def.footprintZ
end

function ShardUnitType:maxVelocity()
	return self.def.speed
end

function ShardUnitType:MaxAcceleration()
	return self.def.maxAcc
end

function ShardUnitType:MaxDeceleration()
	return self.def.maxDec
end

function ShardUnitType:BuildSpeed()
	return self.def.buildSpeed -- Time to build = (buildTime / buildspeed) * 32
end

function ShardUnitType:BuildTime()
	return self.def.buildTime -- Time to build = (buildTime / buildspeed) * 32
end

function ShardUnitType:BuildCostMetal()
	return self.def.buildCostMetal
end

function ShardUnitType:BuildCostEnergy()
	return self.def.buildCostEnergy
end

function ShardUnitType:Health()
	return self.def.health
end
