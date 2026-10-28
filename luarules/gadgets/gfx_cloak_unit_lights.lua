local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Cloak Unit Lights",
		desc = "Keeps showWhenCloaked unit lights attached while the unit is not drawn",
		author = "SethDGamre",
		date = "2026.10.27",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced
	local CLOAK_LIGHT_ACTION = "cloakUnitLight"

	local cloakLightUnitDefs = {}

	local function collectCloakLightUnitDefs()
		local includeOk, lightConfig = pcall(VFS.Include, "luaui/configs/DeferredLightsGL4config.lua")
		if not includeOk or type(lightConfig) ~= "table" or type(lightConfig.unitDefLights) ~= "table" then
			return
		end
		for unitDefID, lights in pairs(lightConfig.unitDefLights) do
			for lightName, light in pairs(lights) do
				if lightName ~= "initComplete" and type(light) == "table" and light.showWhenCloaked then
					cloakLightUnitDefs[unitDefID] = true
					break
				end
			end
		end
	end

	local didRescan = false

	local function trackCloakLightUnit(unitID, unitDefID, enabled)
		if not cloakLightUnitDefs[unitDefID] then
			return
		end
		SendToUnsynced(CLOAK_LIGHT_ACTION, unitID, unitDefID, enabled)
	end

	local function rescanCloakLightUnits()
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			trackCloakLightUnit(unitID, Spring.GetUnitDefID(unitID), true)
		end
	end

	function gadget:Initialize()
		collectCloakLightUnitDefs()
		didRescan = false
	end

	function gadget:GameFrame()
		if didRescan then
			return
		end
		didRescan = true
		rescanCloakLightUnits()
	end

	function gadget:UnitCreated(unitID, unitDefID)
		trackCloakLightUnit(unitID, unitDefID, true)
	end

	function gadget:UnitDestroyed(unitID, unitDefID)
		trackCloakLightUnit(unitID, unitDefID, false)
	end
else
	local spSetUnitAlwaysUpdateMatrix = Spring.SetUnitAlwaysUpdateMatrix
	local spValidUnitID = Spring.ValidUnitID
	local spGetUnitIsDead = Spring.GetUnitIsDead

	local activeUnits = {}

	local function notifyWidget(unitID, unitDefID, enabled)
		if enabled then
			if Script.LuaUI("AddDeferredCloakLight") then
				Script.LuaUI.AddDeferredCloakLight(unitID, unitDefID)
			end
			return
		end
		if Script.LuaUI("RemoveDeferredCloakLight") then
			Script.LuaUI.RemoveDeferredCloakLight(unitID)
		end
	end

	local function setMatrixUpdates(unitID, enabled)
		if spSetUnitAlwaysUpdateMatrix and spValidUnitID(unitID) and spGetUnitIsDead(unitID) ~= true then
			spSetUnitAlwaysUpdateMatrix(unitID, enabled)
		end
	end

	local function resyncCloakLights()
		for unitID, unitDefID in pairs(activeUnits) do
			if spValidUnitID(unitID) and spGetUnitIsDead(unitID) ~= true then
				setMatrixUpdates(unitID, true)
				notifyWidget(unitID, unitDefID, true)
			else
				activeUnits[unitID] = nil
			end
		end
	end

	local function cloakUnitLight(_, unitID, unitDefID, enabled)
		if enabled then
			activeUnits[unitID] = unitDefID
			setMatrixUpdates(unitID, true)
			notifyWidget(unitID, unitDefID, true)
			return
		end
		activeUnits[unitID] = nil
		setMatrixUpdates(unitID, false)
		notifyWidget(unitID, unitDefID, false)
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("cloakUnitLight", cloakUnitLight)
		GG.CloakUnitLights = {
			Resync = resyncCloakLights,
		}
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("cloakUnitLight")
		GG.CloakUnitLights = nil
		for unitID in pairs(activeUnits) do
			setMatrixUpdates(unitID, false)
		end
	end
end
