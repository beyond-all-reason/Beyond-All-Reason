local Rules = VFS.Include("modules/transport/lib/rules.lua") ---@type TransportRules
local Defs = VFS.Include("modules/transport/lib/defs.lua") ---@type TransportDefs
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.Transport
	assert(surface ~= nil, "Transport." .. name .. " called before the transport_rules gadget initialized")
	return surface
end

---@class TransportApi
---@field IsCarried fun(unitID: integer): boolean
---@field CarrierOf fun(unitID: integer): integer|nil
---@field Cargo fun(transportID: integer): integer[]
---@field CanCarry fun(transportDefID: integer, unitDefID: integer, carriedMass: number|nil, carriedCount: integer|nil): boolean
---@field CanEverCarry fun(transportDefID: integer, unitDefID: integer): boolean
---@field MayLoad fun(ctx: TransportLoadContext): boolean
---@field DefFacts fun(unitDefID: integer|nil): TransportDefFacts|nil

local canEverCarry = {} ---@type table<integer, table<integer, boolean>>

---@type TransportApi
return {
	---@param unitID integer
	---@return boolean
	IsCarried = function(unitID)
		return gadgetSurface("IsCarried").IsCarried(unitID)
	end,

	---@param unitID integer
	---@return integer|nil transportID
	CarrierOf = function(unitID)
		return gadgetSurface("CarrierOf").CarrierOf(unitID)
	end,

	---@param transportID integer
	---@return integer[]
	Cargo = function(transportID)
		return gadgetSurface("Cargo").Cargo(transportID)
	end,

	---No gadget behind these two: pure def math and the load pipeline, so
	---widgets may ask before they order.
	---@param transportDefID integer
	---@param unitDefID integer
	---@param carriedMass number|nil
	---@param carriedCount integer|nil
	---@return boolean
	CanCarry = function(transportDefID, unitDefID, carriedMass, carriedCount)
		local transportDef, unitDef = UnitDefs[transportDefID], UnitDefs[unitDefID]
		return transportDef ~= nil
			and unitDef ~= nil
			and Rules.CanCarry(transportDef, unitDef, carriedMass, carriedCount)
	end,

	DefFacts = Defs.Of,

	---Def-pair verdict, memoized: could this carrier ever lift this def,
	---empty and unburdened?
	---@param transportDefID integer
	---@param unitDefID integer
	---@return boolean
	CanEverCarry = function(transportDefID, unitDefID)
		local perCarrier = canEverCarry[transportDefID]
		if perCarrier == nil then
			perCarrier = {}
			canEverCarry[transportDefID] = perCarrier
		end
		local verdict = perCarrier[unitDefID]
		if verdict == nil then
			local transportDef, unitDef = UnitDefs[transportDefID], UnitDefs[unitDefID]
			verdict = transportDef ~= nil and unitDef ~= nil and Rules.CanCarry(transportDef, unitDef)
			perCarrier[unitDefID] = verdict
		end
		return verdict
	end,

	---@param ctx TransportLoadContext
	---@return boolean
	MayLoad = function(ctx)
		local pipelines = ModuleHandler.LoadPolicies(Modules.Transport) ---@type TransportPipelines
		return ModuleHandler.Evaluate(pipelines.load, ctx) == true
	end,
}
