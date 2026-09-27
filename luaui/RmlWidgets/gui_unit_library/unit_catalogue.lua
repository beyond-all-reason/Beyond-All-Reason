-- The unit library's catalogue, its classification and its filter (refactor plan, U2 and U7).
-- Pure: it is handed the UnitDefs and WeaponDefs tables (and a file-exists test for unit
-- pictures) rather than reading the engine, so all of it runs in the spec suite
-- (spec/mission_editor/unit_catalogue_spec.lua).
--
-- What a unit library offers is taken from uBdev's dev panel (PtaQ: a basis, not code to copy):
-- a picture per unit with the icon type as the fallback, tech level, faction, search over the
-- internal and the human name. U7 (PtaQ, 2026-09-27: "the roster is very big") adds the rest:
-- every unit carries a TYPE, a DOMAIN and ROLES, and the filter combines them.
--
--   type    bot veh ship air seaplane hover turret util eco factory (and "other")
--   domain  land sea air (a set: a hovercraft is land AND sea)
--   roles   builder scout raider skirmish arty aa -- inferred from stats against the units of
--           the same tier and domain, never from names (see Catalogue.ROLE_RULES)

local Catalogue = {}

--- Never offered: editor furniture, not mission content.
Catalogue.HIDDEN = { editorgodbuilder = true }

Catalogue.FACTIONS = { "arm", "cor", "leg", "other" }
Catalogue.TIERS = { 1, 2, 3, 4 }
Catalogue.TYPES = { "bot", "veh", "hover", "ship", "air", "seaplane", "turret", "eco", "util", "factory" }
Catalogue.ROLES = { "builder", "scout", "raider", "skirmish", "arty", "aa" }
Catalogue.DOMAINS = { "land", "sea", "air" }

--- The rows the filter has, in the order the library shows them.
Catalogue.ROWS = { "faction", "tier", "type", "role", "domain" }

--- How roles are read off the stats. Every threshold is a PERCENTILE among the unit's peers
--- (same tier, same main domain, mobile, armed, not a builder), so "fast" means fast for a T1
--- land unit and not fast next to a T3 aircraft. One table, so a wrong call is fixed here.
Catalogue.ROLE_RULES = {
	-- Cheap, armed, among the quickest, and sees far for what it costs (the Flea: 600 sight
	-- for 21 metal at 132 speed; the Grunt is cheap but slow, the Pawn quick but short-sighted).
	scout = { maxCostPct = 0.25, minSightPerCostPct = 0.85, minSpeedPct = 0.8 },
	-- In the air a scout carries no gun at all (Peeper, Fink): cheap and long-sighted.
	airScout = { maxCostPct = 0.35, minSightPct = 0.7 },
	-- Fast and cheap, fighting up close.
	raider = { minSpeedPct = 0.55, maxRangePct = 0.5, maxCostPct = 0.6 },
	-- Out-ranges the pack without being artillery.
	skirmish = { minRangePct = 0.65 },
	-- A lobbed (high-trajectory) weapon; or very long range and not quick.
	arty = { minRangePct = 0.85, maxSpeedPct = 0.6 },
}

--- The faction a unit belongs to, by name prefix. Scavenger and raptor variants are OTHER,
--- whatever their prefix says, because a designer looking for Armada does not want them.
function Catalogue.factionOf(name)
	name = tostring(name)
	if name:find("_scav", 1, true) or name:find("raptor", 1, true) then
		return "other"
	end
	local prefix = name:sub(1, 3)
	if prefix == "arm" or prefix == "cor" or prefix == "leg" then
		return prefix
	end
	return "other"
end

local function lower(value)
	return tostring(value or ""):lower()
end

local function hasTarget(targets, name)
	for key, value in pairs(targets or {}) do
		local category = (type(key) == "string") and key or value
		if lower(category) == name then
			return true
		end
	end
	return false
end

--- The numbers a unit is judged on.
---@return table { speed, cost, sight, range, lofted, armed, aaOnly, mobile, builder, flies, smClass, water, subfolder, group }
function Catalogue.statsOf(def, weaponDefs)
	local custom = def.customParams or {}
	local range, lofted, armed, surface = 0.0, false, false, false
	for _, weapon in ipairs(def.weapons or {}) do
		local wd = weaponDefs and weaponDefs[weapon.weaponDef]
		-- Shields and interceptors (a mobile anti-nuke "reaches" 72000 elmos) are not guns.
		if
			wd
			and not lower(wd.name):find("shield", 1, true)
			and lower(wd.type) ~= "shield"
			and (tonumber(wd.interceptor) or 0) == 0
		then
			armed = true
			local airOnly = hasTarget(weapon.onlyTargets, "vtol") and not hasTarget(weapon.onlyTargets, "notair")
			if not airOnly then
				surface = true
				range = math.max(range, tonumber(wd.range) or 0)
				if (tonumber(wd.highTrajectory) or 0) == 1 then
					lofted = true
				end
			end
		end
	end
	local buildOptions = def.buildOptions or {}
	local speed = tonumber(def.speed) or 0
	local building = def.isBuilding == true or (speed == 0 and not def.canFly)
	local moveDef = def.moveDef or {}
	local metal = tonumber(def.metalCost) or 0
	local energy = tonumber(def.energyCost) or 0
	return {
		speed = speed,
		cost = metal,
		energy = energy,
		-- POWER, the sort's "how much unit is this": metal plus energy at 60 to 1, the exchange
		-- rate BAR's own unit stats use when they fold the two costs into one number.
		power = metal + energy / 60,
		health = tonumber(def.health) or 0,
		-- SIZE: the footprint in build squares (8 elmos each side).
		footprint = (tonumber(def.xsize) or 0) * (tonumber(def.zsize) or 0) / 4,
		sight = tonumber(def.sightDistance or def.losRadius) or 0,
		range = range,
		lofted = lofted,
		armed = armed,
		aaOnly = armed and not surface,
		mobile = not building,
		builder = #buildOptions > 0 or def.isBuilder == true,
		buildOptions = #buildOptions,
		flies = def.canFly == true,
		smClass = tonumber(moveDef.smClass),
		water = tonumber(def.minWaterDepth) or 0,
		subfolder = lower(custom.subfolder),
		group = lower(custom.unitgroup),
	}
end

--- A unit's TYPE. The subfolder a def was filed under says it best (ArmBots, CorShips/T2,
--- Legion/Air/...); the engine's own fields decide where it says nothing useful.
function Catalogue.typeOf(stats)
	local sub = stats.subfolder
	if stats.flies then
		return sub:find("seaplane", 1, true) and "seaplane" or "air"
	end
	if stats.mobile then
		if sub:find("hover", 1, true) or stats.smClass == 2 then
			return "hover"
		end
		if sub:find("ship", 1, true) or stats.smClass == 3 then
			return "ship"
		end
		if sub:find("vehic", 1, true) or stats.smClass == 0 then
			return "veh"
		end
		if sub:find("bot", 1, true) or sub:find("gantry", 1, true) or stats.smClass == 1 then
			return "bot"
		end
		return "bot"
	end
	-- Buildings.
	if
		stats.buildOptions > 0 and (sub:find("factor", 1, true) or sub:find("lab", 1, true) or stats.buildOptions > 3)
	then
		return "factory"
	end
	if sub:find("econom", 1, true) or stats.group == "energy" or stats.group == "metal" then
		return "eco"
	end
	if sub:find("defen", 1, true) or stats.armed then
		return "turret"
	end
	return "util"
end

--- Where a unit lives, as a set. A hovercraft crosses both; a building in the sea is sea.
function Catalogue.domainsOf(stats, unitType)
	if unitType == "air" or unitType == "seaplane" then
		return { air = true }
	end
	if unitType == "hover" then
		return { land = true, sea = true }
	end
	if unitType == "ship" or stats.water > 0 or stats.subfolder:find("sea", 1, true) then
		return { sea = true }
	end
	return { land = true }
end

--- The domain a unit is compared within for its roles: its first of air, sea, land.
local function mainDomain(domains)
	return (domains.air and "air") or (domains.land and "land") or "sea"
end

--- The fraction of `values` below `value` (0 = the smallest, 1 = the largest).
local function percentile(sorted, value)
	local n = #sorted
	if n <= 1 then
		return 0.5
	end
	local below = 0
	for _, other in ipairs(sorted) do
		if other < value then
			below = below + 1
		end
	end
	return below / (n - 1)
end

--- The factions whose units set the scale. Raptors and scavengers (126 raptor defs alone)
--- would drag every percentile; they are still judged, against the playable factions.
---@type table<string, boolean>
local SCALE_FACTIONS = { arm = true, cor = true, leg = true }

--- Roles for every entry, each judged against its peers (same tier, same main domain,
--- mobile, not a builder). A builder is only a builder; an AA-only unit is only AA.
function Catalogue.assignRoles(entries)
	---@type table<string, table>
	local groups = {}
	for _, entry in ipairs(entries) do
		local s = entry.stats
		entry.roles = {}
		if s.mobile and s.builder then
			entry.roles.builder = true
		elseif s.mobile and s.aaOnly then
			entry.roles.aa = true
		elseif s.mobile then
			local key = entry.tier .. ":" .. mainDomain(entry.domains)
			local g = groups[key]
			if not g then
				g = { entries = {}, speed = {}, cost = {}, range = {}, sightPerCost = {}, sight = {} }
				groups[key] = g
			end
			g.entries[#g.entries + 1] = entry
			if SCALE_FACTIONS[entry.faction] then
				g.speed[#g.speed + 1] = s.speed
				g.cost[#g.cost + 1] = s.cost
				g.sight[#g.sight + 1] = s.sight
				g.sightPerCost[#g.sightPerCost + 1] = s.sight / math.max(1, s.cost)
				if s.armed then
					g.range[#g.range + 1] = s.range
				end
			end
		end
	end
	local rules = Catalogue.ROLE_RULES
	for _, g in pairs(groups) do
		table.sort(g.speed)
		table.sort(g.cost)
		table.sort(g.range)
		table.sort(g.sightPerCost)
		table.sort(g.sight)
		for _, entry in ipairs(g.entries) do
			local s = entry.stats
			local speedPct, costPct = percentile(g.speed, s.speed), percentile(g.cost, s.cost)
			local rangePct = s.armed and percentile(g.range, s.range) or 0
			local sightPerCostPct = percentile(g.sightPerCost, s.sight / math.max(1, s.cost))
			local roles = entry.roles
			if entry.domains.air then
				-- Aircraft: scouts only (fighters are AA, builders are builders). A bomber's
				-- "range" is its bomb's, and ground roles mean nothing up there.
				if
					not s.armed
					and costPct <= rules.airScout.maxCostPct
					and percentile(g.sight, s.sight) >= rules.airScout.minSightPct
				then
					roles.scout = true
				end
			else
				if
					s.armed
					and costPct <= rules.scout.maxCostPct
					and sightPerCostPct >= rules.scout.minSightPerCostPct
					and speedPct >= rules.scout.minSpeedPct
				then
					roles.scout = true
				end
				if
					s.armed
					and (s.lofted or (rangePct >= rules.arty.minRangePct and speedPct <= rules.arty.maxSpeedPct))
				then
					roles.arty = true
				elseif s.armed and rangePct >= rules.skirmish.minRangePct then
					roles.skirmish = true
				end
				if
					s.armed
					and not roles.scout
					and speedPct >= rules.raider.minSpeedPct
					and rangePct <= rules.raider.maxRangePct
					and costPct <= rules.raider.maxCostPct
				then
					roles.raider = true
				end
			end
		end
	end
end

--- The words a search matches besides the names: "t2 arty cor" finds T2 Cortex artillery.
local function tagWords(entry)
	local words = { "t" .. entry.tier, entry.faction, entry.type }
	for domain in pairs(entry.domains) do
		words[#words + 1] = domain
	end
	for role in pairs(entry.roles or {}) do
		words[#words + 1] = role
	end
	return words
end

--- Every placeable unit type, classified and sorted: those with a unit picture first (a tile
--- with a real picture is what the eye finds), then by human name.
---@param unitDefs table the engine's UnitDefs (array by id)
---@param fileExists fun(path: string): boolean
---@param iconTypes table|nil gamedata/icontypes.lua, for the fallback picture
---@param weaponDefs table|nil the engine's WeaponDefs, for ranges and trajectories
---@return table entries
function Catalogue.build(unitDefs, fileExists, iconTypes, weaponDefs)
	local entries = {}
	for _, def in pairs(unitDefs or {}) do
		if type(def) == "table" and type(def.name) == "string" and not Catalogue.HIDDEN[def.name] then
			local pic = "unitpics/" .. def.name .. ".dds"
			local hasPic = fileExists and fileExists(pic) or false
			local img
			if hasPic then
				img = "/" .. pic
			else
				local icon = iconTypes and def.iconType and iconTypes[def.iconType]
				img = (icon and icon.bitmap) and ("/" .. icon.bitmap) or "/icons/inverted/blank.png"
			end
			local custom = def.customParams or {}
			local group = custom.unitgroup or "weaponexplo"
			if group == "explo" then
				group = "weaponexplo"
			end
			local stats = Catalogue.statsOf(def, weaponDefs)
			local unitType = Catalogue.typeOf(stats)
			local human = tostring(def.translatedHumanName or def.humanName or def.name)
			entries[#entries + 1] = {
				name = def.name,
				human = human,
				img = img,
				tier = math.max(1, math.min(4, tonumber(custom.techlevel) or 1)),
				faction = Catalogue.factionOf(def.name),
				group = group,
				type = unitType,
				domains = Catalogue.domainsOf(stats, unitType),
				building = not stats.mobile,
				hasPic = hasPic,
				stats = stats,
			}
		end
	end
	Catalogue.assignRoles(entries)
	for _, entry in ipairs(entries) do
		entry.tags = tagWords(entry)
		entry.search = (entry.name .. " " .. entry.human:lower() .. " " .. table.concat(entry.tags, " ")):lower()
	end
	table.sort(entries, function(a, b)
		if a.hasPic ~= b.hasPic then
			return a.hasPic
		end
		if a.human ~= b.human then
			return a.human < b.human
		end
		return a.name < b.name
	end)
	return entries
end

--- Does an entry pass one row? An empty (or absent) selection passes everything; several
--- values in a row pass if ANY matches (OR within a row).
local function rowPasses(entry, row, selected)
	if not selected or next(selected) == nil then
		return true
	end
	if row == "faction" then
		return selected[entry.faction] == true
	elseif row == "tier" then
		return selected[entry.tier] == true or selected[tostring(entry.tier)] == true
	elseif row == "type" then
		return selected[entry.type] == true
	elseif row == "role" then
		for role in pairs(entry.roles or {}) do
			if selected[role] then
				return true
			end
		end
		return false
	elseif row == "domain" then
		for domain in pairs(entry.domains or {}) do
			if selected[domain] then
				return true
			end
		end
		return false
	end
	return true
end

--- Every search word must be found in the names or the tags (AND across words).
local function searchPasses(entry, words)
	for _, word in ipairs(words) do
		if not entry.search:find(word, 1, true) then
			return false
		end
	end
	return true
end

local function searchWords(text)
	local words = {}
	for word in tostring(text or ""):lower():gmatch("%S+") do
		words[#words + 1] = word
	end
	return words
end

--- The entries a filter lets through, in catalogue order. Rows combine with AND; values
--- within a row with OR. `except` leaves one row out (for the per-chip counts).
---@param filter table { search: string, faction = set, tier = set, type = set, role = set, domain = set }
---@param except string|nil a row to ignore
---@return table matches
function Catalogue.filter(entries, filter, except)
	filter = filter or {}
	local words = searchWords(filter.search)
	local out = {}
	for _, entry in ipairs(entries or {}) do
		local ok = searchPasses(entry, words)
		for _, row in ipairs(Catalogue.ROWS) do
			if ok and row ~= except then
				ok = rowPasses(entry, row, filter[row])
			end
		end
		if ok then
			out[#out + 1] = entry
		end
	end
	return out
end

--- How many units each chip would show if it were the only choice in its row, given every
--- OTHER row as it is: a zero is visible before anyone clicks it.
---@return table counts row -> value -> number
function Catalogue.counts(entries, filter)
	local counts = {}
	for _, row in ipairs(Catalogue.ROWS) do
		local rest = Catalogue.filter(entries, filter, row)
		local c = {}
		for _, entry in ipairs(rest) do
			if row == "faction" then
				c[entry.faction] = (c[entry.faction] or 0) + 1
			elseif row == "tier" then
				c[entry.tier] = (c[entry.tier] or 0) + 1
			elseif row == "type" then
				c[entry.type] = (c[entry.type] or 0) + 1
			elseif row == "role" then
				for role in pairs(entry.roles or {}) do
					c[role] = (c[role] or 0) + 1
				end
			elseif row == "domain" then
				for domain in pairs(entry.domains or {}) do
					c[domain] = (c[domain] or 0) + 1
				end
			end
		end
		counts[row] = c
	end
	return counts
end

--- A chip pressed: plain replaces the row with that value (or clears it if it was the only
--- one), Shift adds or removes it. Returns the row's new selection.
function Catalogue.toggle(selected, value, additive)
	selected = selected or {}
	if additive then
		local out = {}
		for k, v in pairs(selected) do
			out[k] = v
		end
		out[value] = (not out[value]) or nil
		return out
	end
	local count = 0
	for _ in pairs(selected) do
		count = count + 1
	end
	if selected[value] and count == 1 then
		return {}
	end
	return { [value] = true }
end

--- Most-recent-first list of picked names, without repeats, at most `limit` long.
function Catalogue.remember(recent, name, limit)
	local out = { name }
	for _, other in ipairs(recent or {}) do
		if other ~= name and #out < (limit or 8) then
			out[#out + 1] = other
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Sorting (PtaQ, 2026-09-27)
--------------------------------------------------------------------------------

--- The sort keys, in the order the SORT chips show them. `desc` is the direction a key starts
--- in when picked: the biggest, fastest, strongest first; names A to Z.
Catalogue.SORTS = {
	{ key = "name", label = "NAME", desc = false },
	{ key = "power", label = "POWER", desc = true },
	{ key = "type", label = "TYPE", desc = false },
	{ key = "size", label = "SIZE", desc = true },
	{ key = "tier", label = "TIER", desc = false },
	{ key = "speed", label = "SPEED", desc = true },
	{ key = "range", label = "RANGE", desc = true },
	{ key = "health", label = "HEALTH", desc = true },
}

local TYPE_ORDER = {}
for index, value in ipairs(Catalogue.TYPES) do
	TYPE_ORDER[value] = index
end

local function stat(entry, field)
	return tonumber(entry.stats and entry.stats[field]) or 0
end

--- The value a key sorts on. TYPE sorts by the TYPE chips' order; within one type (and one
--- tier) the order falls through to power, which is what "type, then strongest" should mean.
local SORT_VALUE = {
	power = function(entry)
		return stat(entry, "power")
	end,
	type = function(entry)
		return TYPE_ORDER[entry.type] or #Catalogue.TYPES + 1
	end,
	size = function(entry)
		return stat(entry, "footprint")
	end,
	tier = function(entry)
		return tonumber(entry.tier) or 0
	end,
	speed = function(entry)
		return stat(entry, "speed")
	end,
	range = function(entry)
		return stat(entry, "range")
	end,
	health = function(entry)
		return stat(entry, "health")
	end,
}

--- Is this a sort key?
function Catalogue.sortKnown(key)
	return key == "name" or SORT_VALUE[key] ~= nil
end

--- The direction a key starts in.
function Catalogue.sortDefaultDesc(key)
	for _, sort in ipairs(Catalogue.SORTS) do
		if sort.key == key then
			return sort.desc
		end
	end
	return false
end

--- A sorted COPY of a list of entries. "name" is the catalogue's own order (pictures first,
--- then A to Z); every other key breaks its ties on power, then on the name, so a sort never
--- shuffles equal units differently between two keystrokes.
---@param entries table
---@param key string one of Catalogue.SORTS' keys
---@param desc boolean|nil biggest first
function Catalogue.sort(entries, key, desc)
	local out = {}
	for index, entry in ipairs(entries or {}) do
		out[index] = entry
	end
	local function byName(a, b)
		if a.hasPic ~= b.hasPic then
			return a.hasPic == true
		end
		if a.human ~= b.human then
			return a.human < b.human
		end
		return a.name < b.name
	end
	if key == "name" or not SORT_VALUE[key] then
		if desc then
			table.sort(out, function(a, b)
				return byName(b, a)
			end)
		else
			table.sort(out, byName)
		end
		return out
	end
	local value = SORT_VALUE[key]
	table.sort(out, function(a, b)
		local va, vb = value(a), value(b)
		if va ~= vb then
			if desc then
				return va > vb
			end
			return va < vb
		end
		if key ~= "power" then
			local pa, pb = stat(a, "power"), stat(b, "power")
			if pa ~= pb then
				return pa > pb
			end
		end
		return byName(a, b)
	end)
	return out
end

return Catalogue
