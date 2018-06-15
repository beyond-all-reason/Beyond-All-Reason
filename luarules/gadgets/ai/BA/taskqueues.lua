--[[
 Task Queues! -- Author: Damgam
]]--

math.randomseed( os.time() )
math.random(); math.random(); math.random()

-- Locals
----------------------------------------------------------------------
-- c = current, s = storage, p = pull(?), i = income, e = expense (Ctrl C Ctrl V into functions)
--local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
--local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
----------------------------------------------------------------------
-- for example ------------- UDC(ai.id, UDN.cormex.id) ---------------
local UDC = Spring.GetTeamUnitDefCount
local UDN = UnitDefNames
----------------------------------------------------------------------

local unitoptions = {}
--------------------------------------------------------------------------------------------
--------------------------------------- Main Functions -------------------------------------
--------------------------------------------------------------------------------------------
function ThirdMex(taskqueuebehaviour)
	if ai and ai.id then
		local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
		if mi < 5.5 then
			return "mex"
		else
			return "rship"
		end
	else
		return "rship"
	end
end

function FindBest(unitoptions)
	if GG.info and GG.info[ai.id] and unitoptions and unitoptions[1] then
		local effect = {}
		local randomization = 1
		local randomunit = {}
		for n, unitName in pairs(unitoptions) do
			local cost = UnitDefs[UnitDefNames[unitName].id].energyCost / 60 + UnitDefs[UnitDefNames[unitName].id].metalCost
			local avgkilled_cost = GG.info and GG.info[ai.id] and GG.info[ai.id][UnitDefNames[unitName].id] and GG.info[ai.id][UnitDefNames[unitName].id].avgkilled_cost or 200 --start at 200 so that costly units aren't made from the start
			effect[unitName] = math.max(math.floor((avgkilled_cost/cost)^4*100),1)
			for i = randomization, randomization + effect[unitName] do
				randomunit[i] = unitName
			end
			randomization = randomization + effect[unitName]
		end
		if randomization < 1 then
			return "corkrog"
		end
		return randomunit[math.random(1,randomization)]	
	else
		return unitoptions[math.random(1,#unitoptions)]
	end
end

function UUDC(unitName, teamID) -- Unfinished UnitDef Count
	local count = 0
	if UnitDefNames[unitName] then
		local tableUnits = Spring.GetTeamUnitsByDefs(teamID, UnitDefNames[unitName].id)
		for k, v in pairs(tableUnits) do
			local _,_,_,_,bp = Spring.GetUnitHealth(v)
			if bp < 1 then
				count = count + 1
			end
		end
	end
	return count
end

function WindOrSolar()
    local curWind = Spring.GetWind()
    local avgWind = (Game.windMin + Game.windMax)/2
	if ai and ai.id then
		if not (UDC(ai.id, UDN.armfus.id) + UDC(ai.id, UDN.corfus.id) > 1) then
			if curWind > 7 then
				return "win"
			else
				local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
				local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
				if ei > 200 and mi > 15 and (UUDC("armadvsol", ai.id) + UUDC("coradvsol", ai.id)) < 2 then
					return "advsol"
				else
					return "solar"
				end
			end
		else
			return "rship"	
		end
	else
		return "solar"
	end
end

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------- Core Functions -------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

function CorLLT()
	if Spring.GetGameSeconds() < 240 then
		return "corllt"
	elseif Spring.GetGameSeconds() < 480 then
		local unitoptions = {"corllt", "corhllt", "corhlt", "cormaw", "corrl"}
		return FindBest(unitoptions)
	else
		local unitoptions = {"corllt", "corhllt", "corhlt", "cormaw", "corrl", "cormadsam", "corerad"}
		return FindBest(unitoptions)
	end
end

function CorNanoT()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		return "cornanotc"
	else
		return "corkrog"
	end
end

function CorEnT1( taskqueuebehaviour )	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countEstore = UDC(ai.id, UDN.corestor.id) + UDC(ai.id, UDN.armestor.id)
	if ei - ep < 0 and ec < 0.5 * es then
        return ("cor"..WindOrSolar())
    elseif ei - ep > 0 and ec > 0.8 * es then
        return "cormakr"
	elseif es < (ei * 8) and ec > (es * 0.8) and countEstore < (ei*8)/6000 then
		return "corestor"
	elseif ms < (mi * 8) or mc > (ms*0.9) then
		return "cormstor"
	else
		return "cormex"
	end
end

function CorEcoT1( taskqueuebehaviour )
-- c = current, s = storage, p = pull(?), i = income, e = expense (Ctrl C Ctrl V into functions)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if taskqueuebehaviour.ai.map:AverageWind() > 7 and ec < es*0.10 then
		return "corwin"
	elseif taskqueuebehaviour.ai.map:AverageWind() <= 7 and ec < es*0.10 then
		return "corsolar"
	elseif mc < ms*0.1 and ec > es*0.90 then
		return "cormakr"
	else
		return "corkrog"
	end
end


function CorEnT2( taskqueuebehaviour )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ei - ep < 0 and ec < 0.5 * es and ei > 800 and mi > 35 and (UUDC("armfus", ai.id) + UUDC("corfus", ai.id)) < 2 then
        return "corfus"
    elseif ei - ep > 0 and ec > 0.8 * es then
        return "cormmkr"
	else
		return "cormoho"
	end
end

function CorMexT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms*0.1 then
		return "cormex"
	elseif mc < ms*0.3 then
		return "corexp"
	elseif ec < es*0.10 then
        return ("cor"..WindOrSolar())
    elseif ei - Spring.GetTeamRulesParam(ai.id, "mmCapacity") > 0 then
        return "cormakr"
	else
		return "corkrog"
	end
end

function CorStarterLabT1()
	local countStarterFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id)
	if countStarterFacs < 1 then
		local r = math.random(0,10)
		if r < 6 then
			return "corlab"
		else
			return "corvp"
		end
	else
		return "corkrog"
	end
end

function CorRandomLab()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local countBasicFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id) + UDC(ai.id, UDN.corhp.id)
	--local countAdvFacs = UDC(ai.id, UDN.coravp.id) + UDC(ai.id, UDN.coralab.id) + UDC(ai.id, UDN.coraap.id) + UDC(ai.id, UDN.corgant.id)
	local m = (mi - mp)*200 + mc
	local e = (ei - ep)*200 + ec
	if UDC(ai.id, UDN.corlab.id) == 1 and UDC(ai.id, UDN.corvp.id) == 0 and UDC(ai.id, UDN.coralab.id) == 0 and (((m > 2000 and e > 18000) and Spring.GetGameSeconds() >= 300) or Spring.GetGameSeconds() >= math.random(480, 720)) then
		return "coralab"
	elseif UDC(ai.id, UDN.corlab.id) == 0 and UDC(ai.id, UDN.corvp.id) == 1 and UDC(ai.id, UDN.coravp.id) == 0 and (((m > 2000 and e > 18000) and Spring.GetGameSeconds() >= 300) or Spring.GetGameSeconds() >= math.random(480, 720)) then
		return "coravp"
	end
	
	if (UDC(ai.id, UDN.armavp.id) + UDC(ai.id, UDN.armalab.id) + UDC(ai.id, UDN.coravp.id) + UDC(ai.id, UDN.coralab.id)) >= 1 and (m > 2000 and e > 18000) and Spring.GetGameSeconds() > 300 and not ((UUDC("corap", ai.id) + UUDC("coraap", ai.id) + UUDC("corvp", ai.id) + UUDC("coravp", ai.id) + UUDC("corlab", ai.id) + UUDC( "coralab", ai.id) + UUDC("armap", ai.id) + UUDC("armaap", ai.id) + UUDC("armvp", ai.id) + UUDC("armavp", ai.id) + UUDC("armlab", ai.id) + UUDC( "armalab", ai.id)) > 0) then
		if UDC(ai.id, UDN.corap.id) < 1 then
			return "corap"
		elseif UDC(ai.id, UDN.coraap.id) < 1 then
			return "coraap"
		elseif UDC(ai.id, UDN.corlab.id) < 1 then
			return "corlab"
		elseif UDC(ai.id, UDN.coralab.id) < 1 then
			return "coralab"
		elseif UDC(ai.id, UDN.corvp.id) < 1 then
			return "corvp"
		elseif UDC(ai.id, UDN.coravp.id) < 1 then
			return "coravp"
		elseif UDC(ai.id, UDN.corhp.id) < 1 then
			return "corhp"
		elseif UDC(ai.id, UDN.corgant.id) < 1 then
			return "corgant"
		else
			return "corkrog"
		end
	else
		return "corkrog"
	end
end

function CorGroundAdvDefT1()
	local r = math.random(0,100)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		if r == 0 and Spring.GetGameSeconds() > 600 then
			return "corpun"
		else
			local unitoptions = {"cormaw", "corhllt", "corhlt",}
			return FindBest(unitoptions)
		end
	else
		return "corkrog"
	end
end

function CorAirAdvDefT1()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"cormadsam", "corrl",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function CorAirAdvDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"corflak","corscreamer" }
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function CorTacticalAdvDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"corvipe","cortoast","cordoom", "corint"}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function CorTacticalOffDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		if  UDC(ai.id, UDN.corfmd.id) < 3 then
			return "corfmd"
		elseif 	 UDC(ai.id, UDN.corgate.id) < 6 then
			return "corgate"
		else
			return "corkrog"
		end
	else
		return "corkrog"
	end
end
	--local unitoptions = {"corfmd", "corsilo",}
	--return unitoptions[math.random(1,#unitoptions)]


function CorKBotsT1()
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if not (countAdvBuilders > 0 and (ec < es*0.3 or mc < ms*0.3)) then
		local unitoptions = {"corak", "corthud", "corstorm", "cornecro", "corcrash",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function CorVehT1()
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if not (countAdvBuilders > 0 and (ec < es*0.3 or mc < ms*0.3)) then
		local unitoptions = {"corfav", "corgator", "corraid", "corlevlr", "cormist", "corwolv", "corgarp",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function CorAirT1()
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if not (countAdvBuilders > 0 and (ec < es*0.3 or mc < ms*0.3)) then
		local unitoptions = {"corveng", "corshad", "corbw", "corfink",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function CorKBotsT2()
	
	local unitoptions = {"coraak", "coramph", "corcan", "corhrk", "cormort", "corpyro", "corroach", "cortermite", "corspec", "corsumo",}
	return FindBest(unitoptions)
end

function CorVehT2()
	
	local unitoptions = {"corban", "coreter", "corgol", "cormart", "corparrow", "correap", "corseal", "corsent", "cortrem", "corvroc",}
	return FindBest(unitoptions)
end

function CorAirT2()
	
	local unitoptions = {"corape", "corcrw", "corhurc", "corvamp",}
	return FindBest(unitoptions)
end

function CorHover()
	
	local unitoptions = {"corah", "corch", "corhal", "cormh", "corsh", "corsnap","corsok",}
	return FindBest(unitoptions)
end 
--[[
function CorSeaPlanes()
	
	local unitoptions = {"corcsa", "corcut", "corhunt", "corsb", "corseap", "corsfig", }
	return unitoptions[math.random(1,#unitoptions)]
end 		

function CorShipT1()
	
	local unitoptions = {"corcs", "cordship", "coresupp", "corpship", "corpt", "correcl", "corroy", "corrship", "corsub", "cortship",}
	return unitoptions[math.random(1,#unitoptions)]
end		

function CorShipT2()
	
	local unitoptions = {"coracsub", "corarch", "corbats", "corblackhy", "corcarry", "corcrus", "cormls", "cormship", "corshark", "corsjam", "corssub", }
	return unitoptions[math.random(1,#unitoptions)]
end				
]]--

function CorGantry()
	
	local unitoptions = {"corcat", "corjugg", "corkarg", "corkrog", "corshiva", }
	return FindBest(unitoptions)
end 

--constructors:

function CorT1KbotCon()
	return "corck"
end

function CorStartT1KbotCon()
	return (((Spring.GetGameSeconds() < 180) and"corck") or CorKBotsT1())
end


function CorT1RezBot()
	local CountRez = UDC(ai.id, UDN.cornecro.id)
	if CountRez <= 10 then
		return "cornecro"
	else
		return "corkrog"
	end
end

function CorT1VehCon()
		return "corcv"
end

function CorStartT1VehCon()
	return (((Spring.GetGameSeconds() < 180) and"corcv") or CorVehT1())
	end

function CorT1AirCon()
	local CountCons = UDC(ai.id, UDN.corca.id)
	if CountCons <= 4 then
		return "corca"
	else
		return "corkrog"
	end
end

function CorFirstT2Mexes()
	if not ai.firstt2mexes then
		ai.firstt2mexes = 1
		return "cormoho"
	elseif ai.firstt2mexes and ai.firstt2mexes <= 3 then
		ai.firstt2mexes = ai.firstt2mexes + 1
		return "cormoho"
	else
		return "corkrog"
	end
end

function CorFirstT1Mexes()
	if not ai.firstt1mexes then
		ai.firstt1mexes = 1
		return "cormex"
	elseif ai.firstt1mexes and ai.firstt1mexes <= 3 then
		ai.firstt1mexes = ai.firstt1mexes + 1
		return "cormex"
	else
		return "corkrog"
	end
end

--------------------------------------------------------------------------------------------
----------------------------------------- CoreTasks ----------------------------------------
--------------------------------------------------------------------------------------------

local corcommanderfirst = {
	"cormex",
	"cormex",
	"cor"..ThirdMex(),
	"cor"..WindOrSolar(),
	"cor"..WindOrSolar(),
	CorStarterLabT1,
	"corllt",
	"cor"..WindOrSolar(),
	CorStarterLabT1,
	--"corllt",
	"cor"..WindOrSolar(),
	CorStarterLabT1,
	"corrad",
	--"corllt",
}

local cort1construction = {
	CorRandomLab,
	CorFirstT1Mexes,
	CorFirstT1Mexes,
	CorFirstT1Mexes,
	-- CorLLT,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorNanoT,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	"corrad",
	CorLLT,
	CorLLT,
	CorRandomLab,
	CorNanoT,
	CorNanoT,
	CorNanoT,
	CorGroundAdvDefT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorLLT,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorNanoT,
	CorLLT,
	CorLLT,
	"corrad",
	CorMexT1,
	CorNanoT,
	"cormex",
	CorLLT,
	CorEnT1,
	CorEnT1,
	CorAirAdvDefT1,
	"corgeo",
}

local cort2construction = {
	CorFirstT2Mexes,
	CorFirstT2Mexes,
	CorFirstT2Mexes,
	CorTacticalAdvDefT2,
	CorEnT2,
	CorEnT2,
	CorEnT2,
	"corarad",
	CorTacticalAdvDefT2,
	CorRandomLab,
	CorTacticalOffDefT2,
	CorAirAdvDefT2,
}

local corkbotlab = {
	CorStartT1KbotCon,
	CorT1KbotCon,	--	Constructor
	CorKBotsT1,
	CorStartT1KbotCon,
	CorKBotsT1,
	CorStartT1KbotCon,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorT1RezBot,
}

local corvehlab = {
	CorStartT1VehCon,
	CorT1VehCon,	--	Constructor
	CorVehT1,
	CorStartT1VehCon,
	CorVehT1,
	CorStartT1VehCon,
	CorVehT1,
	CorVehT1,
	CorVehT1,
}

local corairlab = {
	CorT1AirCon,	-- 	Constructor
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
}

corkbotlabT2 = {
	"corack",
	"corfast",
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
}

corvehlabT2 = {
	"coracv",
	CorVehT2,
	CorVehT2,
	CorVehT2,
	CorVehT2,
	CorVehT2,
	CorVehT2,
	CorVehT2,
	CorVehT2,
	CorVehT2,
	CorVehT2,
}

corairlabT2 = {
	"coraca",
	CorAirT2,
	CorAirT2,
	CorAirT2,
	CorAirT2,
	CorAirT2,
	CorAirT2,
	CorAirT2,
	CorAirT2,
	CorAirT2,
	CorAirT2,
}
corhoverlabT2 = {
	"armch",
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
}
corgantryT3 = {
	CorGantry,
}

assistqueue = {
	{ action = "patrolrelative", position = {x = 100, y = 0, z = 100} },
}

--------------------------------------------------------------------------------------------
-------------------------------------- CoreQueuePicker -------------------------------------
--------------------------------------------------------------------------------------------

local function corcommander()
	if ai.engineerfirst == true then
		--return corcommanderq
		return assistqueue
	else
		ai.engineerfirst = true
		return corcommanderfirst
	end
end

--local function corT1constructorrandommexer()
	--if ai.engineerfirst1 == true then
			--local r = math.random(0,1)
		--if r == 0 or Spring.GetGameSeconds() < 300 then
			--return cort1mexingqueue
		--else
			--return cort1construction
		--end
	--else
        --ai.engineerfirst1 = true
        --return corT1ConFirst
    --end
--end

--------------------------------------------------------------------------------------------	
--------------------------------------------------------------------------------------------
--------------------------------------- Arm Functions --------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

function ArmLLT()
	if Spring.GetGameSeconds() < 240 then
		return "armllt"
	elseif Spring.GetGameSeconds() < 480 then
		local unitoptions = {"armllt", "armbeamer", "armhlt", "armclaw", "armrl"}
		return FindBest(unitoptions)
	else
		local unitoptions = {"armllt", "armbeamer", "armhlt", "armclaw", "armrl", "armpacko", "armcir"}
		return FindBest(unitoptions)
	end
end

function ArmNanoT()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		return "armnanotc"
	else
		return "corkrog"
	end
end


function ArmEnT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countEstore = UDC(ai.id, UDN.corestor.id) + UDC(ai.id, UDN.armestor.id)

	if ei - ep < 0 and ec < 0.5 * es then
        return ("arm"..WindOrSolar())
    elseif ei - ep > 0 and ec > 0.8 * es then
        return "armmakr"
	elseif es < (ei * 8) and ec > (es * 0.8) and countEstore < (ei *8) / 6000 then
		return "armestor"
	elseif ms < (mi * 8) or mc > (ms*0.9) then
		return "armmstor"
	else
		return "armmex"
	end
end

function ArmEcoT1( taskqueuebehaviour )
-- c = current, s = storage, p = pull(?), i = income, e = expense (Ctrl C Ctrl V into functions)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if taskqueuebehaviour.ai.map:AverageWind() > 7 and ec < es*0.10 then
		return "armwin"
	elseif taskqueuebehaviour.ai.map:AverageWind() <= 7 and ec < es*0.10 then
		return "armsolar"
	elseif mc < ms*0.1 and ec > es*0.90 then
		return "armmakr"
	else
		return "corkrog"
	end
end



function ArmEnT2( taskqueuebehaviour )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ei - ep < 0 and ec < 0.5 * es and ei > 800 and mi > 35 and (UUDC("armfus",ai.id) + UUDC("corfus",ai.id)) < 2 then
        return "armfus"
    elseif ei - ep > 0 and ec > 0.8 * es then
        return "armmmkr"
	else
		return "armmoho"
	end
end

function ArmMexT1( taskqueuebehaviour )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms - ms*0.8 then
		return "armmex"
	elseif ec < es*0.10 then
        return ("arm"..WindOrSolar())
    elseif ei - Spring.GetTeamRulesParam(ai.id, "mmCapacity") > 0 then
        return "armmakr"
	else
		return "corkrog"
	end
end

function ArmStarterLabT1()
	local countStarterFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id)
	if countStarterFacs < 1 then
		local r = math.random(0,10)
		if r < 6 then
			return "armlab"
		else
			return "armvp"
		end
	else
		return "corkrog"
	end
end

function ArmRandomLab()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local countBasicFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id) + UDC(ai.id, UDN.armhp.id)
	--local countAdvFacs = UDC(ai.id, UDN.armavp.id) + UDC(ai.id, UDN.armalab.id) + UDC(ai.id, UDN.armaap.id) + UDC(ai.id, UDN.armgant.id)
	local m = (mi - mp)*200 + mc
	local e = (ei - ep)*200 + ec
	if UDC(ai.id, UDN.armlab.id) == 1 and UDC(ai.id, UDN.armvp.id) == 0 and UDC(ai.id, UDN.armalab.id) == 0 and (((m > 2000 and e > 18000) and Spring.GetGameSeconds() >= 300) or Spring.GetGameSeconds() >= math.random(480, 720)) then
		return "armalab"
	elseif UDC(ai.id, UDN.armlab.id) == 0 and UDC(ai.id, UDN.armvp.id) == 1 and UDC(ai.id, UDN.armavp.id) == 0 and (((m > 2000 and e > 18000) and Spring.GetGameSeconds() >= 300) or Spring.GetGameSeconds() >= math.random(480, 720)) then
		return "armavp"
	end
	
	if (UDC(ai.id, UDN.armavp.id) + UDC(ai.id, UDN.armalab.id) + UDC(ai.id, UDN.coravp.id) + UDC(ai.id, UDN.coralab.id)) >= 1 and (m > 2000 and e > 18000) and Spring.GetGameSeconds() > 300 and not ((UUDC("corap", ai.id) + UUDC("coraap", ai.id) + UUDC("corvp", ai.id) + UUDC("coravp", ai.id) + UUDC("corlab", ai.id) + UUDC( "coralab", ai.id) + UUDC("armap", ai.id) + UUDC("armaap", ai.id) + UUDC("armvp", ai.id) + UUDC("armavp", ai.id) + UUDC("armlab", ai.id) + UUDC( "armalab", ai.id)) > 0) then
		if UDC(ai.id, UDN.armap.id) < 1 then
			return "armap"
		elseif UDC(ai.id, UDN.armaap.id) < 1 then
			return "armaap"
		elseif UDC(ai.id, UDN.armlab.id) < 1 then
			return "armlab"
		elseif UDC(ai.id, UDN.armalab.id) < 1 then
			return "armalab"
		elseif UDC(ai.id, UDN.armvp.id) < 1 then
			return "armvp"
		elseif UDC(ai.id, UDN.armavp.id) < 1 then
			return "armavp"
		elseif UDC(ai.id, UDN.armhp.id) < 1 then
			return "armhp"
		elseif UDC(ai.id, UDN.armshltx.id) < 1 then
			return "armshltx"
		else
			return "corkrog"
		end
	else
		return "corkrog"
	end
end

function ArmGroundAdvDefT1()
	local r = math.random(0,100)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		if r == 0 and Spring.GetGameSeconds() > 600 then
			return "armguard"
		else
			local unitoptions = {"armclaw", "armbeamer","armhlt",}
			return FindBest(unitoptions)
		end
	else
		return "corkrog"
	end
end

function ArmAirAdvDefT1()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"armrl", "armpacko",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function ArmAirAdvDefT2()
	local unitoptions = {"armmercury", "armflak",}
	return FindBest(unitoptions)
end

function ArmTacticalAdvDefT2()
    local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"armpb","armamb","armanni", "armbrtha"}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function ArmTacticalOffDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		if  UDC(ai.id, UDN.armamd.id) < 3 then
			return "armamd"
		elseif 	 UDC(ai.id, UDN.armgate.id) < 6 then
			return "armgate"
		else
			return "corkrog"
		end
	else
		return "corkrog"
	end
end
	--local unitoptions = {"armamd", "armsilo",}
	--return FindBest(unitoptions)

function ArmKBotsT1()
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if not (countAdvBuilders > 0 and (ec < es*0.3 or mc < ms*0.3)) then
		local unitoptions = {"armpw", "armham", "armrectr", "armrock", "armwar", "armjeth",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function ArmVehT1()
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if not (countAdvBuilders > 0 and (ec < es*0.3 or mc < ms*0.3)) then
		local unitoptions = {"armstump", "armjanus", "armsam", "armfav", "armflash", "armart", "armpincer",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end

function ArmAirT1()
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if not (countAdvBuilders > 0 and (ec < es*0.3 or mc < ms*0.3)) then
		local unitoptions = {"armpeep", "armthund", "armfig", "armkam",}
		return FindBest(unitoptions)
	else
		return "corkrog"
	end
end	

function ArmKBotsT2()
	
	local unitoptions = {"armaak", "armamph", "armaser", "armfast", "armfboy", "armfido", "armmav", "armsnipe", "armspid", "armzeus", "armvader",}
	return FindBest(unitoptions)
end

function ArmVehT2()
	
	local unitoptions = {"armbull", "armcroc", "armlatnk", "armmanni", "armmart", "armmerl", "armst", "armyork",}
	return FindBest(unitoptions)
end

function ArmAirT2()
	
	local unitoptions = {"armblade", "armbrawl", "armhawk", "armliche", "armpnix", "armstil",}
	return FindBest(unitoptions)
end

function ArmHover()
	
	local unitoptions = {"armah", "armanac", "armch", "armlun", "armmh", "armsh",}
	return FindBest(unitoptions)
end

--[[
function ArmSeaPlanes()
	
	local unitoptions = {"armcsa", "armsaber", "armsb", "armseap", "armsehak", "armsfig", }
	return unitoptions[math.random(1,#unitoptions)]
end 		

function ArmShipT1()
	
	local unitoptions = {"armcs", "armdecade", "armdship", "armpship", "armpt", "armrecl", "armroy", "armrship", "armsub", "armtship",}
	return unitoptions[math.random(1,#unitoptions)]
end		

function ArmShipT2()
	
	local unitoptions = {"armaas", "armacsub", "armbats", "armcarry", "armcrus", "armepoch", "armmls", "armmship", "armserp", "armsjam", "armsubk", }
	return unitoptions[math.random(1,#unitoptions)]
end		
]]--

function ArmGantry()
	
	local unitoptions = {"armbanth", "armmar", "armraz", "armvang", }
	return FindBest(unitoptions)
end

--constructors:

function ArmT1KbotCon()
	local CountCons = UDC(ai.id, UDN.armck.id)
	return "armck"
end

function ArmStartT1KbotCon()
	return (((Spring.GetGameSeconds() < 180) and "armck") or ArmKBotsT1())
end

function ArmT1RezBot()
	local CountRez = UDC(ai.id, UDN.armrectr.id)
	if CountRez <= 10 then
		return "armrectr"
	else
		return "corkrog"
	end
end

function ArmT1VehCon()
		return "armcv"
end

function ArmStartT1VehCon()
	return (((Spring.GetGameSeconds() < 180) and "armcv") or ArmVehT1())
end

function ArmT1AirCon()
	local CountCons = UDC(ai.id, UDN.armca.id)
	if CountCons <= 4 then
		return "armca"
	else
		return "corkrog"
	end
end

function ArmFirstT2Mexes()
	if not ai.firstt2mexes then
		ai.firstt2mexes = 1
		return "armmoho"
	elseif ai.firstt2mexes and ai.firstt2mexes <= 3 then
		ai.firstt2mexes = ai.firstt2mexes + 1
		return "armmoho"
	else
		return "corkrog"
	end
end

function ArmFirstT1Mexes()
	if not ai.firstt1mexes then
		ai.firstt1mexes = 1
		return "armmex"
	elseif ai.firstt1mexes and ai.firstt1mexes <= 3 then
		ai.firstt1mexes = ai.firstt1mexes + 1
		return "armmex"
	else
		return "corkrog"
	end
end
--------------------------------------------------------------------------------------------
----------------------------------------- ArmTasks -----------------------------------------
--------------------------------------------------------------------------------------------

local armcommanderfirst = {
	"armmex",
	"armmex",
	"arm"..ThirdMex(),
	"arm"..WindOrSolar(),
	"arm"..WindOrSolar(),
	ArmStarterLabT1,
	"armllt",
	"arm"..WindOrSolar(),
	ArmStarterLabT1,
	--"armllt",
	"arm"..WindOrSolar(),
	"armrad",
	ArmStarterLabT1,
	--"armllt",
}

local armt1construction = {
	ArmRandomLab,
	ArmFirstT1Mexes,
	ArmFirstT1Mexes,
	ArmFirstT1Mexes,
	-- ArmLLT,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmNanoT,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	"armrad",
	ArmLLT,
	ArmLLT,
	ArmRandomLab,
	ArmNanoT,
	ArmNanoT,
	ArmNanoT,
	ArmGroundAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmLLT,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmNanoT,
	ArmLLT,
	ArmLLT,
	"armrad",
	ArmMexT1,
	ArmNanoT,
	"armmex",
	ArmLLT,
	ArmEnT1,
	ArmEnT1,
	ArmAirAdvDefT1,
	"armgeo",
}

local armt2construction = {
	ArmFirstT2Mexes,
	ArmFirstT2Mexes,
	ArmFirstT2Mexes,
	ArmTacticalAdvDefT2,
	ArmEnT2,
	ArmEnT2,
	ArmEnT2,
	"armarad",
	ArmTacticalAdvDefT2,
	ArmRandomLab,
	ArmTacticalOffDefT2,
	ArmAirAdvDefT2,
}

local armkbotlab = {
	ArmStartT1KbotCon,	-- 	Constructor
	ArmT1KbotCon,	-- 	Constructor
	ArmKBotsT1,
	ArmStartT1KbotCon,	-- 	Constructor
	ArmKBotsT1,
	ArmStartT1KbotCon,	-- 	Constructor
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmT1RezBot,
}

local armvehlab = {
	ArmStartT1VehCon,	--	Constructor
	ArmT1VehCon,	--	Constructor
	ArmVehT1,
	ArmVehT1,
	ArmStartT1VehCon,	--	Constructor
	ArmVehT1,
	ArmStartT1VehCon,	--	Constructor
	ArmVehT1,
	ArmVehT1,
}

local armairlab = {
	ArmT1AirCon,	--	Constructor
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
}

armkbotlabT2 = {
	"armack",
	"armfark",
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
}

armvehlabT2 = {
	"armacv",
	"armconsul",
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
}

armairlabT2 = {
	"armaca",
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
}

armhoverlabT2 = {
	"armch",
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
}
armgantryT3 = {
	ArmGantry,
}

assistqueue = {
	{ action = "patrolrelative", position = {x = 100, y = 0, z = 100} },
}

--------------------------------------------------------------------------------------------
-------------------------------------- ArmQueuePicker --------------------------------------
--------------------------------------------------------------------------------------------

local function armcommander()
	if ai.engineerfirst == true then
		--return armcommanderq
		return assistqueue
	else
		ai.engineerfirst = true
		return armcommanderfirst
	end
end

--local function armT1constructorrandommexer()
    --if ai.engineerfirst1 == true then
		--return armt1construction
    --else
        --ai.engineerfirst1 = true
		--return armT1ConFirst
    --end
--end

--------------------------------------------------------------------------------------------
---------------------------------------- TASKQUEUES ----------------------------------------
--------------------------------------------------------------------------------------------

taskqueues = {
	---CORE
	--constructors
	corcom = corcommander,
	corck = cort1construction,
	corcv = cort1construction,
	corca = cort1construction,
	corch = cort1construction,
	cornanotc = assistqueue,
	corack = cort2construction,
	coracv = cort2construction,
	coraca = cort2construction,
	-- ASSIST
	corfast = assistqueue,
	--factories
	corlab = corkbotlab,
	corvp = corvehlab,
	corap = corairlab,
	coralab = corkbotlabT2,
	coravp = corvehlabT2,
	coraap = corairlabT2,
	corhp = corhoverlabT2,
	corgant = corgantryT3,

	---ARM
	--constructors
	armcom = armcommander,
	armck = armt1construction,
	armcv = armt1construction,
	armca = armt1construction,
	armch = armt1construction,
	armnanotc = assistqueue,
	armack = armt2construction,
	armacv = armt2construction,
	armaca = armt2construction,
	--ASSIST
	armconsul = assistqueue,
	armfark = assistqueue,
	--factories
	armlab = armkbotlab,
	armvp = armvehlab,
	armap = armairlab,
	armalab = armkbotlabT2,
	armavp = armvehlabT2,
	armaap = armairlabT2,
	armhp = armhoverlabT2,
	armshltx = armgantryT3,
}
