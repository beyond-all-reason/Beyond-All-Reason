function gadget:GetInfo()
	return {
		name    = "Air Agile Flight (debug)",
		desc    = "Turns the engine's agile flight regime on for strafing aircraft, with an A/B toggle. Local test file, not part of the game.",
		author  = "PtaQ",
		date    = "2026-09",
		license = "GPL v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- /luarules agile 1            agile regime on for every strafing aircraft (default)
-- /luarules agile 0            off: stock engine behaviour, for A/B comparison on the same units
-- /luarules agileset <k> <v>   override a movetype member for all of them; <v> is a number, or true/false for
--                              the boolean members. For these, 0 restores the engine default:
--                              agileSpeed (elmos/s), agileTurnRate, agileAccRate, cruiseDistance (elmos), agileAltitude,
--                              cruiseEntryAngle (degrees), cruiseEntrySpeed (share of agileSpeed), cruiseEntryTurnBoost
--                              The rest take the value as given:
--                              agileHoverBob (elmos an aircraft holding in the air bobs up and down, 0 = none),
--                              agileHoverSway (elmos it sways to its own left and right, 0 = none),
--                              agileHoverTilt (how hard it leans while it does, 1 = default, 0 = level),
--                              and the stock members (maxSpeed in elmos/s, wantedHeight, turnRadius, maxAcc, maxDec,
--                              maxBank, maxPitch, maxAileron, maxElevator, maxRudder, myGravity, attackSafetyDistance,
--                              collide, useSmoothMesh, loopbackAttack)
-- /luarules agilesetdef <unitDefName> <k> <v>   the same for one unit type only, applied after the ones for all
-- /luarules agileunset <k>                      drop one override for all, the aircraft get back what they had
-- /luarules agileunsetdef <unitDefName> <k>     drop one override of one unit type
-- /luarules agilereset                          drop every override for all
-- /luarules agileresetdef <unitDefName>         drop every override of one unit type
-- /luarules agileinfo          print what the engine reports for one aircraft of each type, and the overrides
-- /luarules lookahead 0|1      1 (default): fixed-wing altitude hold looks at the terrain along the whole
--                              flight path (climbs for cliffs early, descends gently past them); 0 is stock
-- /luarules agilearmed 0|1     0 (default): weapons are held while maneuvering, live only in cruise
--
-- The Air Flight Tuning widget sends the same commands as Lua messages ("airtune:<command>"), which are not echoed
-- for every slider step.
--
-- defaults applied here for the test: agileAltitude = 45% of each type's cruise altitude,
-- agileHoverBob = 0.15 and agileHoverSway = 0.2 of each aircraft's radius
--
-- The overrides are published as game rules params, so the widget knows them after a LuaUI reload too:
--   airtune_over_all  = "key=value;key=value"                        ("-" when there are none)
--   airtune_over_defs = "defName:key=value,key=value|defName:..."    ("-" when there are none)
-- numbers as %.6g, booleans as true/false, keys and unit types sorted

local SetData = Spring.MoveCtrl.SetAirMoveTypeData
local Echo = Spring.Echo

local enabled = true
local armedWhileManeuvering = false
local terrainLookahead = true
local overrides = {}
-- unitDefID -> { key -> value }, applied after the overrides for all
local defOverrides = {}
-- unitID -> { key -> value the aircraft had before the first override of that key }
local originals = {}
-- keys the engine refused during the last apply
local rejected = {}
local ALTITUDE_FRACTION = 0.45
local HOVER_BOB_RADII = 0.15
local HOVER_SWAY_RADII = 0.2
local MSG_PREFIX = "airtune:"

-- the engine reads the value through a bool* or a float* depending on the member, so the Lua type has to match
local BOOL_KEYS = {
	collide = true,
	useSmoothMesh = true,
	loopbackAttack = true,
	agileFlight = true,
	terrainLookahead = true,
	agileLandOnly = true,
}

-- members for which zero asks the engine to derive its default; every other member is put back from what the
-- aircraft had (GetUnitMoveTypeData reports the derived value for these, not the zero)
local ZERO_IS_DEFAULT = {
	agileSpeed = true,
	agileTurnRate = true,
	agileAccRate = true,
	cruiseDistance = true,
	agileAltitude = true,
	cruiseEntryAngle = true,
	cruiseEntrySpeed = true,
	cruiseEntryTurnBoost = true,
}

-- one name per member, the one GetUnitMoveTypeData reports where it reports it
local KEY_ALIAS = {
	accRate = "maxAcc",
	decRate = "maxDec",
}

-- the engine divides by these
local MIN_VALUE = {
	maxAcc = 0.001,
	maxDec = 0.001,
	maxSpeed = 1,
}

-- stands for "could not be read" in originals, where false is a real value
local NONE = {}

-- weapon ranges per unitdef, to put back when an aircraft goes over to cruise
local weaponRanges = {}
for udid, ud in pairs(UnitDefs) do
	if ud.isStrafingAirUnit and ud.weapons then
		local ranges = {}
		for i, w in ipairs(ud.weapons) do
			ranges[i] = WeaponDefs[w.weaponDef].range
		end
		weaponRanges[udid] = ranges
	end
end

-- a held weapon: no range, so it finds no target, and whatever it was tracking is dropped
local function setArmed(unitID, unitDefID, armed)
	local ranges = weaponRanges[unitDefID]
	if not ranges then
		return
	end
	for i, range in ipairs(ranges) do
		Spring.SetUnitWeaponState(unitID, i, "range", armed and range or 0)
		if not armed then
			Spring.UnitWeaponHoldFire(unitID, i)
		end
	end
end

local function isManeuvering(unitID)
	local mt = Spring.GetUnitMoveTypeData(unitID)
	return (mt ~= nil and mt.flightRegime == "agile")
end

-- the engine calls this the moment an aircraft changes between maneuvering and cruise
function gadget:UnitFlightRegimeChanged(unitID, unitDefID, unitTeam, regime)
	setArmed(unitID, unitDefID, armedWhileManeuvering or regime ~= "agile")
end
local supported = nil

local isStrafeAir = {}
for udid, ud in pairs(UnitDefs) do
	isStrafeAir[udid] = ud.isStrafingAirUnit
end

-- for the members GetUnitMoveTypeData does not report: what the engine starts an aircraft of this type with
local function fallbackOriginal(unitDefID, key)
	local ud = UnitDefs[unitDefID]
	if ud == nil then
		return nil
	end
	if key == "maxDec" then
		return math.max(0.01, ud.maxDec or 0.01)
	elseif key == "attackSafetyDistance" then
		-- the engine starts it at 0, the game's unit_air_attacksafetydistance gadget sets it from this
		return tonumber(ud.customParams and ud.customParams.attacksafetydistance) or 0
	elseif key == "wantedHeight" then
		return (ud.wantedHeight or 0) * 1.5
	elseif key == "loopbackAttack" then
		return (ud.canLoopbackAttack and ud.isFighterAirUnit) and true or false
	end
	return nil
end

-- remember what the aircraft had, the first time a key is overridden on it
local function captureOriginal(unitID, unitDefID, key)
	local saved = originals[unitID]
	if saved == nil then
		saved = {}
		originals[unitID] = saved
	end
	if saved[key] ~= nil then
		return
	end
	local value = nil
	local mt = Spring.GetUnitMoveTypeData(unitID)
	if mt ~= nil then
		value = mt[key]
		-- a landing aircraft has its wantedHeight taken over by the landing, that is not what it cruises at
		if key == "wantedHeight" and (mt.aircraftState == "landing" or mt.aircraftState == "landed") then
			value = nil
		end
	end
	if value == nil then
		value = fallbackOriginal(unitDefID, key)
	end
	if value == nil then
		value = NONE
	end
	saved[key] = value
end

local function setOverride(unitID, unitDefID, key, value)
	if not ZERO_IS_DEFAULT[key] then
		captureOriginal(unitID, unitDefID, key)
	end
	if SetData(unitID, key, value) == 0 then
		rejected[key] = true
	end
end

-- an override was dropped: give the aircraft back what it had
local function restoreOriginal(unitID, unitDefID, key)
	if ZERO_IS_DEFAULT[key] then
		-- what its unitdef asks for, which is zero (the engine derives it) unless the tag has been baked in
		local ud = UnitDefs[unitDefID]
		local defValue = ud and ud[key]
		if type(defValue) ~= "number" or defValue < 0 then
			defValue = 0
		end
		SetData(unitID, key, defValue)
		return
	end
	local saved = originals[unitID]
	if saved == nil or saved[key] == nil then
		return
	end
	local value = saved[key]
	saved[key] = nil
	if value ~= NONE then
		SetData(unitID, key, value)
	end
end

local function apply(unitID, unitDefID)
	if not isStrafeAir[unitDefID] then
		return
	end

	-- (a stock engine warns about every member it does not know, once per unit and key: ask it
	-- once, then leave its aircraft alone)
	if supported == false then
		return
	end

	local accepted = SetData(unitID, "agileFlight", enabled)

	if supported == nil then
		supported = (accepted ~= 0)
		if not supported then
			Echo("[agile] this engine does not know agileFlight: it is a stock build, nothing will change")
			return
		end
	end

	SetData(unitID, "terrainLookahead", terrainLookahead)

	local defOv = defOverrides[unitDefID]

	if overrides.agileAltitude == nil and (defOv == nil or defOv.agileAltitude == nil) then
		SetData(unitID, "agileAltitude", enabled and (UnitDefs[unitDefID].wantedHeight * 1.5 * ALTITUDE_FRACTION) or 0)
	end

	if overrides.agileHoverBob == nil and (defOv == nil or defOv.agileHoverBob == nil) then
		SetData(unitID, "agileHoverBob", enabled and (Spring.GetUnitRadius(unitID) * HOVER_BOB_RADII) or 0)
	end
	if overrides.agileHoverSway == nil and (defOv == nil or defOv.agileHoverSway == nil) then
		SetData(unitID, "agileHoverSway", enabled and (Spring.GetUnitRadius(unitID) * HOVER_SWAY_RADII) or 0)
	end

	for key, value in pairs(overrides) do
		setOverride(unitID, unitDefID, key, value)
	end
	if defOv ~= nil then
		for key, value in pairs(defOv) do
			setOverride(unitID, unitDefID, key, value)
		end
	end

	setArmed(unitID, unitDefID, armedWhileManeuvering or not isManeuvering(unitID))
end

local function applyAll()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		apply(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	apply(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID)
	originals[unitID] = nil
end

-- the tuning widget reads these to show the three switches as they are
local function publishState()
	Spring.SetGameRulesParam("airtune_agile", enabled and 1 or 0)
	Spring.SetGameRulesParam("airtune_lookahead", terrainLookahead and 1 or 0)
	Spring.SetGameRulesParam("airtune_armed", armedWhileManeuvering and 1 or 0)
	-- for the header of the widget's export
	Spring.SetGameRulesParam("airtune_altitude_fraction", ALTITUDE_FRACTION)
	Spring.SetGameRulesParam("airtune_hover_bob_radii", HOVER_BOB_RADII)
	Spring.SetGameRulesParam("airtune_hover_sway_radii", HOVER_SWAY_RADII)
end

local function serialiseScope(scope, separator)
	local parts = {}
	for key, value in pairs(scope) do
		if type(value) == "boolean" then
			parts[#parts + 1] = key .. "=" .. tostring(value)
		else
			parts[#parts + 1] = key .. "=" .. string.format("%.6g", value)
		end
	end
	table.sort(parts)
	return table.concat(parts, separator)
end

-- the tuning widget reads these to know what is overridden, also after a LuaUI reload (format at the top)
local function publishOverrides()
	local all = serialiseScope(overrides, ";")
	local defs = {}
	for unitDefID, defOv in pairs(defOverrides) do
		if next(defOv) ~= nil and UnitDefs[unitDefID] then
			defs[#defs + 1] = UnitDefs[unitDefID].name .. ":" .. serialiseScope(defOv, ",")
		end
	end
	table.sort(defs)
	-- never empty, and never something that reads as a number
	Spring.SetGameRulesParam("airtune_over_all", (all ~= "") and all or "-")
	Spring.SetGameRulesParam("airtune_over_defs", (#defs > 0) and table.concat(defs, "|") or "-")
end

-- returns the value in the Lua type the member needs, or nil and why not
local function parseValue(key, word)
	if word == nil then
		return nil, "no value given"
	end
	local lower = word:lower()
	local value
	if lower == "true" then
		value = true
	elseif lower == "false" then
		value = false
	else
		value = tonumber(word)
	end
	if value == nil then
		return nil, "'" .. word .. "' is neither a number nor true/false"
	end
	if BOOL_KEYS[key] then
		if type(value) == "number" then
			value = (value ~= 0)
		end
		return value
	end
	if type(value) == "boolean" then
		return nil, key .. " takes a number"
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil, "'" .. word .. "' is not a usable number"
	end
	local floor = MIN_VALUE[key]
	if floor ~= nil and value < floor then
		value = floor
	end
	return value
end

local function strafeDefID(name)
	local ud = name and UnitDefNames[name]
	if ud == nil then
		Echo("[agile] no unit type is called '" .. tostring(name) .. "'")
		return nil
	end
	if not isStrafeAir[ud.id] then
		Echo("[agile] " .. name .. " is not a strafing aircraft")
		return nil
	end
	return ud.id
end

-- unitDefID nil: for all. Returns false if the engine refused the key
local function storeOverride(unitDefID, key, value)
	local scope = overrides
	if unitDefID ~= nil then
		scope = defOverrides[unitDefID]
		if scope == nil then
			scope = {}
			defOverrides[unitDefID] = scope
		end
	end
	scope[key] = value
	rejected = {}
	applyAll()

	local ok = true
	for badKey in pairs(rejected) do
		if badKey == key then
			ok = false
		end
		overrides[badKey] = nil
		for udid, defOv in pairs(defOverrides) do
			defOv[badKey] = nil
		end
		Echo("[agile] this engine build has no settable '" .. badKey .. "', override dropped")
	end
	rejected = {}
	-- a type left without overrides is not kept
	for udid, defOv in pairs(defOverrides) do
		if next(defOv) == nil then
			defOverrides[udid] = nil
		end
	end
	publishOverrides()
	return ok
end

-- unitDefID nil: the overrides for all. onlyKey nil: every key. Returns how many were dropped
local function dropOverrides(unitDefID, onlyKey)
	local scope = overrides
	if unitDefID ~= nil then
		scope = defOverrides[unitDefID]
	end
	if scope == nil then
		return 0
	end

	local dropped = {}
	for key in pairs(scope) do
		if onlyKey == nil or key == onlyKey then
			dropped[#dropped + 1] = key
		end
	end
	for _, key in ipairs(dropped) do
		scope[key] = nil
	end
	if unitDefID ~= nil and next(scope) == nil then
		defOverrides[unitDefID] = nil
	end
	if #dropped == 0 then
		return 0
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local udid = Spring.GetUnitDefID(unitID)
		if isStrafeAir[udid] and (unitDefID == nil or udid == unitDefID) then
			local defOv = defOverrides[udid]
			for _, key in ipairs(dropped) do
				-- still overridden in the other scope: apply() sets that one again
				if overrides[key] == nil and (defOv == nil or defOv[key] == nil) then
					restoreOriginal(unitID, udid, key)
				end
			end
		end
	end
	-- puts this gadget's own defaults back (agileAltitude, agileHoverBob, agileHoverSway)
	applyAll()
	publishOverrides()
	return #dropped
end

local function formatOverrides(scope)
	local parts = {}
	for key, value in pairs(scope) do
		parts[#parts + 1] = key .. "=" .. tostring(value)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-- quiet: from the tuning widget, a slider being dragged sends ten of these a second
local function handleCommand(words, quiet)
	if words[1] == "agile" and (words[2] == "0" or words[2] == "1") then
		enabled = (words[2] == "1")
		applyAll()
		publishState()
		Echo("[agile] agile flight " .. (enabled and "ON" or "OFF (stock behaviour)") .. " for all strafing aircraft")
	elseif words[1] == "lookahead" and (words[2] == "0" or words[2] == "1") then
		terrainLookahead = (words[2] == "1")
		applyAll()
		publishState()
		Echo("[agile] terrain lookahead for fixed-wing flight: " .. (terrainLookahead and "ON" or "OFF (stock)"))
	elseif words[1] == "agilearmed" and (words[2] == "0" or words[2] == "1") then
		armedWhileManeuvering = (words[2] == "1")
		applyAll()
		publishState()
		Echo("[agile] weapons while maneuvering: " .. (armedWhileManeuvering and "LIVE" or "HELD (live only in cruise)"))
	elseif words[1] == "agileset" and words[2] then
		local key = KEY_ALIAS[words[2]] or words[2]
		local value, why = parseValue(key, words[3])
		if value == nil then
			Echo("[agile] agileset " .. key .. ": " .. tostring(why))
			return
		end
		if storeOverride(nil, key, value) and not quiet then
			Echo("[agile] " .. key .. " = " .. tostring(value) .. ((value == 0 and ZERO_IS_DEFAULT[key]) and " (engine default)" or ""))
		end
	elseif words[1] == "agilesetdef" and words[2] and words[3] then
		local unitDefID = strafeDefID(words[2])
		if unitDefID == nil then
			return
		end
		local key = KEY_ALIAS[words[3]] or words[3]
		local value, why = parseValue(key, words[4])
		if value == nil then
			Echo("[agile] agilesetdef " .. words[2] .. " " .. key .. ": " .. tostring(why))
			return
		end
		if storeOverride(unitDefID, key, value) and not quiet then
			Echo("[agile] " .. words[2] .. ": " .. key .. " = " .. tostring(value) .. ((value == 0 and ZERO_IS_DEFAULT[key]) and " (engine default)" or ""))
		end
	elseif words[1] == "agileunset" and words[2] then
		local key = KEY_ALIAS[words[2]] or words[2]
		local count = dropOverrides(nil, key)
		Echo("[agile] " .. key .. ((count > 0) and ": override for all aircraft dropped" or ": there was no override for all aircraft"))
	elseif words[1] == "agileunsetdef" and words[2] and words[3] then
		local unitDefID = strafeDefID(words[2])
		if unitDefID == nil then
			return
		end
		local key = KEY_ALIAS[words[3]] or words[3]
		local count = dropOverrides(unitDefID, key)
		Echo("[agile] " .. words[2] .. ": " .. key .. ((count > 0) and ": override dropped" or ": there was no override"))
	elseif words[1] == "agilereset" then
		local count = dropOverrides(nil, nil)
		Echo("[agile] dropped " .. count .. " override(s) for all aircraft")
	elseif words[1] == "agileresetdef" and words[2] then
		local unitDefID = strafeDefID(words[2])
		if unitDefID == nil then
			return
		end
		local count = dropOverrides(unitDefID, nil)
		Echo("[agile] dropped " .. count .. " override(s) of " .. words[2])
	elseif words[1] == "agileinfo" then
		local seen = {}
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if isStrafeAir[unitDefID] and not seen[unitDefID] then
				seen[unitDefID] = true
				local mt = Spring.GetUnitMoveTypeData(unitID)
				if mt ~= nil then
					Echo(string.format("[agile] %s: agileFlight=%s regime=%s agileSpeed=%.0f (max %.0f) agileTurnRate=%.0f agileAccRate=%.3f cruiseDistance=%.0f agileAltitude=%.0f (cruise %.0f) agileHoverBob=%.1f agileHoverSway=%.1f agileHoverTilt=%.1f state=%s",
						UnitDefs[unitDefID].name, tostring(mt.agileFlight), tostring(mt.flightRegime), mt.agileSpeed or -1, mt.maxSpeed or -1,
						mt.agileTurnRate or -1, mt.agileAccRate or -1, mt.cruiseDistance or -1, mt.agileAltitude or -1, mt.wantedHeight or -1, mt.agileHoverBob or -1, mt.agileHoverSway or -1, mt.agileHoverTilt or -1, tostring(mt.aircraftState)))
				end
			end
		end
		if next(overrides) ~= nil then
			Echo("[agile] overrides for all aircraft: " .. formatOverrides(overrides))
		end
		for unitDefID, defOv in pairs(defOverrides) do
			if next(defOv) ~= nil then
				Echo("[agile] overrides of " .. UnitDefs[unitDefID].name .. ": " .. formatOverrides(defOv))
			end
		end
	end
end

local function splitWords(msg)
	local words = {}
	for w in msg:gmatch("%S+") do
		words[#words + 1] = w
	end
	return words
end

function gadget:GotChatMsg(msg, playerID)
	handleCommand(splitWords(msg), false)
end

function gadget:RecvLuaMsg(msg, playerID)
	if type(msg) ~= "string" or msg:sub(1, #MSG_PREFIX) ~= MSG_PREFIX then
		return
	end
	handleCommand(splitWords(msg:sub(#MSG_PREFIX + 1)), true)
	return true
end

-- the test launcher asks for a ready-made flight line so nothing has to be /give'n first
local SPAWN = {"armpeep", "armpeep", "armpeep", "armfig", "armfig", "armfig", "armthund", "armthund", "armhawk", "armhawk"}

function gadget:GameFrame(frame)
	if frame ~= 90 then
		return
	end
	gadgetHandler:RemoveCallIn("GameFrame")

	if (Spring.GetModOptions().airagile_spawn or "0") ~= "1" then
		return
	end

	local teamID = Spring.GetTeamList()[1]
	local sx, _, sz = Spring.GetTeamStartPosition(teamID)
	if not sx or sx < 0 then
		sx, sz = Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5
	end

	for i, name in ipairs(SPAWN) do
		if UnitDefNames[name] then
			local x, z = sx + 150 + ((i - 1) % 5) * 80, sz + 150 + math.floor((i - 1) / 5) * 80
			local unitID = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
			if unitID then
				-- land when idle, so that landing can be watched; BAR's default is to keep flying
				Spring.GiveOrderToUnit(unitID, CMD.IDLEMODE, {1}, 0)
			end
		end
	end
	Echo("[agile] spawned a test flight line next to your start position (idle mode: land)")
end

function gadget:Initialize()
	applyAll()
	publishState()
	publishOverrides()
	Echo("[agile] debug gadget active: agile flight ON, maneuvering at 45% of cruise altitude with weapons held. /luarules agile 0|1, agilearmed 0|1, agileinfo, agileset <key> <value>")
end
