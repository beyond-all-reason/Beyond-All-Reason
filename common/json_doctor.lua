-- json_doctor.lua ---------------------------------------------------------------
-- Reads and writes a JSON file holding a list of records under one named key.
--
-- The list is the part worth having help with. A JSON null decodes to a gap, and
-- ipairs stops at the first gap, so a list read with ipairs can silently end early
-- and then be written back that short. Reading the whole list and closing the gaps
-- is what this does, along with saying whether the file can be written back at all.
--
-- It knows nothing about what the records are. Deciding whether one is usable, and
-- what to tell anyone about it, belongs to the caller.
----------------------------------------------------------------------------------

local UserFile = VFS.Include("common/user_files.lua")
if not UserFile then
	return
end

local Json = Json or VFS.Include("common/luaUtilities/json.lua")
if not Json then
	return
end

local UserFileRead = UserFile.Read
local UserFileWrite = UserFile.Write
local USERFILE_OK = UserFile.OK
local USERFILE_ABSENT = UserFile.ABSENT
local USERFILE_DAMAGED = UserFile.DAMAGED

---The four lists below are read in pairs: `entries[i]` sit at `entryIndices[i]`.
---@class JsonDoctorReading
---@field status "ok"|"absent"|"damaged"
---@field entries table[] the records, in file order and without gaps
---@field entryIndices number[] where each record sat in the file
---@field setAside any[] list items that are not records, kept verbatim
---@field setAsideIndices number[] where each of those sat in the file
---@field repairs string[] what had to be put right to read the list
---@field document table everything in the file that is not the list

---A null in the list left a gap, and the items past it were closed back up.
local REPAIR_GAP = "gap"

---Reads the list stored under `listKey`.
---
---A `damaged` file holds records we could not read so will refuse to rewrite.
---An `absent` file does not check for backups and allows writing to the path.
---@param path string
---@param listKey string the key the list is stored under
---@return JsonDoctorReading
local function read(path, listKey)
	---@type JsonDoctorReading
	local reading = {
		status = USERFILE_ABSENT,
		entries = {},
		entryIndices = {},
		setAside = {},
		setAsideIndices = {},
		repairs = {},
		document = {},
	}

	local decoded, status = UserFileRead(path, Json.decode)

	if status == USERFILE_ABSENT then
		return reading
	end

	if status == USERFILE_DAMAGED or type(decoded) ~= "table" then
		reading.status = USERFILE_DAMAGED
		return reading
	end

	local list = decoded[listKey]

	-- A file with no list in it is not damaged, just a file with no entries;
	-- it could contain other keys, hold other lists, or just be an empty doc.
	if list == nil then
		list = {}
	end

	if type(list) ~= "table" then
		reading.status = USERFILE_DAMAGED
		return reading
	end

	-- Never throw away the non-list contents of the file.
	decoded[listKey] = nil
	reading.document = decoded

	local count, highestIndex = 0, 0
	for key in pairs(list) do
		count = count + 1
		if type(key) == "number" and key > highestIndex then
			highestIndex = math.floor(key)
		end
	end

	if count > highestIndex then
		reading.status = USERFILE_DAMAGED
		return reading
	end

	if count < highestIndex then
		reading.repairs[#reading.repairs + 1] = REPAIR_GAP
	end

	for i = 1, highestIndex do
		local item = list[i]
		if item == nil then
			-- gap in a list
		elseif type(item) == "table" then
			reading.entries[#reading.entries + 1] = item
			reading.entryIndices[#reading.entryIndices + 1] = i
		else
			reading.setAside[#reading.setAside + 1] = item
			reading.setAsideIndices[#reading.setAsideIndices + 1] = i
		end
	end

	reading.status = USERFILE_OK

	return reading
end

---Writes the list back into the file the reading came from.
---@param path string
---@param listKey string
---@param entries any[] everything to write, including items that were set aside
---@param reading JsonDoctorReading the reading this write follows
---@return boolean written
local function write(path, listKey, entries, reading)
	-- Write operations take a "reading" rather than a status so there's no way
	-- to ask to write without having looked at the file. This is inconvenient,
	-- but we are in unsynced and possibly in widget space where user code roams.
	if type(reading) ~= "table" or reading.status == nil then
		Spring.Log("json_doctor", LOG.ERROR, "Writing " .. path .. " without a reading of it.")
		return false
	end

	if reading.status ~= USERFILE_OK and reading.status ~= USERFILE_ABSENT then
		return false
	end

	local document = reading.document
	document[listKey] = entries

	local success, text = pcall(Json.encode, document)
	if not success or type(text) ~= "string" then
		return false
	end

	return UserFileWrite(path, text)
end

return {
	Read = read,
	Write = write,
	OK = USERFILE_OK,
	ABSENT = USERFILE_ABSENT,
	DAMAGED = USERFILE_DAMAGED,
	REPAIR_GAP = REPAIR_GAP,
}
