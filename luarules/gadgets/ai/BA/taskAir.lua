local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskAir: " .. inStr)
	end
end

--LEVEL 1

function ConAir()
	unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corca"
	else
		unitName = "armca"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function Lvl1AirRaider(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "bladew"
	else
		unitName = "armkam"
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl1Fighter()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corveng"
	else
		unitName = "armfig"
	end
	return BuildAAIfNeeded(unitName)
end

function Lvl1Bomber()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corshad"
	else
		unitName = "armthund"
	end
	return BuildBomberIfNeeded(unitName)
end

function ScoutAir()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corfink"
	else
		unitName = "armpeep"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2
function ConAdvAir()
	unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coraca"
	else
		unitName = "armaca"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitAdvPerTypeLimit))
end

function Lvl2Fighter()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corvamp"
	else
		unitName = "armhawk"
	end
	return BuildAAIfNeeded(unitName)
end

function Lvl2AirRaider(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corape"
	else
		-- spedical case: arm has an ubergunship
		local raidCounter = ai.raidhandler:GetCounter("air")
		if raidCounter < baseRaidCounter and raidCounter > minRaidCounter then
			return "blade"
		else
			unitName = "armbrawl"
		end
	end
	return BuildRaiderIfNeeded(unitName)
end

function Lvl2Bomber()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corhurc"
	else
		unitName = "armpnix"
	end
	return BuildBomberIfNeeded(unitName)
end


function Lvl2TorpedoBomber()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "cortitan"
	else
		unitName = "armlance"
	end
	return BuildTorpedoBomberIfNeeded(unitName)
end

function MegaAircraft()
	if MyTB.side == CORESideName then
		return BuildBreakthroughIfNeeded("corcrw")
	else
		return BuildBreakthroughIfNeeded("armcybr")
	end
end


function ScoutAdvAir()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corawac"
	else
		unitName = "armawac"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--SEAPLANE
function ConSeaAir()
	unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corcsa"
	else
		unitName = "armcsa"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 9) + 1, ai.conUnitAdvPerTypeLimit))
end

function SeaBomber()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corsb"
	else
		unitName = "armsb"
	end
	return BuildBomberIfNeeded(unitName)
end

function SeaTorpedoBomber()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corseap"
	else
		unitName = "armseap"
	end
	return BuildTorpedoBomberIfNeeded(unitName)
end

function SeaFighter()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corsfig"
	else
		unitName = "armsfig"
	end
	return BuildAAIfNeeded(unitName)
end

function SeaAirRaider(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corcut"
	else
		unitName = "armsaber"
	end
	return BuildRaiderIfNeeded(unitName)
end

function ScoutSeaAir()
	local unitName
	if MyTB.side == CORESideName then
		unitName = "corhunt"
	else
		unitName = "armsehak"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--AIRPAD
function AirRepairPadIfNeeded()
	local tmpUnitName = DummyUnitName

	-- only make air pads if the team has at least 1 air fac
	if CountOwnUnits("corap") > 0 or CountOwnUnits("armap") > 0 or CountOwnUnits("coraap") > 0 or CountOwnUnits("armaap") > 0 then
		if MyTB.side == CORESideName then
			tmpUnitName = "corasp"
		else
			tmpUnitName = "armasp"
		end
	end
	
	return BuildWithLimitedNumber(tmpUnitName, ai.conUnitPerTypeLimit)
end
