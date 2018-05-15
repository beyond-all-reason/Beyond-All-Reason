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

if (tonumber((Spring.GetModOptions().disabledaimetalcheat or 0) == 1)) then
	getmetalcheat = 0
else
	getmetalcheat = 1
end
if getmetalcheat == nil then
	getmetalcheat = 1
end

local metalcheat = 0
local unitoptions = {}

----------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------- Core Functions -------------------------------------
--------------------------------------------------------------------------------------------

function CorEnT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"corwin", "corsolar",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorMexT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	--local unitoptions = {"cormex", "corexp",}
	--return unitoptions[math.random(1,#unitoptions)]
	return "cormex"
end

function CorStarterLabT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local r = math.random(0,100)
	if r < 70 then
		return "corlab"
	else
		return "corvp"
	end
end

function CorRandomLab()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local countAdvFacs = UDC(ai.id, UDN.coravp.id) + UDC(ai.id, UDN.coralab.id) + UDC(ai.id, UDN.coraap.id)
	local countBasicFacs = UDC(ai.id, UDN.corvp.id) + UDC(ai.id, UDN.corlab.id) + UDC(ai.id, UDN.corap.id)
	
	if countBasicFacs + countAdvFacs < Spring.GetGameSeconds() * 0.001 then
		if countAdvFacs < countBasicFacs then
			local unitoptions = {"coralab", "coravp", "coraap",}
			return unitoptions[math.random(1,#unitoptions)]
		else
			local unitoptions = {"corlab", "corvp", "corap",}
			return unitoptions[math.random(1,#unitoptions)]
		end
	else
		return "corkrog"
	end
end

function CorAdvDefT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"cormaw", "corhllt", "corhlt", "cormadsam",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorKBotsT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"corak", "cornecro", "corthud", "corstorm", "corcrash",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorVehT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"corgator", "corraid", "corlevlr", "corwolv", "cormist", "corgarp",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorAirT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"corveng", "corshad", "corbw",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorKBotsT2()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.05
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"coraak", "coramph", "corcan", "corhrk", "cormando", "cormort", "corpyro", "corroach", "cortermite", "corspec", "corsumo",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorVehT2()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.05
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"corban", "coreter", "corgol", "cormart", "corparrow", "correap", "corseal", "corsent", "cortrem", "corvroc",}
	return unitoptions[math.random(1,#unitoptions)]
end

function CorAirT2()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.05
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"corape", "corcrw", "corhurc", "corvamp",}
	return unitoptions[math.random(1,#unitoptions)]
end
		
--------------------------------------------------------------------------------------------
--------------------------------------- Arm Functions --------------------------------------
--------------------------------------------------------------------------------------------

function ArmEnT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armwin", "armsolar",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmMexT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	--local unitoptions = {"armmex", "armamex",}
	--return unitoptions[math.random(1,#unitoptions)]
	return "armmex"
end

function ArmStarterLabT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local r = math.random(0,100)
	if r < 70 then
		return "armlab"
	else
		return "armvp"
	end
end

function ArmRandomLab()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local countAdvFacs = UDC(ai.id, UDN.armavp.id) + UDC(ai.id, UDN.armalab.id) + UDC(ai.id, UDN.armaap.id)
	local countBasicFacs = UDC(ai.id, UDN.armvp.id) + UDC(ai.id, UDN.armlab.id) + UDC(ai.id, UDN.armap.id)
	if countBasicFacs + countAdvFacs < Spring.GetGameSeconds() * 0.001 then
		if countAdvFacs < countBasicFacs then
			local unitoptions = {"armalab", "armavp", "armaap",}
			return unitoptions[math.random(1,#unitoptions)]
		else
			local unitoptions = {"armlab", "armvp", "armap",}
			return unitoptions[math.random(1,#unitoptions)]
		end
	else
		return "corkrog"
	end
end

function ArmAdvDefT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armclaw", "armbeamer", "armhlt", "armpacko",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmKBotsT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armpw", "armham", "armrectr", "armrock", "armjeth", "armwar",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmVehT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armflash", "armstump", "armjanus", "armart", "armsam", "armpincer",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmAirT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armthund", "armfig", "armkam",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmKBotsT2()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.05
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armaak", "armamph", "armaser", "armfast", "armfboy", "armfido", "armmav", "armsnipe", "armspid", "armzeus", "armvader",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmVehT2()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.05
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armbull", "armcroc", "armjam", "armlatnk", "armmanni", "armmart", "armmerl", "armst", "armyork",}
	return unitoptions[math.random(1,#unitoptions)]
end

function ArmAirT2()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.05
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", metalcheat*2)
	
	local unitoptions = {"armblade", "armbrawl", "armhawk", "armliche", "armpnix", "armstil",}
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
	CorAdvDefT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorEnT1,
	CorAdvDefT1,
	CorEnT1,
	CorAdvDefT1,
	CorEnT1,
	"cormstor",
	CorEnT1,
	"corrad",
	CorEnT1,
	CorEnT1,
	CorRandomLab,
	"cornanotc",
	CorAdvDefT1,
	"cormakr",
	"cormakr",
	CorEnT1,
	"cormakr",
	"cormakr",
	"cormakr",
	CorEnT1,
	CorRandomLab,
	"cornanotc",
	CorAdvDefT1,
	CorEnT1,
	CorAdvDefT1,
	CorEnT1,
	"coradvsol",
	CorEnT1,
	CorEnT1,
	CorAdvDefT1,
	CorEnT1,
	"corestor",
	CorEnT1,
	CorAdvDefT1,
	"coradvsol",
}

local cort1mexingqueue = {
	CorMexT1,
	"corllt",
	CorMexT1,
	"corllt",
	CorMexT1,
	"corllt",
	CorMexT1,
	"corllt",
	CorMexT1,
	"corllt",
}

local cort2construction = {
	"cormoho",
	CorRandomLab,
	"cormoho",
	CorRandomLab,
	"cormoho",
	CorRandomLab,
	"cormoho",
	CorRandomLab,
	"corfus",
	CorRandomLab,
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
	ArmEnT1,
	"armmakr",
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
	"armestor",
	"armmstor",
	ArmEnT1,
	ArmRandomLab,
	"armllt",
}

local armt1construction = {
	--"armnanotc",
	ArmEnT1,
	ArmRandomLab,
	"armnanotc",
	ArmAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmAdvDefT1,
	ArmEnT1,
	ArmAdvDefT1,
	"armrad",
	ArmEnT1,
	ArmEnT1,
	"armadvsol",
	ArmAdvDefT1,
	"armmstor",
	ArmRandomLab,
	"armnanotc",
	ArmAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmAdvDefT1,
	"armmakr",
	"armmakr",
	"armmakr",
	"armmakr",
	"armmakr",
	ArmRandomLab,
	"armnanotc",
	ArmAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	ArmAdvDefT1,
	ArmEnT1,
	ArmEnT1,
	ArmAdvDefT1,
	"armrad",
	"armadvsol",
	ArmEnT1,
	ArmEnT1,
	ArmAdvDefT1,
	"armestor",
	ArmEnT1,
}

local armt1mexingqueue = {
	ArmMexT1,
	"armllt",
	ArmMexT1,
	"armllt",
	ArmMexT1,
	"armllt",
	ArmMexT1,
	"armllt",
	ArmMexT1,
	"armllt",
}

local armt2construction = {
	"armmoho",
	ArmRandomLab,
	"armmoho",
	ArmRandomLab,
	"armmoho",
	ArmRandomLab,
	"armmoho",
	ArmRandomLab,
	"armfus",
	ArmRandomLab,
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

local assistqueue = {
	{ action = "patrolrelative", position = {x = math.random(-100, 100), y = 0, z = math.random(-100, 100)} },
}
----------------------------------------------------------
	
local function corcommander()
	if ai.engineerfirst == true then
		--return corcommanderq
		return assistqueue
	else
		ai.engineerfirst = true
		return corcommanderfirst
	end
end

local function armcommander()
	if ai.engineerfirst == true then
		--return armcommanderq
		return assistqueue
	else
		ai.engineerfirst = true
		return armcommanderfirst
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
	---ARM
	--constructors
	armcom = armcommander,
	armck = armT1constructorrandommexer,
	armcv = armT1constructorrandommexer,
	armca = armT1constructorrandommexer,
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
}
