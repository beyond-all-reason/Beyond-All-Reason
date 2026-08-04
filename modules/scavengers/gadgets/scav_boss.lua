local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scavengers Boss",
		desc = "Boss resistance, the stagger bank, and the shared boss health bar",
		author = "Damgam, Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		-- Above the flavor gadget: its damage modifiers apply first, and the
		-- boss's own arithmetic is the last word on what a boss takes.
		layer = 10,
		enabled = true,
	}
end

if not (Spring.Utilities.Gametype.IsScavengers() and not Spring.Utilities.Gametype.IsRaptors()) then
	return false
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- The boss fight, and only the boss fight.
--
-- Two mechanics, both scavenger-specific, both deliberately left out of the
-- waves module. RESISTANCE is an adaptation: the boss learns what is hurting
-- it and takes less from that weapon, which is what stops one massed unit
-- type from being the answer every game. STAGGER is the counter-adaptation:
-- damage fills a bank, and a full bank paralyses the boss for a window that
-- gets longer and costlier every time — so burst damage is rewarded even
-- though sustained damage is resisted.
--
-- Callins are hooked only while a boss is alive.
--------------------------------------------------------------------------------

local WAVE_EVENT = "ScavEvent"

local scavTeamID
local config
local bossIDs = {} ---@type table<integer, boolean>
local bossCount = 0

-- Serialized to pveBossInfo for the UI: per-boss status, per-weapon
-- resistance, per-team damage contribution.
local bosses = { resistances = {}, statuses = {}, playerDamages = {} }
local aliveMaxHealth = 0
local healthPercentage = nil ---@type number|nil

local stagger = nil ---@type table|nil
local staggerMultiplier = {} ---@type table<integer, number>

-- How many bosses this cycle expects. The stagger divisor, so a five-boss
-- fight does not fill the bank five times as fast.
local expectedBosses = 1

--------------------------------------------------------------------------------

local Boss = VFS.Include("modules/waves/lib/boss.lua")

for defID, unitDef in ipairs(UnitDefs) do
	staggerMultiplier[defID] = tonumber(unitDef.customParams.bossStaggerMultiplier) or 1
end

---@param cfg table
local function newStagger(cfg)
	return {
		health = cfg.health,
		currentHealth = cfg.health - 1,
		time = cfg.time,
		currentTimer = cfg.time + 1,
		active = false,
	}
end

local HOT_CALLINS = { "GameFrame", "UnitPreDamaged", "UnitDamaged" }
local hot = {}

---Install once and leave installed. Unhooking from inside a callin is not
---safe: the handler defers its list update while it is iterating, but the
---method field goes nil at once, and the next gadget it reaches in that same
---loop calls a nil. A boss dying inside GameFrame is exactly that case.
local function installCallins()
	for _, name in ipairs(HOT_CALLINS) do
		if gadget[name] == nil then
			gadget[name] = hot[name]
			gadgetHandler:UpdateCallIn(name)
		end
	end
end

---Lightning, or a plain effect where the lightning gadget is absent.
---@param x number
---@param y number
---@param z number
---@param spread number
---@param count integer
local function radiation(x, y, z, spread, count)
	for _ = 1, count do
		local px = x + math.random(-spread, spread)
		local pz = z + math.random(-spread, spread)
		if GG.SpawnEnvironmentalLightning then
			GG.SpawnEnvironmentalLightning("scavradiation", px, y + 100, pz)
		else
			Spring.SpawnCEG("scavradiation-lightning", px, y + 100, pz, 0, 0, 0)
		end
	end
end

---One second of the stagger machine.
---
---Reads as a state machine because it is one: banking while the boss is
---upright, discharging while it is down, and on recovery the bank grows a
---tenth and the window five seconds — so the second stagger costs more than
---the first and the tenth is a real investment.
local function tickStagger()
	if stagger == nil or bossCount == 0 then
		return
	end

	if not stagger.active then
		if stagger.currentHealth > 0 then
			Spring.SetGameRulesParam("scavBossStaggerPercentage",
				math.ceil((stagger.currentHealth / stagger.health) * 100))
			for bossID in pairs(bossIDs) do
				Spring.SetUnitHealth(bossID, { paralyze = 0 })
			end
		else
			stagger.active = true
			stagger.currentTimer = stagger.time + 0
			for bossID in pairs(bossIDs) do
				local x, y, z = Spring.GetUnitPosition(bossID)
				Spring.AddUnitDamage(bossID, 0, 1600000)
				Spring.SetUnitHealth(bossID, { paralyze = 16000000 })
				radiation(x, y, z, 1000, 50)
			end
			Spring.SetGameRulesParam("scavBossStaggerPercentage",
				math.ceil((1 - (stagger.currentTimer / stagger.time)) * 100))
		end
	end

	if stagger.active then
		stagger.currentTimer = stagger.currentTimer - 1
		if stagger.currentTimer > 0 then
			Spring.SetGameRulesParam("scavBossStaggerPercentage",
				math.ceil((1 - (stagger.currentTimer / stagger.time)) * 100))
			for bossID in pairs(bossIDs) do
				local x, y, z = Spring.GetUnitPosition(bossID)
				Spring.AddUnitDamage(bossID, 0, 1600000)
				Spring.SetUnitHealth(bossID, { paralyze = 16000000 })
				radiation(x, y, z, 500, 10)
			end
		else
			stagger.active = false
			stagger.time = stagger.time + 5
			stagger.currentTimer = stagger.time + 0
			stagger.health = stagger.health * 1.1
			stagger.currentHealth = stagger.health
			Spring.SetGameRulesParam("scavBossStaggerPercentage",
				math.ceil((stagger.currentHealth / stagger.health) * 100))
		end
	elseif stagger.currentHealth <= 0 then
		stagger.currentTimer = stagger.currentTimer - 1
	end

	Spring.SetGameRulesParam("scavBossStaggerActive", stagger.active)
end

---Refresh every boss's health and publish the shared bar.
local function tickHealth()
	for bossID, status in pairs(bosses.statuses) do
		if not status.isDead then
			local health, maxHealth = Spring.GetUnitHealth(tonumber(bossID))
			if not health then
				status.isDead = true
			else
				status.health = health
				status.maxHealth = maxHealth
			end
		end
	end

	local percent, aliveMax = Boss.HealthPercent(bosses.statuses)
	healthPercentage = percent
	aliveMaxHealth = aliveMax
	Spring.SetGameRulesParam("scavBossHealth", percent)
	Spring.SetGameRulesParam("pveBossInfo", Json.encode(bosses))
end

hot.GameFrame = function(_, n)
	if bossCount > 0 and n % 30 == 16 then
		tickStagger()
		tickHealth()
	end
end

---Damage TO a boss.
---
---Order matters and is the monolith's: the health-fraction curve first (a
---healthy boss takes double, a nearly-dead one a quarter — the fight has a
---shape), then the per-weapon resistance bank, then the stagger bank, and
---the resistance is applied twice over depending on whether the boss is
---currently down.
---@return number|nil damage
local function damageToBoss(unitID, damage, weaponID, attackerDefID)
	if attackerDefID == nil then
		-- Nothing to learn from: unattributed damage is capped at a scratch.
		return 1
	end
	if weaponID == -1 and damage > 1 then
		-- Collisions and debris do not get to chip a boss down.
		damage = 1
	end

	if healthPercentage then
		if healthPercentage > 50 then
			damage = damage * 2
		elseif healthPercentage > 25 then
			damage = damage
		elseif healthPercentage > 10 then
			damage = damage * 0.75
		elseif healthPercentage > 5 then
			damage = damage * 0.5
		else
			damage = damage * 0.25
		end
	end

	-- The bank is keyed by attacker def as a STRING: pveBossInfo is JSON, and
	-- a numeric key would come out the other side as an array.
	local key = tostring(attackerDefID)
	local resistMult = config.bossResistanceMult
	if not bosses.resistances[key] then
		bosses.resistances[key] = { damage = damage * 5 * resistMult, notify = 0 }
	end
	local bank = bosses.resistances[key]
	local resistPercent = math.min(bank.damage / math.max(1, aliveMaxHealth), 0.95)

	if resistPercent > 0.5 then
		if bank.notify == 0 then
			-- Tell the players once, the first time a weapon stops working.
			SendToUnsynced("WaveEvent", WAVE_EVENT, "bossResistance", tonumber(attackerDefID))
			bank.notify = 1
		end
		damage = damage - (damage * resistPercent)
	end

	-- Stagger banks the damage the resistance did NOT eat, floored at a
	-- quarter: a fully-resisted weapon still contributes to the stagger, which
	-- is what keeps a resisted army from being useless.
	local banked = math.max(damage * 0.25, math.min(damage * (1 - resistPercent) * 2, damage))
	stagger.currentHealth = stagger.currentHealth
		- ((banked / math.sqrt(expectedBosses)) * (staggerMultiplier[attackerDefID] or 1))

	if stagger.active then
		damage = damage - (damage * resistPercent * 0.5)
		-- Hitting a staggered boss shortens the stagger: the window is a
		-- damage opportunity, not a free one.
		stagger.currentTimer = stagger.currentTimer - (damage * 0.0001)
		local x, y, z = Spring.GetUnitPosition(unitID)
		radiation(x, y, z, 500, 1)
	else
		damage = damage - (damage * resistPercent)
	end

	bank.damage = bank.damage + (damage * 5 * resistMult)
	bank.percent = resistPercent
	return damage
end

---Damage FROM a boss: the mirror of the curve above, so a boss that is
---nearly dead hits hardest.
---@return number damage
local function damageFromBoss(damage)
	if not healthPercentage then
		return damage
	end
	if healthPercentage > 50 then
		return damage * 0.25
	elseif healthPercentage > 25 then
		return damage * 0.5
	elseif healthPercentage > 10 then
		return damage * 0.75
	elseif healthPercentage > 5 then
		return damage
	end
	return damage * 2
end

hot.UnitPreDamaged = function(_, unitID, _, _, damage, _, weaponID, _, attackerID, attackerDefID)
	if bossCount == 0 then
		return damage, 1
	end
	if bossIDs[unitID] then
		return damageToBoss(unitID, damage, weaponID, attackerDefID), 1
	end
	if attackerID and bossIDs[attackerID] then
		return damageFromBoss(damage), 1
	end
	return damage, 1
end

hot.UnitDamaged = function(_, unitID, _, _, damage, _, _, _, _, _, attackerTeam)
	if bossCount > 0 and bossIDs[unitID] and attackerTeam and attackerTeam ~= scavTeamID then
		local key = tostring(attackerTeam)
		bosses.playerDamages[key] = (bosses.playerDamages[key] or 0) + damage
	end
end

--------------------------------------------------------------------------------

function gadget:UnitDestroyed(unitID)
	if not bossIDs[unitID] then
		return
	end
	bossIDs[unitID] = nil
	bossCount = bossCount - 1
	local status = bosses.statuses[tostring(unitID)]
	if status then
		status.isDead = true
		status.health = 0
	end
	tickHealth()
end

function gadget:Initialize()
	local scavengers = GG.Scavengers
	if scavengers == nil then
		-- The flavor gadget owns discovery; without it there is no fight to
		-- referee. Layers put it first, so this is a real failure, not a race,
		-- and staying inert is better than half-refereeing.
		Spring.Log("scav_boss", LOG.ERROR, "GG.Scavengers missing; boss mechanics disabled")
		return
	end
	scavTeamID = scavengers.teamID
	config = scavengers.config
	expectedBosses = math.max(1, Spring.GetModOptions().scav_boss_count or 1)
	stagger = newStagger(config.bossStagger)

	-- The director tells us when a boss lands; everything above is dormant
	-- until it does.
	GG.Scavengers.OnBossSpawned = function(bossID)
		bossIDs[bossID] = true
		bossCount = bossCount + 1
		bosses.statuses[tostring(bossID)] = {}
	end

	-- Endless mode: a fresh cycle is a fresh boss, and it must not inherit
	-- the last one's resistance bank — the players would face a boss already
	-- immune to everything they own.
	GG.Scavengers.OnCycleComplete = function()
		bosses = { resistances = {}, statuses = {}, playerDamages = bosses.playerDamages }
		aliveMaxHealth = 0
		healthPercentage = nil
		stagger = newStagger(config.bossStagger)
		Spring.SetGameRulesParam("scavBossHealth", 0)
	end

	installCallins()
end

function gadget:Shutdown()
	if GG.Scavengers then
		GG.Scavengers.OnBossSpawned = nil
		GG.Scavengers.OnCycleComplete = nil
	end
end
