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

----------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------- Core Functions -------------------------------------
--------------------------------------------------------------------------------------------

function CorNanoT()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		return "cornanotc"
	else
		return "corkrog"
	end
end

function CorEnT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ec < es - es*0.8 then
        if taskqueuebehaviour.ai.map:AverageWind() > 7 then
            return "corwin"
        else
            return "corsolar"
        end
	elseif mc < ms - ms*0.8 then
		return "cormex"
	elseif mc < ms - ms*0.4 then
		return "corexp"
	else
		return "corkrog"
	end
end

function CorEnT2( taskqueuebehaviour )

	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ec < es - es*0.8 then
		return "corfus"
	elseif mc < ms - ms*0.8 then
		return "cormexp"
	elseif mc < ms - ms*0.4 then
		return "cormmkr"
	else
		return "corkrog"
	end
end

function CorMexT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms - ms*0.8 then
		return "cormex"
	elseif mc < ms - ms*0.7 then
		return "corexp"
	elseif ec < es - es*0.8 then
        if taskqueuebehaviour.ai.map:AverageWind() > 7 then
            return "corwin"
        else
            return "corsolar"
        end
	else
		return "corkrog"
	end
end

function CorStarterLabT1()
	local countStarterFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id)
	if countStarterFacs < 1 then
		local r = math.random(0,100)
		if r < 70 then
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
	local countAdvFacs = UDC(ai.id, UDN.coravp.id) + UDC(ai.id, UDN.coralab.id) + UDC(ai.id, UDN.coraap.id) + UDC(ai.id, UDN.corgant.id)
	local countBasicFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id) + UDC(ai.id, UDN.corhp.id)
	local countAirLabs = UDC(ai.id, UDN.corap.id)
	
	if countBasicFacs + countAdvFacs < Spring.GetGameSeconds() / 600 + 1 and ms + Spring.GetGameSeconds() > 1000 then
		if countAirLabs < 1 then
			return "corap"
		elseif countAdvFacs < countBasicFacs*2 then
			local unitoptions = {"coralab", "coravp", "coraap", "corgant",}
			return unitoptions[math.random(1,#unitoptions)]
		else
			local unitoptions = {"corlab", "corvp", "corap", "corhp",}
			return unitoptions[math.random(1,#unitoptions)]
		end
	else
		return "corkrog"
	end
end

function CorGroundAdvDefT1()
	local r = math.random(0,100)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		if r == 0 and Spring.GetGameSeconds() > 600 then
			return "corpun"
		else
			local unitoptions = {"cormaw", "corhllt", "corhlt",}
			return unitoptions[math.random(1,#unitoptions)]
		end
	else
		return "corkrog"
	end
end

function CorAirAdvDefT1()
	local countAirDefs = UDC(ai.id, UDN.cormadsam.id) + UDC(ai.id, UDN.corrl.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		if Spring.GetGameSeconds() / 450 > countAirDefs then
			local unitoptions = {"cormadsam", "corrl",}
			return unitoptions[math.random(1,#unitoptions)]
		else
			return "corkrog"
		end
	else
		return "corkrog"
	end
end

function CorKBotsT1()
	if Spring.GetGameSeconds() < 150 then
		return "corak"
	elseif Spring.GetGameSeconds() >= 150 and Spring.GetGameSeconds() < 300 then
		local unitoptions = {"corak", "corak", "corak", "cornecro", "corstorm",}
		return unitoptions[math.random(1,#unitoptions)]
	else
	    local unitoptions = {"corak", "corthud", "corthud", "corstorm", "corstorm", "cornecro", "cornecro",}
		return unitoptions[math.random(1,#unitoptions)]
	end
end

function CorVehT1()
    if Spring.GetGameSeconds() < 150 then
		return "corfav"
    elseif Spring.GetGameSeconds() >= 150 and Spring.GetGameSeconds() < 300 then
		local unitoptions = {"corgator", "corgator", "corfav",}
		return unitoptions[math.random(1,#unitoptions)]
    else 
		local unitoptions = {"corraid", "corraid", "corraid", "corlevlr", "corlevlr", "cormist", "cormist",}
		return unitoptions[math.random(1,#unitoptions)]
	end
end

function CorAirT1()
	
	local unitoptions = {"corveng", "corshad", "corbw",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorAirAdvDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		local unitoptions = {"corvipe","corflak", }
		return unitoptions[math.random(1,#unitoptions)]
	else
		return "corkrog"
	end
end

function CorTacticalAdvDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
	    if UDC(ai.id, UDN.corint.id) < UDC(ai.id, UDN.cordoom.id)*2 then
			return "corint"
		elseif UDC(ai.id, UDN.cordoom.id) < UDC(ai.id, UDN.cortoast.id)*4 then
			return "cordoom"
		else
			return "cortoast"
		end
	else
		return "corkrog"
	end
end

function CorTacticalOffDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		if  UDC(ai.id, UDN.corfmd.id) < 3 then
			return "corfmd"
		elseif UDC(ai.id, UDN.corscreamer.id) < 3 then
			return "corscreamer"
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



function CorKBotsT2()
	
	local unitoptions = {"coraak", "coramph", "corcan", "corhrk", "cormort", "corpyro", "corroach", "cortermite", "corspec", "corsumo",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorVehT2()
	
	local unitoptions = {"corban", "coreter", "corgol", "cormart", "corparrow", "correap", "corseal", "corsent", "cortrem", "corvroc",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorAirT2()
	
	local unitoptions = {"corape", "corcrw", "corhurc", "corvamp",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorHover()
	
	local unitoptions = {"corah", "corch", "corhal", "cormh", "corsh", "corsnap","corsok", }
	return unitoptions[math.random(1,#unitoptions)]
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
	return unitoptions[math.random(1,#unitoptions)]
end 

		
--------------------------------------------------------------------------------------------
--------------------------------------- Arm Functions --------------------------------------
--------------------------------------------------------------------------------------------

function ArmNanoT()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		return "armnanotc"
	else
		return "corkrog"
	end
end


function ArmEnT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ec < es - es*0.8 then
        if taskqueuebehaviour.ai.map:AverageWind() > 7 then
            return "armwin"
        else
            return "armsolar"
        end
	elseif mc < ms - ms*0.8 then
		return "armmex"
	else
		return "corkrog"
	end
end

function ArmEnT2( taskqueuebehaviour )

	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if ec < es - es*0.8 then
		return "armfus"
	elseif mc < ms - ms*0.8 then
		return "armmoho"
	elseif mc < ms - ms*0.4 then
		return "armmmkr"
	else
		return "corkrog"
	end
end

function ArmMexT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms - ms*0.8 then
		return "armmex"
	elseif ec < es - es*0.8 then
        if taskqueuebehaviour.ai.map:AverageWind() > 7 then
            return "armwin"
        else
            return "armsolar"
        end
	else
		return "corkrog"
	end
end

function ArmStarterLabT1()
	local countStarterFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id)
	if countStarterFacs < 1 then
		local r = math.random(0,100)
		if r < 70 then
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
	local countAdvFacs = UDC(ai.id, UDN.armavp.id) + UDC(ai.id, UDN.armalab.id) + UDC(ai.id, UDN.armaap.id) + UDC(ai.id, UDN.armshltx.id)
	local countBasicFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id) + UDC(ai.id, UDN.armhp.id)
	local countAirLabs = UDC(ai.id, UDN.armap.id)
	
	if countBasicFacs + countAdvFacs < Spring.GetGameSeconds() / 600 + 1 and ms + Spring.GetGameSeconds() > 1000 then
		if countAirLabs < 1 then
			return "armap"
		elseif countAdvFacs < countBasicFacs*2 then
			local unitoptions = {"armalab", "armavp", "armaap", "armshltx",}
			return unitoptions[math.random(1,#unitoptions)]
		else
			local unitoptions = {"armlab", "armvp", "armap", "armhp",}
			return unitoptions[math.random(1,#unitoptions)]
		end
	else
		return "corkrog"
	end
end

function ArmGroundAdvDefT1()
	local r = math.random(0,100)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		if r == 0 and Spring.GetGameSeconds() > 600 then
			return "armguard"
		else
			local unitoptions = {"armclaw", "armbeamer","armhlt",}
			return unitoptions[math.random(1,#unitoptions)]
		end
	else
		return "corkrog"
	end
end

function ArmAirAdvDefT1()
	local countAirDefs = UDC(ai.id, UDN.armrl.id) + UDC(ai.id, UDN.armpacko.id)
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		if Spring.GetGameSeconds() / 450 > countAirDefs then
			local unitoptions = {"armrl", "armpacko",}
			return unitoptions[math.random(1,#unitoptions)]
		else
			return "corkrog"
		end
	else
		return "corkrog"
	end
end

function ArmKBotsT1()
	if Spring.GetGameSeconds() < 150 then
		return "armflea"
	elseif Spring.GetGameSeconds() >= 150 and Spring.GetGameSeconds() < 300 then
		local unitoptions = {"armpw", "armpw", "armflea",}
		return unitoptions[math.random(1,#unitoptions)]
	else 
		local unitoptions = {"armpw", "armflea", "armflea", "armham", "armham", "armham", "armrectr", "armrectr", "armrock", "armrock", "armrock", "armwar", "armwar", "armwar",}
	return unitoptions[math.random(1,#unitoptions)]
	end
end

function ArmVehT1()
    if Spring.GetGameSeconds() < 150 then
       return "armfav"
    elseif Spring.GetGameSeconds() >= 150 and Spring.GetGameSeconds() < 300 then
       local unitoptions = {"armflash", "armflash", "armfav",}
		return unitoptions[math.random(1,#unitoptions)]
    else 
       local unitoptions = {"armstump", "armstump", "armstump", "armjanus", "armjanus", "armsam", "armsam",}
		return unitoptions[math.random(1,#unitoptions)]
	end
end

function ArmAirT1()
	
	local unitoptions = {"armthund", "armfig", "armkam",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmAirAdvDefT2()

	local unitoptions = {"armpb", "armflak",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmTacticalAdvDefT2()
    local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		if UDC(ai.id, UDN.armbrtha.id) < UDC(ai.id, UDN.armanni.id)*2 then
			return "armbrtha"
		elseif UDC(ai.id, UDN.armanni.id) < UDC(ai.id, UDN.armamb.id)*4 then
			return "armanni"
		else
			return "armamb"
		end
	else
		return "corkrog"
	end
end

function ArmTacticalOffDefT2()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc > ms*0.2 and ec > es*0.2 then
		if  UDC(ai.id, UDN.corfmd.id) < 3 then
			return "armamd"
		elseif UDC(ai.id, UDN.corscreamer.id) < 3 then
			return "armmercury"
		elseif 	 UDC(ai.id, UDN.corgate.id) < 6 then
			return "armgate"
		else
			return "corkrog"
		end
	else
		return "corkrog"
	end
end
	--local unitoptions = {"armamd", "armsilo",}
	--return unitoptions[math.random(1,#unitoptions)]


function ArmKBotsT2()
	
	local unitoptions = {"armaak", "armamph", "armaser", "armfast", "armfboy", "armfido", "armmav", "armsnipe", "armspid", "armzeus", "armvader",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmVehT2()
	
	local unitoptions = {"armbull", "armcroc", "armlatnk", "armmanni", "armmart", "armmerl", "armst", "armyork",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmAirT2()
	
	local unitoptions = {"armblade", "armbrawl", "armhawk", "armliche", "armpnix", "armstil",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmHover()
	
	local unitoptions = {"armah", "armanac", "armch", "armlun", "armmh", "armsh", }
	return unitoptions[math.random(1,#unitoptions)]
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
	return unitoptions[math.random(1,#unitoptions)]
end

-------------------------------------------------------------




--------------------------------------------------------------------------------------------
----------------------------------------- CoreTasks ----------------------------------------
--------------------------------------------------------------------------------------------

local corcommanderfirst = {
	"cormex",
	"cormex",
	"corsolar",
	"corsolar",
	CorStarterLabT1,
	"corsolar",
	"corsolar",
}

local corcommanderq = {
	CorEnT1,
	CorEnT1,
	"corllt",
	"corrad",
	CorEnT1,
	CorEnT1,
	"corllt",
	CorEnT1,
	CorEnT1,
	CorEnT1,
	"corllt",
	CorEnT1,
	CorEnT1,
	"corllt",
	CorEnT1,
	"corllt",
	"corrad",
	CorEnT1,
	CorEnT1,
	CorEnT1,
	"corllt",
	CorEnT1,
	CorEnT1,
	"corllt",
	CorEnT1,
	"cormstor",
	"corestor",
	CorRandomLab,
}

local cort1construction = {
	--CorNanoT,
	CorRandomLab,
	CorNanoT,
	CorGroundAdvDefT1,
    CorAirAdvDefT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorGroundAdvDefT1,
	CorEnT1,
	CorAirAdvDefT1,
	"cormstor",
	CorEnT1,
	CorEnT1,
	"corrad",
	CorGroundAdvDefT1,
	CorEnT1,
	CorRandomLab,
	CorNanoT,
	CorGroundAdvDefT1,
	CorEnT1,
	CorEnT1,
	CorGroundAdvDefT1,
	CorRandomLab,
	CorNanoT,
	CorAirAdvDefT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
    CorAirAdvDefT1,
	CorEnT1,
	CorEnT1,
	"coradvsol",
	CorEnT1,
	CorEnT1,
	CorGroundAdvDefT1,
	"corestor",
	CorEnT1,
}

local cort1mexingqueue = {
	CorMexT1,
	CorNanoT,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorGroundAdvDefT1,
	CorMexT1,
	CorNanoT,
	CorEnT1,
	CorGroundAdvDefT1,
	CorMexT1,
	CorNanoT,
	CorEnT1,
	CorGroundAdvDefT1,
	CorMexT1,
	CorNanoT,
	CorEnT1,
	CorGroundAdvDefT1,
	CorMexT1,
	CorNanoT,
	CorEnT1,
	CorGroundAdvDefT1,
}

local cort2construction = {
	CorEnT2,
	CorEnT2,
	CorRandomLab,
	CorTacticalOffDefT2,
	CorTacticalAdvDefT2,
    CorAirAdvDefT2,
	CorTacticalAdvDefT2,
	CorEnT2,
	CorEnT2,
	CorRandomLab,
	CorEnT2,
	CorRandomLab,
	CorEnT2,
	CorRandomLab,
	CorTacticalOffDefT2,
	CorTacticalAdvDefT2,
    CorAirAdvDefT2,
	CorEnT2,
	CorEnT2,
	CorRandomLab,
	CorTacticalOffDefT2,
	CorTacticalAdvDefT2,
    CorAirAdvDefT2,
    CorTacticalAdvDefT2,
}

local corkbotlab = {
	"corck",	--	Constructor
	"corck",	--	Constructor
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,
	CorKBotsT1,

}

local corvehlab = {
	"corcv",	--	Constructor
	"corcv",	--	Constructor
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,
	CorVehT1,

}

local corairlab = {
	"corca",	-- 	Constructor
	"corca",	-- 	Constructor
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
	CorAirT1,
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
	"corack",
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
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
	CorKBotsT2,
}

corvehlabT2 = {
	"coracv",
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
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
	CorHover,
}
corgantryT3 = {
	CorGantry,
	CorGantry,
	CorGantry,
	CorGantry,
	CorGantry,
	CorGantry,
}


--------------------------------------------------------------------------------------------
----------------------------------------- ArmTasks -----------------------------------------
--------------------------------------------------------------------------------------------

local armcommanderfirst = {
	"armmex",
	"armmex",
	"armsolar",
	"armsolar",
	ArmStarterLabT1,
	"armsolar",
	"armsolar",
}

local armcommanderq = {
	ArmEnT1,
	ArmEnT1,
	"armllt",
	"armrad",
	ArmEnT1,
	ArmEnT1,
	"armllt",
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	"armllt",
	"armrad",
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	"armllt",
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	"armllt",
	"armrad",
	ArmEnT1,
	ArmEnT1,
	"armestor",
	"armmstor",
	ArmEnT1,
	ArmRandomLab,
}

local armt1construction = {
	--ArmNanoT,
	ArmRandomLab,
	ArmNanoT,
	ArmGroundAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmEnT1,
	ArmAirAdvDefT1,
	"armrad",
	ArmEnT1,
	ArmEnT1,
	"armadvsol",
	ArmGroundAdvDefT1,
	"armmstor",
	ArmRandomLab,
	ArmNanoT,
	ArmAirAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmRandomLab,
	ArmNanoT,
	ArmAirAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmAirAdvDefT1,
	"armrad",
	"armadvsol",
	ArmEnT1,
	ArmEnT1,
	ArmGroundAdvDefT1,
	"armestor",
	ArmEnT1,
}

local armt1mexingqueue = {
	ArmMexT1,
	ArmNanoT,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmMexT1,
	ArmNanoT,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmMexT1,
	ArmNanoT,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmMexT1,
	ArmNanoT,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmMexT1,
	ArmNanoT,
	ArmEnT1,
	ArmGroundAdvDefT1,
}

local armt2construction = {
	ArmEnT2,
	ArmEnT2,
	ArmRandomLab,
	ArmTacticalAdvDefT2,
	ArmTacticalOffDefT2,
	ArmAirAdvDefT2,
	ArmTacticalOffDefT2,
	ArmEnT2,
	ArmEnT2,
	ArmRandomLab,
    ArmGroundAdvDefT2,
	ArmTacticalOffDefT2,
	ArmEnT2,
	ArmEnT2,
	ArmRandomLab,
	ArmEnT2,
	ArmEnT2,
	ArmRandomLab,
	ArmTacticalAdvDefT2,
	ArmTacticalOffDefT2,
	ArmEnT2,
	ArmEnT2,
	ArmRandomLab,
	ArmTacticalAdvDefT2,
    ArmTacticalAdvDefT2,

}

local armkbotlab = {
	"armck",	-- 	Constructor
	"armck",	-- 	Constructor
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,
	ArmKBotsT1,

}

local armvehlab = {
	"armcv",	--	Constructor
	"armcv",	--	Constructor
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,
	ArmVehT1,

}

local armairlab = {
	"armca",	--	Constructor
	"armca",	--	Constructor
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
	ArmAirT1,
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
	"armack",
	"armack",
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
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
	ArmKBotsT2,
}

armvehlabT2 = {
	"armacv",
	"armacv",
	"armacv",
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
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
	ArmVehT2,
}

armairlabT2 = {
	"armaca",
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
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
	ArmAirT2,
}

armhoverlabT2 = {
	"armch",
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
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
	ArmHover,
}
armgantryT3 = {
	ArmGantry,
	ArmGantry,
	ArmGantry,
	ArmGantry,
	ArmGantry,
	ArmGantry,
	ArmGantry,
}

local assistqueue = {
	{ action = "patrolrelative", position = {x = 100, y = 0, z = 100} },
}
----------------------------------------------------------
	
---------------------------------------------------------- Core
local function corcommander()
	if ai.engineerfirst == true then
		--return corcommanderq
		return assistqueue
	else
		ai.engineerfirst = true
		return corcommanderfirst
	end
end

local function corT1constructorrandommexer()
	local r = math.random(0,1)
		if r == 0 or Spring.GetGameSeconds() < 300 then
			return cort1mexingqueue
		else
			return cort1construction
		end
end

----------------------------------------------------------  Arm
local function armcommander()
	if ai.engineerfirst == true then
		--return armcommanderq
		return assistqueue
	else
		ai.engineerfirst = true
		return armcommanderfirst
	end
end

local function armT1constructorrandommexer()
	local r = math.random(0,1)
		if r == 0 or Spring.GetGameSeconds() < 300 then
			return armt1mexingqueue
		else
			return armt1construction
		end
end

taskqueues = {
	---CORE
	--constructors
	corcom = corcommander,
	corck = corT1constructorrandommexer,
	corcv = corT1constructorrandommexer,
	corca = corT1constructorrandommexer,
	corch = corT1constructorrandommexer,
	cornanotc = assistqueue,
	corack = cort2construction,
	coracv = cort2construction,
	coraca = cort2construction,
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
	armck = armT1constructorrandommexer,
	armcv = armT1constructorrandommexer,
	armca = armT1constructorrandommexer,
	armch = armT1constructorrandommexer,
	armnanotc = assistqueue,
	armack = armt2construction,
	armacv = armt2construction,
	armaca = armt2construction,
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
