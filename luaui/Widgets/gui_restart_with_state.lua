-- Superseded: all logic moved into gui_options.lua (guaranteed-loaded, has startScript).
-- This file is kept as a stub so existing widget handler state doesn't break.
do
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Restart With State IO",
		desc = "Writes/reads the restart-with-state save file on behalf of the gadget (io is unavailable in LuaRules)",
		author = "Copilot",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local STATE_FILE = "LuaUI/Config/restart_state.lua"

local recvBuffer = nil

function widget:RecvLuaMsg(msg, _playerID)
	if msg == "rws:begin" then
		recvBuffer = {}
		return true
	end

	local chunk = msg:match("^rws:chunk:(.*)")
	if chunk then
		if recvBuffer then
			recvBuffer[#recvBuffer + 1] = chunk
		end
		return true
	end

	if msg == "rws:commit" then
		if not recvBuffer then
			return true
		end
		local data = table.concat(recvBuffer)
		recvBuffer = nil

		Engine.Unsynced.CreateDir("LuaUI/Config")
		local f, err = io.open(STATE_FILE, "w")
		if not f then
			Engine.Shared.Echo("[Restart With State] Could not write state file: " .. tostring(err))
			return true
		end
		f:write(data)
		f:close()

		local startScript = VFS.LoadFile("_script.txt")
		if not startScript or startScript == "" then
			Engine.Shared.Echo("[Restart With State] No _script.txt available; cannot restart automatically.")
			return true
		end
		Engine.Shared.Echo("[Restart With State] State saved (" .. tostring(#data) .. " bytes). Restarting...")
		Engine.Unsynced.Restart("", startScript)
		return true
	end

	if msg == "rws:clear" then
		-- Truncate to empty; VFS.LoadFile returns "" for an empty file, which the
		-- gadget's Initialize now skips gracefully.
		local f = io.open(STATE_FILE, "w")
		if f then
			f:close()
		end
		return true
	end
end
