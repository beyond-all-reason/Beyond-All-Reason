-- Trigger Context Builder
-- Mocks the shared trigger context that api_missions_triggers.lua assembles in
-- gadget:Initialize() and passes to every trigger call-in handler.
--
-- Defaults model the ordinary case: names match, the build frame belongs to the
-- asking trigger, the frame is not in a factory, and activation succeeds. A spec
-- that cares about one of those replaces the function on the built context, which
-- is also how a test varies an answer part-way through.

---@class TriggerContextMock
---@field ActivateTrigger fun(trigger: table): boolean
---@field DoesUnitHaveName fun(unitID: number, name: string): boolean
---@field DoesFeatureHaveName fun(featureID: number, name: string): boolean
---@field IsBuildFrameOwner fun(unbuiltID: number, builderName: string?, builderDefName: string?): boolean
---@field InFactory fun(buildeeID: number): boolean
---@field ClaimConstructionStart fun(buildeeID: number, triggerID: string)
---@field HasConstructionStarted fun(buildeeID: number, triggerID: string): boolean
---@field WasUnderConstruction table<number, boolean>
---@field GetUnitsInArea fun(trigger: table): number[]
---@field IsFeatureInArea fun(featureID: number, area: table): boolean
---@field PreviousUnitsInAreas table
---@field ConstructionState table
---@field DwellingUnitsInAreas table
---@field GetReclaimIncomeSnapshot fun(teamID: number): table?
---@field calls TriggerContextMockCalls
---@field timesFired fun(): number

--- Recorded calls, keyed by the context function that produced them.
---@class TriggerContextMockCalls
---@field activateTrigger table

---@class TriggerContextBuilder
local TCB = {}
TCB.__index = TCB

---Constant values are wrapped, so `:WithInFactory(true)` and
---`:WithInFactory(function(id) ... end)` both work.
local function asFunction(value)
	if type(value) == "function" then
		return value
	end
	return function()
		return value
	end
end

---@return TriggerContextBuilder
function TCB.new()
	return setmetatable({
		inFactory = false,
		unitsInArea = {},
	}, TCB)
end

---Whether the build frame is a factory's, which separates production from construction.
---@param self TriggerContextBuilder
---@param value boolean|fun(buildeeID: number): boolean
---@return TriggerContextBuilder
function TCB:WithInFactory(value)
	self.inFactory = value
	return self
end

---The units a location trigger finds inside its area on each sweep.
---@param self TriggerContextBuilder
---@param unitIDs number[]|fun(trigger: table): number[]
---@return TriggerContextBuilder
function TCB:WithUnitsInArea(unitIDs)
	self.unitsInArea = unitIDs
	return self
end

---@param self TriggerContextBuilder
---@return TriggerContextMock
function TCB:Build()
	local instance = self

	local activateCalls = {}
	-- Mirrors constructionStarts in api_missions_triggers.lua: one claim per buildee.
	local constructionStarts = {}

	---@type TriggerContextMock
	local context = {
		ActivateTrigger = function(trigger)
			activateCalls[#activateCalls + 1] = { trigger = trigger }
			return true
		end,
		DoesUnitHaveName = asFunction(true),
		DoesFeatureHaveName = asFunction(true),
		IsBuildFrameOwner = asFunction(true),
		InFactory = asFunction(instance.inFactory),
		ClaimConstructionStart = function(buildeeID, triggerID)
			constructionStarts[buildeeID] = constructionStarts[buildeeID] or {}
			constructionStarts[buildeeID][triggerID] = true
		end,
		HasConstructionStarted = function(buildeeID, triggerID)
			local claims = constructionStarts[buildeeID]
			return claims and claims[triggerID]
		end,
		-- The gadget marks every unit it saw as a nanoframe; an index of nil is a unit
		-- that was spawned whole, which a spec models by replacing this with {}.
		WasUnderConstruction = setmetatable({}, {
			__index = function()
				return true
			end,
		}),
		GetUnitsInArea = asFunction(instance.unitsInArea),
		IsFeatureInArea = asFunction(true),
		PreviousUnitsInAreas = {},
		ConstructionState = {},
		DwellingUnitsInAreas = {},
		GetReclaimIncomeSnapshot = asFunction(nil),

		--- Recorded context calls, keyed by the function they came from.
		calls = {
			activateTrigger = activateCalls,
		},
	}

	---How many times a handler asked this context to activate its trigger.
	context.timesFired = function()
		return #activateCalls
	end

	return context
end

return TCB
