local Boss = VFS.Include("modules/waves/lib/boss.lua")

local BossReferee = {}

---@class BossPolicy
---@field resistanceMult number the difficulty rung's resistance multiplier
---@field stagger { health: number, time: number }|nil the stagger bank; nil disables
---@field staggerDivisor "sqrt"|"linear"|nil how the bank drains against several bosses; "sqrt" unless said
---@field expectedBosses integer how many bosses the cycle fields

---@param healthPercent number|nil
---@return number
local function incomingCurve(healthPercent)
	if healthPercent == nil then
		return 1
	elseif healthPercent > 50 then
		return 2
	elseif healthPercent > 25 then
		return 1
	elseif healthPercent > 10 then
		return 0.75
	elseif healthPercent > 5 then
		return 0.5
	end
	return 0.25
end

---@param healthPercent number|nil
---@return number
local function outgoingCurve(healthPercent)
	if healthPercent == nil then
		return 1
	elseif healthPercent > 50 then
		return 0.25
	elseif healthPercent > 25 then
		return 0.5
	elseif healthPercent > 10 then
		return 0.75
	elseif healthPercent > 5 then
		return 1
	end
	return 2
end

---@param policy BossPolicy
---@return table referee
function BossReferee.New(policy)
	local referee = {
		policy = policy,
		-- Keyed by attacker def as a STRING: pveBossInfo is JSON, and a
		-- numeric key would come out the other side as an array.
		resistances = {},
		statuses = {},
		playerDamages = {},
		aliveMaxHealth = 0,
		healthPercent = nil,
		stagger = nil,
	}

	local function newStagger()
		local cfg = policy.stagger
		if cfg == nil then
			return nil
		end
		return {
			health = cfg.health,
			currentHealth = cfg.health - 1,
			time = cfg.time,
			currentTimer = cfg.time + 1,
			active = false,
		}
	end
	referee.stagger = newStagger()

	local function divisor()
		local n = math.max(1, policy.expectedBosses or 1)
		if policy.staggerDivisor == "linear" then
			return n
		end
		return math.sqrt(n)
	end

	---@param bossID integer
	referee.Track = function(bossID)
		referee.statuses[tostring(bossID)] = {}
	end

	---@param bossID integer
	referee.Died = function(bossID)
		local status = referee.statuses[tostring(bossID)]
		if status then
			status.isDead = true
			status.health = 0
		end
	end

	referee.NextCycle = function()
		referee.resistances = {}
		referee.statuses = {}
		referee.aliveMaxHealth = 0
		referee.healthPercent = nil
		referee.stagger = newStagger()
	end

	---@param readHealth fun(bossID: integer): number|nil, number|nil health, maxHealth
	---@return integer percent
	referee.UpdateHealth = function(readHealth)
		for bossID, status in pairs(referee.statuses) do
			if not status.isDead then
				local health, maxHealth = readHealth(tonumber(bossID))
				if not health then
					status.isDead = true
				else
					status.health = health
					status.maxHealth = maxHealth
				end
			end
		end
		local percent, aliveMax = Boss.HealthPercent(referee.statuses)
		referee.healthPercent = percent
		referee.aliveMaxHealth = aliveMax
		return percent
	end

	---@param damage number
	---@param weaponID integer
	---@param attackerDefID integer|nil
	---@param staggerMultiplier number the attacker def's bossStaggerMultiplier
	---@return number damage
	---@return boolean notify the resistance crossed half: tell the UI once
	referee.Incoming = function(damage, weaponID, attackerDefID, staggerMultiplier)
		if attackerDefID == nil then
			return 1, false
		end
		if weaponID == -1 and damage > 1 then
			damage = 1
		end
		damage = damage * incomingCurve(referee.healthPercent)

		local key = tostring(attackerDefID)
		local resistMult = policy.resistanceMult or 1
		local bank = referee.resistances[key]
		if bank == nil then
			bank = { damage = damage * 5 * resistMult, notify = 0 }
			referee.resistances[key] = bank
		end
		local resistPercent = math.min(bank.damage / math.max(1, referee.aliveMaxHealth), 0.95)
		local notify = false
		if resistPercent > 0.5 then
			if bank.notify == 0 then
				bank.notify = 1
				notify = true
			end
		end

		local stagger = referee.stagger
		if stagger then
			-- The bank takes what the resistance did NOT eat, floored at a
			-- quarter: a fully-resisted weapon still contributes.
			local banked = math.max(damage * 0.25, math.min(damage * (1 - resistPercent) * 2, damage))
			stagger.currentHealth = stagger.currentHealth - ((banked / divisor()) * (staggerMultiplier or 1))
		end

		if stagger and stagger.active then
			damage = damage - (damage * resistPercent * 0.5)
			stagger.currentTimer = stagger.currentTimer - (damage * 0.0001)
		else
			damage = damage - (damage * resistPercent)
		end

		bank.damage = bank.damage + (damage * 5 * resistMult)
		bank.percent = resistPercent
		return damage, notify
	end

	---@param damage number
	---@return number
	referee.Outgoing = function(damage)
		return damage * outgoingCurve(referee.healthPercent)
	end

	---@param attackerTeam integer
	---@param damage number
	referee.Tally = function(attackerTeam, damage)
		local key = tostring(attackerTeam)
		referee.playerDamages[key] = (referee.playerDamages[key] or 0) + damage
	end

	---@return { percent: integer, active: boolean, down: boolean, up: boolean }|nil
	referee.TickStagger = function()
		local stagger = referee.stagger
		if stagger == nil then
			return nil
		end
		local result = { active = stagger.active, down = false, up = false, percent = 0 }
		if not stagger.active then
			if stagger.currentHealth > 0 then
				result.percent = math.ceil((stagger.currentHealth / stagger.health) * 100)
			else
				stagger.active = true
				stagger.currentTimer = stagger.time
				result.active, result.down = true, true
				result.percent = math.ceil((1 - (stagger.currentTimer / stagger.time)) * 100)
			end
		end
		if stagger.active then
			stagger.currentTimer = stagger.currentTimer - 1
			if stagger.currentTimer > 0 then
				result.percent = math.ceil((1 - (stagger.currentTimer / stagger.time)) * 100)
			else
				stagger.active = false
				stagger.time = stagger.time + 5
				stagger.currentTimer = stagger.time
				stagger.health = stagger.health * 1.1
				stagger.currentHealth = stagger.health
				result.active, result.up = false, true
				result.percent = math.ceil((stagger.currentHealth / stagger.health) * 100)
			end
		elseif stagger.currentHealth <= 0 then
			stagger.currentTimer = stagger.currentTimer - 1
		end
		return result
	end

	---@return table
	referee.Info = function()
		return { resistances = referee.resistances, statuses = referee.statuses, playerDamages = referee.playerDamages }
	end

	return referee
end

return BossReferee
