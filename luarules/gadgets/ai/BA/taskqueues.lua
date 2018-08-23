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
local skip = {action = "nexttask"}
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

function RequestedAction(tqb, ai, unit)
	return ai.requestshandler:GetRequestedTask(unit)
end

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

function GetLabs(tqb,ai,unit)
	local list = {
	UDN.armlab.id,
	UDN.corlab.id,
	UDN.armvp.id,
	UDN.corvp.id,
	UDN.armap.id,
	UDN.corap.id,	
	UDN.armsy.id,
	UDN.corsy.id,
	}
	local units = Spring.GetTeamUnitsByDefs(ai.id, list)
	return #units
end

function GetType(tqb,ai,unit,list)
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

function GetPlannedLabs(tqb, ai, unit)
	local list = {
	UDN.armalab.id,
	UDN.coralab.id,
	UDN.armavp.id,
	UDN.coravp.id,
	UDN.armaap.id,
	UDN.coraap.id,	
	UDN.armasy.id,
	UDN.corasy.id,
	UDN.armvp.id,
	UDN.corvp.id,
	UDN.armap.id,
	UDN.corap.id,
	UDN.armlab.id,
	UDN.corlab.id,
	UDN.armshltx.id,
	UDN.corgant.id,
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

function GetPlannedType(tqb, ai, unit,list)
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

function GetPlannedAndUnfinishedType(tqb,ai,unit,list)
	local count = 0
	for ct, unitDefID in pairs(list) do
		count = count + UUDC(UnitDefs[unitDefID].name, ai.id)
	end
	count = count + GetPlannedType(tqb, ai, unit,list)
	return count
end

function GetPlannedAndUnfinishedLabs(tqb,ai,unit)
	local list = {
	UDN.armalab.id,
	UDN.coralab.id,
	UDN.armavp.id,
	UDN.coravp.id,
	UDN.armaap.id,
	UDN.coraap.id,	
	UDN.armasy.id,
	UDN.corasy.id,
	UDN.armvp.id,
	UDN.corvp.id,
	UDN.armap.id,
	UDN.corap.id,
	UDN.armlab.id,
	UDN.corlab.id,
	UDN.armshltx.id,
	UDN.corgant.id,
	}
	local count = 0
	for ct, unitDefID in pairs(list) do
		count = count + UUDC(UnitDefs[unitDefID].name, ai.id)
	end
	count = count + GetPlannedLabs(tqb, ai, unit)
	return count
end

function AllAdvancedLabs(tqb, ai, unit)
	return GetAdvancedLabs(tqb,ai,unit) + GetPlannedAdvancedLabs(tqb, ai, unit)
end

function AllLabs(tqb, ai, unit)
	return GetLabs(tqb,ai,unit) + GetPlannedLabs(tqb, ai, unit)
end

function AllType(tqb, ai, unit, list)
	return GetType(tqb,ai,unit,list) + GetPlannedType(tqb, ai, unit, list)
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
			effect[unitName] = math.max(math.floor((avgkilled_cost/cost)^4*100),10)
			for i = randomization, randomization + effect[unitName] do
				randomunit[i] = unitName
			end
			randomization = randomization + effect[unitName]
		end
		if randomization < 1 then
			return skip
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
			return skip	
		end
	else
		return "corsolar"
	end
end

function CorLLT(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if hasTech2 then
		return skip
	end
	local unitoptions = {"corllt", "corhllt", "corhlt", "cormaw", "corrl", "cormadsam", "corerad"}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorNanoT(tqb, ai, unit)
	if timetostore(ai, "energy", 5000) < 40 and timetostore(ai, "metal", 300) < 40 and UDC(ai.id, UDN.armnanotc.id) + UDC(ai.id, UDN.cornanotc.id) < income(ai, "energy")/150 then
		return "cornanotc"
	else
		return skip
	end
end

function CorEnT1( tqb, ai, unit )	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countEstore = UDC(ai.id, UDN.corestor.id) + UDC(ai.id, UDN.armestor.id)
	if (income(ai, "energy") < ai.aimodehandler.eincomelimiterpretech2) and ei - ee < 0 and ec < 0.5 * es then
        return (CorWindOrSolar(tqb, ai, unit))
	elseif (income(ai, "energy") < ai.aimodehandler.eincomelimiterposttech2) and ei - ee < 0 and ec < 0.8 * es and GetFinishedAdvancedLabs(tqb, ai, unit) >= 1 then
		return (CorWindOrSolar(tqb, ai, unit))
    elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") and ec > 0.3 * es then
        return "cormakr"
	elseif es < (ei * 8) and ec > (es * 0.8) and countEstore < (ei*8)/6000 then
		return "corestor"
	elseif ms < (mi * 8) or mc > (ms*0.9) then
		return "cormstor"
	else
		return skip
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
		return skip
	end
end


function CorEnT2( tqb, ai, unit )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if es < ei * 10 and not (GetPlannedAndUnfinishedType(tqb,ai,unit, {UDN.coruwadves.id, UDN.armuwadves.id }) > 0) then
		return "coruwadves"
	elseif ms < mi * 5 and not (GetPlannedAndUnfinishedType(tqb,ai,unit, {UDN.coruwadvms.id, UDN.armuwadvms.id }) > 0)then
		return "coruwadvms"
	elseif ei > 6000 and mi > 100 and Spring.GetTeamRulesParam(ai.id, "mmCapacity") > income(ai, "energy")-3000 and income(ai, "energy") < ((math.max((Spring.GetGameSeconds() / 60) - 5, 1)/6) ^ 2) * 1000 and unit:Name() == "coracv" then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "corafus", pos = {x = x, y = y, z = z}}
		else
			return "corafus"
		end
	elseif ei > ai.aimodehandler.mintecheincome and mi > ai.aimodehandler.mintechmincome and Spring.GetTeamRulesParam(ai.id, "mmCapacity") > income(ai, "energy")-1200 and income(ai, "energy") < ((math.max((Spring.GetGameSeconds() / 60) - 5, 1)/6) ^ 2) * 1000 then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "corfus", pos = {x = x, y = y, z = z}}
		else
			return "corfus"
		end
	elseif ei > 6000 and mi > 100 and (UUDC("armafus",ai.id) + UUDC("corafus",ai.id)) < 2 and Spring.GetTeamRulesParam(ai.id, "mmCapacity") > income(ai, "energy")-3000 and timetostore(ai, "metal", UnitDefs[UnitDefNames["corafus"].id].metalCost) < 240 and unit:Name() == "coracv" then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "corafus", pos = {x = x, y = y, z = z}}
		else
			return "corafus"
		end
	elseif ei > ai.aimodehandler.mintecheincome and mi > ai.aimodehandler.mintechmincome and (UUDC("armfus",ai.id) + UUDC("corfus",ai.id)) < 2 and Spring.GetTeamRulesParam(ai.id, "mmCapacity") > income(ai, "energy")-1200 and timetostore(ai, "metal", UnitDefs[UnitDefNames["corfus"].id].metalCost) < 120 then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "corfus", pos = {x = x, y = y, z = z}}
		else
			return "corfus"
		end
    elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "cormmkr", pos = {x = x, y = y, z = z}}
		else
			return "cormmkr"
		end
	else
		return skip
	end
end

function CorMexT1( tqb, ai, unit )
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if hasTech2 then
		return skip
	end
	return "cormex"
end

function CorStarterLabT1(tqb, ai, unit)
	if ai.aimodehandler.t2rusht1reclaim == true and AllAdvancedLabs(tqb, ai, unit) > 0 then return RequestedAction(tqb,ai,unit) end
	local countStarterFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id)
	if countStarterFacs < 1 then
		local labtype = KbotOrVeh()
		if labtype == "kbot" then
			return "corlab"
		else
			return "corvp"
		end
	else
		return skip
	end
end

function CorTech(tqb, ai, unit)
	if AllAdvancedLabs(tqb, ai, unit) == 0 then
		if (income(ai, "metal") > ai.aimodehandler.mintechmincome and (income(ai, "energy") > ai.aimodehandler.mintecheincome)) or (timetostore(ai, "metal", 2500) < 75 and timetostore(ai, "energy", 8000) < 25) then
			if unit:Name() == "corck" then
				local pos = unit:GetPosition()
				ai.requestshandler:AddRequest(false, {action = "command", params = {cmdID = CMD.FIGHT, cmdParams = {pos.x, pos.y, pos.z}, cmdOptions = {"shift"}}}, true)
				ai.firstT2 = true
				return "coralab"
			elseif unit:Name() == "corcv" then
				local pos = unit:GetPosition()
				ai.requestshandler:AddRequest(false, {action = "command", params = {cmdID = CMD.FIGHT, cmdParams = {pos.x, pos.y, pos.z}, cmdOptions = {"shift"}}}, true)
				ai.firstT2 = true
				return "coravp"
			else 
				return skip
			end
		else
			return skip
		end
	else
		return skip
	end
end

function CorExpandRandomLab(tqb, ai, unit)
	local labtype = ai.aimodehandler:CorExpandRandomLab(tqb,ai,unit)
	if UnitDefNames[labtype] then
		local defs = UnitDefs[UnitDefNames[labtype].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 0  and AllAdvancedLabs(tqb,ai,unit) > 0 then
			labtype = labtype
		else
			labtype = skip
		end
	else
		labtype = skip
	end
	if labtype == skip then
		return labtype
	elseif GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
		local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
		return {action = labtype, pos = {x = x, y = y, z = z}}
	else
		return labtype
	end
end

function CorGroundAdvDefT1(tqb, ai, unit)
	local unitoptions = {"cormaw", "corhllt", "corhlt",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorAirAdvDefT1(tqb, ai, unit)
	local unitoptions = {"cormadsam", "corrl",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorAirAdvDefT2(tqb, ai, unit)
	local unitoptions = {"corflak","corscreamer" }
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorTacticalAdvDefT2(tqb, ai, unit)
	local unitoptions = {"corvipe","corflak", "cordoom", "corint", "corscreamer", "cortoast"}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		pos = unit:GetPosition()
		ai.requestshandler:AddRequest(false, {action = "fight", position = { x = pos.x, y = pos.y, z = pos.z}})
		return FindBest(list,ai)
	else
		return skip
	end
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
			return skip
		end
	else
		return skip
	end
end
	--local unitoptions = {"corfmd", "corsilo",}
	--return unitoptions[math.random(1,#unitoptions)]


function CorKBotsT1(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	local unitoptions = {"corak", "corthud", "corstorm", "cornecro", "corcrash",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorVehT1(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	local unitoptions = {"corfav", "corgator", "corraid", "corlevlr", "cormist", "corwolv", "corgarp",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorAirT1(tqb, ai, unit)
	local unitoptions = {"corveng", "corshad", "corbw", "corfink",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorKBotsT2(tqb, ai, unit)
	
	local unitoptions = {"coraak", "coramph", "corcan", "corhrk", "cormort", "corpyro", "corroach", "cortermite", "corspec", "corsumo",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorVehT2(tqb, ai, unit)
	local unitoptions = {"corban", "coreter", "corgol", "cormart", "corparrow", "correap", "corseal", "corsent", "cortrem", "corvroc",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorAirT2(tqb, ai, unit)
	local unitoptions = {"corape", "corcrw", "corhurc", "corvamp",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function CorHover(tqb, ai, unit)
	local unitoptions = {"corah", "corch", "corhal", "cormh", "corsh", "corsnap","corsok",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
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
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

--constructors:

function CorT1KbotCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["corck"].id].metalCost) < UnitDefs[UnitDefNames["corck"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["corck"].id].energyCost) < UnitDefs[UnitDefNames["corck"].id].buildTime/100 then
		return "corck"
	else
		return skip
	end
end

function CorStartT1KbotCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	return (((Spring.GetGameSeconds() < 180) and"corck") or CorKBotsT1(tqb, ai, unit))
end


function CorT1RezBot(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["cornecro"].id].metalCost) < UnitDefs[UnitDefNames["cornecro"].id].buildTime/100 then
		return "cornecro"
	else
		return skip
	end
end

function CorT1VehCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["corcv"].id].metalCost) < UnitDefs[UnitDefNames["corcv"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["corcv"].id].energyCost) < UnitDefs[UnitDefNames["corcv"].id].buildTime/100 then
		return "corcv"
	else
		return skip
	end
end

function CorConVehT2(tqb, ai, unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["coracv"].id].metalCost) < UnitDefs[UnitDefNames["coracv"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["coracv"].id].energyCost) < UnitDefs[UnitDefNames["coracv"].id].buildTime/100 then
		return "coracv"
	else
		return skip
	end
end

function CorConKBotT2(tqb, ai, unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["corack"].id].metalCost) < UnitDefs[UnitDefNames["corack"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["corack"].id].energyCost) < UnitDefs[UnitDefNames["corack"].id].buildTime/100 then
		return "corack"
	else
		return skip
	end
end

function CorStartT2KbotCon(tqb, ai, unit)
	local pos = unit:GetPosition()
	return (((UDC(ai.id, UDN.corack.id) < 5) and"corack") or CorKBotsT2(tqb, ai, unit))
end

function CorStartT2VehCon(tqb, ai, unit)
	local pos = unit:GetPosition()
	return (((UDC(ai.id, UDN.coracv.id) < 5) and"coracv") or CorVehT2(tqb, ai, unit))
end

function CorStartT1VehCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	return (((Spring.GetGameSeconds() < 180) and"corcv") or CorVehT1(tqb, ai, unit))
	end

function CorT1AirCon(tqb, ai, unit)
	local CountCons = UDC(ai.id, UDN.corca.id)
	if CountCons <= 4 then
		return "corca"
	else
		return skip
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
		return skip
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
		return skip
	end
end

function CorThirdMex(tqb, ai, unit)
	if income(ai, "metal") < 5.5 then
		return 'cormex'
	else
		return skip
	end
end

function fast(tqb,ai,unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["corfast"].id].metalCost) < UnitDefs[UnitDefNames["corfast"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["corfast"].id].energyCost) < UnitDefs[UnitDefNames["corfast"].id].buildTime/100 then
		return "corfast"
	else
		return skip
	end
end

function CorVehT2RushOffense(tqb,ai,unit)
	ai.t2rushoff = ai.t2rushoff or 0
	ai.t2rushoff = ai.t2rushoff + 1
	if ai.t2rushoff <= 2 then
		local unitoptions = {"corgol","corban","correap"}
		return FindBest(unitoptions,ai)
	else
		return CorVehT2(tqb,ai,unit)
	end
end

function CorKBotsT2RushOffense(tqb,ai,unit)
	ai.t2rushoff = ai.t2rushoff or 0
	ai.t2rushoff = ai.t2rushoff + 1
	if ai.t2rushoff <= 2 then
		local unitoptions = {"corsumo","corcan"}
		return FindBest(unitoptions,ai)
	else
		return CorKBotsT2(tqb,ai,unit)
	end
end

function CorGeo(tqb,ai,unit)
	if income(ai, "metal") < 20 then
		return skip
	else
		return "corgeo"
	end
end

function CorRad(tqb,ai,unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if hasTech2 then
		return skip
	end
	local pos = unit:GetPosition()
	for ct, unitID in pairs (Spring.GetUnitsInCylinder(pos.x, pos.z, UnitDefs[UDN.armrad.id].radarRadius, ai.id)) do
		local defID = Spring.GetUnitDefID(unitID)
		if defID == UDN.armrad.id or defID == UDN.corrad.id then
			return skip
		end
	end
	for ct, unitID in pairs (Spring.GetUnitsInCylinder(pos.x, pos.z, UnitDefs[UDN.armarad.id].radarRadius, ai.id)) do
		local defID = Spring.GetUnitDefID(unitID)
		if defID == UDN.armarad.id or defID == UDN.corarad.id then
			return skip
		end
	end
	return "corrad"
end

function CorARad(tqb,ai,unit)
	local pos = unit:GetPosition()
	for ct, unitID in pairs (Spring.GetUnitsInCylinder(pos.x, pos.z, UnitDefs[UDN.armarad.id].radarRadius, ai.id)) do
		local defID = Spring.GetUnitDefID(unitID)
		if defID == UDN.armarad.id or defID == UDN.corarad.id or defID == UDN.corrad.id or defID == UDN.armrad.id then
			return skip
		end
	end
	return "corarad"
end
--------------------------------------------------------------------------------------------
----------------------------------------- CoreTasks ----------------------------------------
--------------------------------------------------------------------------------------------

local corcommanderfirst = {
	CorMexT1,
	CorMexT1,
	CorThirdMex,
	CorWindOrSolar,
	CorWindOrSolar,
	CorStarterLabT1,
	CorWindOrSolar,
	CorWindOrSolar,
	"corllt",
	CorRad,
}

local cort1eco = {
	CorEnT1,
	CorNanoT,
	CorTech,
	CorEnT1,
	CorNanoT,
	CorTech,
	CorEnT1,
	CorNanoT,
	CorTech,
	CorNanoT,
	CorTech,
}

local cort1expand = {
	CorNanoT,
	CorExpandRandomLab,
	-- CorLLT,
	CorMexT1,
	CorExpandRandomLab,
	CorLLT,
	CorMexT1,
	CorExpandRandomLab,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	CorLLT,
	CorRad,
	CorExpandRandomLab,
	CorGeo,
	CorLLT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	CorNanoT,
	CorExpandRandomLab,
	-- CorLLT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	CorNanoT,
}

local cort2eco = {
	CorEnT2,
	CorEnT2,
	CorEnT2,
	CorExpandRandomLab,
}

local cort2expand = {
	"cormoho",
	CorTacticalAdvDefT2,
	"cormoho",
	CorTacticalAdvDefT2,
	CorExpandRandomLab,
	"cormoho",
	CorARad,
	CorExpandRandomLab,
	CorTacticalAdvDefT2,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },

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
	CorStartT2KbotCon,
	CorKBotsT2RushOffense,
	fast,
	CorStartT2KbotCon,
	CorStartT2KbotCon,
	CorKBotsT2RushOffense,
	CorKBotsT2,
	CorConKbotT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
}

corvehlabT2 = {
	CorStartT2VehCon,
	CorVehT2RushOffense,
	CorStartT2VehCon,
	CorStartT2VehCon,
	CorVehT2RushOffense,
	CorVehT2,
	CorConVehT,
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
	ArmExpandRandomLab,
	ArmNanoT,
	RequestedAction,
}

assistqueuepostt2core = {
	CorNanoT,
	CorExpandRandomLab,
	CorNanoT,
	RequestedAction,
}

assistqueue = {
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	RequestedAction,
}

corassistqueue = {
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	RequestedAction,
	CorExpandRandomLab,
}

armassistqueue = {
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	RequestedAction,
	ArmExpandRandomLab,
}

assistqueuepatrol = {
	{ action = "patrolrelative", position = {x = 100, y = 0, z = 100} },
}

assistqueuefreaker = {
	CorNanoT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },	
	RequestedAction,
}

assistqueueconsul = {
	ArmNanoT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },	
	RequestedAction,
}
--------------------------------------------------------------------------------------------
-------------------------------------- CoreQueuePicker -------------------------------------
--------------------------------------------------------------------------------------------

local function corcommander(tqb, ai, unit)
	ai.t1priorityrate = ai.t1priorityrate or ai.aimodehandler.t1ratepret2
	local countBasicFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id) + UDC(ai.id, UDN.corhp.id)
	if AllLabs(tqb,ai,unit) > 0 then
	--return armcommanderq
		return corassistqueue
	elseif ai.engineerfirst then
		return {CorStarterLabT1}
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
			return skip	
		end
	else
		return "armsolar"
	end
end

function ArmLLT(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if hasTech2 then
		return skip
	end
	local unitoptions = {"armllt", "armbeamer", "armhlt", "armclaw", "armrl", "armpacko", "armcir"}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmNanoT(tqb, ai, unit)
	if timetostore(ai, "energy", 5000) < 40 and timetostore(ai, "metal", 300) < 40 and UDC(ai.id, UDN.armnanotc.id) + UDC(ai.id, UDN.cornanotc.id) < income(ai, "energy")/150 then
		return "armnanotc"
	else
		return skip
	end
end


function ArmEnT1( tqb, ai, unit)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local countEstore = UDC(ai.id, UDN.corestor.id) + UDC(ai.id, UDN.armestor.id)
	if (income(ai, "energy") < ai.aimodehandler.eincomelimiterpretech2) and ei - ee < 0 and ec < 0.8 * es then
		return (ArmWindOrSolar(tqb, ai, unit))
	elseif (income(ai, "energy") < ai.aimodehandler.eincomelimiterposttech2) and ei - ee < 0 and ec < 0.8 * es and GetFinishedAdvancedLabs(tqb, ai, unit) >= 1 then
		return (ArmWindOrSolar(tqb, ai, unit))
	elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") and ec > 0.3 * es then
		return "armmakr"
	elseif es < (ei * 8) and ec > (es * 0.8) and countEstore < (ei *8) / 6000 then
		return "armestor"
	elseif ms < (mi * 8) or mc > (ms*0.9) then
		return "armmstor"
	else
		return skip
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
		return skip
	end
end



function ArmEnT2( tqb, ai, unit )
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if es < ei * 10 and not (GetPlannedAndUnfinishedType(tqb,ai,unit, {UDN.coruwadves.id, UDN.armuwadves.id }) > 0)then
		return "armuwadves"
	elseif ms < mi * 5 and not (GetPlannedAndUnfinishedType(tqb,ai,unit, {UDN.coruwadvms.id, UDN.armuwadvms.id }) > 0)then
		return "armuwadvms"
	elseif ei > 6000 and mi > 100 and Spring.GetTeamRulesParam(ai.id, "mmCapacity") > income(ai, "energy")-3000 and income(ai, "energy") < ((math.max((Spring.GetGameSeconds() / 60) - 5, 1)/6) ^ 2) * 1000 and unit:Name() == "armacv" then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "armafus", pos = {x = x, y = y, z = z}}
		else
			return "armafus"
		end
	elseif ei > ai.aimodehandler.mintecheincome and mi > ai.aimodehandler.mintechmincome and Spring.GetTeamRulesParam(ai.id, "mmCapacity") > income(ai, "energy")-1200 and income(ai, "energy") < ((math.max((Spring.GetGameSeconds() / 60) - 5, 1)/6) ^ 2) * 1000 then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "armfus", pos = {x = x, y = y, z = z}}
		else
			return "armfus"
		end
	elseif ei > 6000 and mi > 100 and (UUDC("armafus",ai.id) + UUDC("corafus",ai.id)) < 2 and Spring.GetTeamRulesParam(ai.id, "mmCapacity") > income(ai, "energy")-3000 and timetostore(ai, "metal", UnitDefs[UnitDefNames["armafus"].id].metalCost) < 240 and unit:Name() == "armacv" then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "armafus", pos = {x = x, y = y, z = z}}
		else
			return "armafus"
		end
    elseif Spring.GetTeamRulesParam(ai.id, "mmCapacity") < income(ai, "energy") then
       	if GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
			local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
			return {action = "armmmkr", pos = {x = x, y = y, z = z}}
		else
			return "armmmkr"
		end
	else
		return skip
	end
end

function ArmMexT1( tqb, ai, unit )
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if hasTech2 then
		return skip
	end
	return "armmex"
end

function ArmStarterLabT1(tqb, ai, unit)
	if ai.aimodehandler.t2rusht1reclaim == true and AllAdvancedLabs(tqb, ai, unit) > 0 then return RequestedAction(tqb, ai, unit) end
	local countStarterFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id)
	if countStarterFacs < 1 then
		local labtype = KbotOrVeh()
		if labtype == "kbot" then
			return "armlab"
		else
			return "armvp"
		end
	else
		return skip
	end
end

function ArmTech(tqb, ai, unit)
	if AllAdvancedLabs(tqb, ai, unit) == 0 then
		if (income(ai, "metal") > ai.aimodehandler.mintechmincome and (income(ai, "energy") > ai.aimodehandler.mintecheincome)) or (timetostore(ai, "metal", 2500) < 75 and timetostore(ai, "energy", 8000) < 25) then
			if unit:Name() == "armck" then
				local pos = unit:GetPosition()
				ai.requestshandler:AddRequest(false, {action = "command", params = {cmdID = CMD.FIGHT, cmdParams = {pos.x, pos.y, pos.z}, cmdOptions = {"shift"}}}, true)
				ai.firstT2 = true
				return "armalab"
			elseif unit:Name() == "armcv" then
				local pos = unit:GetPosition()
				ai.requestshandler:AddRequest(false, {action = "command", params = {cmdID = CMD.FIGHT, cmdParams = {pos.x, pos.y, pos.z}, cmdOptions = {"shift"}}}, true)
				ai.firstT2 = true
				return "armavp"
			else 
				return skip
			end
		else
			return skip
		end
	else
		return skip	
	end
end


function ArmExpandRandomLab(tqb, ai, unit)
	local labtype = ai.aimodehandler:ArmExpandRandomLab(tqb,ai,unit)
	if UnitDefNames[labtype] then
		local defs = UnitDefs[UnitDefNames[labtype].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 0 and AllAdvancedLabs(tqb,ai,unit) > 0 then
			labtype = labtype
		else
			labtype = skip
		end
	else
		labtype = skip
	end
	if labtype == skip then
		return labtype
	elseif GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id) then
		local x, y, z = GG.AiHelpers.NanoTC.GetClosestNanoTC(unit.id)
		return {action = labtype, pos = {x = x, y = y, z = z}}
	else
		return labtype
	end
end


function ArmGroundAdvDefT1(tqb, ai, unit)
	local unitoptions = {"armclaw", "armbeamer","armhlt",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmAirAdvDefT1(tqb, ai, unit)
	local unitoptions = {"armrl", "armpacko",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmAirAdvDefT2(tqb, ai, unit)
	local unitoptions = {"armmercury", "armflak",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmTacticalAdvDefT2(tqb, ai, unit)
	local unitoptions = {"armpb","armflak", "armamb", "armmercury", "armbrtha", "armanni"}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		pos = unit:GetPosition()
		ai.requestshandler:AddRequest(false, {action = "fight", position = { x = pos.x, y = pos.y, z = pos.z}})
		return FindBest(list,ai)
	else
		return skip
	end
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
			return skip
		end
	else
		return skip
	end
end
	--local unitoptions = {"armamd", "armsilo",}
	--return FindBest(unitoptions,ai)

function ArmKBotsT1(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	local unitoptions = {"armpw", "armham", "armrectr", "armrock", "armwar", "armjeth",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmVehT1(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	local unitoptions = {"armstump", "armjanus", "armsam", "armfav", "armflash", "armart", "armpincer",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmAirT1(tqb, ai, unit)
	local unitoptions = {"armpeep", "armthund", "armfig", "armkam",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate and timetostore(ai, "energy", defs.energyCost) < (defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed)*ai.t1priorityrate then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmKBotsT2(tqb, ai, unit)
	
	local unitoptions = {"armaak", "armamph", "armaser", "armfast", "armfboy", "armfido", "armmav", "armsnipe", "armspid", "armzeus", "armvader",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmVehT2(tqb, ai, unit)
	local unitoptions = {"armbull", "armcroc", "armlatnk", "armmanni", "armmart", "armmerl", "armst", "armyork",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmAirT2(tqb, ai, unit)
	local unitoptions = {"armblade", "armbrawl", "armhawk", "armliche", "armpnix", "armstil",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

function ArmHover(tqb, ai, unit)	
	local unitoptions = {"armah", "armanac", "armch", "armlun", "armmh", "armsh",}
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
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
	local list = {}
	local count = 0
	for ct, unitName in pairs(unitoptions) do
		local defs = UnitDefs[UnitDefNames[unitName].id]
		if timetostore(ai, "metal", defs.metalCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed and timetostore(ai, "energy", defs.energyCost) < defs.buildTime/UnitDefs[UnitDefNames[unit:Name()].id].buildSpeed then
			count = count + 1
			list[count] = unitName
		end
	end
	if list[1] then
		return FindBest(list,ai)
	else
		return skip
	end
end

--constructors:

function ArmT1KbotCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armck"].id].metalCost) < UnitDefs[UnitDefNames["armck"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["armck"].id].energyCost) < UnitDefs[UnitDefNames["armck"].id].buildTime/100 then
		return "armck"
	else
		return skip
	end
end

function ArmStartT1KbotCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	return (((Spring.GetGameSeconds() < 180) and "armck") or ArmKBotsT1(tqb,ai,unit))
end

function ArmT1RezBot(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armrectr"].id].metalCost) < UnitDefs[UnitDefNames["armrectr"].id].buildTime/100 then
		return "armrectr"
	else
		return skip
	end
end

function ArmT1VehCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armcv"].id].metalCost) < UnitDefs[UnitDefNames["armcv"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["armcv"].id].energyCost) < UnitDefs[UnitDefNames["armcv"].id].buildTime/100 then
		return "armcv"
	else
		return skip
	end
end

function ArmStartT1VehCon(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if ai.aimodehandler.t2rusht1reclaim == true and GetPlannedAndUnfinishedLabs(tqb, ai, unit) == 1 and not hasTech2 then
		ai.requestshandler:AddRequest(true, {action = "command", params = {cmdID = CMD.INSERT, cmdParams = {1, CMD.RECLAIM, CMD.OPT_SHIFT, unit.id}, cmdOptions = {"alt"} }},true)
		return {action = "wait", frames = "infinite"}
	end
	return (((Spring.GetGameSeconds() < 180) and "armcv") or ArmVehT1(tqb, ai, unit))
end

function ArmT1AirCon(tqb, ai, unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armca"].id].metalCost) < UnitDefs[UnitDefNames["armca"].id].buildTime/100 then
		return "armca"
	else
		return skip
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
		return skip
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
		return skip
	end
end

function ArmThirdMex(tqb, ai, unit)
	if income(ai, "metal") < 5.5 then
		return 'armmex'
	else
		return ArmWindOrSolar(tqb,ai,unit)
	end
end

function ArmConVehT2(tqb, ai, unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armacv"].id].metalCost) < UnitDefs[UnitDefNames["armacv"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["armacv"].id].energyCost) < UnitDefs[UnitDefNames["armacv"].id].buildTime/100 then
		return "armacv"
	else
		return skip
	end
end

function ArmConKBotT2(tqb, ai, unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armack"].id].metalCost) < UnitDefs[UnitDefNames["armack"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["armack"].id].energyCost) < UnitDefs[UnitDefNames["armack"].id].buildTime/100 then
		return "armack"
	else
		return skip
	end
end

function ArmStartT2KbotCon(tqb, ai, unit)
	local pos = unit:GetPosition()
	return (((UDC(ai.id, UDN.armack.id) < 5) and"armack") or ArmKBotsT2(tqb, ai, unit))
end

function ArmStartT2VehCon(tqb, ai, unit)
	local pos = unit:GetPosition()
	return (((UDC(ai.id, UDN.armacv.id) < 5) and"armacv") or ArmVehT2(tqb, ai, unit))
end

function fark(tqb,ai,unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armfark"].id].metalCost) < UnitDefs[UnitDefNames["armfark"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["armfark"].id].energyCost) < UnitDefs[UnitDefNames["armfark"].id].buildTime/100 then
		return "armfark"
	else
		return skip
	end
end

function consul(tqb,ai,unit)
	if timetostore(ai, "metal", UnitDefs[UnitDefNames["armconsul"].id].metalCost) < UnitDefs[UnitDefNames["armconsul"].id].buildTime/100 and timetostore(ai, "energy", UnitDefs[UnitDefNames["armconsul"].id].energyCost) < UnitDefs[UnitDefNames["armconsul"].id].buildTime/100 then
		return "armconsul"
	else
		return skip
	end
end

function ArmVehT2RushOffense(tqb,ai,unit)
	ai.t2rushoff = ai.t2rushoff or 0
	ai.t2rushoff = ai.t2rushoff + 1
	if ai.t2rushoff <= 2 then
		local unitoptions = {"armbull","armmanni"}
		return FindBest(unitoptions,ai)
	else
		return ArmVehT2(tqb,ai,unit)
	end
end

function ArmKBotsT2RushOffense(tqb,ai,unit)
	ai.t2rushoff = ai.t2rushoff or 0
	ai.t2rushoff = ai.t2rushoff + 1
	if ai.t2rushoff <= 2 then
		local unitoptions = {"armmav","armfido", "armfboy"}
		return FindBest(unitoptions,ai)
	else
		return ArmKBotsT2(tqb,ai,unit)
	end
end

function ArmGeo(tqb,ai,unit)
	if income(ai, "metal") < 20 then
		return skip
	else
		return "armgeo"
	end
end

function ArmRad(tqb,ai,unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
	if hasTech2 then
		return skip
	end
	local pos = unit:GetPosition()
	for ct, unitID in pairs (Spring.GetUnitsInCylinder(pos.x, pos.z, UnitDefs[UDN.armrad.id].radarRadius, ai.id)) do
		local defID = Spring.GetUnitDefID(unitID)
		if defID == UDN.armrad.id or defID == UDN.corrad.id then
			return skip
		end
	end
	for ct, unitID in pairs (Spring.GetUnitsInCylinder(pos.x, pos.z, UnitDefs[UDN.armarad.id].radarRadius, ai.id)) do
		local defID = Spring.GetUnitDefID(unitID)
		if defID == UDN.armarad.id or defID == UDN.corarad.id then
			return skip
		end
	end
	return "armrad"
end

function ArmARad(tqb,ai,unit)
	local pos = unit:GetPosition()
	for ct, unitID in pairs (Spring.GetUnitsInCylinder(pos.x, pos.z, UnitDefs[UDN.armarad.id].radarRadius, ai.id)) do
		local defID = Spring.GetUnitDefID(unitID)
		if defID == UDN.armarad.id or defID == UDN.corarad.id or defID == UDN.armrad.id or defID == UDN.corrad.id then
			return skip
		end
	end
	return "armarad"
end
--------------------------------------------------------------------------------------------
----------------------------------------- ArmTasks -----------------------------------------
--------------------------------------------------------------------------------------------

local armcommanderfirst = {
	ArmMexT1,
	ArmMexT1,
	ArmThirdMex,
	ArmWindOrSolar,
	ArmWindOrSolar,
	ArmStarterLabT1,
	ArmWindOrSolar,
	ArmWindOrSolar,
	"armllt",
	ArmRad,
}

local armt1eco = {
	ArmEnT1,
	ArmNanoT,
	ArmTech,
	ArmEnT1,
	ArmNanoT,
	ArmTech,
	ArmEnT1,
	ArmNanoT,
	ArmTech,
	ArmNanoT,
	ArmTech,
}

local armt1expand = {
	ArmNanoT,
	ArmExpandRandomLab,
	-- ArmLLT,
	ArmMexT1,
	ArmExpandRandomLab,
	ArmLLT,
	ArmMexT1,
	ArmExpandRandomLab,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	ArmLLT,
	ArmRad,
	ArmExpandRandomLab,
	ArmGeo,
	-- ArmLLT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	ArmNanoT,
	ArmExpandRandomLab,
	ArmLLT,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
	ArmNanoT,
}

local armt2eco = {
	ArmEnT2,
	ArmEnT2,
	ArmEnT2,
	ArmExpandRandomLab,
}

local armt2expand = {
	"armmoho",
	ArmTacticalAdvDefT2,
	"armmoho",
	ArmExpandRandomLab,
	ArmTacticalAdvDefT2,
	"armmoho",
	ArmARad,
	ArmExpandRandomLab,
	ArmTacticalAdvDefT2,
	{ action = "fightrelative", position = {x = 0, y = 0, z = 0} },
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
	ArmStartT2KbotCon,
	ArmKBotsT2RushOffense,
	fark,
	ArmStartT2KbotCon,
	ArmStartT2KbotCon,
	ArmKBotsT2RushOffense,
	ArmConKBotT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
}

armvehlabT2 = {
	ArmStartT2VehCon,
	ArmVehT2RushOffense,
	consul,
	ArmStartT2VehCon,
	ArmStartT2VehCon,
	ArmVehT2RushOffense,
	ArmConVehT2,
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

--------------------------------------------------------------------------------------------
-------------------------------------- ArmQueuePicker --------------------------------------
--------------------------------------------------------------------------------------------

local function armcommander(tqb, ai, unit)
	ai.t1priorityrate = ai.t1priorityrate or ai.aimodehandler.t1ratepret2
	local countBasicFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id) + UDC(ai.id, UDN.armhp.id)
	if AllLabs(tqb,ai,unit) > 0 then
	--return armcommanderq
		return armassistqueue
	elseif ai.engineerfirst then
		return {ArmStarterLabT1}
	else
		ai.engineerfirst = true
		return armcommanderfirst
	end
end

local function armt1con(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
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
		if (income(ai, "energy") < ai.aimodehandler.eincomelimiterpretech2 or AllAdvancedLabs(tqb, ai, unit) < 1) then
			ai.t1priorityrate = ai.aimodehandler.t1ratepret2
			return armt1eco
		else
		ai.t1priorityrate = ai.aimodehandler.t1ratepostt2
			return armt1expand
		end
	elseif unit.mode == "expand" and (not hasTech2) then
		return armt1expand
	elseif GetFinishedAdvancedLabs(tqb,ai,unit) >= 1 then
		return assistqueuepostt2arm	
	else
		return assistqueue
	end
	return assistqueue
end

local function cort1con(tqb, ai, unit)
	local hasTech2 = (UDC(ai.id, UDN.armack.id) + UDC(ai.id, UDN.armacv.id) +UDC(ai.id, UDN.armaca.id) +UDC(ai.id, UDN.corack.id) +UDC(ai.id, UDN.coracv.id) +UDC(ai.id, UDN.coraca.id)) >= ai.aimodehandler.mint2countpauset1
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
		if (income(ai, "energy") < ai.aimodehandler.eincomelimiterpretech2 or AllAdvancedLabs(tqb, ai, unit) < 1) then
			ai.t1priorityrate = ai.aimodehandler.t1ratepret2
			return cort1eco
		else
			ai.t1priorityrate = ai.aimodehandler.t1ratepostt2
			return cort1expand
		end
	elseif unit.mode == "expand" and (not hasTech2) then
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
		elseif ai.t2concounter%10 == 1 or ai.t2concounter%10 == 2 or ai.t2concounter%10 == 4 or ai.t2concounter%10 == 5 or ai.t2concounter%10 == 7 or ai.t2concounter%10 == 0 then
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
		elseif ai.t2concounter%10 == 1 or ai.t2concounter%10 == 2 or ai.t2concounter%10 == 4 or ai.t2concounter%10 == 5 or ai.t2concounter%10 == 7 or ai.t2concounter%10 == 0 then
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
	cornanotc = assistqueuepatrol,
	corack = cort2con,
	coracv = cort2con,
	coraca = cort2con,
	-- ASSIST
	corfast = assistqueuefreaker,
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
	armnanotc = assistqueuepatrol,
	armack = armt2con,
	armacv = armt2con,
	armaca = armt2con,
	--ASSIST
	armconsul = assistqueueconsul,
	armfark = assistqueuepatrol,
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
