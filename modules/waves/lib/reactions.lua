local Reactions = {}

local DEFAULT_TIMEOUT = 2
local DEFAULT_FLEE_SECONDS = 30
local DEFAULT_COWARD_HEALTH_FRACTION = 0.8

---A policy with every dial filled in.
---@class WaveReactionRules
---@field skirmish table<UnitDefName, WaveReaction>
---@field coward table<UnitDefName, WaveReaction>
---@field berserk table<UnitDefName, WaveReaction>
---@field timeout number
---@field fleeSeconds number
---@field cowardHealthFraction number

---@param reactions WaveReactions
---@return WaveReactionRules
function Reactions.Policy(reactions)
	return {
		skirmish = reactions.skirmish or {},
		coward = reactions.coward or {},
		berserk = reactions.berserk or {},
		timeout = reactions.timeout or DEFAULT_TIMEOUT,
		fleeSeconds = reactions.fleeSeconds or DEFAULT_FLEE_SECONDS,
		cowardHealthFraction = reactions.cowardHealthFraction or DEFAULT_COWARD_HEALTH_FRACTION,
	}
end

---@class WaveHit
---@field unitDef UnitDefName|nil the def that was hit
---@field attackerDef UnitDefName|nil
---@field unitIsWave boolean the hit unit belongs to the director
---@field attackerIsWave boolean the attacker belongs to the director
---@field healthFraction number|nil the hit unit's health, as a fraction of max

---@class WaveReactionDecision
---@field kind "flee"|"charge"|"none" none: the unit reacted by holding its ground
---@field actor "unit"|"attacker" who moves
---@field record WaveReaction|nil

---What a hit provokes. The attacker answers first: a skirmisher that landed
---a hit backs off, a berserker that landed one charges. Then the unit hit: a
---coward below its health line runs, a berserker charges.
---@param policy WaveReactionRules
---@param hit WaveHit
---@param rng fun(): number
---@return WaveReactionDecision|nil
function Reactions.Decide(policy, hit, rng)
	if hit.attackerIsWave and hit.attackerDef ~= nil then
		local skirmish = policy.skirmish[hit.attackerDef]
		if skirmish and rng() < skirmish.chance then
			return { kind = "flee", actor = "attacker", record = skirmish }
		end
		local berserk = policy.berserk[hit.attackerDef]
		if berserk and rng() < berserk.chance then
			return { kind = "charge", actor = "attacker", record = berserk }
		end
	end
	if hit.unitIsWave and hit.unitDef ~= nil then
		local coward = policy.coward[hit.unitDef]
		if coward and rng() < coward.chance then
			if hit.healthFraction ~= nil and hit.healthFraction < policy.cowardHealthFraction then
				return { kind = "flee", actor = "unit", record = coward }
			end
			return { kind = "none", actor = "unit", record = coward }
		end
		local berserk = policy.berserk[hit.unitDef]
		if berserk and rng() < berserk.chance then
			return { kind = "charge", actor = "unit", record = berserk }
		end
	end
	return nil
end

---Where a fleeing unit goes: away from (fromX, fromZ) by roughly the
---record's distance.
---@param record WaveReaction
---@param x number
---@param z number
---@param fromX number
---@param fromZ number
---@param rng fun(lo: integer, hi: integer): integer
---@return number tx
---@return number tz
function Reactions.FleeTarget(record, x, z, fromX, fromZ, rng)
	local angle = math.atan2(x - fromX, z - fromZ)
	local distance = rng(math.ceil(record.distance * 0.75), math.floor(record.distance * 1.25))
	return x + math.sin(angle) * distance, z + math.cos(angle) * distance
end

return Reactions
