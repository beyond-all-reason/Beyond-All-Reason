local Rules = VFS.Include("modules/transport/lib/rules.lua") ---@type TransportRules
local Defs = VFS.Include("modules/transport/lib/defs.lua") ---@type TransportDefs
local ModuleHandler = VFS.Include("modules/module_handler.lua")

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
---@field CanLoad fun(transportID: integer, unitID: integer): boolean
---@field MayLoad fun(ctx: TransportLoadContext): boolean
---@field DefFacts fun(unitDefID: number|nil): TransportDefFacts|nil
---@field UnitFacts fun(unitID: integer|nil): TransportDefFacts|nil the live unit's def facts

local canEverCarry = {} ---@type table<integer, table<integer, boolean>>

---Memoized static pair verdict, on facts: the engine proxy is never touched
---after each def's first read.
---@param transportDefID integer
---@param unitDefID integer
---@return boolean
local function canEverCarryOf(transportDefID, unitDefID)
	local perCarrier = canEverCarry[transportDefID]
	if perCarrier == nil then
		perCarrier = {}
		canEverCarry[transportDefID] = perCarrier
	end
	local verdict = perCarrier[unitDefID]
	if verdict == nil then
		local transportFacts, unitFacts = Defs.Of(transportDefID), Defs.Of(unitDefID)
		verdict = transportFacts ~= nil and unitFacts ~= nil and Rules.CanCarry(transportFacts, unitFacts)
		perCarrier[unitDefID] = verdict
	end
	return verdict
end

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
		local transportFacts, unitFacts = Defs.Of(transportDefID), Defs.Of(unitDefID)
		return transportFacts ~= nil
			and unitFacts ~= nil
			and Rules.CanCarry(transportFacts, unitFacts, carriedMass, carriedCount)
	end,

	DefFacts = Defs.Of,
	UnitFacts = Defs.OfUnit,

	CanEverCarry = canEverCarryOf,

	---The live verdict: what this carrier, as burdened right now, can lift.
	---Engine state is read per call, never mirrored.
	---@param transportID integer
	---@param unitID integer
	---@return boolean
	CanLoad = function(transportID, unitID)
		local transportDefID = Spring.GetUnitDefID(transportID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		if transportDefID == nil or unitDefID == nil then
			return false
		end
		---@cast transportDefID integer
		---@cast unitDefID integer
		if not canEverCarryOf(transportDefID, unitDefID) then
			return false
		end
		local cargo = Spring.GetUnitIsTransporting(transportID) or {}
		local carriedMass = 0 ---@type number
		for _, carriedID in ipairs(cargo) do
			local facts = Defs.OfUnit(carriedID)
			if facts then
				carriedMass = carriedMass + facts.mass
			end
		end
		local transportFacts, unitFacts = Defs.Of(transportDefID), Defs.Of(unitDefID)
		return transportFacts ~= nil
			and unitFacts ~= nil
			and Rules.CanCarry(transportFacts, unitFacts, carriedMass, #cargo)
	end,

	---@param ctx TransportLoadContext
	---@return boolean
	MayLoad = function(ctx)
		local pipelines = ModuleHandler.LoadPolicies("transport") ---@type TransportPipelines
		return ModuleHandler.Evaluate(pipelines.load, ctx) == true
	end,
}
