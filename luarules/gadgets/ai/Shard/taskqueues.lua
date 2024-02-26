--[[
 Task Queues!
]]--

math.randomseed( os.time() )
math.random(); math.random(); math.random()

function CoreWindSolar( taskqueuebehaviour )
	if taskqueuebehaviour.ai.map:AverageWind() > 10 then
		return "cortex_windturbined"
	else
		return "cortex_solarcollector"
	end
end
function randomLab( taskqueuebehaviour )
	local r = math.random(0,2)
	if r == 0 then
		return "cortex_botlab"
	elseif r == 1 then
		return "cortex_vehicleplant"
	else
		return "cortex_aircraftplant"
	end
end

local corecommanderlist = {
	CoreWindSolar,
	"cortex_metalextractor",
	CoreWindSolar,
	"cortex_metalextractor",
	"cortex_metalextractor",
	randomLab,
	"cortex_guard",
	"cortex_radartower",
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	"cortex_metalextractor",
	"cortex_metalextractor",
	"cortex_metalextractor",
	"cortex_guard",
	CoreWindSolar,
}
local coreconstructionbot = {
	CoreWindSolar,
	"cortex_metalextractor",
	CoreWindSolar,
	"cortex_metalextractor",
	"cortex_metalextractor",
	"cortex_guard",
	"cortex_radartower",
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	CoreWindSolar,
	"cortex_metalextractor",
	"cortex_metalextractor",
	"cortex_metalextractor",
	"cortex_guard",
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
	-- we can assign 1 list, to multiple unit types, here a construction bot (cortex_constructionbot) gets the construction bot tasklist, but then we assign it to the construction vehicle too (cortex_constructionvehicle))
	cortex_constructionbot = coreconstructionbot,
	cortex_constructionvehicle = coreconstructionbot,
	armada_commander = armada_commandermander,
	armada_constructionbot = armconstructionbot,
	cortex_botlab = corebotlab,
	armada_botlab = armbotlab,
}
