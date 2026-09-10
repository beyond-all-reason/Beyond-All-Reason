local Rules = VFS.Include("modules/transport/lib/rules.lua") ---@type TransportRules
local Traits = VFS.Include("modules/transport/lib/traits.lua") ---@type TransportTraits
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
---@field CanLoad fun(transportID: integer, unitID: integer): boolean
---@field MayLoad fun(ctx: TransportLoadContext): boolean
---@field DefTraits fun(unitDefID: integer): TransportDefTraits a known def; the id must name one
---@field UnitTraits fun(unitID: integer|nil): TransportDefTraits|nil the live unit's def traits

local pairVerdicts = {} ---@type table<integer, table<integer, boolean>> carrier def -> passenger def -> may it ever

---@param transportDefID integer
---@param unitDefID integer
---@return boolean
local function canEverCarry(transportDefID, unitDefID)
	local perCarrier = pairVerdicts[transportDefID]
	if perCarrier == nil then
		perCarrier = {}
		pairVerdicts[transportDefID] = perCarrier
	end
	local verdict = perCarrier[unitDefID]
	if verdict == nil then
		verdict = Rules.CanCarry(Traits.Of(transportDefID), Traits.Of(unitDefID))
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

	---@param transportDefID integer
	---@param unitDefID integer
	---@param carriedMass number|nil
	---@param carriedCount integer|nil
	---@return boolean
	CanCarry = function(transportDefID, unitDefID, carriedMass, carriedCount)
		return Rules.CanCarry(Traits.Of(transportDefID), Traits.Of(unitDefID), carriedMass, carriedCount)
	end,

	DefTraits = Traits.Of,
	UnitTraits = Traits.OfUnit,

	CanEverCarry = canEverCarry,

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
		if not canEverCarry(transportDefID, unitDefID) then
			return false
		end
		local cargo = Spring.GetUnitIsTransporting(transportID) or {}
		local carriedMass = 0 ---@type number
		for _, carriedID in ipairs(cargo) do
			local traits = Traits.OfUnit(carriedID)
			if traits then
				carriedMass = carriedMass + traits.mass
			end
		end
		return Rules.CanCarry(Traits.Of(transportDefID), Traits.Of(unitDefID), carriedMass, #cargo)
	end,

	---@param ctx TransportLoadContext
	---@return boolean
	MayLoad = function(ctx)
		local pipelines = ModuleHandler.LoadPolicies(Modules.Transport) ---@type TransportPipelines
		return ModuleHandler.Evaluate(pipelines.load, ctx) == true
	end,
}
