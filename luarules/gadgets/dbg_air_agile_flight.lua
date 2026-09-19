function gadget:GetInfo()
	return {
		name    = "Air Agile Flight (debug)",
		desc    = "Test gadget for the engine's agile flight regime: turns it on for strafing aircraft, with live A/B toggles and tunables. Needs an engine built from the air-agile-flight branch; does nothing on other engines.",
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
-- /luarules agileset <k> <v>   override a tunable for all of them, 0 restores the engine default:
--                              agileSpeed (elmos/s), agileTurnRate, agileAccRate, cruiseDistance (elmos)
-- /luarules agileinfo          print what the engine reports for one aircraft of each type
-- /luarules agilearmed 0|1     0 (default): weapons are held while manoeuvring, live only in cruise
--
-- defaults applied here for the test: agileAltitude = 45% of each type's cruise altitude

local SetData = Spring.MoveCtrl.SetAirMoveTypeData
local Echo = Spring.Echo

local enabled = true
local armedWhileManoeuvring = false
local overrides = {}
local ALTITUDE_FRACTION = 0.45

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

local function isManoeuvring(unitID)
	local mt = Spring.GetUnitMoveTypeData(unitID)
	return (mt ~= nil and mt.flightRegime == "agile")
end

-- the engine calls this the moment an aircraft changes between manoeuvring and cruise
function gadget:UnitFlightRegimeChanged(unitID, unitDefID, unitTeam, regime)
	setArmed(unitID, unitDefID, armedWhileManoeuvring or regime ~= "agile")
end
local supported = nil

local isStrafeAir = {}
for udid, ud in pairs(UnitDefs) do
	isStrafeAir[udid] = ud.isStrafingAirUnit
end

local function apply(unitID, unitDefID)
	if not isStrafeAir[unitDefID] then
		return
	end

	local accepted = SetData(unitID, "agileFlight", enabled)

	if supported == nil then
		supported = (accepted ~= 0)
		if not supported then
			Echo("[agile] this engine does not know agileFlight: it is a stock build, nothing will change")
		end
	end

	if overrides.agileAltitude == nil then
		SetData(unitID, "agileAltitude", enabled and (UnitDefs[unitDefID].wantedHeight * 1.5 * ALTITUDE_FRACTION) or 0)
	end

	for key, value in pairs(overrides) do
		SetData(unitID, key, value)
	end

	setArmed(unitID, unitDefID, armedWhileManoeuvring or not isManoeuvring(unitID))
end

local function applyAll()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		apply(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	apply(unitID, unitDefID)
end

function gadget:GotChatMsg(msg, playerID)
	local words = {}
	for w in msg:gmatch("%S+") do
		words[#words + 1] = w
	end

	if words[1] == "agile" and (words[2] == "0" or words[2] == "1") then
		enabled = (words[2] == "1")
		applyAll()
		Echo("[agile] agile flight " .. (enabled and "ON" or "OFF (stock behaviour)") .. " for all strafing aircraft")
	elseif words[1] == "agilearmed" and (words[2] == "0" or words[2] == "1") then
		armedWhileManoeuvring = (words[2] == "1")
		applyAll()
		Echo("[agile] weapons while manoeuvring: " .. (armedWhileManoeuvring and "LIVE" or "HELD (live only in cruise)"))
	elseif words[1] == "agileset" and words[2] and tonumber(words[3]) then
		overrides[words[2]] = tonumber(words[3])
		applyAll()
		Echo("[agile] " .. words[2] .. " = " .. words[3] .. ((tonumber(words[3]) == 0) and " (engine default)" or ""))
	elseif words[1] == "agileinfo" then
		local seen = {}
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if isStrafeAir[unitDefID] and not seen[unitDefID] then
				seen[unitDefID] = true
				local mt = Spring.GetUnitMoveTypeData(unitID)
				Echo(string.format("[agile] %s: agileFlight=%s regime=%s agileSpeed=%.0f (max %.0f) agileTurnRate=%.0f agileAccRate=%.3f cruiseDistance=%.0f agileAltitude=%.0f (cruise %.0f) state=%s",
					UnitDefs[unitDefID].name, tostring(mt.agileFlight), tostring(mt.flightRegime), mt.agileSpeed or -1, mt.maxSpeed or -1,
					mt.agileTurnRate or -1, mt.agileAccRate or -1, mt.cruiseDistance or -1, mt.agileAltitude or -1, mt.wantedHeight or -1, tostring(mt.aircraftState)))
			end
		end
	end
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
	Echo("[agile] debug gadget active: agile flight ON, manoeuvring at 45% of cruise altitude with weapons held. /luarules agile 0|1, agilearmed 0|1, agileinfo, agileset <key> <value>")
end
