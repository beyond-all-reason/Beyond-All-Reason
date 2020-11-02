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

function TaskAirHST:ConAir()
	unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corca"
	else
		unitName = "armca"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskAirHST:Lvl1AirRaider()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corbw"
	else
		unitName = "armkam"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:Lvl1Fighter()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corveng"
	else
		unitName = "armfig"
	end
	return self.ai.taskshst:BuildAAIfNeeded(unitName)
end

function TaskAirHST:Lvl1Bomber()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corshad"
	else
		unitName = "armthund"
	end
	return self.ai.taskshst:BuildBomberIfNeeded(unitName)
end

function TaskAirHST:ScoutAir()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corfink"
	else
		unitName = "armpeep"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2
function TaskAirHST:ConAdvAir()
	unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coraca"
	else
		unitName = "armaca"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, self.ai.conUnitAdvPerTypeLimit))
end

function TaskAirHST:Lvl2Fighter()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corvamp"
	else
		unitName = "armhawk"
	end
	return self.ai.taskshst:BuildAAIfNeeded(unitName)
end

function TaskAirHST:Lvl2AirRaider()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corape"
	else
		-- spedical case: arm has an ubergunship
		local raidCounter = self.ai.raidhst:GetCounter("air")
		if raidCounter < self.ai.armyhst.baseRaidCounter and raidCounter > self.ai.armyhst.minRaidCounter then
			return "armblade"
		else
			unitName = "armbrawl"
		end
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:Lvl2Bomber()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corhurc"
	else
		unitName = "armpnix"
	end
	return self.ai.taskshst:BuildBomberIfNeeded(unitName)
end


function TaskAirHST:Lvl2TorpedoBomber()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cortitan"
	else
		unitName = "armlance"
	end
	return self.ai.taskshst:BuildTorpedoBomberIfNeeded(unitName)
end

function TaskAirHST:MegaAircraft()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildBreakthroughIfNeeded("corcrw")
	else
		return self.ai.taskshst:BuildBreakthroughIfNeeded("armliche")
	end
end


function TaskAirHST:ScoutAdvAir()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corawac"
	else
		unitName = "armawac"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--SEAPLANE
function TaskAirHST:ConSeaAir()
	unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcsa"
	else
		unitName = "armcsa"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 9) + 1, self.ai.conUnitAdvPerTypeLimit))
end

function TaskAirHST:SeaBomber()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsb"
	else
		unitName = "armsb"
	end
	return self.ai.taskshst:BuildBomberIfNeeded(unitName)
end

function TaskAirHST:SeaTorpedoBomber()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corseap"
	else
		unitName = "armseap"
	end
	return self.ai.taskshst:BuildTorpedoBomberIfNeeded(unitName)
end

function TaskAirHST:SeaFighter()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsfig"
	else
		unitName = "armsfig"
	end
	return self.ai.taskshst:BuildAAIfNeeded(unitName)
end

function TaskAirHST:SeaAirRaider()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcut"
	else
		unitName = "armsaber"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:ScoutSeaAir()
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corhunt"
	else
		unitName = "armsehak"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--AIRPAD
function TaskAirHST:AirRepairPadIfNeeded()
	local tmpUnitName = self.ai.armyhst.DummyUnitName

	-- only make air pads if the team has at least 1 air fac
	if self.ai.taskshst:CountOwnUnits("corap") > 0 or self.ai.taskshst:CountOwnUnits("armap") > 0 or self.ai.taskshst:CountOwnUnits("coraap") > 0 or self.ai.taskshst:CountOwnUnits("armaap") > 0 then
		if  self.ai.side == self.ai.armyhst.CORESideName then
			tmpUnitName = "corasp"
		else
			tmpUnitName = "armasp"
		end
	end

	return self.ai.taskshst:BuildWithLimitedNumber(tmpUnitName, self.ai.conUnitPerTypeLimit)
end
