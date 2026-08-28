---
--- The validation report: collects validation messages
---

-- The order in the log:
local sections = {
	Stages = 1,
	Objectives = 2,
	Triggers = 3,
	Actions = 4,
	Loadouts = 5,
	References = 6,
}

local function isBefore(a, b)
	if a.section ~= b.section then
		return a.section < b.section
	end
	if a.id ~= b.id then
		return a.id < b.id
	end
	-- table.sort is not stable, so keep insertion order within an entity
	return a.sequence < b.sequence
end

local function formatMessage(entry)
	if entry.id == "" then
		-- A mission wide message, e.g. one about the mission's stages as a whole.
		return entry.details and (entry.message .. ". " .. entry.details) or entry.message
	end

	local message = entry.message .. ". " .. entry.label .. ": " .. entry.id
	return entry.details and (message .. ", " .. entry.details) or message
end

local function toMessages(entries)
	table.sort(entries, isBefore)

	local messages = {}
	for i, entry in ipairs(entries) do
		messages[i] = formatMessage(entry)
	end
	return messages
end

local function createReport()
	local errors, warnings = {}, {}
	local sequence = 0

	local function add(entries, section, label, id, message, details)
		sequence = sequence + 1
		entries[#entries + 1] = {
			section = section or math.huge, -- an unknown section sorts last
			label = label,
			id = label and tostring(id or "") or "",
			sequence = sequence,
			message = message,
			details = details,
		}
	end

	return {
		Error = function(section, label, id, message, details)
			add(errors, section, label, id, message, details)
		end,
		Warn = function(section, label, id, message, details)
			add(warnings, section, label, id, message, details)
		end,

		GetResult = function()
			return {
				ok = #errors == 0,
				errors = toMessages(errors),
				warnings = toMessages(warnings),
			}
		end,
	}
end

return {
	Create = createReport,
	Sections = sections,
}
