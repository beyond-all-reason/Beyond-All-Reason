
local Boss = {}

---@return { spawned: integer, killed: integer, ids: table<integer, boolean>, aliveMaxHealth: number }
function Boss.NewState()
	return { spawned = 0, killed = 0, ids = {}, aliveMaxHealth = 0 }
end

---Two ways in. The countdown reaching 100 is the intended one. The other is
---the escape hatch: a map with one burrow left, well past grace, means the
---players have won the attrition fight and the wave director has no way to
---spend its clock — so the boss comes early rather than never.
---@param bossAnger number
---@param burrowCount integer
---@param t number game seconds
---@param gracePeriod number
---@return boolean
function Boss.IsDue(bossAnger, burrowCount, t, gracePeriod)
	return bossAnger >= 100 or (burrowCount <= 1 and t > gracePeriod + 60)
end

---@param state { spawned: integer, killed: integer }
---@param config WaveBossConfig
---@return boolean
function Boss.CanSpawnMore(state, config)
	return state.spawned < config.count
end

---Floored so an early boss is still a boss; a boss that arrives through the
---A boss that arrives through the escape hatch above is a pushover by design.
---@param maxHealth number
---@param techAnger number
---@param minFraction number
---@return number
function Boss.SpawnHealth(maxHealth, techAnger, minFraction)
	return math.max(maxHealth * (techAnger * 0.01), maxHealth * minFraction)
end

---The health bar every UI panel reads: one number across every boss alive or
---dead this cycle, so killing three of five reads as 40% and not as a bar
---that resets each time.
---@param statuses table<string, { isDead: boolean|nil, health: number|nil, maxHealth: number|nil }>
---@return integer percent 0-100
---@return number aliveMaxHealth the resistance denominator
function Boss.HealthPercent(statuses)
	local totalHealth, totalMaxHealth, aliveMax = 0, 0, 0
	for _, status in pairs(statuses) do
		local maxHealth = status.maxHealth or 0
		if status.isDead then
			totalMaxHealth = totalMaxHealth + maxHealth
		else
			totalHealth = totalHealth + (status.health or 0)
			totalMaxHealth = totalMaxHealth + maxHealth
			aliveMax = aliveMax + maxHealth
		end
	end
	if totalMaxHealth <= 0 then
		return 0, 0
	end
	return math.floor(0.5 + ((totalHealth / totalMaxHealth) * 100)), aliveMax
end

---@param state { spawned: integer, killed: integer }
---@param config WaveBossConfig
---@return boolean
function Boss.CycleComplete(state, config)
	return state.killed >= config.count
end

return Boss
