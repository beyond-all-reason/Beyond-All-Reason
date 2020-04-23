--[[
 Task Queues!
]]--

math.randomseed( os.time() )
math.random(); math.random(); math.random()

function CoreWindSolar( taskqueuebehaviour )
	if taskqueuebehaviour.ai.map:AverageWind() > 10 then
		return "corwind"
	else
		return "corsolar"
	end
end
function randomLab( taskqueuebehaviour )
	local r = math.random(0,2)
	if r == 0 then
		return "corlab"
	elseif r == 1 then
		return "corvp"
	else
		return "corap"
	end
end

local corecommanderlist = {
	CoreWindSolar,
	"cormex",
	CoreWindSolar,
	"cormex",
	"cormex",
	randomLab,
	"corllt",
	"corrad",
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	"cormex",
	"cormex",
	"cormex",
	"corllt",
	CoreWindSolar,
}
local coreconstructionkbot = {
	CoreWindSolar,
	"cormex",
	CoreWindSolar,
	"cormex",
	"cormex",
	"corllt",
	"corrad",
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	"cormex",
	"cormex",
	"cormex",
	"corllt",
	CoreWindSolar,
}

local armcommander = {
	"armsolar",
	"armmex",
	"armsolar",
	"armmex",
	"armmex",
	"armlab",
	"armllt",
	"armrad",
	"armsolar",
	"armsolar",
	"armsolar",
	"armsolar",
	"armmex",
	"armsolar",
	"armmex",
	"armmex",
	"armllt",
	"armlab",
	"armrad",
	"armsolar",
	"armsolar",
	"armsolar",
}

local armconstructionkbot = {
	"armsolar",
	"armmex",
	"armsolar",
	"armmex",
	"armmex",
	"armlab",
	"armllt",
	"armrad",
	"armsolar",
	"armsolar",
	"armsolar",
	"armsolar",
	"armmex",
	"armsolar",
	"armmex",
	"armmex",
	"armllt",
	"armlab",
	"armrad",
	"armsolar",
	"armsolar",
	"armsolar",
}

local corekbotlab = {
	"corck",
	"corck",
	"corck",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
	"corak",
}

local armkbotlab = {
	"armck",
	"armck",
	"armck",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
	"armpw",
}
taskqueues = {
	-- unittype = tasklist,
	corcom = corecommanderlist,
	-- we can assign 1 list, to multiple unit types, here a construction kbot (corck) gets the construction kbot tasklist, but then we assign it to the construction vehicle too (corcv))
	corck = coreconstructionkbot,
	corcv = coreconstructionkbot,
	armcom = armcommander,
	armck = armconstructionkbot,
	corlab = corekbotlab,
	armlab = armkbotlab,
}
