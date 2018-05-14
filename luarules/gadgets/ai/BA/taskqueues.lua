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

if (tonumber((Spring.GetModOptions().daimetalcheat or 0) == 1)) then
	getmetalcheat = 0
else
	getmetalcheat = 1
end
if getmetalcheat == nil then
	getmetalcheat = 0
end

local metalcheat = 0

----------------------------------------------------------------------
--------------------------------------------------------------------------------------------
--------------------------------------- Core Functions -------------------------------------
--------------------------------------------------------------------------------------------

function CorEnT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,1)
	if r == 0 then
		return "corwin"
	else
		return "corsolar"
	end
end

function CorMexT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,1)
	if r == 0 then
		return "cormex"
	else
		return "corexp"
	end
end

function CorStarterLabT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,1)
	if r == 0 then
		return "corlab"
	else
		return "corvp"
	end
end

function CorRandomLabT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,2)
	if r == 0 then
		return "corlab" 	--T1 KBots
	elseif r == 1 then
		return "corvp" 		--T1 Vehs
	else
		return "corap" 		--T1 Planes
	end
end

function CorAdvDefT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,5)
	if r == 0 then
		return "cormaw"
	elseif r == 1 then
		return "corhllt"
	elseif r == 2 then
		return "corhlt"
	elseif r == 3 then
		return "corpun"
	elseif r == 4 then
		return "cormadsam"
	elseif r == 5 then
		return "corerad"
	end
end

function CorKBotsT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,4)
	if r == 0 then
		return "corak"
	elseif r == 1 then
		return "cornecro"
	elseif r == 2 then
		return "corthud"
	elseif r == 3 then
		return "corstorm"
	else
		return "corcrash"
	end
end

function CorVehT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,5)
	if r == 0 then
		return "corgator"
	elseif r == 1 then
		return "corraid"
	elseif r == 2 then
		return "corlevlr"
	elseif r == 3 then
		return "corwolv"
	elseif r == 4 then
		return "cormist"
	else
		return "corgarp"
	end
end

function CorAirT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,2)
	if r == 0 then
		return "corveng"
	elseif r == 1 then
		return "corshad"
	else
		return "corbw"
	end
end
--------------------------------------------------------------------------------------------
--------------------------------------- Arm Functions --------------------------------------
--------------------------------------------------------------------------------------------

function ArmEnT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,1)
	if r == 0 then
		return "armwin"
	else
		return "armsolar"
	end
end

function ArmMexT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,1)
	if r == 0 then
		return "armmex"
	else
		return "armamex"
	end
end

function ArmStarterLabT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,1)
	if r == 0 then
		return "armlab"
	else
		return "armvp"
	end
end

function ArmRandomLabT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,2)
	if r == 0 then
		return "armlab"
	elseif r == 1 then
		return "armvp"
	else
		return "armap"
	end
end

function ArmAdvDefT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,5)
	if r == 0 then
		return "armclaw"
	elseif r == 1 then
		return "armbeamer"
	elseif r == 2 then
		return "armhlt"
	elseif r == 3 then
		return "armguard"
	elseif r == 4 then
		return "armpacko"
	elseif r == 5 then
		return "armcir"
	end
end

function ArmKBotsT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,5)
	if r == 0 then
		return "armpw"
	elseif r == 1 then
		return "armham"
	elseif r == 2 then
		return "armrectr"
	elseif r == 3 then
		return "armrock"
	elseif r == 4 then
		return "armjeth"
	else
		return "armwar"
	end
end

function ArmVehT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,5)
	if r == 0 then
		return "armflash"
	elseif r == 1 then
		return "armstump"
	elseif r == 2 then
		return "armjanus"
	elseif r == 3 then
		return "armart"
	elseif r == 4 then
		return "armsam"
	else
		return "armpincer"
	end
end

function ArmAirT1()
	if getmetalcheat == 1 then
		metalcheat = Spring.GetGameSeconds() * 0.025
	end
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	local r = math.random(0,2)
	if r == 0 then
		return "armthund"
	elseif r == 1 then
		return "armfig"
	else
		return "armkam"
	end
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
	"cormstor",
	CorEnT1,
	CorEnT1,
	CorEnT1,
	"corllt",
	CorEnT1,
	CorEnT1,
	"corllt",
	"corestor",
	CorEnT1,
	"corllt",
	"corrad",
	CorEnT1,
	CorEnT1,
	CorEnT1,
	"corllt",
	"cormstor",
	CorEnT1,
	CorEnT1,
	"corllt",
	CorEnT1,
	"corestor",
	CorRandomLabT1,
}

local cort1construction = {
	"cornanotc",
	CorMexT1,
	CorMexT1,
	CorMexT1,
	CorEnT1,
	CorEnT1,
	CorAdvDefT1,
	CorMexT1,
	"corllt",
	CorMexT1,
	"cormstor",
	CorMexT1,
	"corrad",
	CorEnT1,
	CorEnT1,
	CorRandomLabT1,
	--"coraap",
	--"coralab",
	--"coravp",
	"cornanotc",
	"cormakr",
	"cormakr",
	"cormakr",
	"cormakr",
	"cormakr",
	CorMexT1,
	CorAdvDefT1,
	CorEnT1,
	"coradvsol",
	CorEnT1,
	CorMexT1,
	"corllt",
	CorMexT1,
	"corestor",
	CorMexT1,
	CorAdvDefT1,
	"coradvsol",
	
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
	"corack",	--	Adv Constructor
}

corvehlabT2 = {

}

corairlabT2 = {

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
	"armmstor",
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	"armllt",
	"armrad",
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	"armestor",
	ArmEnT1,
	"armmakr",
	ArmEnT1,
	"armllt",
	"armrad",
	ArmEnT1,
	ArmEnT1,
	"armllt",
	"armmstor",
	ArmEnT1,
	ArmEnT1,
	ArmEnT1,
	"armllt",
	"armrad",
	ArmEnT1,
	ArmEnT1,
	"armestor",
	ArmEnT1,
	ArmRandomLabT1,
	"armllt",
}

local armt1construction = {
	"armnanotc",
	ArmMexT1,
	ArmMexT1,
	ArmMexT1,
	ArmEnT1,
	ArmMexT1,
	ArmEnT1,
	"armllt",
	ArmMexT1,
	ArmAdvDefT1,
	"armrad",
	ArmEnT1,
	ArmMexT1,
	"armadvsol",
	ArmAdvDefT1,
	"armmstor",
	ArmRandomLabT1,
	--"armaap",
	--"armalab",
	--"armavp",
	"armnanotc",
	ArmEnT1,
	ArmMexT1,
	"armllt",
	"armmakr",
	"armmakr",
	"armmakr",
	"armmakr",
	"armmakr",
	ArmEnT1,
	ArmMexT1,
	ArmEnT1,
	ArmMexT1,
	ArmMexT1,
	ArmAdvDefT1,
	"armrad",
	"armadvsol",
	ArmEnT1,
	ArmMexT1,
	"armllt",
	"armestor",
	ArmEnT1,
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
}

armvehlabT2 = {
}

armairlabT2 = {
}

----------------------------------------------------------
	
local function corcommander()
	if ai.engineerfirst == true then
		return corcommanderq
	else
		ai.engineerfirst = true
		return corcommanderfirst
	end
end

local function armcommander()
	if ai.engineerfirst == true then
		return armcommanderq
	else
		ai.engineerfirst = true
		return armcommanderfirst
	end
end

taskqueues = {
	---CORE
	--constructors
	corcom = corcommander,
	corck = cort1construction,
	corcv = cort1construction,
	corca = cort1construction,
	--factories
	corlab = corkbotlab,
	corvp = corvehlab,
	corap = corairlab,
	---ARM
	--constructors
	armcom = armcommander,
	armck = armt1construction,
	armcv = armt1construction,
	armca = armt1construction,
	--factories
	armlab = armkbotlab,
	armvp = armvehlab,
	armap = armairlab,
}
