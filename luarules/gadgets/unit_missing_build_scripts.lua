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
	tweaked = tweakDefs ~= "" or tweakUnits ~= ""
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
		layer = 2,
		enabled = true,
	}
end

local isScriptlessBuilder = {}
local atLeastOneScriptlessBuilder = false
for unitDefID, def in pairs(UnitDefs) do
	if def.customParams.scriptlessbuilder then
		isScriptlessBuilder[unitDefID] = true
		atLeastOneScriptlessBuilder = true
	end
end

if not atLeastOneScriptlessBuilder then
	return
else
	-- At least one scriptless builder exists, continue with the gadget
	Spring.Echo("At least one scriptless builder detected, enabling Scriptless Builders Handling")
end

local function HandleUnitCreated(unitID, unitDefID)
	if not isScriptlessBuilder[unitDefID] then
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
