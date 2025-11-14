local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Reactive Armor",
		desc    = "Ablative/reactive armor that degrades and restores.",
		author  = "efrec",
		version = "0.1.0",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = -100, -- early or late so armored state is consistent across damage events
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Configuration

local armorBreakMethod = "ReactiveArmorBreak"
local armorRestoreMethod = "ReactiveArmorRestore"
local unitCombatDuration = math.round(5 * Game.gameSpeed) -- ! Can conflict with units' restore times.
local unitUpdateInterval = math.round((1 / 6) * Game.gameSpeed)

-- Localization

local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local spCallCobScript = Spring.CallCOBScript
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitRulesParam = Spring.SetUnitRulesParam

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

		-- Units that are damaged are definitionally "in combat", so reduce the
		-- restore duration by the duration of non-regeneration due to combat:
		params.frames = math.max(params.frames - unitCombatDuration, 0)

		armoredUnitDefs[unitDefID] = params
	end
end

local callFromLus = Spring.UnitScript.CallAsUnit
local callFromCob = function(unitID, funcName, ...)
	spCallCobScript(unitID, funcName, 0, ...) -- to add arg count 0
end

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

	if (params.pieces - 1) * gameSpeed > params.frames then
		-- Armor pieces regenerate once per second until the end of the armor restore duration.
		Spring.Log("Reactive Armor", LOG.ERROR, ("Too many armor pieces (%d) for restore time: "):format(params.pieces, UnitDefs[unitDefID].name))
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
		params[name] = pieceNames
	end

	-- Fix for the different argument types used between COB and LUS.
	params.call = (not lusEnv and callFromCob) or (
		function(unitID, funcName, ...)
			callFromLus(unitID, lusEnv[funcName], ...)
		end
	)

	return true
end

-- Local state

local unitArmorHealth = table.new(0, 2 ^ 6) -- (Positive) health in each unit's reactive armor health pools
local unitArmorFrames = table.new(0, 2 ^ 6) -- Set of frames when the unit's armor pieces will be recovered
local regenerateFrame = table.new(0, 2 ^ 6) -- Next frame that the unit will begin or resume armor recovery

local gameFrame = 0
local combatEndFrame = gameFrame + unitCombatDuration

---@return table<"countdown"|integer, integer> restoreFrames
local function getArmorRestoreFrames(defData)
	local armorPieceCount = defData.pieces
	local restoreDuration = defData.frames

	if armorPieceCount == 1 then
		return { countdown = restoreDuration, [0] = true } -- special case
	else
		local frames = table.new(0, armorPieceCount + 1)
		frames.countdown = restoreDuration
		for piece = 1, armorPieceCount do
			local framesRemaining = gameSpeed * (piece - 1)
			frames[framesRemaining] = piece
		end
		return frames
	end
end

local function doArmorDamage(unitID, unitDefID, damage)
	local armorHealthOld = unitArmorHealth[unitID]
	local defData = armoredUnitDefs[unitDefID]

	if not armorHealthOld or not defData then
		return false
	end

	local armorHealthNew = armorHealthOld - damage
	local armorHealthMax = defData.health
	local armorPieceCount = defData.pieces

	if armorPieceCount > 1 then
		local armorPieceOld = math_floor(armorPieceCount * (armorHealthMax - armorHealthOld) / armorHealthMax)
		local armorPieceNew = math_floor(armorPieceCount * (armorHealthMax - armorHealthNew) / armorHealthMax)

		if armorPieceOld ~= armorPieceNew then
			local startPiece, lastPiece, step, pieceMethods

			if damage > 0 then
				startPiece = armorPieceOld + 1
				lastPiece = math_min(armorPieceNew, armorPieceCount)
				step = 1
				pieceMethods = defData[armorBreakMethod]
			else
				startPiece = armorPieceOld
				lastPiece = math_max(armorPieceNew + 1, 1)
				step = -1
				pieceMethods = defData[armorRestoreMethod]
			end

			for i = startPiece, lastPiece, step do
				defData.call(unitID, pieceMethods[i])
			end
		end
	end

	if armorHealthNew <= 0 then
		unitArmorHealth[unitID] = nil
		defData.call(unitID, damage > 0 and armorBreakMethod or armorRestoreMethod)
		spSetUnitRulesParam(unitID, "reactiveArmorHealth", false)
	else
		unitArmorHealth[unitID] = math_min(armorHealthNew, armorHealthMax) -- limit healing
		spSetUnitRulesParam(unitID, "reactiveArmorHealth", armorHealthNew)

		if damage > 0 and not unitArmorFrames[unitID] then
			unitArmorFrames[unitID] = getArmorRestoreFrames(defData)
		end
	end

	return true
end

local function restoreUnitArmor(unitID, piece)
	local defData = armoredUnitDefs[spGetUnitDefID(unitID)]

	if piece ~= true then
		defData.call(unitID, defData[armorRestoreMethod][piece])
	end

	if piece == true or piece <= 1 then
		unitArmorFrames[unitID] = nil
		unitArmorHealth[unitID] = defData.health
		defData.call(unitID, armorRestoreMethod)
		spSetUnitRulesParam(unitID, "reactiveArmorHealth", defData.health)
	end
end

local function updateArmoredUnits(frame)
	local interval = unitUpdateInterval -- localize
	local regenerate = regenerateFrame -- localize

	-- Error correction for (n-1) frames inaccuracy:
	frame = frame - math_floor((interval - 1) * 0.5)

	for unitID, data in pairs(unitArmorFrames) do
		local frameCheck = regenerate[unitID] or 0

		if frameCheck <= frame then
			local countdown = data.countdown
			data.countdown = countdown - interval
			frameCheck = math.max(frameCheck, frame + countdown - interval)

			for i = countdown, countdown - interval + 1, -1 do
				if data[i] then
					restoreUnitArmor(unitID, data[i])
					data[i] = nil -- may as well
				end
			end
		end
	end
end

-- Engine callins

function gadget:GameFrame(frame)
	gameFrame = frame

	combatEndFrame = frame + unitCombatDuration

	if frame % unitUpdateInterval == 0 then
		updateArmoredUnits(frame)
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam, builderID)
	if armoredUnitDefs[unitDefID] then
		local defData = armoredUnitDefs[unitDefID]
		if not defData.first or checkReactiveArmor(unitID, unitDefID, defData) then
			unitArmorHealth[unitID] = defData.health
			spSetUnitRulesParam(unitID, "reactiveArmorHealth", defData.health)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitArmorFrames[unitID] = nil
	unitArmorHealth[unitID] = nil
	regenerateFrame[unitID] = nil
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if armoredUnitDefs[unitDefID] and not paralyzer and damage > 0 then
		doArmorDamage(unitID, unitDefID, damage)
		regenerateFrame[unitID] = combatEndFrame
	end
end

-- Lifecycle

---Damage (or repair!) a unit's reactive armor directly, without damaging the unit.
GG.AddReactiveArmorDamage = function(unitID, damage)
	return doArmorDamage(unitID, spGetUnitDefID(unitID), damage)
end

---Get the current armor health remaining of a unit with reactive armor.
GG.GetReactiveArmorHealth = function(unitID)
	return unitArmorHealth[unitID]
end

function gadget:Initialize()
	if not next(armoredUnitDefs) then
		gadgetHandler:RemoveGadget()
		return
	end

	callFromLus = Spring.UnitScript.CallAsUnit
	gameFrame = Spring.GetGameFrame()
	combatEndFrame = gameFrame + unitCombatDuration

	if gameFrame <= 0 then
		return
	end

	-- We handle `/luarules reload` mostly correctly except for out-of-combat timers.

	-- See getArmorRestoreFrames. This might be its poor copy.
	local function resetArmorRestoreFrames(defData, progress)
		local pieces = defData.pieces
		local frames = defData.frames
		if pieces == 1 then
			return { countdown = frames, [0] = true }
		else
			local restoreFrames = table.new(0, pieces + 1)
			restoreFrames.countdown = frames
			for piece = 1, pieces do
				local framesRemaining = gameSpeed * (piece - 1)
				if framesRemaining <= frames then
					restoreFrames[framesRemaining] = piece
				end
			end
			return restoreFrames
		end
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			local defData = armoredUnitDefs[spGetUnitDefID(unitID)]

			if defData then
				local armorHealth = Spring.GetUnitRulesParam(unitID, "reactiveArmorHealth")

				gadget:UnitFinished(unitID, spGetUnitDefID(unitID)) -- replaces rules params

				if armorHealth and armorHealth < defData.health then
					unitArmorFrames[unitID] = nil -- we forget our next regeneration frame :c
					unitArmorHealth[unitID] = armorHealth
					spSetUnitRulesParam(unitID, "reactiveArmorHealth", armorHealth)
				else
					unitArmorFrames[unitID] = resetArmorRestoreFrames(defData)
					unitArmorHealth[unitID] = nil
					spSetUnitRulesParam(unitID, "reactiveArmorHealth", false)
				end
			end
		end
	end
end

function gadget:Shutdown()
	GG.AddReactiveArmorDamage = function() return false end
	GG.GetReactiveArmorHealth = function() end
end
