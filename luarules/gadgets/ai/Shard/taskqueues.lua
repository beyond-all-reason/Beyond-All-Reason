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

local armada_commandermander = {
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_metalextractor",
	"armada_botlab",
	"armada_sentry",
	"armada_radartower",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_metalextractor",
	"armada_sentry",
	"armada_botlab",
	"armada_radartower",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_solarcollector",
}

local armconstructionbot = {
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_metalextractor",
	"armada_botlab",
	"armada_sentry",
	"armada_radartower",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_solarcollector",
	"armada_metalextractor",
	"armada_metalextractor",
	"armada_sentry",
	"armada_botlab",
	"armada_radartower",
	"armada_solarcollector",
	"armada_solarcollector",
	"armada_solarcollector",
}

local corebotlab = {
	"cortex_constructionbot",
	"cortex_constructionbot",
	"cortex_constructionbot",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
	"cortex_grunt",
}

local armbotlab = {
	"armada_constructionbot",
	"armada_constructionbot",
	"armada_constructionbot",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
	"armada_pawn",
}
taskqueues = {
	-- unittype = tasklist,
	cortex_commander = corecommanderlist,
	-- we can assign 1 list, to multiple unit types, here a construction bot (cortex_constructionbot) gets the construction bot tasklist, but then we assign it to the construction vehicle too (corcv))
	cortex_constructionbot = coreconstructionbot,
	corcv = coreconstructionbot,
	armada_commander = armada_commandermander,
	armada_constructionbot = armconstructionbot,
	corlab = corebotlab,
	armada_botlab = armbotlab,
}
