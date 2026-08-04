local EconomyScale = {}

-- Each multiplier contributes only a third of its deviation from 1: the dials
-- compound, and a host who turns three of them up should not get a cubed
-- difficulty spike.
local DIAL_SHARE = 0.33
local DIAL_BASE = 0.67

-- Starting resources move the needle a tenth as much as income does — they
-- are one-off, not a rate.
local START_SHARE = 0.1
local START_BASE = 0.9
local START_REFERENCE = 1000
local START_SPAN = 9000

local MAX_SCALE = 5

---@param value number|nil
---@param default number
---@return number
local function dial(value, default)
	return type(value) == "number" and value or default
end

---@param modOptions table the Spring.GetModOptions() snapshot
---@return number
function EconomyScale.Compute(modOptions)
	modOptions = modOptions or {}
	local startMetal = dial(modOptions.startmetal, START_REFERENCE)
	local startEnergy = dial(modOptions.startenergy, START_REFERENCE)

	local scale = dial(modOptions.multiplier_resourceincome, 1)
		* (DIAL_BASE + (dial(modOptions.multiplier_metalextraction, 1) * DIAL_SHARE))
		* (DIAL_BASE + (dial(modOptions.multiplier_energyconversion, 1) * DIAL_SHARE))
		* (DIAL_BASE + (dial(modOptions.multiplier_energyproduction, 1) * DIAL_SHARE))
		* (((((startMetal - START_REFERENCE) / START_SPAN) + 1) * START_SHARE) + START_BASE)
		* (((((startEnergy - START_REFERENCE) / START_SPAN) + 1) * START_SHARE) + START_BASE)

	-- The same third-share flattening once more over the product, so a default
	-- game lands on exactly 1.
	return math.min(MAX_SCALE, (scale * DIAL_SHARE) + DIAL_BASE)
end

---Drops one for Gaia — always present, never a player.
---@param teamList integer[]
---@param getTeamLuaAI fun(teamID: integer): string|nil
---@param aiMarker string the LuaAI name fragment that marks a director team
---@return integer
function EconomyScale.HumanTeamCount(teamList, getTeamLuaAI, aiMarker)
	local count = -1
	for _, teamID in ipairs(teamList or {}) do
		local luaAI = getTeamLuaAI(teamID)
		if not (luaAI and string.find(luaAI, aiMarker)) then
			count = count + 1
		end
	end
	return count
end

return EconomyScale
