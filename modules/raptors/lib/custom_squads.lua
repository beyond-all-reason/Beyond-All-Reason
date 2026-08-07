local CustomSquads = {}

---@param params table
---@param key string
---@param default number
---@return number
local function number(params, key, default)
	return tonumber(params[key]) or default
end

---@param class string
---@param params table
---@return table<string, table|boolean> byCategory
local function behaviourFor(class, params)
	local distance = params.raptorsquadbehaviordistance
	local chance = params.raptorsquadbehaviorchance

	local function reaction(defaultChance, defaultDistance)
		return { chance = tonumber(chance) or defaultChance, distance = tonumber(distance) or defaultDistance }
	end

	if class == "berserk" then
		return { BERSERK = reaction(0.1, 2000) }
	elseif class == "skirmisher" then
		return { SKIRMISH = reaction(0.5, 500), COWARD = reaction(0.5, 500) }
	elseif class == "healer" then
		return { COWARD = reaction(1, 500), HEALER = true }
	elseif class == "artillery" then
		return { SKIRMISH = reaction(0.5, 500), COWARD = reaction(0.5, 500), ARTILLERY = true }
	elseif class == "kamikaze" then
		return { BERSERK = reaction(1, 500), KAMIKAZE = true }
	end
	return {}
end

---@param params table
---@param canFly boolean
---@return string pool the legacy pool name
local function poolFor(params, canFly)
	if params.raptorsquadbehavior == "healer" then
		return "healer"
	end
	local air = (canFly or params.raptorsquadforceair) and not params.raptorsquadforcesurface
	if params.raptorsquadrarity == "basic" then
		return air and "basicAir" or "basic"
	end
	return air and "specialAir" or "special"
end

---@class RaptorCustomSquadResult
---@field squads { pool: string, minAnger: number, maxAnger: number, weight: integer, units: table[] }[]
---@field behaviours table<string, table<string, table|boolean>> category -> unit name -> record

---@param unitDefNames table<string, table> name -> def (needs customParams and canFly)
---@return RaptorCustomSquadResult
function CustomSquads.Scan(unitDefNames)
	local names = {}
	for name in pairs(unitDefNames or {}) do
		names[#names + 1] = name
	end
	table.sort(names)

	local result = { squads = {}, behaviours = {} }
	for _, name in ipairs(names) do
		local unitDef = unitDefNames[name]
		local params = unitDef and unitDef.customParams
		if params and params.raptorcustomsquad == "1" then
			if params.raptorsquadbehavior then
				for category, record in pairs(behaviourFor(params.raptorsquadbehavior, params)) do
					result.behaviours[category] = result.behaviours[category] or {}
					result.behaviours[category][name] = record
				end
			end
			result.squads[#result.squads + 1] = {
				pool = poolFor(params, unitDef.canFly and true or false),
				minAnger = number(params, "raptorsquadminanger", 0),
				maxAnger = number(params, "raptorsquadmaxanger", 999),
				weight = number(params, "raptorsquadweight", 1),
				units = { { count = number(params, "raptorsquadunitsamount", 1), unit = name } },
			}
		end
	end
	return result
end

return CustomSquads
