-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
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

local function hasBuildScript(unitID, unitDefID)
	if hasBuildScripts[unitDefID] ~= nil then
		return hasBuildScripts[unitDefID] 
	end
	local env = Spring.UnitScript.GetScriptEnv(unitID)
	if env then
		if env.script.StartBuilding then
			hasBuildScripts[unitDefID] = true
			return true
		end
		hasBuildScripts[unitDefID] = false
		return false
	end
	if Spring.GetCOBScriptID(unitID, "StartBuilding") then
		hasBuildScripts[unitDefID] = true
		return true
	end

	hasBuildScripts[unitDefID] = false
	return false
end

function gadget:UnitCreated(unitID, unitDefID)
	if hasBuildScripts[unitDefID] then
		return
	end
	local def = UnitDefs[unitDefID]
	local isBuilder = def.canBuild or def.canRepair or def.canCapture or def.canAssist or def.canRestore or def.canResurrect 
	if not isBuilder then
		return
	end
	if hasBuildScript(unitID, unitDefID) then
		return
	end
	Spring.SetUnitCOBValue(unitID, COB.INBUILDSTANCE, true)
	Spring.SetUnitNanoPieces(unitID, {1})
end

function gadget:Initialize()
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
	end
end