local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskEco: " .. inStr)
	end
end

--Factory call
function BuildAppropriateFactory()
	return UnitiesHST.FactoryUnitName
end
--nano call
function NanoTurret()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "cornanotc"
	else
		unitName = "armnanotc"
	end
	return unitName
end

function NanoWater()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "cornanotcplat"
	else
		unitName = "armnanotcplat"
	end
	return unitName
end

-- MEX

function BuildMex()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "cormex"
	else
		unitName = "armmex"
	end
	return unitName
end

function SpecialMex()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "corexp"
	else
		unitName = "armamex"
	end
	return unitName
end

function BuildUWMex()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "coruwmex"
	else
		unitName = "armuwmex"
	end
	return unitName
end

function BuildMohoMex()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "cormoho"
	else
		unitName = "armmoho"
	end
	return unitName
end

function BuildUWMohoMex()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "coruwmme"
	else
		unitName = "armuwmme"
	end
	return unitName
end

--ENERGY
function Solar()
	if MyTB.side == UnitiesHST.CORESideName then
		return "corsolar"
	else
		return "armsolar"
	end
end

local function SolarAdv()
	if MyTB.side == UnitiesHST.CORESideName then
		return "coradvsol"
	else
		return "armadvsol"
	end
end

function Tidal()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "cortide"
	else
		unitName = "armtide"
	end
	return unitName
end

function Wind()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "corwin"
	else
		unitName = "armwin"
	end
	return unitName
end

function TidalIfTidal()
	local unitName = UnitiesHST.DummyUnitName
	local tidalPower = map:TidalStrength()
	EchoDebug("tidal power is " .. tidalPower)
	if tidalPower >= 10 then
		unitName = Tidal()
	end
	return unitName
end

function windLimit()
	if map:AverageWind() >= 10 then
		local minWind = map:MinimumWindSpeed()
		if minWind >= 8 then
			EchoDebug("minimum wind high enough to build only wind")
			return true
		else
			return math.random() < math.max(0.5, minWind / 8)
		end
	else
		return false
	end
end

function WindSolar()
	if windLimit() then
		return Wind()
	else
		return Solar()
	end
end

function Energy1()

	if ai.Energy.income > math.max(map:AverageWind() * 20, 150) then --and ai.Metal.reserves >50
		return SolarAdv()
	else
		return WindSolar()
	end
end

function BuildGeo()
	-- don't attempt if there are no spots on the map
	EchoDebug("BuildGeo " .. tostring(ai.mapHasGeothermal))
	if not ai.mapHasGeothermal or ai.Energy.income < 150 or ai.Metal.income < 10 then
		return UnitiesHST.DummyUnitName
	end
	if MyTB.side == UnitiesHST.CORESideName then
		return "corgeo"
	else
		return "armgeo"
	end
end

function BuildMohoGeo()
	EchoDebug("BuildMohoGeo " .. tostring(ai.mapHasGeothermal))
	-- don't attempt if there are no spots on the map
	if not ai.mapHasGeothermal or ai.Energy.income < 900 or ai.Metal.income < 24 then
		return UnitiesHST.DummyUnitName
	end
	if MyTB.side == UnitiesHST.CORESideName then
		return "corageo"
	else
		return "armageo"
	end
	-- will turn into a safe geothermal or a geothermal plasma battery if too close to a factory
end

local function BuildSpecialGeo()
	-- don't attempt if there are no spots on the map
	if not ai.mapHasGeothermal then
		return UnitiesHST.DummyUnitName
	end
	if MyTB.side == UnitiesHST.CORESideName then
		return "corbhmt"
	else
		return "armgmm"
	end
end

local function BuildFusion()
	if MyTB.side == UnitiesHST.CORESideName then
		return "corfus"
	else
		return "armfus"
	end
	-- will become corafus and armafus in CategoryEconFilter in TaskQueueBST if energy income is higher than 4000
end

local function BuildAdvFusion()
	if MyTB.side == UnitiesHST.CORESideName then
		return "corafus"
	else
		return "armafus"
	end
	-- will become corafus and armafus in CategoryEconFilter in TaskQueueBST if energy income is higher than 4000
end

local function BuildAdvEnergy(tskqbhvr)
	EchoDebug(tostring('advname '..tskqbhvr.name))
	local unitName = UnitiesHST.DummyUnitName
	unitName = BuildFusion()
	if ai.Energy.income > 4000 and (tskqbhvr.name == 'armacv' or tskqbhvr.name == 'coracv') then
		unitName = BuildAdvFusion()
	end
	return unitName
end


local function BuildUWFusion()
	if MyTB.side == UnitiesHST.CORESideName then
		return "coruwfus"
	else
		return "armuwfus"
	end
end

function buildEstore1()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "corestor"
	else
		unitName = "armestor"
	end
	return unitName
end

function buildEstore2()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "coruwadves"
	else
		unitName = "armuwadves"
	end
	return unitName
end

function buildMstore1()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
			unitName = "cormstor"
	else
			unitName = "armmstor"
	end
	return unitName
end

function buildMstore2()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "coruwadvms"
	else
		unitName = "armuwadvms"
	end
	return unitName
end

function buildMconv1()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "cormakr"
	else
		unitName = "armmakr"
	end
	return unitName
end

function buildMconv2()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
			unitName ='cormmkr'
	else
			unitName ='armmmkr'
	end
	return unitName
end

function buildMconv2UW()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
			unitName ='corfmmm'
	else
			unitName ='armfmmm'
	end
	return unitName
end

function buildWEstore1()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "coruwes"
	else
		unitName = "armuwes"
	end
	return unitName
end

function buildWMstore1()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "coruwms"
	else
		unitName = "armuwms"
	end
	return unitName
end

function buildWMconv1()
	local unitName = UnitiesHST.DummyUnitName
	if MyTB.side == UnitiesHST.CORESideName then
		unitName = "corfmkr"
	else
		unitName = "armfmkr"
	end
	return unitName
end

function Economy0()
	local unitName=UnitiesHST.DummyUnitName
	if ai.Energy.full > 0.1 and (ai.Metal.income < 1 or ai.Metal.full < 0.3) then
		unitName = BuildMex()
	elseif ai.Energy.full > 0.9 and ai.Energy.income > 400  and ai.Metal.reserves > 100 and ai.Energy.capacity < 7000 then
		 unitName = buildEstore1()
	elseif ai.Metal.full > 0.7 and ai.Metal.income > 50 and ai.Metal.capacity < 4000 and ai.Energy.reserves > 500  then
		 unitName = buildMstore1()
	elseif ai.Energy.income > ai.Energy.usage * 1.1 and ai.Energy.full > 0.9 and ai.Energy.income > 200 and ai.Energy.income < 2000 and ai.Metal.full < 0.3 then
		unitName = buildMconv1()
	elseif (ai.Energy.full < 0.5 or ai.Energy.income < ai.Energy.usage )   then
		unitName = WindSolar()
	else
		unitName = BuildMex()
	end
	EchoDebug('Economy commander '..unitName)
	return unitName
end

function Economy0uw()
	local unitName = UnitiesHST.DummyUnitName
	if ai.Energy.full > 0.9 and ai.Energy.income > 500  and ai.Metal.reserves > 300 and ai.Energy.capacity < 7000 then
		unitName = buildWEstore1()
	elseif ai.Metal.full > 0.7 and ai.Metal.income > 30 and ai.Metal.capacity < 4000 and ai.Energy.reserves > 600 then
		unitName = buildWMstore1()
	elseif ai.Energy.income > ai.Energy.usage and ai.Energy.full > 0.9 and ai.Energy.income > 200 and ai.Energy.income < 2000 and ai.Metal.full < 0.3 then
		unitName = buildWMconv1()
	elseif ai.Energy.full > 0.1 and (ai.Metal.income < 1 or ai.Metal.full < 0.6) then
		unitName = BuildUWMex()
	elseif (ai.Energy.full < 0.3 or ai.Energy.income < ai.Energy.usage * 1.25) and ai.Metal.income > 3 and ai.Metal.full > 0.1 then
		unitName = TidalIfTidal()--this can get problems
	else
		unitName = BuildUWMex()
	end
	EchoDebug('Under water Economy level 1 '..unitName)
	return unitName
end

function Economy1()
	local unitName=UnitiesHST.DummyUnitName
	if ai.Energy.full > 0.5 and ai.Metal.full > 0.3 and ai.Metal.full < 0.7 and ai.Metal.income > 30 then
		unitName = SpecialMex()
	elseif (ai.Energy.full > 0.5  and ai.Metal.full > 0.3 and ai.Metal.income > 10 and ai.Energy.income > 100) then
		unitName = NanoTurret()
	elseif 	ai.Energy.full > 0.8 and ai.Energy.income > 600 and ai.Metal.reserves > 200 and ai.Energy.capacity < 7000 then
		unitName = buildEstore1()
	elseif ai.Metal.full > 0.8 and ai.Metal.income > 40 and ai.Metal.capacity < 4000  and ai.Energy.reserves > 300 then
		unitName = buildMstore1()
	elseif ai.Energy.income > ai.Energy.usage and ai.Energy.full > 0.8 and ai.Energy.income > 100 and ai.Energy.income < 2000 and ai.Metal.full < 0.5 then
		unitName = buildMconv1()
	elseif (ai.Energy.full < 0.3 or ai.Energy.income < ai.Energy.usage * 1.25) and ai.Metal.full > 0.1 then
		unitName = Energy1()
	else
		unitName = BuildMex()
	end
	EchoDebug('Economy level 1 '..unitName)
	return unitName
end

function EconomyUnderWater()
	local unitName = UnitiesHST.DummyUnitName
	if (ai.Energy.full > 0.5  and ai.Metal.full > 0.3 and ai.Metal.income > 10 and ai.Energy.income > 100) then
	unitName = NanoWater()
	elseif ai.Energy.full > 0.9 and ai.Energy.income > 500  and ai.Metal.reserves > 300 and ai.Energy.capacity < 7000 then
		unitName = buildWEstore1()
	elseif ai.Metal.full > 0.7 and ai.Metal.income > 30 and ai.Metal.capacity < 4000 and ai.Energy.reserves > 600 then
		unitName = buildWMstore1()
	elseif ai.Energy.income > ai.Energy.usage and ai.Energy.full > 0.9 and ai.Energy.income > 200 and ai.Energy.income < 2000 and ai.Metal.full < 0.3 then
		unitName = buildWMconv1()
	elseif ai.Energy.full > 0.1 and (ai.Metal.income < 1 or ai.Metal.full < 0.6) then
		unitName = BuildUWMex()
	elseif (ai.Energy.full < 0.3 or ai.Energy.income < ai.Energy.usage * 1.25) and ai.Metal.income > 3 and ai.Metal.full > 0.1 then
		unitName = TidalIfTidal()--this can get problems
	else
		unitName = BuildUWMex()
	end
	EchoDebug('Under water Economy level 1 '..unitName)
	return unitName
end

function AdvEconomy(tskqbhvr)
	local unitName=UnitiesHST.DummyUnitName
	if tskqbhvr.ai.Energy.full > 0.9 and tskqbhvr.ai.Energy.income > 3000 and tskqbhvr.ai.Metal.reserves > 1000 and tskqbhvr.ai.Energy.capacity < 40000 then
		unitName = buildEstore2()
	elseif tskqbhvr.ai.Metal.full > 0.8 and tskqbhvr.ai.Metal.income > 100 and tskqbhvr.ai.Metal.capacity < 20000 and tskqbhvr.ai.Energy.full > 0.3 then
		unitName = buildMstore2()
	elseif tskqbhvr.ai.Energy.income > tskqbhvr.ai.Energy.usage and tskqbhvr.ai.Energy.full > 0.7 and tskqbhvr.ai.Energy.income > 2000 and tskqbhvr.ai.Metal.full < 0.5 then
		unitName = buildMconv2()
	elseif (tskqbhvr.ai.Energy.full < 0.3 or tskqbhvr.ai.Energy.income < tskqbhvr.ai.Energy.usage * 1.25) and tskqbhvr.ai.Metal.full > 0.1 and tskqbhvr.ai.Metal.income > 18 then
		unitName = BuildAdvEnergy(tskqbhvr)
	else--if tskqbhvr.ai.Metal.full < 0.2 and tskqbhvr.ai.Energy.full > 0.1 then
		unitName = BuildMohoMex()
	end
	EchoDebug('Economy level 3 '..unitName)
	return unitName
end

function AdvEconomyUnderWater(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	if tskqbhvr.ai.Energy.full>0.8 and tskqbhvr.ai.Energy.income > 2500 and tskqbhvr.ai.Metal.reserves > 800 and tskqbhvr.ai.Energy.capacity < 50000  then
		unitName=buildEstore2(tskqbhvr)
	elseif tskqbhvr.ai.Metal.full>0.7 and tskqbhvr.ai.Metal.income>30 and tskqbhvr.ai.Metal.capacity < 20000 and tskqbhvr.ai.Energy.full > 0.4 then
		unitName=buildMstore2(tskqbhvr)
	elseif tskqbhvr.ai.Energy.income > tskqbhvr.ai.Energy.usage and tskqbhvr.ai.Energy.full > 0.9 and tskqbhvr.ai.Energy.income > 2000 and tskqbhvr.ai.Metal.full < 0.3 then
		unitName = buildMconv2UW(tskqbhvr)
	elseif (tskqbhvr.ai.Energy.full<0.3 or tskqbhvr.ai.Energy.income < tskqbhvr.ai.Energy.usage * 1.5) and tskqbhvr.ai.Metal.full>0.1 then
		unitName = BuildUWFusion(tskqbhvr)
	else
		unitName = BuildUWMohoMex()
	end
	EchoDebug('Economy under water level 2 '..unitName)
	return unitName
end

function EconomySeaplane(tskqbhvr)
	local unitName=UnitiesHST.DummyUnitName
	if tskqbhvr.ai.Energy.full>0.7 and tskqbhvr.ai.Energy.income > 2000 and tskqbhvr.ai.Metal.income>tskqbhvr.ai.Metal.usage and tskqbhvr.ai.Energy.capacity < 60000  then
		unitName=buildEstore2(tskqbhvr)
	elseif tskqbhvr.ai.Metal.full>0.9 and tskqbhvr.ai.Metal.income>30 and tskqbhvr.ai.Metal.capacity < 30000 and tskqbhvr.ai.Energy.full > 0.3 then
		unitName=buildMstore2(tskqbhvr)
	elseif tskqbhvr.ai.Energy.full>0.8  then
		unitName=buildMconv2UW(tskqbhvr)
	elseif tskqbhvr.ai.Energy.full>0.5 and tskqbhvr.ai.Metal.full>0.5 then
		unitName=Lvl2ShipAssist()
	end
	EchoDebug('Economy Seaplane '..unitName)
	return unitName
end

function EconomyBattleEngineer(tskqbhvr)
        local unitName=UnitiesHST.DummyUnitName
	if tskqbhvr.ai.realEnergy > 1.25 and tskqbhvr.ai.realMetal > 1.1 then
		unitName= NanoTurret()
	elseif tskqbhvr.ai.Energy.full < 0.1 and tskqbhvr.ai.Metal.full > 0.1 then
		unitName = Solar()
	elseif tskqbhvr.ai.Metal.full < 0.2 then
		unitName=BuildMex()
	else
		unitName = EngineerAsFactory()
	end
	EchoDebug('Economy battle engineer  '..unitName)
	return unitName
end

function EconomyNavalEngineer(tskqbhvr)
        local unitName=UnitiesHST.DummyUnitName
	if tskqbhvr.ai.Energy.full < 0.2 and realMetal > 1 then
		unitName = TidalIfTidal()
	elseif tskqbhvr.ai.Metal.full < 0.2 and tskqbhvr.ai.Energy.income > tskqbhvr.ai.Metal.usage then
		unitName = BuildUWMex()
	else
		unitName = NavalEngineerAsFactory()
	end
	EchoDebug('Economy Naval Engineer '..unitName)
	return unitName
end

function EconomyFark(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	if (tskqbhvr.ai.Energy.full < 0.3 or tskqbhvr.ai.realEnergy < 1.1)   then
		unitName = WindSolar()
	elseif tskqbhvr.ai.Energy.full > 0.9 and tskqbhvr.ai.Metal.capacity < 4000 then
		unitName = buildEstore1()
	else
		unitName = BuildMex()
	end
	return unitName
end
