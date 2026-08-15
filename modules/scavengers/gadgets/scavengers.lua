local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scavengers",
		desc = "The scavengers flavor over the wave director: roster, unit conversion, populations, damage modifiers",
		author = "TheFatController/quantum, Damgam, Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		-- Above the wave director (layer 0). Layer IS the dependency
		-- declaration here: gadgets initialize in layer order, and this one
		-- hands a spec to GG.Waves the moment it starts.
		layer = 1,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Activation. Unchanged from the spawner this replaces: the presence of a
-- scavengers AI is what turns the mode on, so every existing lobby and SPADS
-- config keeps working without a new modoption.
--
-- A mission that wants scavenger pressure does NOT come through here — it
-- goes through modules/scavengers/api.lua and needs no bot at all.
--------------------------------------------------------------------------------

if not (BAR.Utilities.Gametype.IsScavengers() and not BAR.Utilities.Gametype.IsRaptors()) then
	return false
end

if not gadgetHandler:IsSyncedCode() then
	--------------------------------------------------------------------------
	-- The legacy toggle. gui_scavStatsPanel says "luarules HasScavEvent 1"
	-- when it loads and 0 when it unloads; the wire itself lives in the wave
	-- director's unsynced half, which owns the sync action.
	--------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------

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

-- The population tallies the roster caps against. Counted here rather than
-- asked of the engine, because "how many commanders are alive" is asked once
-- per burrow per composition loop.
local populations = { commanders = 0, decoys = 0 }

-- Spec hooks: the moments the director cannot decide alone. Shared with the
-- mission path, so a mission's scavengers look and behave like these ones.
local hooks = Hooks.New(config, behaviourByID, populations)

-- Units created by the swap below, spawned on the next frame: creating a unit
-- inside UnitCreated is how you get a recursion the engine does not enjoy.
local createQueue = {}

--------------------------------------------------------------------------------
-- Unit conversion: anything the scavengers come to own becomes its purple
-- variant. This is what makes losing a factory frightening rather than merely
-- annoying — it does not change hands, it changes species.
--------------------------------------------------------------------------------

---@param unitID integer
---@param unitDefID integer
---@param override string|nil the customParam naming an explicit swap
local function swapToScav(unitID, unitDefID, override)
	local unitDef = UnitDefs[unitDefID]
	local x, y, z = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID) or 0

	if override == nil then
		-- The convention: <name>_scav is the scavenger version of <name>.
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

---A unit that is already a scavenger: dress it and count it.
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

--------------------------------------------------------------------------------

---Scavenger allies are not players. A human who joined the scavengers' ally
---team is moved onto the scav team itself and their units removed, and any
---second AI on that ally team is killed off — one director, one team.
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

	-- The flavor's own surface: what the boss and capture gadgets need, and
	-- what a UI panel would ask for.
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
	-- Scavenger units arrive at full health whatever built them.
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

---Damage modifiers: the difficulty rung's thumb on the scale, in both
---directions. The boss gadget sits above this layer and has the last word on
---what a boss itself takes.
function gadget:UnitPreDamaged(_, _, unitTeam, damage, _, _, _, _, _, attackerTeam)
	if attackerTeam == scavTeamID then
		damage = damage * config.damageMod
	end
	if unitTeam == scavTeamID then
		damage = damage / config.healthMod
	end
	return damage, 1
end
