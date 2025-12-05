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
local unitCombatDuration = math.round(5 * Game.gameSpeed) -- Also sets the minimum `reactive_armor_restore`.
local unitUpdateInterval = math.round((1 / 6) * Game.gameSpeed)

-- Localization

local table_new = table.new
local math_floor = math.floor
local math_clamp = math.clamp

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

local unitArmorHealth = table_new(0, 2 ^ 6) -- (Positive) health in each unit's reactive armor health pools
local unitArmorFrames = table_new(0, 2 ^ 6) -- Set of frames when the unit's armor pieces will be recovered
local regenerateFrame = table_new(0, 2 ^ 6) -- Next frame that the unit will begin or resume armor recovery

local gameFrame = 0
local combatEndFrame = gameFrame + unitCombatDuration

---@return table<"countdown"|integer, integer> restoreFrames
local function getArmorRestoreFrames(defData, duration)
	local armorPieceCount = defData.pieces
	local restoreDuration = duration or defData.frames

	if armorPieceCount == 1 then
		return { countdown = restoreDuration, [0] = true } -- special case
	else
		local frames = table_new(0, armorPieceCount + 1)
		frames.countdown = restoreDuration
		for piece = 1, armorPieceCount do
			local framesRemaining = gameSpeed * (piece - 1)
			frames[framesRemaining] = piece
		end
		return frames
	end
end

local function doArmorDamage(unitID, defData, damage)
	local armorHealthOld = unitArmorHealth[unitID]
	local armorHealthMax = defData.health
	local armorPieceCount = defData.pieces

	if damage > 0 then
		regenerateFrame[unitID] = combatEndFrame
	elseif armorHealthOld == armorHealthMax then
		return false
	end

	if armorHealthOld == nil then
		return false -- neither damage nor repair occurs when armor is broken
	end

	local armorHealthNew = math_clamp(armorHealthOld - damage, 0, armorHealthMax)

	if armorPieceCount > 1 then
		local armorPieceOld = math_floor(armorPieceCount * (armorHealthMax - armorHealthOld) / armorHealthMax)
		local armorPieceNew = math_floor(armorPieceCount * (armorHealthMax - armorHealthNew) / armorHealthMax)

		if armorPieceOld ~= armorPieceNew then
			local startPiece, lastPiece, step, pieceMethods

			if damage > 0 then
				startPiece = armorPieceOld + 1
				lastPiece = armorPieceNew
				step = 1
				pieceMethods = defData[armorBreakMethod]
			else
				startPiece = armorPieceOld
				lastPiece = armorPieceNew + 1
				step = -1
				pieceMethods = defData[armorRestoreMethod]
			end

			for i = startPiece, lastPiece, step do
				defData.call(unitID, pieceMethods[i])
			end
		end
	end

	local armorRestoreFrames = unitArmorFrames[unitID]

	if armorHealthNew == 0 then
		unitArmorHealth[unitID] = nil
		spSetUnitRulesParam(unitID, "reactiveArmorHealth", false) -- not 0 to hide healthbar
		defData.call(unitID, armorBreakMethod)

		if armorRestoreFrames then
			armorRestoreFrames.countdown = defData.frames
		else
			unitArmorFrames[unitID] = getArmorRestoreFrames(defData)
		end
	elseif armorHealthNew < armorHealthMax then
		unitArmorHealth[unitID] = armorHealthNew
		spSetUnitRulesParam(unitID, "reactiveArmorHealth", armorHealthNew)

		if armorRestoreFrames then
			local frames, framesMax = armorRestoreFrames.countdown, defData.frames
			armorRestoreFrames.countdown = math_clamp(frames + math_floor(framesMax * damage / defData.health), 0, framesMax)
		elseif not armorRestoreFrames and damage > 0 then
			unitArmorFrames[unitID] = getArmorRestoreFrames(defData) -- start armor restore timer
		end
	else
		unitArmorHealth[unitID] = armorHealthMax
		spSetUnitRulesParam(unitID, "reactiveArmorHealth", armorHealthMax)

		if armorRestoreFrames then
			unitArmorFrames[unitID] = nil
			defData.call(unitID, armorRestoreMethod)
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
	local regenerate, interval = regenerateFrame, unitUpdateInterval -- localize

	-- Error correction for (n-1) frames inaccuracy:
	frame = frame - math_floor((interval - 1) * 0.5)

	for unitID, data in pairs(unitArmorFrames) do
		if regenerate[unitID] <= frame then
			local countdown = data.countdown
			data.countdown = countdown - interval
			for i = countdown, countdown - interval + 1, -1 do
				if data[i] then
					restoreUnitArmor(unitID, data[i])
				end
			end
		end
	end
end

local debugReloads = false

local function getUnitDebugInfo(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	local x, y, z = Spring.GetUnitPosition(unitID)
	return {
		x = x,
		y = y,
		z = z,
		unitID        = unitID,
		unitDefID     = unitDefID,
		unitDefName   = UnitDefs[unitDefID].name,
		unitDefParams = armoredUnitDefs[unitDefID] or "none",
		health        = Spring.GetUnitHealth(unitID),
		armorFrames   = unitArmorFrames[unitID] or "nil",
		armorHealth   = unitArmorHealth[unitID] or "nil",
		inCombatUntil = regenerateFrame[unitID] or "nil",
		unitCountdown = unitArmorFrames[unitID] and unitArmorFrames[unitID].countdown or "nil",
	}
end

local function showDebugInfo(unitID)
	local info = getUnitDebugInfo(unitID)
	if info.unitCountdown then
		local display = ("hp:%s res:%s"):format(tostring(info.armorHealth), tostring(info.unitCountdown))
		Spring.MarkerAddPoint(info.x, info.y, info.z, display)
		Spring.Echo("Reactive Armor", info)
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
	if not paralyzer and damage > 0 and armoredUnitDefs[unitDefID] then
		doArmorDamage(unitID, armoredUnitDefs[unitDefID], damage)
	end
end

-- Lifecycle

---Damages or repairs a unit's reactive armor without changing unit health.
GG.AddReactiveArmorDamage = function(unitID, damage)
	local unitDefData = armoredUnitDefs[spGetUnitDefID(unitID)]
	if unitDefData and damage ~= 0 then
		return doArmorDamage(unitID, unitDefData, damage)
	else
		return false
	end
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

	local spGetUnitRulesParam = Spring.GetUnitRulesParam

	local function reloadUnitState(unitID, unitDefID, unitTeam)
		if Spring.GetUnitIsBeingBuilt(unitID) then
			return
		end

		local armorHealth = spGetUnitRulesParam(unitID, "reactiveArmorHealth")
		local armorFrames = spGetUnitRulesParam(unitID, "reactiveArmorFrames")
		local combatUntil = spGetUnitRulesParam(unitID, "unitIsInCombatUntil")
		gadget:UnitFinished(unitID, unitDefID, unitTeam)
		spSetUnitRulesParam(unitID, "reactiveArmorFrames", nil)
		spSetUnitRulesParam(unitID, "unitIsInCombatUntil", nil)

		local armor = armoredUnitDefs[unitDefID]
		if not armor then
			return -- invalid unit script removed in g:UnitFinished
		end

		armorHealth = armorHealth and math_clamp(armorHealth, 1, armor.health) or false
		armorFrames = armorFrames and math_clamp(armorFrames, 0, armor.frames) or false

		spSetUnitRulesParam(unitID, "reactiveArmorHealth", armorHealth)
		unitArmorHealth[unitID] = armorHealth or nil
		if armorFrames or not armorHealth or armorHealth < armor.health then
			unitArmorFrames[unitID] = getArmorRestoreFrames(armor, armorFrames)
			regenerateFrame[unitID] = combatUntil or combatEndFrame
		end

		if debugReloads then
			showDebugInfo(unitID)
		end
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if armoredUnitDefs[spGetUnitDefID(unitID)] then
			reloadUnitState(unitID, spGetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
	end
end

local isLuaRulesReload = true

function gadget:GameOver(winningAllyTeams)
	isLuaRulesReload = false
end

function gadget:Shutdown()
	if isLuaRulesReload then
		for unitID, data in pairs(unitArmorFrames) do
			spSetUnitRulesParam(unitID, "reactiveArmorFrames", data.countdown)
			spSetUnitRulesParam(unitID, "unitIsInCombatUntil", regenerateFrame[unitID])
		end
	end
	GG.AddReactiveArmorDamage = nil
	GG.GetReactiveArmorHealth = nil
end
