--- Mission unit roster: validate the spawn table a mission's units.lua
--- returns. Pure Lua — no Spring — so it specs under busted; the loader
--- resolves teams and spawns where Spring exists.
---
--- The smallest honest naming mechanism (no loadout system): one entry
--- spawns one unit; `name` makes it addressable as Unit("name"), `group`
--- collects it for the Units verbs. Teams are roles, not ids — "player",
--- "enemy", "gaia" — resolved at arm time.

local Roster = {}

local VALID_TEAMS = { player = true, enemy = true, gaia = true }

---@param data any the table units.lua returned
---@return MissionRosterEntry[]
function Roster.Parse(data)
	assert(type(data) == "table", "units.lua must return a list of spawn entries")
	local entries = {}
	local seenNames = {}
	for index, raw in ipairs(data) do
		local where = "units.lua entry " .. index
		assert(type(raw) == "table", where .. ": entries are tables")
		assert(type(raw.def) == "string", where .. ": def (unit def name) is required")
		assert(type(raw.team) == "string" and VALID_TEAMS[raw.team],
			where .. ': team must be "player", "enemy" or "gaia"')
		assert(type(raw.x) == "number" and type(raw.z) == "number",
			where .. ": x and z are required numbers")
		assert(raw.facing == nil or type(raw.facing) == "number", where .. ": facing must be a number")
		if raw.name ~= nil then
			assert(type(raw.name) == "string", where .. ": name must be a string")
			assert(not seenNames[raw.name], where .. ": duplicate unit name " .. raw.name)
			seenNames[raw.name] = true
		end
		if raw.group ~= nil then
			assert(type(raw.group) == "string", where .. ": group must be a string")
		end
		entries[#entries + 1] = {
			def = raw.def,
			team = raw.team,
			x = raw.x,
			z = raw.z,
			facing = raw.facing or 0,
			name = raw.name,
			group = raw.group,
		}
	end
	return entries
end

return Roster
