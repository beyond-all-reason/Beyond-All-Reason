local Boxes = require("modules/start/lib/boxes")
local Export = require("modules/start/lib/export")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Placement = require("modules/start/lib/placement")
local Positions = require("modules/start/lib/positions")

---@return StartboxConfig
local function resolveWithGame()
	local StartboxLib = require("luarules/gadgets/include/startbox_utilities")
	local config, source, explicit = StartboxLib.GetConfig()
	return { byAllyTeam = config, source = source, explicit = explicit == true }
end

---@class StartApi
return {
	Export = Export,
	Placement = Placement,

	---@param springRepo Spring
	---@param resolveBoxes (fun(): StartboxConfig)|nil
	---@return { areas: StartRegion[], positions: StartPosition[] }
	Current = function(springRepo, resolveBoxes)
		---@type StartContext
		local ctx = {
			springRepo = springRepo,
			modOptions = springRepo.GetModOptions(),
			areas = Boxes.Resolve(springRepo, (resolveBoxes or resolveWithGame)()),
			positions = Positions.Read(springRepo),
		}
		---@type StartContract
		local Start = ModuleHandler.Contract(Modules.Start)
		local Facts = Start.Facts
		local facts = ModuleHandler.Enrich(Facts, ctx)
		return { areas = facts[Facts.Areas] or {}, positions = facts[Facts.Positions] or {} }
	end,
}
