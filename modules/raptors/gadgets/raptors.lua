local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Raptors",
		desc = "The raptors flavor over the wave director: roster, targets, damage modifiers, the end of the hunt",
		author = "TheFatController/quantum, Damgam, Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		-- Above the wave director (layer 0): gadgets initialize in layer
		-- order, and this one hands a spec to GG.Waves the moment it starts.
		layer = 1,
		enabled = true,
	}
end

if not (BAR.Utilities.Gametype.IsRaptors() and not BAR.Utilities.Gametype.IsScavengers()) then
	return false
end

if not gadgetHandler:IsSyncedCode() then
	local function hasRaptorEvent(_, _, words)
		if GG.WaveEvents then
			GG.WaveEvents.SetWanted("RaptorEvent", words[1] ~= "0")
		end
		return true
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction("HasRaptorEvent", hasRaptorEvent, "toggles hasRaptorEvent setting")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("HasRaptorEvent")
	end

	-- Every raptor gets its own shade, so a swarm reads as animals, not clones.
	if gl.SetUnitBufferUniforms then
		local NO_SHIFT = { 0, 0, 0 }
		local shift = { 0, 0, 0 }
		function gadget:UnitCreated(unitID, unitDefID)
			if string.find(UnitDefs[unitDefID].name, "raptor") then
				gl.SetUnitBufferUniforms(unitID, NO_SHIFT, 8)
				shift[1] = math.random(-100, 100) * 0.0001
				shift[2] = math.random(-200, 200) * 0.0001
				shift[3] = math.random(-200, 200) * 0.0001
				gl.SetUnitBufferUniforms(unitID, shift, 8)
			end
		end
	end

	return
end

local LOG_TAG = "raptors"
local DIRECTOR = "raptors"
-- from luarules/configs/customcmds.h.lua
local CMD_CLOAK_SHIELD = 37382
local ENDGAME_DELAY = 200

local DefsBuild = VFS.Include("modules/raptors/lib/defs_build.lua")
local Hooks = VFS.Include("modules/raptors/lib/hooks.lua")
local SpecBuild = VFS.Include("modules/raptors/lib/spec_build.lua")

local config = DefsBuild.FromEngine()
local modOptions = Spring.GetModOptions()

local raptorTeamID = BAR.Utilities.GetRaptorTeamID()
local raptorAllyTeamID = BAR.Utilities.GetRaptorAllyTeamID()
if not raptorTeamID then
	raptorTeamID = Spring.GetGaiaTeamID()
	raptorAllyTeamID = select(6, Spring.GetTeamInfo(raptorTeamID, false))
end

local hooks = Hooks.New(config, SpecBuild.Behaviours(config.raptorBehaviours))

local killTeamAt = nil ---@type integer|nil

local function collapseRaptorAllies()
	for _, playerID in ipairs(Spring.GetPlayerList()) do
		local _, _, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(playerID, false)
		if allyTeamID == raptorAllyTeamID and not spectator then
			Spring.AssignPlayerToTeam(playerID, raptorTeamID)
			for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
				Spring.DestroyUnit(unitID, false, true)
			end
			Spring.KillTeam(teamID)
		end
	end
	for _, teamID in ipairs(Spring.GetTeamList(raptorAllyTeamID) or {}) do
		local _, _, _, isAI = Spring.GetTeamInfo(teamID, false)
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if (isAI or (luaAI and luaAI ~= "")) and teamID ~= raptorTeamID then
			for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
				Spring.DestroyUnit(unitID, false, true)
			end
			Spring.KillTeam(teamID)
		end
	end
end

local function endTheHunt()
	Spring.KillTeam(raptorTeamID)
	for _, teamID in ipairs(Spring.GetTeamList(raptorAllyTeamID) or {}) do
		local luaAI = Spring.GetTeamLuaAI(teamID)
		local _, _, isDead = Spring.GetTeamInfo(teamID, false)
		if luaAI and luaAI:find("Scavengers") and not isDead then
			return
		end
	end
	for _, teamID in ipairs(Spring.GetTeamList(raptorAllyTeamID) or {}) do
		local _, _, isDead = Spring.GetTeamInfo(teamID, false)
		if not isDead then
			Spring.KillTeam(teamID)
		end
	end
end

local function startDirector()
	if GG.Waves == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "GG.Waves missing; the wave director must initialize first")
		return
	end
	local spec = SpecBuild.Build({
		name = DIRECTOR,
		config = config,
		modOptions = modOptions,
		teamID = raptorTeamID,
		allyTeamID = raptorAllyTeamID,
		teamCount = config.humanTeamCount,
		unitCap = math.floor(Game.maxUnits * 0.80),
		hooks = hooks,
	})
	if not GG.Waves.Start(spec) then
		Spring.Log(LOG_TAG, LOG.ERROR, "could not start the raptors director")
		return
	end
	GG.Raptors = {
		teamID = raptorTeamID,
		allyTeamID = raptorAllyTeamID,
		config = config,
		director = DIRECTOR,
		OnCycleComplete = function()
			if not modOptions.raptor_endless then
				killTeamAt = Spring.GetGameFrame() + ENDGAME_DELAY
			end
		end,
	}
	Spring.SetGameRulesParam("raptorDifficulty", config.difficulty)
end

function gadget:Initialize()
	Spring.Log(LOG_TAG, LOG.INFO, "Raptors activated")
	Spring.SetGameRulesParam("BossFightStarted", 0)
	startDirector()
end

function gadget:Shutdown()
	GG.Raptors = nil
end

function gadget:GameFrame(n)
	if n == 1 then
		collapseRaptorAllies()
		-- The AI's starting units are not part of the roster.
		for _, unitID in ipairs(Spring.GetTeamUnits(raptorTeamID)) do
			Spring.DestroyUnit(unitID, false, true)
		end
	end
	if killTeamAt ~= nil and n >= killTeamAt then
		killTeamAt = nil
		endTheHunt()
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]
	if unitTeam == raptorTeamID then
		Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { config.defaultRaptorFirestate }, 0)
		if unitDef.canCloak then
			Spring.GiveOrderToUnit(unitID, CMD_CLOAK_SHIELD, { 1 }, 0)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
	if unitTeam ~= raptorTeamID or GG.Waves == nil then
		return
	end
	local unitDef = UnitDefs[unitDefID]
	local byPlayer = attackerID ~= nil and Spring.GetUnitTeam(attackerID) ~= raptorTeamID
	if unitDefID == config.burrowDef then
		if math.random() <= config.spawnChance then
			GG.Waves.SpawnStructures(DIRECTOR)
		end
	elseif unitDef.isBuilding and byPlayer then
		GG.Waves.AddAggression(DIRECTOR, (config.angerBonus / (config.raptorSpawnMultiplier or 1)) * 0.1)
	end
end

function gadget:UnitPreDamaged(_, _, unitTeam, damage, _, _, _, _, attackerDefID, attackerTeam)
	if unitTeam == raptorTeamID then
		if
			attackerTeam == raptorTeamID
			and not (attackerDefID and config.raptorBehaviours.ALLOWFRIENDLYFIRE[attackerDefID])
		then
			return 0, 1
		end
		damage = damage / config.healthMod
	end
	if attackerTeam == raptorTeamID then
		damage = damage * config.damageMod
	end
	return damage, 1
end

function gadget:AllowUnitTransfer(_, _, _, newTeam)
	return newTeam ~= raptorTeamID
end
