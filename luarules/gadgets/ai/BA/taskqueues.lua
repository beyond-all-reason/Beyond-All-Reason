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
--------------------------------------------------------------------------------------------
--------------------------------------- Core Functions -------------------------------------
--------------------------------------------------------------------------------------------

function CorEnT1()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
	local r = math.random(0,1)
	if r == 0 then
		return "corwin"
	else
		return "corsolar"
	end
end

function CorMexT1()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
	local r = math.random(0,1)
	if r == 0 then
		return "cormex"
	else
		return "corexp"
	end
end

function CorRandomLabT1()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
	local r = math.random(0,2)
	if r == 0 then
		return "corlab"
	elseif r == 1 then
		return "corvp"
	else
		return "corap"
	end
end

function CorAdvDefT1()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
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
--------------------------------------------------------------------------------------------
--------------------------------------- Arm Functions --------------------------------------
--------------------------------------------------------------------------------------------

function ArmEnT1()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
	local r = math.random(0,1)
	if r == 0 then
		return "armwin"
	else
		return "armsolar"
	end
end

function ArmMexT1()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
	local r = math.random(0,1)
	if r == 0 then
		return "armmex"
	else
		return "armamex"
	end
end

function ArmRandomLabT1()
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
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
	local mc, ms, mp, mi, me = Spring.GetTeamResources(ai.id, "metal")
	local ec, es, ep, ei, ee = Spring.GetTeamResources(ai.id, "energy")
	local metalcheat = ms - mc
	local energycheat = es - ec
	Spring.AddTeamResource(ai.id, "m", metalcheat)
	Spring.AddTeamResource(ai.id, "e", energycheat)
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
-------------------------------------------------------------




--------------------------------------------------------------------------------------------
----------------------------------------- CoreTasks ----------------------------------------
--------------------------------------------------------------------------------------------

local corcommanderfirst = {
	"corlab",
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
	"cormakr",
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
	CorMexT1,
	CorEnT1,
	"cornanotc",
	CorEnT1,
	CorAdvDefT1,
	CorMexT1,
	"cornanotc",
	CorMexT1,
	"corllt",
	"cormstor",
	CorMexT1,
	"corrad",
	CorEnT1,
	CorEnT1,
	CorRandomLabT1,
	"cornanotc",
	"cornanotc",
	CorMexT1,
	CorAdvDefT1,
	CorEnT1,
	"cornanotc",
	"coradvsol",
	CorEnT1,
	CorMexT1,
	CorMexT1,
	"cornanotc",
	"corllt",
	"corestor",
	CorMexT1,
	CorAdvDefT1,
	"coradvsol",
	CorRandomLabT1,
	"cornanotc",
	"cornanotc",
}

local corkbotlab = {
	"corck",	--	Constructor
	"corck",	--	Constructor
	"corck",	--	Constructor
	"corck",	--	Constructor
	"corck",	--	Constructor
	"corck",	--	Constructor
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"cornecro",	--	Rez-Reclaim
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"cornecro",	--	Rez-Reclaim
	"cornecro",	--	Rez-Reclaim
	"corthud",	--	Light Plasma
	"corthud",	--	Light Plasma
	"corak",	--	Fast Infantry
	"cornecro",	--	Rez-Reclaim
	"corthud",	--	Light Plasma
	"corthud",	--	Light Plasma
	"corstorm",	--	Rocket Bot
	"corstorm",	--	Rocket Bot
	"cornecro",	--	Rez-Reclaim
	"corak",	--	Fast Infantry
	"corstorm",	--	Rocket Bot
	"corstorm",	--	Rocket Bot
	"corcrash",	--	Anti-Air
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"cornecro",	--	Rez-Reclaim
	"corak",	--	Fast Infantry
	"corak",	--	Fast Infantry
	"cornecro",	--	Rez-Reclaim
	"cornecro",	--	Rez-Reclaim
	"corthud",	--	Light Plasma
	"corthud",	--	Light Plasma
	"corak",	--	Fast Infantry
	"cornecro",	--	Rez-Reclaim
	"corthud",	--	Light Plasma
	"corthud",	--	Light Plasma
	"corstorm",	--	Rocket Bot
	"corstorm",	--	Rocket Bot
	"cornecro",	--	Rez-Reclaim
	"corak",	--	Fast Infantry
	"corstorm",	--	Rocket Bot
	"corstorm",	--	Rocket Bot
	"corcrash",	--	Anti-Air
}

local corvehlab = {
	"corcv",	--	Constructor
	"corcv",	--	Constructor
	"corcv",	--	Constructor
	"corcv",	--	Constructor
	"corcv",	--	Constructor
	"corcv",	--	Constructor
	"corfav",	--	Scout
	"corfav",	--	Scout
	"corgator",	--	Fast Assault Tank
	"corgator",	--	Fast Assault Tank
	"corgator",	--	Fast Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corlevlr",	--	Riot Tank
	"corlevlr",	--	Riot Tank
	"corlevlr",	--	Riot Tank
	"corlevlr",	--	Riot Tank
	"corwolv",	--	Light Artilery
	"corwolv",	--	Light Artilery
	"cormist",	--	Misile Truck
	"cormist",	--	Misile Truck
	"corgarp",	--	Light Amphibious Tank
	"corgarp",	--	Light Amphibious Tank
	"corfav",	--	Scout
	"corfav",	--	Scout
	"corgator",	--	Fast Assault Tank
	"corgator",	--	Fast Assault Tank
	"corgator",	--	Fast Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corraid",	--	Medium Assault Tank
	"corlevlr",	--	Riot Tank
	"corlevlr",	--	Riot Tank
	"corlevlr",	--	Riot Tank
	"corlevlr",	--	Riot Tank
	"corwolv",	--	Light Artilery
	"corwolv",	--	Light Artilery
	"cormist",	--	Misile Truck
	"cormist",	--	Misile Truck
	"corgarp",	--	Light Amphibious Tank
	"corgarp",	--	Light Amphibious Tank
}

local corairlab = {
	"corca",	-- 	Constructor
	"corca",	-- 	Constructor
	"corca",	-- 	Constructor
	"corca",	-- 	Constructor
	"corca",	-- 	Constructor
	"corca",	-- 	Constructor
	"corfink",	--	Scout
	"corfink",	--	Scout
	"corveng",	--	Fighter
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corbw",	--	Paralyzer Drone
	"corfink",	--	Scout
	"corfink",	--	Scout
	"corveng",	--	Fighter
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corveng",	--	Fighter
	"corshad",	--	Bomber
	"corshad",	--	Bomber
	"corbw",	--	Paralyzer Drone
}

--------------------------------------------------------------------------------------------
----------------------------------------- ArmTasks -----------------------------------------
--------------------------------------------------------------------------------------------

local armcommanderfirst = {
	"armlab",
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
	ArmMexT1,
	ArmEnT1,
	ArmMexT1,
	ArmEnT1,
	"armllt",
	ArmMexT1,
	"armnanotc",
	ArmAdvDefT1,
	"armrad",
	ArmEnT1,
	ArmMexT1,
	"armnanotc",
	"armadvsol",
	ArmAdvDefT1,
	"armmstor",
	ArmEnT1,
	ArmRandomLabT1,
	"armnanotc",
	"armnanotc",
	ArmMexT1,
	"armllt",
	"armmakr",
	ArmEnT1,
	ArmMexT1,
	"armnanotc",
	ArmEnT1,
	"armnanotc",
	ArmMexT1,
	ArmMexT1,
	ArmAdvDefT1,
	"armrad",
	"armadvsol",
	ArmEnT1,
	ArmMexT1,
	"armnanotc",
	"armllt",
	"armestor",
	ArmEnT1,
	ArmRandomLabT1,
	"armnanotc",
	"armnanotc",
}

local armkbotlab = {
	"armck",	-- 	Constructor
	"armck",	-- 	Constructor
	"armck",	-- 	Constructor
	"armck",	-- 	Constructor
	"armck",	-- 	Constructor
	"armck",	-- 	Constructor
	"armflea",	--	Scout
	"armflea",	--	Scout
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armrectr",	--	Rez-Reclaim
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armrectr",	--	Rez-Reclaim
	"armham", 	--	Light Plasma
	"armham", 	--	Light Plasma
	"armham", 	--	Light Plasma
	"armham", 	--	Light Plasma
	"armrectr",	--	Rez-Reclaim
	"armrectr",	--	Rez-Reclaim
	"armrock",	--	Rocket Bot
	"armrock",	--	Rocket Bot
	"armrock",	--	Rocket Bot
	"armrock",	--	Rocket Bot
	"armjeth",	--	Anti-Air
	"armrectr",	--	Rez-Reclaim
	"armwar",	--	Medium Infantry
	"armwar",	--	Medium Infantry
	"armflea",	--	Scout
	"armflea",	--	Scout
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armrectr",	--	Rez-Reclaim
	"armpw", 	-- 	Fast Infantry
	"armpw", 	-- 	Fast Infantry
	"armrectr",	--	Rez-Reclaim
	"armham", 	--	Light Plasma
	"armham", 	--	Light Plasma
	"armham", 	--	Light Plasma
	"armham", 	--	Light Plasma
	"armrectr",	--	Rez-Reclaim
	"armrectr",	--	Rez-Reclaim
	"armrock",	--	Rocket Bot
	"armrock",	--	Rocket Bot
	"armrock",	--	Rocket Bot
	"armrock",	--	Rocket Bot
	"armjeth",	--	Anti-Air
	"armrectr",	--	Rez-Reclaim
	"armwar",	--	Medium Infantry
	"armwar",	--	Medium Infantry
}

local armvehlab = {
	"armcv",	--	Constructor
	"armcv",	--	Constructor
	"armcv",	--	Constructor
	"armcv",	--	Constructor
	"armcv",	--	Constructor
	"armcv",	--	Constructor
	"armfav",	--	Scout
	"armfav",	--	Scout
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armjanus",	--	Rocket Tank
	"armjanus",	--	Rocket Tank
	"armjanus",	--	Rocket Tank
	"armjanus",	--	Rocket Tank
	"armart",	-- 	Light Artilery
	"armart",	-- 	Light Artilery
	"armsam",	--	Missile Truck
	"armsam",	--	Missile Truck
	"armpincer",--	Light Amphibious Tank
	"armfav",	--	Scout
	"armfav",	--	Scout
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armflash",	--	Fast Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armstump",	--	Medium Assault Tank
	"armjanus",	--	Rocket Tank
	"armjanus",	--	Rocket Tank
	"armjanus",	--	Rocket Tank
	"armjanus",	--	Rocket Tank
	"armart",	-- 	Light Artilery
	"armart",	-- 	Light Artilery
	"armsam",	--	Missile Truck
	"armsam",	--	Missile Truck
	"armpincer",--	Light Amphibious Tank
}

local armairlab = {
	"armca",	--	Constructor
	"armca",	--	Constructor
	"armca",	--	Constructor
	"armca",	--	Constructor
	"armca",	--	Constructor
	"armca",	--	Constructor
	"armpeep",	--	Scout
	"armpeep",	--	Scout
	"armfig",	-- 	Fighter
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armkam",	--	Light Gunship
	"armpeep",	--	Scout
	"armpeep",	--	Scout
	"armfig",	-- 	Fighter
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armthund",	--	Bomber
	"armfig",	-- 	Fighter
	"armthund",	--	Bomber
	"armkam",	--	Light Gunship
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
