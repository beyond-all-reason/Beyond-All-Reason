-- user_files.lua --------------------------------------------------------------
-- This module adds common directories for copying, backups, and pending writes.
-- It provides a simple methodology for ingesting files containing users' data
-- without producing bad patterns, e.g. writing back out a misread user file.
-- Pending and interrupted write operations leave the existing file as it was.
--------------------------------------------------------------------------------

if not io or not os then
	return
end

if not VFS then
	Spring.Log("user_file", LOG.ERROR, "No VFS present when loading user_files.")
	return
end

local SUFFIX_PENDING = ".pending"
local SUFFIX_BACKUP = ".backup"

local STATUS_OK = "ok"
local STATUS_ABSENT = "absent"
local STATUS_DAMAGED = "damaged"

---An interrupted write leaves both of these behind. The pending copy is the
---newer of the two, and is only ever written in full, so it is tried first.
local RECOVERY_ORDERED = { SUFFIX_PENDING, SUFFIX_BACKUP }

---@param path string
---@param decode nil|fun(contents: string): any
---@return nil|any value
---@return "ok"|"absent"|"damaged" status
local function readFile(path, decode)
	local contents = VFS.LoadFile(path)

	if not contents then
		return nil, VFS.FileExists(path) and STATUS_DAMAGED or STATUS_ABSENT
	end

	if contents:match("^%s*$") then
		return nil, STATUS_ABSENT
	end

	if not decode then
		return contents, STATUS_OK
	end

	local decoded, value = pcall(decode, contents)

	if not decoded or value == nil then
		return nil, STATUS_DAMAGED
	end

	return value, STATUS_OK
end

---Reads a file, optionally through a decoder.
---@param path string
---@param decode nil|fun(contents: string): any a decoder such as Json.decode
---@return nil|any value the contents, or whatever the decoder made of them
---@return "ok"|"absent"|"damaged" status
local function read(path, decode)
	if VFS.FileExists(path) then
		return readFile(path, decode)
	end

	for _, suffix in ipairs(RECOVERY_ORDERED) do
		local value, status = readFile(path .. suffix, decode)
		if status == STATUS_OK then
			return value, status
		end
	end

	return nil, STATUS_ABSENT
end

---Puts a finished pending file in place of `path`, keeping the old one alongside.
---@param path string
---@param pending string
---@param options nil|{ backup: boolean }
---@return boolean written
local function commit(path, pending, options)
	-- Existing file-level backups do not survive a new write operation.
	local backup = path .. SUFFIX_BACKUP
	os.remove(backup)
	local hasBackup = os.rename(path, backup) ~= nil

	-- os.rename requires _both_ file paths to be inside the write directory,
	-- so the rename can be refused even when the write (io.open) was allowed.
	if os.rename(pending, path) == nil then
		-- Nothing reached `path`, so put back what we moved aside and take the
		-- pending copy with us, leaving the directory as we found it.
		if hasBackup then
			os.rename(backup, path)
		end

		os.remove(pending)

		return false
	end

	-- `backup = false` still copies (see above); we just clean up afterward.
	if options and options.backup == false then
		os.remove(backup)
	end

	return true
end

---@class UserFileWriter
---@field write fun(self: UserFileWriter, text: string) writes, as a file handle does
---@field close fun(self: UserFileWriter): boolean puts the finished result in place
---@field abort fun(self: UserFileWriter) discards it, leaving the file as it was

---Opens a write that only reaches `path` once it is closed cleanly.
---
---Stands in for an `io.open` handle where the contents arrive a piece at a time,
---so a large file does not have to be held in memory whole to be written safely.
---@param path string
---@param options nil|{ backup: boolean } backup = false skips the rotation
---@return UserFileWriter? writer `nil` the file could not be opened
local function open(path, options)
	local pending = path .. SUFFIX_PENDING
	local file = io.open(pending, "w")
	if not file then
		return nil
	end

	local failed = false
	local writer = {}

	function writer:write(text)
		if file and not file:write(text) then
			failed = true
		end
	end

	function writer:abort()
		if not file then
			return
		end

		file:close()
		file = nil

		os.remove(pending)
	end

	function writer:close()
		if not file then
			return false
		end

		local closed = file:close()
		file = nil

		if failed or not closed then
			os.remove(pending)
			return false
		end

		return commit(path, pending, options)
	end

	return writer
end

---Writes a file into a *.pending copy, keeping the previous copy as *.backup.
---@param path string
---@param contents string
---@param options nil|{ backup: boolean } backup = false skips the rotation
---@return boolean written
local function write(path, contents, options)
	local writer = open(path, options)
	if not writer then
		return false
	end

	writer:write(contents)

	return writer:close()
end

---Create a copy of a file beforehand when the engine handles the write.
---
---The engine truncates files it saves or writes into, which we cannot make safe,
---so the best we can do is create a retrievable copy of its contents somewhere.
---@param path string
---@return boolean? created `false` the copy failed; `nil` nothing to copy
local function temp(path)
	local file = io.open(path, "r")
	if not file then
		return
	end

	local contents = file:read("*a")
	file:close()

	if contents and contents ~= "" then
		return write(path .. SUFFIX_BACKUP, contents, { backup = false })
	end
end

return {
	Read = read,
	Write = write,
	Open = open,
	Temp = temp,

	OK = STATUS_OK,
	ABSENT = STATUS_ABSENT,
	DAMAGED = STATUS_DAMAGED,

	PENDING_SUFFIX = SUFFIX_PENDING,
	BACKUP_SUFFIX = SUFFIX_BACKUP,
}
