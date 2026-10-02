local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Rules = require("modules/transport/lib/rules")
local Traits = require("modules/transport/lib/traits")
local TransportEnums = require("modules/transport/enums")

---@class TransportApi
---@field IsCarried fun(unitID: integer): boolean
---@field CarrierOf fun(unitID: integer): integer|nil
---@field Cargo fun(transportID: integer): integer[]
---@field CanCarry fun(transportDefID: integer, unitDefID: integer, carriedMass: number|nil, carriedCount: integer|nil): boolean
---@field CanEverCarry fun(transportDefID: integer, unitDefID: integer): boolean
---@field CanLoad fun(transportID: integer, unitID: integer): boolean
---@field MayCarry fun(carrierDefID: integer, passengerID: integer, passengerDefID: integer): boolean the engine's pick-up question: may this carrier hold that passenger, where it stands
---@field MayOrderLoad fun(carrierID: integer, carrierDefID: integer, teamID: integer, targetID: integer): boolean a player's load order: the command question, with who owns the target
---@field MayOrderUnload fun(goalX: number, goalY: number, goalZ: number): boolean a player's order to set a nano turret down at the goal
---@field LoadedSpeed fun(carrierID: integer): number|nil elmos per frame the loaded carrier may fly; nil when it carries nothing
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
local TransportApi = {
	---@param unitID integer
	---@return boolean
	IsCarried = function(unitID)
		return Spring.GetUnitTransporter(unitID) ~= nil
	end,

	---@param unitID integer
	---@return integer|nil transportID
	CarrierOf = function(unitID)
		return Spring.GetUnitTransporter(unitID)
	end,

	---@param transportID integer
	---@return integer[]
	Cargo = function(transportID)
		return Spring.GetUnitIsTransporting(transportID) or {}
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

	---@param carrierDefID integer
	---@param passengerID integer
	---@param passengerDefID integer
	---@return boolean
	MayCarry = function(carrierDefID, passengerID, passengerDefID)
		---@type TransportContract
		local Transport = ModuleHandler.Contract(Modules.Transport)
		local _, y = Spring.GetUnitPosition(passengerID)
		return ModuleHandler.Evaluate(Transport.Load, {
			goalY = y,
			height = Spring.GetUnitHeight(passengerID),
			carrierDef = UnitDefs[carrierDefID],
			passengerDef = UnitDefs[passengerDefID],
		}) == true
	end,

	---@param carrierID integer
	---@param carrierDefID integer
	---@param teamID integer the carrier's team
	---@param targetID integer
	---@return boolean
	MayOrderLoad = function(carrierID, carrierDefID, teamID, targetID)
		---@type TransportContract
		local Transport = ModuleHandler.Contract(Modules.Transport)
		local targetTeam = Spring.GetUnitTeam(targetID)
		local targetDefID = Spring.GetUnitDefID(targetID)
		local _, y = Spring.GetUnitPosition(targetID)
		return ModuleHandler.Evaluate(Transport.Load, {
			goalY = y,
			height = Spring.GetUnitHeight(targetID),
			carrierDef = UnitDefs[carrierDefID],
			passengerDef = UnitDefs[targetDefID],
			allied = Spring.AreTeamsAllied(teamID, targetTeam),
			ownTeam = targetTeam == teamID,
			nano = Traits.Of(targetDefID).isNano,
			distance = 0,
			passengerSpeed = 0,
		}) == true
	end,

	---@param goalX number
	---@param goalY number
	---@param goalZ number
	---@return boolean
	MayOrderUnload = function(goalX, goalY, goalZ)
		---@type TransportContract
		local Transport = ModuleHandler.Contract(Modules.Transport)
		local _, normalY = Spring.GetGroundNormal(goalX, goalZ)
		return ModuleHandler.Evaluate(Transport.Unload, {
			goalY = goalY,
			height = 0,
			nano = true,
			groundNormalY = normalY,
		}) == true
	end,

	---@param carrierID integer
	---@return number|nil
	LoadedSpeed = function(carrierID)
		---@type TransportContract
		local Transport = ModuleHandler.Contract(Modules.Transport)
		local cargo = Spring.GetUnitIsTransporting(carrierID)
		if cargo == nil then
			return nil
		end
		local carriesCommander = false
		for _, unitID in ipairs(cargo) do
			local traits = Traits.OfUnit(unitID)
			if traits and traits.isCommander then
				carriesCommander = true
			end
		end
		return ModuleHandler.Evaluate(Transport.LoadedSpeed, {
			carriesCommander = carriesCommander,
			transportSpeed = Traits.OfUnit(carrierID).speed or 0,
			dragEnabled = Spring.GetModOptions()[TransportEnums.ModOptions.CommanderTransportSlow] == true,
			framesPerSecond = Game.gameSpeed,
		})
	end,
}

return TransportApi
