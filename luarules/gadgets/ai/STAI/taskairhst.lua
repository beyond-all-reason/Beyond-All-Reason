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

local

--LEVEL 1

function TaskAirHST:ConAir()
	unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corca"
	else
		unitName = "armca"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function TaskAirHST:Lvl1AirRaider()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "armcorbw"
	else
		unitName = "armkam"
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:Lvl1Fighter()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corveng"
	else
		unitName = "armfig"
	end
	return BuildAAIfNeeded(unitName)
end

function TaskAirHST:Lvl1Bomber()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corshad"
	else
		unitName = "armthund"
	end
	return BuildBomberIfNeeded(unitName)
end

function TaskAirHST:ScoutAir()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corfink"
	else
		unitName = "armpeep"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2
function TaskAirHST:ConAdvAir()
	unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "coraca"
	else
		unitName = "armaca"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitAdvPerTypeLimit))
end

function TaskAirHST:Lvl2Fighter()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corvamp"
	else
		unitName = "armhawk"
	end
	return BuildAAIfNeeded(unitName)
end

function TaskAirHST:Lvl2AirRaider()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corape"
	else
		-- spedical case: arm has an ubergunship
		local raidCounter = ai.raidhst:GetCounter("air")
		if raidCounter < UnitiesHST.baseRaidCounter and raidCounter > UnitiesHST.minRaidCounter then
			return "armblade"
		else
			unitName = "armbrawl"
		end
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:Lvl2Bomber()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corhurc"
	else
		unitName = "armpnix"
	end
	return BuildBomberIfNeeded(unitName)
end


function TaskAirHST:Lvl2TorpedoBomber()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "cortitan"
	else
		unitName = "armlance"
	end
	return BuildTorpedoBomberIfNeeded(unitName)
end

function TaskAirHST:MegaAircraft()
	if self.side == UnitiesHST.CORESideName then
		return BuildBreakthroughIfNeeded("corcrw")
	else
		return BuildBreakthroughIfNeeded("armliche")
	end
end


function TaskAirHST:ScoutAdvAir()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corawac"
	else
		unitName = "armawac"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--SEAPLANE
function TaskAirHST:ConSeaAir()
	unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corcsa"
	else
		unitName = "armcsa"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 9) + 1, ai.conUnitAdvPerTypeLimit))
end

function TaskAirHST:SeaBomber()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corsb"
	else
		unitName = "armsb"
	end
	return BuildBomberIfNeeded(unitName)
end

function TaskAirHST:SeaTorpedoBomber()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corseap"
	else
		unitName = "armseap"
	end
	return BuildTorpedoBomberIfNeeded(unitName)
end

function TaskAirHST:SeaFighter()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corsfig"
	else
		unitName = "armsfig"
	end
	return BuildAAIfNeeded(unitName)
end

function TaskAirHST:SeaAirRaider()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corcut"
	else
		unitName = "armsaber"
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskAirHST:ScoutSeaAir()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corhunt"
	else
		unitName = "armsehak"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--AIRPAD
function TaskAirHST:AirRepairPadIfNeeded()
	local tmpUnitName = UnitiesHST.DummyUnitName

	-- only make air pads if the team has at least 1 air fac
	if CountOwnUnits("corap") > 0 or CountOwnUnits("armap") > 0 or CountOwnUnits("coraap") > 0 or CountOwnUnits("armaap") > 0 then
		if self.side == UnitiesHST.CORESideName then
			tmpUnitName = "corasp"
		else
			tmpUnitName = "armasp"
		end
	end

	return BuildWithLimitedNumber(tmpUnitName, ai.conUnitPerTypeLimit)
end
