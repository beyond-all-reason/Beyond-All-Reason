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
local coreconstructionbot = {
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

local armconstructionbot = {
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

local corebotlab = {
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

local armbotlab = {
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
	-- we can assign 1 list, to multiple unit types, here a construction bot (corck) gets the construction bot tasklist, but then we assign it to the construction vehicle too (corcv))
	corck = coreconstructionbot,
	corcv = coreconstructionbot,
	armcom = armcommander,
	armck = armconstructionbot,
	corlab = corebotlab,
	armlab = armbotlab,
}
