local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskEco: " .. inStr)
	end
end

--Factory call
function BuildAppropriateFactory()
	return FactoryUnitName
end
--nano call
function NanoTurret()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cornanotc"
	else
		unitName = "armnanotc"
	end
	return unitName
end

-- MEX

function BuildMex()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cormex"
	else
		unitName = "armmex"
	end
	return unitName
end

function SpecialMex()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corexp"
	else
		unitName = "armamex"
	end
	return unitName
end

function BuildUWMex()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coruwmex"
	else
		unitName = "armuwmex"
	end
	return unitName
end

function BuildMohoMex()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cormoho"
	else
		unitName = "armmoho"
	end
	return unitName
end

function BuildUWMohoMex()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coruwmme"
	else
		unitName = "armuwmme"
	end
	return unitName
end

--ENERGY
function Solar()
	if MyTB.side == CORESideName then
		return "corsolar"
	else
		return "armsolar"
	end
end

local function SolarAdv()
	if MyTB.side == CORESideName then
		return "coradvsol"
	else
		return "armadvsol"
	end
end

function Tidal()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cortide"
	else
		unitName = "armtide"
	end
	return unitName
end

function Wind()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corwin"
	else
		unitName = "armwin"
	end
	return unitName
end

function TidalIfTidal()
	local unitName = DummyUnitName
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
		return DummyUnitName
	end
	if MyTB.side == CORESideName then
		return "corgeo"
	else
		return "armgeo"
	end
end

function BuildMohoGeo()
	EchoDebug("BuildMohoGeo " .. tostring(ai.mapHasGeothermal))
	-- don't attempt if there are no spots on the map
	if not ai.mapHasGeothermal or ai.Energy.income < 900 or ai.Metal.income < 24 then
		return DummyUnitName
	end
	if MyTB.side == CORESideName then
		return "cmgeo"
	else
		return "amgeo"
	end
	-- will turn into a safe geothermal or a geothermal plasma battery if too close to a factory
end

local function BuildSpecialGeo()
	-- don't attempt if there are no spots on the map
	if not ai.mapHasGeothermal then
		return DummyUnitName
	end
	if MyTB.side == CORESideName then
		return "corbhmt"
	else
		return "armgmm"
	end
end

local function BuildFusion()
	if MyTB.side == CORESideName then
		return "corfus"
	else
		return "armfus"
	end
	-- will become cafus and aafus in CategoryEconFilter in TaskQueueBehaviour if energy income is higher than 4000
end

local function BuildAdvFusion()
	if MyTB.side == CORESideName then
		return "cafus"
	else
		return "aafus"
	end
	-- will become cafus and aafus in CategoryEconFilter in TaskQueueBehaviour if energy income is higher than 4000
end

local function BuildAdvEnergy(tskqbhvr)
	EchoDebug(tostring('advname '..tskqbhvr.name))
	local unitName = DummyUnitName
	unitName = BuildFusion()
	if ai.Energy.income > 4000 and (tskqbhvr.name == 'armacv' or tskqbhvr.name == 'coracv') then
		unitName = BuildAdvFusion()
	end
	return unitName
end
			

local function BuildUWFusion()
	if MyTB.side == CORESideName then
		return "coruwfus"
	else
		return "armuwfus"
	end
end

function buildEstore1()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corestor"
	else
		unitName = "armestor"
	end
	return unitName
end

function buildEstore2()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coruwadves"
	else
		unitName = "armuwadves"
	end
	return unitName	
end

function buildMstore1()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
			unitName = "cormstor"
	else
			unitName = "armmstor"
	end
	return unitName
end

function buildMstore2()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coruwadvms"
	else
		unitName = "armuwadvms"
	end
	return unitName
end

function buildMconv1()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cormakr"	
	else
		unitName = "armmakr"
	end
	return unitName
end

function buildMconv2()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
			unitName ='cormmkr'
	else
			unitName ='armmmkr'
	end
	return unitName
end

function buildMconv2UW()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
			unitName ='corfmmm'
	else
			unitName ='armfmmm'
	end
	return unitName
end

function buildWEstore1()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coruwes"
	else
		unitName = "armuwes"
	end
	return unitName
end

function buildWMstore1()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coruwms"
	else
		unitName = "armuwms"
	end
	return unitName
end

function buildWMconv1()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corfmkr"	
	else
		unitName = "armfmkr"
	end
	return unitName
end

function Economy0()
	local unitName=DummyUnitName
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

function Economy1()
        local unitName=DummyUnitName
	if ai.Energy.full > 0.5 and ai.Metal.full > 0.3 and ai.Metal.full < 0.7 and ai.Metal.income > 30 then
		unitName = SpecialMex()
	elseif (ai.Energy.full > 0.5  and ai.Metal.full > 0.3 and ai.Metal.income > 10 and ai.Energy.income > 100) then
		unitName = NanoTurret()
	elseif 	ai.Energy.full > 0.8 and ai.Energy.income > 600 and ai.Metal.reserves > 200 and ai.Energy.capacity < 7000 then
		unitName = buildEstore1()
	elseif ai.Metal.full > 0.8 and ai.Metal.income > 40 and ai.Metal.capacity < 4000  and ai.Energy.reserves > 300 then
		unitName = buildMstore1()
	elseif ai.Energy.income > ai.Energy.usage and ai.Energy.full > 0.9 and ai.Energy.income > 200 and ai.Energy.income < 2000 and ai.Metal.full < 0.3 then
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
	local unitName = DummyUnitName
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

function AdvEconomy(tskqbhvr)
	local unitName=DummyUnitName
	if ai.Energy.full > 0.9 and ai.Energy.income > 3000 and ai.Metal.reserves > 1000 and ai.Energy.capacity < 40000 then
		unitName = buildEstore2()
	elseif ai.Metal.full > 0.8 and ai.Metal.income > 100 and ai.Metal.capacity < 20000 and ai.Energy.full > 0.3 then
		unitName = buildMstore2()
	elseif ai.Energy.income > ai.Energy.usage and ai.Energy.full > 0.9 and ai.Energy.income > 2000 and ai.Metal.full < 0.3 then
		unitName = buildMconv2()
	elseif (ai.Energy.full < 0.3 or ai.Energy.income < ai.Energy.usage * 1.25) and ai.Metal.full > 0.1 and ai.Metal.income > 18 then
		unitName = BuildAdvEnergy(tskqbhvr)
	else--if ai.Metal.full < 0.2 and ai.Energy.full > 0.1 then
		unitName = BuildMohoMex()
	end
	EchoDebug('Economy level 3 '..unitName)
	return unitName
end

function AdvEconomyUnderWater(tskqbhvr)
	local unitName = DummyUnitName
	if 	ai.Energy.full>0.8 and ai.Energy.income > 2500 and ai.Metal.reserves > 800 and ai.Energy.capacity < 50000  then
		unitName=buildEstore2(tskqbhvr)
	elseif ai.Metal.full>0.7 and ai.Metal.income>30 and ai.Metal.capacity < 20000 and ai.Energy.full > 0.4 then
		unitName=buildMstore2(tskqbhvr)
	elseif ai.Energy.income > ai.Energy.usage and ai.Energy.full > 0.9 and ai.Energy.income > 2000 and ai.Metal.full < 0.3 then
		unitName = buildMconv2UW(tskqbhvr)
	elseif (ai.Energy.full<0.3 or ai.Energy.income < ai.Energy.usage * 1.5) and ai.Metal.full>0.1 then
		unitName = BuildUWFusion(tskqbhvr)
	else
		unitName = BuildUWMohoMex()
	end
	EchoDebug('Economy under water level 2 '..unitName)
	return unitName
end

function EconomySeaplane(tskqbhvr)
	local unitName=DummyUnitName
	if 	ai.Energy.full>0.7 and ai.Energy.income > 2000 and ai.Metal.income>ai.Metal.usage and ai.Energy.capacity < 60000  then
		unitName=buildEstore2(tskqbhvr)
	elseif ai.Metal.full>0.9 and ai.Metal.income>30 and ai.Metal.capacity < 30000 and ai.Energy.full > 0.3 then
		unitName=buildMstore2(tskqbhvr)
	elseif ai.Energy.full>0.8  then
		unitName=buildMconv2UW(tskqbhvr)
	elseif ai.Energy.full>0.5 and ai.Metal.full>0.5 then
		unitName=Lvl2ShipAssist() 
	end
	EchoDebug('Economy Seaplane '..unitName)
	return unitName
end

function EconomyBattleEngineer(tskqbhvr)
        local unitName=DummyUnitName
	if ai.realEnergy > 1.25 and ai.realMetal > 1.1 then
		unitName= NanoTurret()
	elseif ai.Energy.full < 0.1 and ai.Metal.full > 0.1 then
		unitName = Solar()
	elseif ai.Metal.full < 0.2 then 
		unitName=BuildMex()
	else
		unitName = EngineerAsFactory()
	end
	EchoDebug('Economy battle engineer  '..unitName)
	return unitName
end

function EconomyNavalEngineer(tskqbhvr)
        local unitName=DummyUnitName
	if ai.Energy.full < 0.2 and realMetal > 1 then
		unitName = TidalIfTidal()
	elseif ai.Metal.full < 0.2 and ai.Energy.income > ai.Metal.usage then
		unitName = BuildUWMex()
	else
		unitName = NavalEngineerAsFactory()
	end
	EchoDebug('Economy Naval Engineer '..unitName)
	return unitName
end

function EconomyFark(tskqbhvr)
	local unitName = DummyUnitName
	if (ai.Energy.full < 0.3 or ai.realEnergy < 1.1)   then
		unitName = WindSolar()
	elseif ai.Energy.full > 0.9 and ai.Metal.capacity < 4000 then
		unitName = buildEstore1()
	else
		unitName = BuildMex()
	end
	return unitName
end