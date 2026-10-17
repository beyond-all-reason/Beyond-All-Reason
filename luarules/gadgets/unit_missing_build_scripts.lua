-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end

local modOptions = Spring.GetModOptions() or {}
local tweaked = modOptions.tweakunits ~= "" or modOptions.tweakdefs ~= ""
local i = 1
local tweakUnits, tweakDefs
while not tweaked do
	tweakUnits = modOptions["tweakunits" .. i]
	tweakDefs = modOptions["tweakdefs" .. i]
	if tweakUnits == nil or tweakDefs == nil then
		break -- we reached numTweakSlots
	end
	tweaked  = tweakDefs ~= "" or tweakUnits ~= ""
	i = i + 1
end
if not tweaked then
	return
end

Spring.Echo("Detected tweaked defs; loading unit_missing_build_scripts.lua.")
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Allow tweaked builders",
		desc = "Handles setting INBUILDSTANCE for builders with no build script",
		author = "DoodVanDaag",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 2, -- needs to happen after unit scripts loaded
		enabled = true,
	}
end

local hasBuildScripts = {}
local isBuilder = {}
for unitDefID, def in pairs(UnitDefs) do
	isBuilder[unitDefID] = def.isBuilder
end

local function hasBuildScript(unitID, unitDefID)
	if hasBuildScripts[unitDefID] ~= nil then
		return hasBuildScripts[unitDefID]
	end
	local env = Spring.UnitScript.GetScriptEnv(unitID)--[[@as table|nil]]
	if env then
		if env.script.StartBuilding then -- these units already build through their LUS.
			hasBuildScripts[unitDefID] = true
			return true
		end
		hasBuildScripts[unitDefID] = false
		return false
	end
	if Spring.GetCOBScriptID(unitID, "StartBuilding") then -- these units already build through their COB.
		hasBuildScripts[unitDefID] = true
		return true
	end
	if UnitDefs[unitDefID].customParams.attached_con_turret then -- these units already build through an attached construction turret-unit which has COB or LUS.
		-- I'm currently using the custom param. But if its setup in unit_attached_con_turret somehow failed due to incorrect settings, this will not "save" the unit.
		-- A more robust solution: SetUnitRulesParam() set when unit_attached_con_turret succeeded, and read here.
		hasBuildScripts[unitDefID] = true
		return true
	end
	hasBuildScripts[unitDefID] = false
	return false -- this includes drone carriers which might have non zero workerTime but no build scripts.
	-- i'm wondering why they even have non zero workerTime; Maybe they're considered as repairPads, but i'm assuming repair pads (at least in the past) did have Start/Stop building scripts?
end

local function HandleUnitCreated(unitID, unitDefID)
	if not isBuilder[unitDefID] then
		return
	end
	if hasBuildScripts[unitDefID] then
		return
	end
	if hasBuildScript(unitID, unitDefID) then
		return
	end
	Spring.SetUnitCOBValue(unitID, COB.INBUILDSTANCE, true)
	Spring.SetUnitNanoPieces(unitID, { 1 })
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	HandleUnitCreated(unitID, unitDefID)
end

function gadget:Initialize()
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		HandleUnitCreated(unitID, unitDefID)
	end
end
