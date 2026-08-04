local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scavengers",
		desc = "The scavengers flavor over the wave director: roster, unit conversion, populations, damage modifiers",
		author = "TheFatController/quantum, Damgam, Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		-- Layer IS the dependency declaration: gadgets initialize in layer order, and this one
		-- hands a spec to GG.Waves (layer 0) the moment it starts.
		layer = 1,
		enabled = true,
	}
end

if not (BAR.Utilities.Gametype.IsScavengers() and not BAR.Utilities.Gametype.IsRaptors()) then
	return false
end

if not gadgetHandler:IsSyncedCode() then
	local function hasScavEvent(_, _, words)
		if GG.WaveEvents then
			GG.WaveEvents.SetWanted("ScavEvent", words[1] ~= "0")
		end
		return true
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction("HasScavEvent", hasScavEvent, "toggles hasScavEvent setting")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("HasScavEvent")
	end

	return
end

local LOG_TAG = "scavengers"
local DIRECTOR = "scavengers"
-- CMD_CLOAK_SHIELD, from luarules/configs/customcmds.h.lua.
local CMD_CLOAK_SHIELD = 37382

local DefsBuild = VFS.Include("modules/scavengers/lib/defs_build.lua")
local Hooks = VFS.Include("modules/scavengers/lib/hooks.lua")
local SpecBuild = VFS.Include("modules/scavengers/lib/spec_build.lua")

local config = DefsBuild.FromEngine()
local modOptions = Spring.GetModOptions()

local scavTeamID = BAR.Utilities.GetScavTeamID()
local scavAllyTeamID = BAR.Utilities.GetScavAllyTeamID()
if not scavTeamID then
	scavTeamID = Spring.GetGaiaTeamID()
	scavAllyTeamID = select(6, Spring.GetTeamInfo(scavTeamID, false))
end

local behaviourByID = SpecBuild.Behaviours(config.scavBehaviours)

local populations = { commanders = 0, decoys = 0 }

local hooks = Hooks.New(config, behaviourByID, populations)

-- Units created by the swap below, spawned on the next frame: creating a unit
-- inside UnitCreated is how you get a recursion the engine does not enjoy.
local createQueue = {}

---@param unitID integer
---@param unitDefID integer
---@param override string|nil the customParam naming an explicit swap
local function swapToScav(unitID, unitDefID, override)
	local unitDef = UnitDefs[unitDefID]
	local x, y, z = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID) or 0

	if override == nil then
		local scavName = unitDef.name .. "_scav"
		if UnitDefNames[scavName] then
			createQueue[#createQueue + 1] = { scavName, x, y, z, facing, scavTeamID }
			Spring.DestroyUnit(unitID, true, true)
		end
		return
	end
	if override == "delete" then
		Spring.DestroyUnit(unitID, true, true)
		return
	end
	if override ~= "null" then
		if UnitDefNames[override] then
			createQueue[#createQueue + 1] = { override, x, y, z, facing, scavTeamID }
		end
		Spring.DestroyUnit(unitID, true, true)
	end
end

---@param unitID integer
---@param unitDefID integer
local function adoptScav(unitID, unitDefID)
	local unitDef = UnitDefs[unitDefID]
	Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { config.defaultScavFirestate }, 0)
	if GG.ScavengersSpawnEffectUnitID then
		GG.ScavengersSpawnEffectUnitID(unitID)
	end
	if unitDef.canCloak then
		Spring.GiveOrderToUnit(unitID, CMD_CLOAK_SHIELD, { 1 }, 0)
	end
	if config.squadSpawnOptionsTable.commanders[unitDef.name] then
		populations.commanders = populations.commanders + 1
	elseif config.squadSpawnOptionsTable.decoyCommanders[unitDef.name] then
		populations.decoys = populations.decoys + 1
	end
end

---@param unitID integer
---@param unitDefID integer
---@param created boolean created (vs captured); the two have separate overrides
local function onScavUnit(unitID, unitDefID, created)
	local unitDef = UnitDefs[unitDefID]
	if unitDef.customParams.isscavenger then
		adoptScav(unitID, unitDefID)
		return
	end
	local key = created and "scav_swap_override_created" or "scav_swap_override_captured"
	swapToScav(unitID, unitDefID, unitDef.customParams[key])
end

local function collapseScavAllies()
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		local _, _, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
		if allyTeamID == scavAllyTeamID and not spectator then
			Spring.AssignPlayerToTeam(playerID, scavTeamID)
			for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
				Spring.DestroyUnit(unitID, false, true)
			end
			Spring.KillTeam(teamID)
		end
	end

	for _, teamID in ipairs(Spring.GetTeamList(scavAllyTeamID) or {}) do
		local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if (isAI or (luaAI and luaAI ~= "")) and teamID ~= scavTeamID then
			for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
				Spring.DestroyUnit(unitID, false, true)
			end
			Spring.KillTeam(teamID)
		end
	end
end

local function startDirector()
	if GG.Waves == nil then
		Spring.Log(
			LOG_TAG,
			LOG.ERROR,
			"GG.Waves missing; the wave director must initialize first (this gadget's layer puts it there)"
		)
		return
	end

	local spec = SpecBuild.Build({
		name = DIRECTOR,
		config = config,
		modOptions = modOptions,
		teamID = scavTeamID,
		allyTeamID = scavAllyTeamID,
		teamCount = config.humanTeamCount,
		unitCap = math.floor(Game.maxUnits * 0.80),
		hooks = hooks,
	})
	if not GG.Waves.Start(spec) then
		Spring.Log(LOG_TAG, LOG.ERROR, "could not start the scavengers director")
		return
	end

	GG.Scavengers = {
		teamID = scavTeamID,
		allyTeamID = scavAllyTeamID,
		config = config,
		director = DIRECTOR,
		CommanderPopulation = function()
			return populations.commanders, populations.decoys
		end,
	}
	Spring.SetGameRulesParam("scavDifficulty", config.difficulty)
end

function gadget:Initialize()
	Spring.Log(LOG_TAG, LOG.INFO, "Scavengers activated")
	Spring.SetGameRulesParam("BossFightStarted", 0)
	startDirector()
end

function gadget:Shutdown()
	GG.Scavengers = nil
end

function gadget:GameFrame(n)
	if #createQueue > 0 then
		for _, spawn in ipairs(createQueue) do
			Spring.CreateUnit(spawn[1], spawn[2], spawn[3], spawn[4], spawn[5], spawn[6])
		end
		createQueue = {}
	end
	if n == 1 then
		collapseScavAllies()
		-- The AI's starting commander is not part of the roster.
		for _, unitID in ipairs(Spring.GetTeamUnits(scavTeamID)) do
			Spring.DestroyUnit(unitID, false, true)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam ~= scavTeamID then
		return
	end
	local _, maxHealth = Spring.GetUnitHealth(unitID)
	Spring.SetUnitHealth(unitID, maxHealth)
	onScavUnit(unitID, unitDefID, true)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam)
	if newTeam ~= scavTeamID then
		return
	end
	onScavUnit(unitID, unitDefID, false)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitTeam ~= scavTeamID then
		return
	end
	local unitDef = UnitDefs[unitDefID]
	if not unitDef.customParams.isscavenger then
		return
	end
	if config.squadSpawnOptionsTable.commanders[unitDef.name] then
		populations.commanders = populations.commanders - 1
	elseif config.squadSpawnOptionsTable.decoyCommanders[unitDef.name] then
		populations.decoys = populations.decoys - 1
	end
end

function gadget:UnitPreDamaged(_, _, unitTeam, damage, _, _, _, _, _, attackerTeam)
	if attackerTeam == scavTeamID then
		damage = damage * config.damageMod
	end
	if unitTeam == scavTeamID then
		damage = damage / config.healthMod
	end
	return damage, 1
end
