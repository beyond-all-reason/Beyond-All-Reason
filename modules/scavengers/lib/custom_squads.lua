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
	local distance = params.scavsquadbehaviordistance
	local chance = params.scavsquadbehaviorchance

	---@param defaultChance number
	---@param defaultDistance number
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
---@param sea boolean
---@return string bucket
local function bucketFor(params, canFly, sea)
	if params.scavsquadbehavior == "healer" then
		return sea and "healerSea" or "healerLand"
	end
	local air = (canFly or params.scavsquadforceair) and not params.scavsquadforcesurface
	local basic = params.scavsquadrarity == "basic"
	if basic then
		if air then
			return sea and "basicAirSea" or "basicAirLand"
		end
		return sea and "basicSea" or "basicLand"
	end
	if air then
		return sea and "specialAirSea" or "specialAirLand"
	end
	return sea and "specialSea" or "specialLand"
end

---@class CustomSquadResult
---@field squads { bucket: string, minAnger: number, maxAnger: number, weight: integer, units: table[] }[]
---@field behaviours table<string, table<string, table|boolean>> category -> unit name -> record

---@param unitDefNames table<string, table> name -> def (needs customParams and canFly)
---@return CustomSquadResult
function CustomSquads.Scan(unitDefNames)
	local names = {}
	for name in pairs(unitDefNames or {}) do
		names[#names + 1] = name
	end
	-- Sorted: a roster whose contents depend on table iteration order is a
	-- roster that differs between clients.
	table.sort(names)

	local result = { squads = {}, behaviours = {} }
	for _, name in ipairs(names) do
		local unitDef = unitDefNames[name]
		local params = unitDef and unitDef.customParams
		if params and params.scavcustomsquad == "1" then
			local units = { { count = number(params, "scavsquadunitsamount", 1), unit = name } }
			local minAnger = number(params, "scavsquadminanger", 0)
			local maxAnger = number(params, "scavsquadmaxanger", 999)
			local weight = number(params, "scavsquadweight", 1)

			if params.scavsquadbehavior then
				for category, record in pairs(behaviourFor(params.scavsquadbehavior, params)) do
					result.behaviours[category] = result.behaviours[category] or {}
					result.behaviours[category][name] = record
				end
			end

			local surface = params.scavsquadsurface
			for _, sea in ipairs({ false, true }) do
				local wants = surface == nil or surface == "mixed" or surface == (sea and "sea" or "land")
				if wants then
					result.squads[#result.squads + 1] = {
						bucket = bucketFor(params, unitDef.canFly and true or false, sea),
						minAnger = minAnger,
						maxAnger = maxAnger,
						weight = weight,
						units = units,
					}
				end
			end
		end
	end
	return result
end

return CustomSquads
