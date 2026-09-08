---
--- Loads and combines the .lua files of a mission.
---
--- Every *.lua file directly inside the mission folder is a mission part. Each
--- returns a partial mission table, and the parts are combined into one.
---
--- Combining rules per top level key:
---   Stages, Objectives, Triggers, Actions   merged by ID, duplicate IDs error
---   UnitLoadout, FeatureLoadout             appended, in file name order
---   InitialStage                            scalar, may only be set by one file
---
--- Files are sorted by name first, so the result never depends on the order the filesystem happens to return.
---

local MISSION_FILES_PATTERN = "*.lua"

local MAP_KEYS = { Stages = true, Objectives = true, Triggers = true, Actions = true }
local ARRAY_KEYS = { UnitLoadout = true, FeatureLoadout = true }
local SCALAR_KEYS = { InitialStage = true }

local KNOWN_KEYS_TEXT = "InitialStage, Stages, Objectives, Triggers, Actions, UnitLoadout, FeatureLoadout"

local function mergePart(mission, part, fileName, definedIn)
	for key, value in pairs(part) do
		if MAP_KEYS[key] then
			local entries = table.ensureTable(mission, key)
			local sources = table.ensureTable(definedIn, key)

			for id, entry in pairs(value) do
				if sources[id] then
					error(
						("[Mission API] %s '%s' is defined twice, in %s and %s"):format(
							key,
							tostring(id),
							sources[id],
							fileName
						),
						0
					)
				end
				sources[id] = fileName
				entries[id] = entry
			end

		elseif ARRAY_KEYS[key] then
			table.append(table.ensureTable(mission, key), value)

		elseif SCALAR_KEYS[key] then
			if definedIn[key] then
				error(("[Mission API] %s is set twice, in %s and %s"):format(key, definedIn[key], fileName), 0)
			end
			definedIn[key] = fileName
			mission[key] = value

		else
			error(
				(
					"[Mission API] %s returns unknown key '%s'. Mission files may only return: %s. "
					.. "Keep shared helpers in a subfolder, which is not scanned."
				):format(fileName, tostring(key), KNOWN_KEYS_TEXT),
				0
			)
		end
	end
end

local function loadMissionFiles(missionDir)
	local files = VFS.DirList(missionDir, MISSION_FILES_PATTERN)

	-- Deterministic merge order regardless of what the VFS returns.
	table.sort(files)

	if #files == 0 then
		error(("[Mission API] No %s files found in mission folder '%s'"):format(MISSION_FILES_PATTERN, missionDir), 0)
	end

	local mission = {}
	local definedIn = {}

	for _, filePath in ipairs(files) do
		local fileName = filePath:match("[^/]+$") or filePath
		local part = VFS.Include(filePath)
		if type(part) ~= "table" then
			error(("[Mission API] %s must return a table, got %s"):format(fileName, type(part)), 0)
		end
		mergePart(mission, part, fileName, definedIn)
	end

	return mission
end

return {
	LoadMissionFiles = loadMissionFiles,
}
