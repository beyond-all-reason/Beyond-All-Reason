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

function CorMexT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms - ms*0.8 then
		return "cormex"
	elseif mc < ms - ms*0.4 then
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
	
	local r = math.random(0,100)
	if r < 70 then
		return "corlab"
	else
		return "corvp"
	end
end

function CorRandomLab()
	
	local countAdvFacs = UDC(ai.id, UDN.coravp.id) + UDC(ai.id, UDN.coralab.id) + UDC(ai.id, UDN.coraap.id) + UDC(ai.id, UDN.corgant.id)
	local countBasicFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id) + UDC(ai.id, UDN.corhp.id)
	
	if countBasicFacs + countAdvFacs < Spring.GetGameSeconds() / 300 + 1 then
		if countAdvFacs < countBasicFacs then
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
	
	local unitoptions = {"cormaw", "corhllt", "corhlt", "corpun",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorAirAdvDefT1()

	local unitoptions = {"cormadsam","corrl",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorKBotsT1()
	
	local unitoptions = {"corak", "cornecro", "corthud", "corstorm", "corcrash",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorVehT1()
	
	local unitoptions = {"corgator", "corraid", "corlevlr", "corwolv", "cormist", "corgarp",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorAirT1()
	
	local unitoptions = {"corveng", "corshad", "corbw",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorGroundAdvDefT2()

	local unitoptions = {"cortoast","cordoom"}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorAirAdvDefT2()

	local unitoptions = {"corvipe","corflak","corscreamer", }
	return unitoptions[math.random(1,#unitoptions)]
end

function CorTacticalAdvDefT2()

	local unitoptions = {"corgate", "corint" }
	return unitoptions[math.random(1,#unitoptions)]
end

function CorKBotsT2()
	
	local unitoptions = {"coraak", "coramph", "corcan", "corhrk", "cormando", "cormort", "corpyro", "corroach", "cortermite", "corspec", "corsumo",}
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
	elseif mc < ms - ms*0.4 then
		return "armamex"
	else
		return "corkrog"
	end
end

function ArmMexT1( taskqueuebehaviour )
	
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	if mc < ms - ms*0.8 then
		return "armmex"
	elseif mc < ms - ms*0.4 then
		return "armamex"
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
	
	local r = math.random(0,100)
	if r < 70 then
		return "armlab"
	else
		return "armvp"
	end
end

function ArmRandomLab()
	
	local countAdvFacs = UDC(ai.id, UDN.armavp.id) + UDC(ai.id, UDN.armalab.id) + UDC(ai.id, UDN.armaap.id) + UDC(ai.id, UDN.armshltx.id)
	local countBasicFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id) + UDC(ai.id, UDN.armhp.id)
	if countBasicFacs + countAdvFacs < Spring.GetGameSeconds() / 600 + 1 then
		if countAdvFacs < countBasicFacs then
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
	
	local unitoptions = {"armclaw", "armbeamer","armhlt", "armguard", }
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmAirAdvDefT1()

	local unitoptions = {"armrl", "armpacko",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmKBotsT1()
	
	local unitoptions = {"armpw", "armham", "armrectr", "armrock", "armjeth", "armwar",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmVehT1()
	
	local unitoptions = {"armflash", "armstump", "armjanus", "armart", "armsam", "armpincer",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmAirT1()
	
	local unitoptions = {"armthund", "armfig", "armkam",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmGroundAdvDefT2()

	local unitoptions = {"armamb","armanni", "armbrtha",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmAirAdvDefT2()

	local unitoptions = {"armpb", "armflak","armmercury",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmTacticalAdvDefT2()

	local unitoptions = {"armgate",}
	return unitoptions[math.random(1,#unitoptions)]
end

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
	"cormex",
	"corsolar",
	"corsolar",
	"corsolar",
	"corsolar",
	CorStarterLabT1,
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
	--"cornanotc",
	CorEnT1,
	CorRandomLab,
	"cornanotc",
	CorGroundAdvDefT1,
    CorAirAdvDefT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorGroundAdvDefT1,
	CorEnT1,
	CorAirAdvDefT1,
	CorEnT1,
	"cormstor",
	CorEnT1,
	"corrad",
	CorEnT1,
	CorEnT1,
	CorRandomLab,
	"cornanotc",
	CorGroundAdvDefT1,
	CorEnT1,
	CorEnT1,
	CorRandomLab,
	"cornanotc",
	CorGroundAdvDefT1,
	CorEnT1,
    CorAirAdvDefT1,
	CorEnT1,
	"coradvsol",
	CorEnT1,
	CorEnT1,
	CorGroundAdvDefT1,
	CorEnT1,
	"corestor",
	CorEnT1,
    CorAirAdvDefT1,
	"coradvsol",
}

local cort1mexingqueue = {
	CorMexT1,
	"cornanotc",
	CorEnT1,
	"corllt",
	CorMexT1,
	"cornanotc",
	CorEnT1,
	"corllt",
	CorMexT1,
	"cornanotc",
	CorEnT1,
	"corllt",
	CorMexT1,
	"cornanotc",
	CorEnT1,
	"corllt",
	CorMexT1,
	"cornanotc",
	CorEnT1,
	"corllt",
}

local cort2construction = {
	"cormoho",
	CorRandomLab,
	ArmGroundAdvDefT2,
    ArmAirAdvDefT2,
	"cormoho",
	CorRandomLab,
	"cormoho",
	CorRandomLab,
	"cormoho",
	CorRandomLab,
	ArmGroundAdvDefT2,
    ArmAirAdvDefT2,
	"corfus",
	CorRandomLab,
	ArmGroundAdvDefT2,
    ArmAirAdvDefT2,
    ArmTacticalAdvDefT2,
}

local corkbotlab = {
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
	"armmex",
	"armsolar",
	"armsolar",
	"armsolar",
	"armsolar",
	ArmStarterLabT1,
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
	--"armnanotc",
	ArmEnT1,
	ArmRandomLab,
	"armnanotc",
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
	"armnanotc",
	ArmAirAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmGroundAdvDefT1,
	ArmRandomLab,
	"armnanotc",
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
	"armnanotc",
	ArmEnT1,
	"armllt",
	ArmMexT1,
	"armnanotc",
	ArmEnT1,
	"armllt",
	ArmMexT1,
	"armnanotc",
	ArmEnT1,
	"armllt",
	ArmMexT1,
	"armnanotc",
	ArmEnT1,
	"armllt",
	ArmMexT1,
	"armnanotc",
	ArmEnT1,
	"armllt",
}

local armt2construction = {
	"armmoho",
	ArmRandomLab,
    ArmGroundAdvDefT2,
	"armmoho",
	ArmRandomLab,
    ArmGroundAdvDefT2,
	"armmoho",
	ArmRandomLab,
	"armmoho",
	ArmRandomLab,
    ArmGroundAdvDefT2,
	"armfus",
	ArmRandomLab,
    ArmGroundAdvDefT2,
    ArmTacticalAdvDefT2,
}

local armkbotlab = {
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
