TaskAirHST = class(Module)

function TaskAirHST:Name()
	return "TaskAirHST"
end

function TaskAirHST:internalName()
	return "taskairhst"
end

function TaskAirHST:Init()
	self.DebugEnabled = false
end

--LEVEL 1

function TaskAirHST:ConAir( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corca" ) then
		unitName = "corca"
	else if builder:CanBuild( "armca" ) then
		unitName = "armca"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskAirHST:Lvl1AirRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corbw" ) then
		unitName = "corbw"
	else if builder:CanBuild( "armkam" ) then
		unitName = "armkam"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:Lvl1Fighter( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corveng" ) then
		unitName = "corveng"
	else if builder:CanBuild( "armfig" ) then
		unitName = "armfig"
	end
	return self.ai.taskshst:BuildAAIfNeeded(unitName)
end

function TaskAirHST:Lvl1Bomber( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corshad" ) then
		unitName = "corshad"
	else if builder:CanBuild( "armthund" ) then
		unitName = "armthund"
	end
	return self.ai.taskshst:BuildBomberIfNeeded(unitName)
end

function TaskAirHST:ScoutAir( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corfink" ) then
		unitName = "corfink"
	else if builder:CanBuild( "armpeep" ) then
		unitName = "armpeep"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2
function TaskAirHST:ConAdvAir( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coraca" ) then
		unitName = "coraca"
	else if builder:CanBuild( "armaca" ) then
		unitName = "armaca"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, self.ai.conUnitAdvPerTypeLimit))
end

function TaskAirHST:Lvl2Fighter( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corvamp" ) then
		unitName = "corvamp"
	else if builder:CanBuild( "armhawk" ) then
		unitName = "armhawk"
	end
	return self.ai.taskshst:BuildAAIfNeeded(unitName)
end

function TaskAirHST:Lvl2AirRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corape" ) then
		unitName = "corape"
	else
		-- spedical case: arm has an ubergunship
		local raidCounter = self.ai.raidhst:GetCounter("air")
		if builder:CanBuild( "armblade" ) and raidCounter < self.ai.armyhst.baseRaidCounter and raidCounter > self.ai.armyhst.minRaidCounter then
			return "armblade"
		else if builder:CanBuild( "armbrawl" ) then
			unitName = "armbrawl"
		end
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:Lvl2Bomber( taskQueueBehaviour, ai, builder  taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corhurc" ) then
		unitName = "corhurc"
	else if builder:CanBuild( "armpnix" ) then
		unitName = "armpnix"
	end
	return self.ai.taskshst:BuildBomberIfNeeded(unitName)
end


function TaskAirHST:Lvl2TorpedoBomber( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "cortitan" ) then
		unitName = "cortitan"
	else if builder:CanBuild( "armlance" ) then
		unitName = "armlance"
	end
	return self.ai.taskshst:BuildTorpedoBomberIfNeeded(unitName)
end

function TaskAirHST:MegaAircraft( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corcrw" ) then
		return self.ai.taskshst:BuildBreakthroughIfNeeded("corcrw")
	else if builder:CanBuild( "armliche" ) then
		return self.ai.taskshst:BuildBreakthroughIfNeeded("armliche")
	end
end


function TaskAirHST:ScoutAdvAir( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corawac" ) then
		unitName = "corawac"
	else if builder:CanBuild( "armawac" ) then
		unitName = "armawac"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--SEAPLANE
function TaskAirHST:ConSeaAir( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corcsa" ) then
		unitName = "corcsa"
	else if builder:CanBuild( "armcsa" ) then
		unitName = "armcsa"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 9) + 1, self.ai.conUnitAdvPerTypeLimit))
end

function TaskAirHST:SeaBomber( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corsb" ) then
		unitName = "corsb"
	else if builder:CanBuild( "armsb" ) then
		unitName = "armsb"
	end
	return self.ai.taskshst:BuildBomberIfNeeded(unitName)
end

function TaskAirHST:SeaTorpedoBomber( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corseap" ) then
		unitName = "corseap"
	else if builder:CanBuild( "armseap" ) then
		unitName = "armseap"
	end
	return self.ai.taskshst:BuildTorpedoBomberIfNeeded(unitName)
end

function TaskAirHST:SeaFighter( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corsfig" ) then
		unitName = "corsfig"
	else if builder:CanBuild( "armsfig" ) then
		unitName = "armsfig"
	end
	return self.ai.taskshst:BuildAAIfNeeded(unitName)
end

function TaskAirHST:SeaAirRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corcut" ) then
		unitName = "corcut"
	else if builder:CanBuild( "armsaber" ) then
		unitName = "armsaber"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:ScoutSeaAir( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corhunt" ) then
		unitName = "corhunt"
	else if builder:CanBuild( "armsehak" ) then
		unitName = "armsehak"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--AIRPAD
function TaskAirHST:AirRepairPadIfNeeded( taskQueueBehaviour, ai, builder )
	local tmpUnitName = self.ai.armyhst.DummyUnitName

	-- only make air pads if the team has at least 1 air fac
	if self.ai.taskshst:CountOwnUnits("corap") > 0 or self.ai.taskshst:CountOwnUnits("armap") > 0 or self.ai.taskshst:CountOwnUnits("coraap") > 0 or self.ai.taskshst:CountOwnUnits("armaap") > 0 then
		if builder:CanBuild( "corasp" ) then
			tmpUnitName = "corasp"
		else if builder:CanBuild( "armasp" ) then
			tmpUnitName = "armasp"
		end
	end

	return self.ai.taskshst:BuildWithLimitedNumber(tmpUnitName, self.ai.conUnitPerTypeLimit)
end
