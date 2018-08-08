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

---- RESOURCES RELATED ----
function curstorperc(ai, resource) -- Returns % of storage for resource in real time
	local c, s, p, i, e = Spring.GetTeamResources(ai.id, resource)
	return ((c / s) * 100)
end

function timetostore(ai, resource, amount) -- Returns time to gather necessary resource amount in real time
	local c, s, p, i, e = Spring.GetTeamResources(ai.id, resource)
	local income = (i-e > 0 and i-e) or 0.00001
	return (amount-c)/(income)
end

function income(ai, resource) -- Returns income of resource in realtime
	local c, s, p, i, e = Spring.GetTeamResources(ai.id, resource)
	return i
end

---- TECHTREE RELATED ----
function KbotOrVeh()
	local veh = 0
	local kbot = 0
	-- mapsize
	mapsize = Game.mapX * Game.mapY
	local randomnumber = math.random(1,mapsize+1)
	if randomnumber >= 100 then
		veh = veh + 1
	else
		kbot = kbot + 1
	end
	-- windAvg
	local avgWind = (Game.windMin + Game.windMax)/2
	randomnumber = math.random(0, math.floor(avgWind + 1))
	if randomnumber >= 5 then
		veh = veh + 1
	else
		kbot = kbot + 1
	end
	-- numberPlayers
	local teamList = Spring.GetTeamList()
	local nTeams = #teamList
	randomnumber = math.random(1, nTeams+1)
	if randomnumber <= 6 then
		veh = veh + 1
	else
		kbot = kbot + 1
	end
	-- Height diffs
	local min, max = Spring.GetGroundExtremes()
	local diff = max-min
	randomnumber = math.random(1, math.floor(diff+1))
	if randomnumber <= 100 then
		veh = veh + 1
	else
		kbot = kbot + 1
	end
	if kbot > veh then 
		return 'kbot'
	elseif veh > kbot then
		return 'veh'
	elseif math.random(1,2) == 2 then
		return 'veh'
	else
		return 'kbot'
	end
end


-- Useful Unit Counts

function GetAdvancedLabs(tqb,ai,unit)
	local list = {
	UDN.armalab.id,
	UDN.coralab.id,
	UDN.armavp.id,
	UDN.coravp.id,
	UDN.armaap.id,
	UDN.coraap.id,	
	UDN.armasy.id,
	UDN.corasy.id,
	}
	local units = Spring.GetTeamUnitsByDefs(ai.id, list)
	return #units
end

function GetFinishedAdvancedLabs(tqb,ai,unit)
	local list = {
	UDN.armalab.id,
	UDN.coralab.id,
	UDN.armavp.id,
	UDN.coravp.id,
	UDN.armaap.id,
	UDN.coraap.id,	
	UDN.armasy.id,
	UDN.corasy.id,
	}
	local units = Spring.GetTeamUnitsByDefs(ai.id, list)
	local count = 0
	for ct, unitID in pairs (units) do
		local _,_,_,_,bp = Spring.GetUnitHealth(unitID)
		if bp == 1 then
			count = count + 1
		end
	end
	return count
end

function GetPlannedAdvancedLabs(tqb, ai, unit)
	local list = {
	UDN.armalab.id,
	UDN.coralab.id,
	UDN.armavp.id,
	UDN.coravp.id,
	UDN.armaap.id,
	UDN.coraap.id,	
	UDN.armasy.id,
	UDN.corasy.id,
	}
	local total = 0
	for ct, unitDefID in pairs(list) do
		local planned = ai.newplacementhandler:GetExistingPlansByUnitDefID(unitDefID)
		for planID, plan in pairs(planned) do
			total = total + 1
		end
	end
	return total
end

function GetPlannedAndUnfinishedAdvancedLabs(tqb,ai,unit)
	local list = {
	UDN.armalab.id,
	UDN.coralab.id,
	UDN.armavp.id,
	UDN.coravp.id,
	UDN.armaap.id,
	UDN.coraap.id,	
	UDN.armasy.id,
	UDN.corasy.id,
	}
	local count = 0
	for ct, unitDefID in pairs(list) do
		count = count + UUDC(UnitDefs[unitDefID].name, ai.id)
	end
	count = count + GetPlannedAdvancedLabs(tqb, ai, unit)
	return count
end

function AllAdvancedLabs(tqb, ai, unit)
	return GetAdvancedLabs(tqb,ai,unit) + GetPlannedAdvancedLabs(tqb, ai, unit)
end
 

--- OTHERS

function FindBest(unitoptions,ai)
	if unitoptions and unitoptions[1] then
		local effect = {}
		local randomization = 1
		local randomunit = {}
		for n, unitName in pairs(unitoptions) do
			local cost = UnitDefs[UnitDefNames[unitName].id].energyCost / 60 + UnitDefs[UnitDefNames[unitName].id].metalCost
			local avgkilled_cost = GG.AiHelpers.UnitInfo(ai.id, UnitDefNames[unitName].id) and GG.AiHelpers.UnitInfo(ai.id, UnitDefNames[unitName].id).avgkilled_cost or 200 --start at 200 so that costly units aren't made from the start
			effect[unitName] = math.max(math.floor((avgkilled_cost/cost)^4*100),1)
			for i = randomization, randomization + effect[unitName] do
				randomunit[i] = unitName
			end
			randomization = randomization + effect[unitName]
		end
		if randomization < 1 then
			return {action = "nexttask"}
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

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------- Core Functions -------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

function CorWindOrSolar(tqb, ai, unit)
    local _,_,_,curWind = Spring.GetWind()
    local avgWind = (Game.windMin + Game.windMax)/2
	if ai and ai.id then
		if not (UDC(ai.id, UDN.armfus.id) + UDC(ai.id, UDN.corfus.id) > 1) then
			if curWind > 7 then
				return "corwin"
			else
				local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
				local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
				if ei > 200 and mi > 15 and (UUDC("armadvsol", ai.id) + UUDC("coradvsol", ai.id)) < 2 then
					return "coradvsol"
				else
					return "corsolar"
				end
			end
		else
			return {action = "nexttask"}	
		end
	else
		return "corsolar"
	end
end

function CorLLT(tqb, ai, unit)
	if Spring.GetGameSeconds() < 240 then
		return "corllt"
	elseif Spring.GetGameSeconds() < 480 then
		local unitoptions = {"corllt", "corhllt", "corhlt", "cormaw", "corrl"}
		return FindBest(unitoptions,ai)
	else
		local unitoptions = {"corllt", "corhllt", "corhlt", "cormaw", "corrl", "cormadsam", "corerad"}
		return FindBest(unitoptions,ai)
	end
end

function CorNanoT(tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	if not (countAdvBuilders >= 1) then
		if (UDC(ai.id, UDN.armnanotc.id) + UDC(ai.id, UDN.cornanotc.id)) < 4 and timetostore(ai, "energy", 5000) < 10 and timetostore(ai, "metal", 300) < 10 then
			return "cornanotc"
		else
			return {action = "nexttask"}
		end
	elseif timetostore(ai, "energy", 5000) < 10 and timetostore(ai, "metal", 300) < 10 then
		return "cornanotc"
	else
		return {action = "nexttask"}
	end
end

function CorEnT1( tqb, ai, unit )	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countEstore = UDC(ai.id, UDN.corestor.id) + UDC(ai.id, UDN.armestor.id)
	if (income(ai, "energy") < 750) and ei - ee < 0 and ec < 0.5 * es then
        return (CorWindOrSolar(tqb, ai, unit))
    elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") and ec > 0.3 * es then
        return "cormakr"
	elseif es < (ei * 8) and ec > (es * 0.8) and countEstore < (ei*8)/6000 then
		return "corestor"
	elseif ms < (mi * 8) or mc > (ms*0.9) then
		return "cormstor"
	else
		return {action = "nexttask"}
	end
end

function CorEcoT1( tqb, ai, unit )
-- c = current, s = storage, p = pull(?), i = income, e = expense (Ctrl C Ctrl V into functions)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if tqb.ai.map:AverageWind() > 7 and ec < es*0.10 then
		return "corwin"
	elseif tqb.ai.map:AverageWind() <= 7 and ec < es*0.10 then
		return "corsolar"
	elseif mc < ms*0.1 and ec > es*0.90 then
		return "cormakr"
	else
		return {action = "nexttask"}
	end
end


function CorEnT2( tqb, ai, unit )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ei > 800 and mi > 35 and (UUDC("armfus",ai.id) + UUDC("corfus",ai.id)) < 2 and ei - ee < 0 and ec < 0.8 * es  then
        return "corfus"
    elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") and ec > 0.3 * es then
        return "cormmkr"
	else
		return {action = "nexttask"}
	end
end

function CorMexT1( tqb, ai, unit )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms*0.1 then
		return "cormex"
	elseif mc < ms*0.3 then
		return "corexp"
	elseif ec < es*0.10 then
        return (CorWindOrSolar(tqb, ai, unit))
    elseif ei - Spring.GetTeamRulesParam(ai.id, "mmCapacity") > 0 then
        return "cormakr"
	else
		return {action = "nexttask"}
	end
end

function CorStarterLabT1(tqb, ai, unit)
	local countStarterFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id)
	if countStarterFacs < 1 then
		local labtype = KbotOrVeh()
		if labtype == "kbot" then
			return "corlab"
		else
			return "corvp"
		end
	else
		return {action = "nexttask"}
	end
end

function CorTech(tqb, ai, unit)
	if AllAdvancedLabs(tqb, ai, unit) == 0 then
		if timetostore(ai, "metal", 2500) < 75 and timetostore(ai, "energy", 8000) < 25 then
			if unit:Name() == "corck" then
				ai.firstT2 = true
				return "coralab"
			elseif unit:Name() == "corcv" then
				ai.firstT2 = true
				return "coravp"
			else 
				return {action = "nexttask"}
			end
		else
			return {action = "nexttask"}
		end
	else
		return {action = "nexttask"}
	end
end

function CorT1ExpandRandomLab(tqb, ai, unit)
	if GetFinishedAdvancedLabs(tqb, ai, unit) >= 1 then
		if timetostore(ai, "metal", 4000) < 25 and timetostore(ai, "energy", 12000) < 25 and GetPlannedAndUnfinishedAdvancedLabs(tqb,ai,unit) < 1 then
			if unit:Name() == "corck" or unit:Name() == "corack" then
				ai.firstT2 = true
				return "coralab"
			elseif unit:Name() == "corcv" or unit:Name() == "coracv" then
				ai.firstT2 = true
				return "coravp"
			elseif unit:Name() == "corca" or unit:Name() == "coraca" then
				ai.firstT2 = true
				return "coraap"
			else 
				return {action = "nexttask"}
			end
		elseif timetostore(ai, "metal", 1200) < 15 and timetostore(ai, "energy", 3000) < 25 and GetPlannedAndUnfinishedAdvancedLabs(tqb,ai,unit) < 1 then
			return FindBest({"corlab", "corvp", "corap"}, ai)
		else
			return {action = "nexttask"}
		end
	else
		return {action = "nexttask"}
	end
end

function CorGroundAdvDefT1(tqb, ai, unit)
	local r = math.random(0,100)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		if r == 0 and Spring.GetGameSeconds() > 600 then
			return "corpun"
		else
			local unitoptions = {"cormaw", "corhllt", "corhlt",}
			return FindBest(unitoptions,ai)
		end
	else
		return {action = "nexttask"}
	end
end

function CorAirAdvDefT1(tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"cormadsam", "corrl",}
		return FindBest(unitoptions,ai)
	else
		return {action = "nexttask"}
	end
end

function CorAirAdvDefT2(tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"corflak","corscreamer" }
		return FindBest(unitoptions,ai)
	else
		return {action = "nexttask"}
	end
end

function CorTacticalAdvDefT2(tqb, ai, unit)
	local unitoptions = {"corvipe","corflak"}
	return FindBest(unitoptions,ai)
end

function CorTacticalOffDefT2(tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		if  UDC(ai.id, UDN.corfmd.id) < 3 then
			return "corfmd"
		elseif 	 UDC(ai.id, UDN.corgate.id) < 6 then
			return "corgate"
		else
			return {action = "nexttask"}
		end
	else
		return {action = "nexttask"}
	end
end
	--local unitoptions = {"corfmd", "corsilo",}
	--return unitoptions[math.random(1,#unitoptions)]


function CorKBotsT1(tqb, ai, unit)
	local unitoptions = {"corak", "corthud", "corstorm", "cornecro", "corcrash",}
	return FindBest(unitoptions,ai)
end

function CorVehT1(tqb, ai, unit)
	local unitoptions = {"corfav", "corgator", "corraid", "corlevlr", "cormist", "corwolv", "corgarp",}
	return FindBest(unitoptions,ai)
end

function CorAirT1(tqb, ai, unit)
	local unitoptions = {"corveng", "corshad", "corbw", "corfink",}
	return FindBest(unitoptions,ai)
end

function CorKBotsT2(tqb, ai, unit)
	
	local unitoptions = {"coraak", "coramph", "corcan", "corhrk", "cormort", "corpyro", "corroach", "cortermite", "corspec", "corsumo",}
	return FindBest(unitoptions,ai)
end

function CorVehT2(tqb, ai, unit)
	if Spring.GetGameSeconds() < 1200 then
		local unitoptions = {"corban", "corgol", "cormart", "correap", "corsent",}
		return FindBest(unitoptions,ai)
	else
		local unitoptions = {"corban", "coreter", "corgol", "cormart", "corparrow", "correap", "corseal", "corsent", "cortrem", "corvroc",}
		return FindBest(unitoptions,ai)
	end
end

function CorAirT2(tqb, ai, unit)
	
	local unitoptions = {"corape", "corcrw", "corhurc", "corvamp",}
	return FindBest(unitoptions,ai)
end

function CorHover(tqb, ai, unit)
	
	local unitoptions = {"corah", "corch", "corhal", "cormh", "corsh", "corsnap","corsok",}
	return FindBest(unitoptions,ai)
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

function CorGantry(tqb, ai, unit)
	
	local unitoptions = {"corcat", "corjugg", "corkarg", "corkrog", "corshiva", }
	return FindBest(unitoptions,ai)
end 

--constructors:

function CorT1KbotCon(tqb, ai, unit)
	return "corck"
end

function CorStartT1KbotCon(tqb, ai, unit)
	return (((Spring.GetGameSeconds() < 180) and"corck") or CorKBotsT1(tqb, ai, unit))
end


function CorT1RezBot(tqb, ai, unit)
	local CountRez = UDC(ai.id, UDN.cornecro.id)
	if CountRez <= 10 then
		return "cornecro"
	else
		return {action = "nexttask"}
	end
end

function CorT1VehCon(tqb, ai, unit)
		return "corcv"
end

function CorStartT1VehCon(tqb, ai, unit)
	return (((Spring.GetGameSeconds() < 180) and"corcv") or CorVehT1(tqb, ai, unit))
	end

function CorT1AirCon(tqb, ai, unit)
	local CountCons = UDC(ai.id, UDN.corca.id)
	if CountCons <= 4 then
		return "corca"
	else
		return {action = "nexttask"}
	end
end

function CorFirstT2Mexes(tqb, ai, unit)
	if not ai.firstt2mexes then
		ai.firstt2mexes = 1
		return "cormoho"
	elseif ai.firstt2mexes and ai.firstt2mexes <= 3 then
		ai.firstt2mexes = ai.firstt2mexes + 1
		return "cormoho"
	else
		return {action = "nexttask"}
	end
end

function CorFirstT1Mexes(tqb, ai, unit)
	if not ai.firstt1mexes then
		ai.firstt1mexes = 1
		return "cormex"
	elseif ai.firstt1mexes and ai.firstt1mexes <= 3 then
		ai.firstt1mexes = ai.firstt1mexes + 1
		return "cormex"
	else
		return {action = "nexttask"}
	end
end

function CorThirdMex(tqb, ai, unit)
	if income(ai, "metal") < 5.5 then
		return 'cormex'
	else
		return {action = "nexttask"}
	end
end

--------------------------------------------------------------------------------------------
----------------------------------------- CoreTasks ----------------------------------------
--------------------------------------------------------------------------------------------

local corcommanderfirst = {
	"cormex",
	"cormex",
	CorThirdMex,
	CorWindOrSolar,
	CorWindOrSolar,
	CorStarterLabT1,
	CorWindOrSolar,
	CorWindOrSolar,
	"corllt",
	"corrad",
}

local cort1eco = {
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorNanoT,
	CorTech,
}

local cort1expand = {
	"cormex",
	CorLLT,
	"cormex",
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	CorLLT,
	"corrad",
	"corgeo",
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	CorNanoT,
	CorT1ExpandRandomLab,
}

local cort2eco = {
	CorEnT2,
	CorEnT2,
	CorEnT2,
}

local cort2expand = {
	"cormoho",
	"cormoho",
	CorTacticalAdvDefT2,
	"cormoho",
	"corarad",
	CorT1ExpandRandomLab,
}

local corkbotlab = {
	CorStartT1KbotCon,	-- 	Constructor/KBOT
	CorT1KbotCon,	-- 	Constructor
	CorKBotsT1,
	CorStartT1KbotCon,	-- 	Constructor/KBOT
	CorKBotsT1,
	CorStartT1KbotCon,	-- 	Constructor/KBOT
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorT1RezBot,
}

local corvehlab = {
	CorStartT1VehCon,	--	Constructor
	CorT1VehCon,	--	Constructor
	CorVehT1,
	CorVehT1,
	CorStartT1VehCon,	--	Constructor
	CorVehT1,
	CorStartT1VehCon,	--	Constructor
	CorVehT1,
	CorVehT1,
}

local corairlab = {
	CorT1AirCon,	--	Constructor
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
	"corack",
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
}

corvehlabT2 = {
	"coracv",
	CorVehT2,
	CorVehT2,
	CorVehT2,
	"coracv",
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

assistqueuepostt2arm = {
	ArmNanoT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
}

assistqueuepostt2core = {
	CorNanoT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },	
}

assistqueue = {
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
}

--------------------------------------------------------------------------------------------
-------------------------------------- CoreQueuePicker -------------------------------------
--------------------------------------------------------------------------------------------

local function corcommander(tqb, ai, unit)
	local countBasicFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id) + UDC(ai.id, UDN.corhp.id)
	if countBasicFacs > 0 then
	--return armcommanderq
		return assistqueue
	elseif ai.engineerfirst then
		return {"corlab"}
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

function ArmWindOrSolar(tqb, ai, unit)
    local _,_,_,curWind = Spring.GetWind()
    local avgWind = (Game.windMin + Game.windMax)/2
	if ai and ai.id then
		if not (UDC(ai.id, UDN.armfus.id) + UDC(ai.id, UDN.corfus.id) > 1) then
			if curWind > 7 then
				return "armwin"
			else
				local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
				local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
				if ei > 200 and mi > 15 and (UUDC("armadvsol", ai.id) + UUDC("coradvsol", ai.id)) < 2 then
					return "armadvsol"
				else
					return "armsolar"
				end
			end
		else
			return {action = "nexttask"}	
		end
	else
		return "armsolar"
	end
end

function ArmLLT(tqb, ai, unit)
	if Spring.GetGameSeconds() < 240 then
		return "armllt"
	elseif Spring.GetGameSeconds() < 480 then
		local unitoptions = {"armllt", "armbeamer", "armhlt", "armclaw", "armrl"}
		return FindBest(unitoptions,ai)
	else
		local unitoptions = {"armllt", "armbeamer", "armhlt", "armclaw", "armrl", "armpacko", "armcir"}
		return FindBest(unitoptions,ai)
	end
end

function ArmNanoT(tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countAdvBuilders = UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) + UDC(ai.id, UDN.armaca.id) + UDC(ai.id, UDN.corack.id) + UDC(ai.id, UDN.coracv.id) + UDC(ai.id, UDN.coraca.id)
	if not (countAdvBuilders >= 1) then
		if (UDC(ai.id, UDN.armnanotc.id) + UDC(ai.id, UDN.cornanotc.id)) < 4 and timetostore(ai, "energy", 5000) < 10 and timetostore(ai, "metal", 300) < 10 then
			return "armnanotc"
		else
			return {action = "nexttask"}
		end
	elseif timetostore(ai, "energy", 5000) < 10 and timetostore(ai, "metal", 300) < 10 then
		return "armnanotc"
	else
		return {action = "nexttask"}
	end
end


function ArmEnT1( tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countEstore = UDC(ai.id, UDN.corestor.id) + UDC(ai.id, UDN.armestor.id)
	if (income(ai, "energy") < 750) and ei - ee < 0 and ec < 0.8 * es then
		return (ArmWindOrSolar(tqb, ai, unit))
	elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") and ec > 0.3 * es then
		return "armmakr"
	elseif es < (ei * 8) and ec > (es * 0.8) and countEstore < (ei *8) / 6000 then
		return "armestor"
	elseif ms < (mi * 8) or mc > (ms*0.9) then
		return "armmstor"
	else
		return {action = "nexttask"}
	end
end

function ArmEcoT1( tqb, ai, unit )
-- c = current, s = storage, p = pull(?), i = income, e = expense (Ctrl C Ctrl V into functions)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if tqb.ai.map:AverageWind() > 7 and ec < es*0.10 then
		return "armwin"
	elseif tqb.ai.map:AverageWind() <= 7 and ec < es*0.10 then
		return "armsolar"
	elseif mc < ms*0.1 and ec > es*0.90 then
		return "armmakr"
	else
		return {action = "nexttask"}
	end
end



function ArmEnT2( tqb, ai, unit )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ei > 800 and mi > 35 and (UUDC("armfus",ai.id) + UUDC("corfus",ai.id)) < 2 and ei - ee < 0 and ec < 0.8 * es then
        return "armfus"
    elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") and ec > 0.3 * es then
        return "armmmkr"
	else
		return {action = "nexttask"}
	end
end

function ArmMexT1( tqb, ai, unit )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms - ms*0.8 then
		return "armmex"
	elseif ec < es*0.10 then
        return (ArmWindOrSolar(tqb, ai, unit))
    elseif ei - Spring.GetTeamRulesParam(ai.id, "mmCapacity") > 0 then
        return "armmakr"
	else
		return {action = "nexttask"}
	end
end

function ArmStarterLabT1(tqb, ai, unit)
	local countStarterFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id)
	if countStarterFacs < 1 then
		local labtype = KbotOrVeh()
		if labtype == "kbot" then
			return "armlab"
		else
			return "armvp"
		end
	else
		return {action = "nexttask"}
	end
end

function ArmTech(tqb, ai, unit)
	if AllAdvancedLabs(tqb, ai, unit) == 0 then
		if timetostore(ai, "metal", 2500) < 75 and timetostore(ai, "energy", 8000) < 25 then
			if unit:Name() == "armck" then
				ai.firstT2 = true
				return "armalab"
			elseif unit:Name() == "armcv" then
				ai.firstT2 = true
				return "armavp"
			else 
				return {action = "nexttask"}
			end
		else
			return {action = "nexttask"}
		end
	else
		return {action = "nexttask"}	
	end
end

function ArmT1ExpandRandomLab(tqb, ai, unit)
	if GetFinishedAdvancedLabs(tqb, ai, unit) >= 1 then
		if timetostore(ai, "metal", 4000) < 25 and timetostore(ai, "energy", 12000) < 25 and GetPlannedAndUnfinishedAdvancedLabs(tqb, ai, unit) < 1 then
			if unit:Name() == "armck" or unit:Name() == "armack" then
				ai.firstT2 = true
				return "armalab"
			elseif unit:Name() == "armcv" or unit:Name() == "armacv" then
				ai.firstT2 = true
				return "armavp"
			elseif unit:Name() == "armca" or unit:Name() == "armaca" then
				ai.firstT2 = true
				return "armaap"
			else 
				return {action = "nexttask"}
			end
		elseif timetostore(ai, "metal", 1200) < 15 and timetostore(ai, "energy", 3000) < 25 and GetPlannedAndUnfinishedAdvancedLabs(tqb, ai, unit) < 1 then
			return FindBest({"armlab", "armvp", "armap"}, ai)
		else
			return {action = "nexttask"}
		end
	else
		return {action = "nexttask"}
	end
end

function ArmGroundAdvDefT1(tqb, ai, unit)
	local r = math.random(0,100)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		if r == 0 and Spring.GetGameSeconds() > 600 then
			return "armguard"
		else
			local unitoptions = {"armclaw", "armbeamer","armhlt",}
			return FindBest(unitoptions,ai)
		end
	else
		return {action = "nexttask"}
	end
end

function ArmAirAdvDefT1(tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.1 and ec > es*0.1 then
		local unitoptions = {"armrl", "armpacko",}
		return FindBest(unitoptions,ai)
	else
		return {action = "nexttask"}
	end
end

function ArmAirAdvDefT2(tqb, ai, unit)
	local unitoptions = {"armmercury", "armflak",}
	return FindBest(unitoptions,ai)
end

function ArmTacticalAdvDefT2(tqb, ai, unit)
	local unitoptions = {"armpb","armflak"}
	return FindBest(unitoptions,ai)
end

function ArmTacticalOffDefT2(tqb, ai, unit)
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
		return {action = "nexttask"}
	end
end
	--local unitoptions = {"armamd", "armsilo",}
	--return FindBest(unitoptions,ai)

function ArmKBotsT1(tqb, ai, unit)
	local unitoptions = {"armpw", "armham", "armrectr", "armrock", "armwar", "armjeth",}
	return FindBest(unitoptions,ai)
end

function ArmVehT1(tqb, ai, unit)
	local unitoptions = {"armstump", "armjanus", "armsam", "armfav", "armflash", "armart", "armpincer",}
	return FindBest(unitoptions,ai)
end

function ArmAirT1(tqb, ai, unit)
	local unitoptions = {"armpeep", "armthund", "armfig", "armkam",}
	return FindBest(unitoptions,ai)
end	

function ArmKBotsT2(tqb, ai, unit)
	
	local unitoptions = {"armaak", "armamph", "armaser", "armfast", "armfboy", "armfido", "armmav", "armsnipe", "armspid", "armzeus", "armvader",}
	return FindBest(unitoptions,ai)
end

function ArmVehT2(tqb, ai, unit)
	if Spring.GetGameSeconds() < 1200 then
		local unitoptions = {"armbull", "armlatnk", "armmanni", "armmart", "armyork",}
		return FindBest(unitoptions,ai)
	else
		local unitoptions = {"armbull", "armcroc", "armlatnk", "armmanni", "armmart", "armmerl", "armst", "armyork",}
		return FindBest(unitoptions,ai)
	end
end

function ArmAirT2(tqb, ai, unit)
	
	local unitoptions = {"armblade", "armbrawl", "armhawk", "armliche", "armpnix", "armstil",}
	return FindBest(unitoptions,ai)
end

function ArmHover(tqb, ai, unit)
	
	local unitoptions = {"armah", "armanac", "armch", "armlun", "armmh", "armsh",}
	return FindBest(unitoptions,ai)
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

function ArmGantry(tqb, ai, unit)
	
	local unitoptions = {"armbanth", "armmar", "armraz", "armvang", }
	return FindBest(unitoptions,ai)
end

--constructors:

function ArmT1KbotCon(tqb, ai, unit)
	local CountCons = UDC(ai.id, UDN.armck.id)
	return "armck"
end

function ArmStartT1KbotCon(tqb, ai, unit)
	return (((Spring.GetGameSeconds() < 180) and "armck") or ArmKBotsT1(tqb,ai,unit))
end

function ArmT1RezBot(tqb, ai, unit)
	local CountRez = UDC(ai.id, UDN.armrectr.id)
	if CountRez <= 10 then
		return "armrectr"
	else
		return {action = "nexttask"}
	end
end

function ArmT1VehCon(tqb, ai, unit)
		return "armcv"
end

function ArmStartT1VehCon(tqb, ai, unit)
	return (((Spring.GetGameSeconds() < 180) and "armcv") or ArmVehT1(tqb, ai, unit))
end

function ArmT1AirCon(tqb, ai, unit)
	local CountCons = UDC(ai.id, UDN.armca.id)
	if CountCons <= 4 then
		return "armca"
	else
		return {action = "nexttask"}
	end
end

function ArmFirstT2Mexes(tqb, ai, unit)
	if not ai.firstt2mexes then
		ai.firstt2mexes = 1
		return "armmoho"
	elseif ai.firstt2mexes and ai.firstt2mexes <= 3 then
		ai.firstt2mexes = ai.firstt2mexes + 1
		return "armmoho"
	else
		return {action = "nexttask"}
	end
end

function ArmFirstT1Mexes(tqb, ai, unit)
	if not ai.firstt1mexes then
		ai.firstt1mexes = 1
		return "armmex"
	elseif ai.firstt1mexes and ai.firstt1mexes <= 3 then
		ai.firstt1mexes = ai.firstt1mexes + 1
		return "armmex"
	else
		return {action = "nexttask"}
	end
end

function ArmThirdMex(tqb, ai, unit)
	if income(ai, "metal") < 5.5 then
		return 'armmex'
	else
		return ArmWindOrSolar(tqb,ai,unit)
	end
end
--------------------------------------------------------------------------------------------
----------------------------------------- ArmTasks -----------------------------------------
--------------------------------------------------------------------------------------------

local armcommanderfirst = {
	"armmex",
	"armmex",
	ArmThirdMex,
	ArmWindOrSolar,
	ArmWindOrSolar,
	ArmStarterLabT1,
	ArmWindOrSolar,
	ArmWindOrSolar,
	"armllt",
	"armrad",
}

local armt1eco = {
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmNanoT,
	ArmTech,
}

local armt1expand = {
	"armmex",
	ArmLLT,
	"armmex",
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	ArmLLT,
	"armrad",
	"armgeo",
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	ArmNanoT,
	ArmT1ExpandRandomLab,
}

local armt2eco = {
	ArmEnT2,
	ArmEnT2,
	ArmEnT2,
}

local armt2expand = {
	"armmoho",
	"armmoho",
	ArmTacticalAdvDefT2,
	"armmoho",
	"armarad",
	ArmT1ExpandRandomLab,
}

local armkbotlab = {
	ArmStartT1KbotCon,	-- 	Constructor/KBOT
	ArmT1KbotCon,	-- 	Constructor
	ArmKBotsT1,
	ArmStartT1KbotCon,	-- 	Constructor/KBOT
	ArmKBotsT1,
	ArmStartT1KbotCon,	-- 	Constructor/KBOT
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
	"armack",
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
	"armacv",
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
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
}

--------------------------------------------------------------------------------------------
-------------------------------------- ArmQueuePicker --------------------------------------
--------------------------------------------------------------------------------------------

local function armcommander(tqb, ai, unit)
	local countBasicFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id) + UDC(ai.id, UDN.armhp.id)
	if countBasicFacs > 0 then
	--return armcommanderq
		return assistqueue
	elseif ai.engineerfirst then
		return {"armlab"}
	else
		ai.engineerfirst = true
		return armcommanderfirst
	end
end

local function armt1con(tqb, ai, unit)
	if not unit.mode then
		ai.t1concounter = (ai.t1concounter or 0) + 1
		if ai.t1concounter%10 == 8 or ai.t1concounter%10 == 9 then
			unit.mode = "assist"
		elseif ai.t1concounter%10 == 1 or ai.t1concounter%10 == 3 or ai.t1concounter%10 == 4 or ai.t1concounter%10 == 5 or ai.t1concounter%10 == 7 or ai.t1concounter%10 == 0 then
			unit.mode = "expand"
		else
			unit.mode = "eco"
		end
	end
	if unit.mode == "eco" then
		if income(ai, "energy") < 750 or AllAdvancedLabs(tqb, ai, unit) < 1 then
			return armt1eco
		else
			return armt1expand
		end
	elseif unit.mode == "expand" then
		return armt1expand
	elseif GetFinishedAdvancedLabs(tqb,ai,unit) >= 1 then
		return assistqueuepostt2arm	
	else
		return assistqueue
	end
	return assistqueue
end

local function cort1con(tqb, ai, unit)
	if not unit.mode then
		ai.t1concounter = (ai.t1concounter or 0) + 1
		if ai.t1concounter%10 == 8 or ai.t1concounter%10 == 9 then
			unit.mode = "assist"
		elseif ai.t1concounter%10 == 1 or ai.t1concounter%10 == 3 or ai.t1concounter%10 == 4 or ai.t1concounter%10 == 5 or ai.t1concounter%10 == 7 or ai.t1concounter%10 == 0 then
			unit.mode = "expand"
		else
			unit.mode = "eco"
		end
	end
	if unit.mode == "eco" then
		if income(ai, "energy") < 750 or AllAdvancedLabs(tqb, ai, unit) < 1 then
			return cort1eco
		else
			return cort1expand
		end
	elseif unit.mode == "expand" then
		return cort1expand
	elseif GetFinishedAdvancedLabs(tqb,ai,unit) >= 1 then
		return assistqueuepostt2core
	else
		return assistqueue
	end
	return assistqueue
end

local function armt2con(tqb, ai, unit)
	if not unit.mode then
		ai.t2concounter = (ai.t2concounter or 0) + 1
		if ai.t2concounter%10 == 8 or ai.t2concounter%10 == 9 then
			unit.mode = "assist"
		elseif ai.t2concounter%10 == 1 or ai.t2concounter%10 == 2 or ai.t2concounter%10 == 3 or ai.t2concounter%10 == 5 or ai.t2concounter%10 == 7 or ai.t2concounter%10 == 0 then
			unit.mode = "expand"
		else
			unit.mode = "eco"
		end
	end
	if unit.mode == "eco" then
		return armt2eco
	elseif unit.mode == "expand" then
		return armt2expand
	else
		return assistqueue
	end
	return assistqueue
end

local function cort2con(tqb, ai, unit)
	if not unit.mode then
		ai.t2concounter = (ai.t2concounter or 0) + 1
		if ai.t2concounter%10 == 8 or ai.t2concounter%10 == 9 then
			unit.mode = "assist"
		elseif ai.t2concounter%10 == 1 or ai.t2concounter%10 == 2 or ai.t2concounter%10 == 3 or ai.t2concounter%10 == 5 or ai.t2concounter%10 == 7 or ai.t2concounter%10 == 0 then
			unit.mode = "expand"
		else
			unit.mode = "eco"
		end
	end
	if unit.mode == "eco" then
		return cort2eco
	elseif unit.mode == "expand" then
		return cort2expand
	else
		return assistqueue
	end
	return assistqueue
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
	corck = cort1con,
	corcv = cort1con,
	corca = cort1con,
	corch = cort1con,
	cornanotc = assistqueue,
	corack = cort2con,
	coracv = cort2con,
	coraca = cort2con,
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
	armck = armt1con,
	armcv = armt1con,
	armca = armt1con,
	armch = armt1con,
	armnanotc = assistqueue,
	armack = armt2con,
	armacv = armt2con,
	armaca = armt2con,
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
