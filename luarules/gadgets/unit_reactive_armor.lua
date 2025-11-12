local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Reactive Armor",
		desc    = "Ablative/reactive armor that degrades and restores.",
		author  = "efrec",
		version = "0.1.0",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = -100, -- either early or late for removing armored state during damage events (should be consistent)
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- todo: Set UnitRulesParams for GUI and for reloads

-- Configuration

local armorBreakMethod = "ReactiveArmorBreak"
local armorRestoreMethod = "ReactiveArmorRestore"

-- Localization

local math_floor = math.floor
local math_min = math.min

local callAsUnit = Spring.UnitScript.CallAsUnit
local gameSpeed = Game.gameSpeed

-- Initialization

local armoredUnitDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.reactive_armor_health and unitDef.customParams.reactive_armor_restore then
		local params = {
			health = tonumber(unitDef.customParams.reactive_armor_health),
			frames = tonumber(unitDef.customParams.reactive_armor_restore) * gameSpeed,
			first  = true,
		}
		armoredUnitDefs[unitDefID] = params
	end
end

-- Local state

local unitArmorDamage = {}
local unitArmorBroken = {}

-- We verify unit scripts on unit creation (really, completion)
-- since that is the first time the game gives us info on them.
local function checkReactiveArmor(unitID, unitDefID, params)
	local hasMethod
	local lusEnv = Spring.UnitScript.GetScriptEnv(unitID)

	if lusEnv then
		hasMethod = function(name)
			return lusEnv[name] ~= nil
		end
	else
		hasMethod = function(name)
			return Spring.GetCOBScriptID(unitID, name) ~= nil
		end
	end

	local methods = { armorBreakMethod, armorRestoreMethod }
	local missing = {}

	for _, method in ipairs(methods) do
		if not hasMethod(method) then
			missing[#missing + 1] = method
		end
	end

	local pieces = 1

	repeat
		local found = 0
		for _, method in ipairs(methods) do
			if hasMethod(method .. pieces) then
				found = found + 1
			end
		end
		if found == 0 then
			-- pieces == 1 has no individual piece methods
			params.pieces = pieces == 1 and 1 or pieces - 1
			break
		elseif found < table.count(methods) then
			for _, method in ipairs(methods) do
				if not hasMethod(method .. pieces) then
					missing[#missing + 1] = method
				end
			end
		else
			pieces = pieces + 1
		end
	until false

	local success = true

	if next(missing) then
		-- The unit script is malformed in some way and we make no attempts to recover it.
		Spring.Log("Reactive Armor", LOG.ERROR, ("Unit script missing %s: %s"):format(table.concat(missing, ", "), UnitDefs[unitDefID].name))
		success = false
	end

	if (params.pieces - 1) * gameSpeed < params.frames then
		-- Armor pieces regenerate once per second until the end of the armor restore duration.
		Spring.Log("Reactive Armor", LOG.ERROR, "Too many armor pieces for restore time: " .. UnitDefs[unitDefID].name)
		success = false
	end

	if not success then
		armoredUnitDefs[unitDefID] = nil
		return false
	end

	-- Premake strings. Lua has overheads when doing string operations.
	for _, name in ipairs(methods) do
		local pieceNames = {}
		for i = 1, params.pieces do
			pieceNames[i] = name .. i
		end
		params.name = pieceNames
	end

	-- Fix for the different argument types used between COB and LUS.
	params.call = (not lusEnv and Spring.CallCOBScript) or (
		function(unitID, funcName, ...)
			callAsUnit(unitID, lusEnv[funcName], ...)
		end
	)

	return true
end

local function getRestoreFrames(unitData)
	local lastFrame = Spring.GetGameFrame() + unitData.frames

	if unitData.pieces == 1 then
		return { [lastFrame] = true } -- no piece numbers
	else
		local frames = { [lastFrame] = 1 } -- in reverse order
		local pieces = unitData.pieces
		for i = 1, pieces - 1 do
			frames[lastFrame - gameSpeed * i] = pieces - i
		end
		return frames
	end
end

local function addArmorDamage(unitID, unitDefID, damage)
	local unitData = armoredUnitDefs[unitDefID]
	local armorHealth = unitData.health
	local armorDamage = unitArmorDamage[unitID]

	if unitData.pieces > 1 then
		local pieceNumberOld = math_floor(1 + armorDamage / armorHealth)
		local pieceNumberNew = math_floor(1 + (armorDamage + damage) / armorHealth)

		if pieceNumberOld ~= pieceNumberNew then
			local names = unitData[armorBreakMethod] -- call a list of script methods
			for i = pieceNumberOld, math_min(pieceNumberNew, unitData.pieces) - 1 do
				unitData.call(unitID, names[i]) -- in either LUS or COB
			end
		end
	end

	if armorDamage + damage >= armorHealth then
		unitArmorDamage[unitID] = nil
		unitArmorBroken[unitID] = getRestoreFrames(unitData)
		unitData.call(unitID, armorBreakMethod)
	end
end

local function restoreUnitArmor(unitID, info)
	local unitData = armoredUnitDefs[Spring.GetUnitDefID(unitID)]

	if type(info) == "number" then
		unitData.call(unitID, unitData[armorRestoreMethod][info])
	end

	if info == 1 or info == true then
		unitArmorBroken[unitID] = nil
		unitArmorDamage[unitID] = 0
		unitData.call(unitID, armorRestoreMethod)
	end
end

-- Engine callins

function gadget:Initialize()
	callAsUnit = Spring.UnitScript.CallAsUnit

	if not next(armoredUnitDefs) then
		gadgetHandler:RemoveGadget()
		return
	end

	-- Handles /luarules reload (badly):
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			gadget:UnitFinished(unitID, Spring.GetUnitDefID(unitID))
		end
	end
end

function gadget:GameFrame(frame)
	-- not very efficient:
	for unitID, data in pairs(unitArmorBroken) do
		if data[frame] then
			restoreUnitArmor(unitID, data[frame])
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam, builderID)
	if armoredUnitDefs[unitDefID] then
		local params = armoredUnitDefs[unitDefID]
		if not params.first or checkReactiveArmor(unitID, params) then
			unitArmorDamage[unitID] = 0
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitArmorBroken[unitID] = nil
	unitArmorDamage[unitID] = nil
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if not paralyzer and unitArmorDamage[unitID] and damage > 0 then
		addArmorDamage(unitID, unitDefID, damage)
	end
end
