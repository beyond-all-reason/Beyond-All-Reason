-- Reading and writing LuaUI/Config/blueprints.json.
--
-- The game writes blueprint names empty, so every named blueprint in a real file
-- got there by hand or by being pasted from someone else. The file is a player
-- authored input, and the two rules that follow from that are:
--
--   A file we could not read in full is the only copy of what is in it, so it is
--   never written over. That is what the outcome of a read is for.
--
--   A write that is interrupted must leave the file that was already there. The
--   new contents go to a pending file and are swapped in once they are complete.
--
-- Messages come back as keys and parameters rather than text, so this stays free
-- of Spring and BAR and can be read on its own.

---@class BlueprintsJsonMessage
---@field key string an i18n key under ui.blueprint
---@field params table|nil

---@class BlueprintsJsonReading
---@field outcome string one of the outcomes below
---@field entries table[] blueprint-shaped entries, in file order and without gaps
---@field entryIndices number[] where each of those sat in the file, for naming it
---@field setAside any[] entries that are not blueprints at all, kept verbatim
---@field messages BlueprintsJsonMessage[] what to tell the player, in order
---@field repairs string[] what had to be put right to read the file

local Doctor = {}

---Nothing to lose: there is no file, or it holds nothing. Writing is allowed.
Doctor.ABSENT = "absent"

---Every entry in the file was accounted for. Writing is allowed.
Doctor.LOADED = "loaded"

---The file holds blueprints we could not read. Writing is refused.
Doctor.DAMAGED = "damaged"

---A null in the list left a gap, and the entries past it were closed back up.
Doctor.REPAIR_GAP = "gap"

Doctor.PENDING_SUFFIX = ".pending"
Doctor.BACKUP_SUFFIX = ".backup"

---@param messages BlueprintsJsonMessage[]
---@param key string
---@param params table|nil
local function addMessage(messages, key, params)
	messages[#messages + 1] = { key = key, params = params }
end

---@param path string
---@return BlueprintsJsonReading
function Doctor.read(path)
	---@type BlueprintsJsonReading
	local reading =
		{ outcome = Doctor.ABSENT, entries = {}, entryIndices = {}, setAside = {}, messages = {}, repairs = {} }

	local content = VFS.LoadFile(path)

	-- Unreadable, undecodable and unrecognized all leave the player doing the same
	-- thing: opening the file. They are one message, not three.
	if not content then
		-- Having no file at all is the ordinary first run. Having one we cannot
		-- read is not, and it must not be written over.
		if VFS.FileExists(path) then
			reading.outcome = Doctor.DAMAGED
			addMessage(reading.messages, "ui.blueprint.file_damaged", { file = path })
		end
		return reading
	end

	-- An empty file has nothing in it to lose, so it is the first run again.
	if content:match("^%s*$") then
		return reading
	end

	local decodedOK, decoded = pcall(Json.decode, content) ---@cast decoded table?

	if not decodedOK or type(decoded) ~= "table" then
		reading.outcome = Doctor.DAMAGED
		addMessage(reading.messages, "ui.blueprint.file_damaged", { file = path })
		return reading
	end

	local savedBlueprints = decoded.savedBlueprints

	if savedBlueprints == nil and next(decoded) == nil then
		savedBlueprints = {}
	end

	if type(savedBlueprints) ~= "table" then
		reading.outcome = Doctor.DAMAGED
		addMessage(reading.messages, "ui.blueprint.file_damaged", { file = path })
		return reading
	end

	local count, highestIndex = 0, 0
	for key in pairs(savedBlueprints) do
		count = count + 1
		if type(key) == "number" and key > highestIndex then
			highestIndex = key
		end
	end

	if count > highestIndex then
		reading.outcome = Doctor.DAMAGED
		addMessage(reading.messages, "ui.blueprint.file_damaged", { file = path })
		return reading
	end

	if count < highestIndex then
		reading.repairs[#reading.repairs + 1] = Doctor.REPAIR_GAP
	end

	for i = 1, highestIndex do
		local entry = savedBlueprints[i]
		if entry == nil then
			--Nothing was stored here, so there is nothing to keep.
		elseif type(entry) == "table" then
			reading.entries[#reading.entries + 1] = entry
			reading.entryIndices[#reading.entryIndices + 1] = i
		else
			addMessage(reading.messages, "ui.blueprint.entry_kept", { name = "#" .. i })
			reading.setAside[#reading.setAside + 1] = entry
		end
	end

	reading.outcome = Doctor.LOADED
	return reading
end

---@param path string
---@param entries any[] everything to write, including entries that were set aside
---@param outcome string the outcome of the read this write follows
---@return BlueprintsJsonMessage[] messages
function Doctor.write(path, entries, outcome)
	---@type BlueprintsJsonMessage[]
	local messages = {}

	-- Refusing and failing both come out as "your blueprints were not saved, and
	-- the file you had is still there", which is the whole of what to say.
	if outcome == Doctor.DAMAGED then
		addMessage(messages, "ui.blueprint.save_failed", { file = path })
		return messages
	end

	local encodedOK, encoded = pcall(Json.encode, { savedBlueprints = entries })

	if not encodedOK or type(encoded) ~= "string" then
		addMessage(messages, "ui.blueprint.save_failed", { file = path })
		return messages
	end

	local pendingPath = path .. Doctor.PENDING_SUFFIX
	local backupPath = path .. Doctor.BACKUP_SUFFIX

	local file = io.open(pendingPath, "w")

	if not file then
		addMessage(messages, "ui.blueprint.save_failed", { file = path })
		return messages
	end

	local written = file:write(encoded)
	local closed = file:close()

	if not written or not closed then
		os.remove(pendingPath)
		addMessage(messages, "ui.blueprint.save_failed", { file = path })
		return messages
	end

	-- Rotate rather than overwrite. The previous file becomes the backup, which
	-- also clears the way for the rename on platforms that will not replace an
	-- existing target. Both of these fail harmlessly on a first save.
	os.remove(backupPath)
	os.rename(path, backupPath)

	-- The new contents are left in the pending file and the previous ones in the
	-- backup, both beside the file itself. That is more than the player can act
	-- on, so it is the same line as any other save that did not happen.
	if not os.rename(pendingPath, path) then
		addMessage(messages, "ui.blueprint.save_failed", { file = path })
	end

	return messages
end

return Doctor
