local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Restart With State",
		desc      = "Saves all units, their states and command queues, restarts the game, then restores them",
		author    = "Floris",
		date      = "May 2026",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

--[[
	How it works:
		1. A widget (e.g. gui_options "restart_with_state") sends the lua msg "restart_with_state".
		2. Synced part collects all unit data and streams it (chunked) to unsynced.
		3. Unsynced writes the data to LuaUI/Config/restart_state.lua and calls Spring.Restart.
		4. After the restart, the synced part reads the file at Initialize, destroys any auto-spawned
		   units (e.g. commanders from the initial spawn gadget), recreates all stored units, restores
		   their health/build progress/experience/states, then re-issues their command queues.
		5. Best used in singleplayer. Reading raw-filesystem state in synced will desync multiplayer.
]]



local STATE_FILE = "LuaUI/Config/restart_state.lua"

-- minimal Lua-table serializer for the types we actually store: nil/number/boolean/string/table
local function serialize(o, indent)
	indent = indent or ""
	local t = type(o)
	if t == "number" or t == "boolean" then
		return tostring(o)
	elseif t == "nil" then
		return "nil"
	elseif t == "string" then
		return string.format("%q", o)
	elseif t == "table" then
		local out = { "{" }
		local newIndent = indent .. " "
		-- Emit the array part (consecutive integer keys 1..N) positionally so
		-- the deserialised table is a true array. Using explicit "[1]=..." keys
		-- can land the entries in the hash part instead, which breaks engine
		-- code that iterates with lua_next (e.g. Spring.GiveOrderToUnit's
		-- ParseCommand reorders x/y/z params when keys are in the hash part).
		local n = 0
		while o[n + 1] ~= nil do
			n = n + 1
			out[#out + 1] = newIndent .. serialize(o[n], newIndent) .. ","
		end
		-- Emit any remaining keys (string keys, non-sequential numbers) explicitly.
		for k, v in pairs(o) do
			local emitted = (type(k) == "number" and k >= 1 and k <= n and math.floor(k) == k)
			if not emitted then
				local keyStr
				if type(k) == "number" then
					keyStr = "[" .. k .. "]"
				else
					keyStr = "[" .. string.format("%q", tostring(k)) .. "]"
				end
				out[#out + 1] = newIndent .. keyStr .. "=" .. serialize(v, newIndent) .. ","
			end
		end
		out[#out + 1] = indent .. "}"
		return table.concat(out, "\n")
	end
	return "nil"
end

-------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
-------------------------------------------------------------------------------

local CHUNK_SIZE = 8000

-- Commands that always target a unit (any number of params)
local UNIT_TARGET_ALWAYS = { [CMD.GUARD] = true }
-- Commands that target a unit only when given with exactly 1 parameter
local UNIT_TARGET_SINGLE = { [CMD.ATTACK] = true, [CMD.REPAIR] = true }
-- Wait-family commands carry OPT_INTERNAL while "active" (the engine flips it on
-- once the wait is being processed). We still want to restore them, so exempt
-- them from the OPT_INTERNAL skip below.
local WAIT_CMDS = {
	[CMD.WAIT] = true,
	[CMD.TIMEWAIT] = true,
	[CMD.DEATHWAIT] = true,
	[CMD.SQUADWAIT] = true,
	[CMD.GATHERWAIT] = true,
}
-- Commands that take no parameters and so must be re-issued with an empty
-- params table; the engine flips their OPT_INTERNAL bit on while "active"
-- (counting down / paused), so we also strip that bit before re-issuing.
local NO_PARAM_CMDS = {
	[CMD.WAIT] = true,
	[CMD.STOP] = true,
	[CMD.SELFD] = true,
}

local pendingRestore = nil
local restoreFrame   = nil
local restoreBuffer  = nil  -- reassembly buffer for data arriving from LuaUI

local function collectUnitState()
	local data = {
		gameFrame = Spring.GetGameFrame(),
		units = {},
	}
	local allUnits = Spring.GetAllUnits()
	-- Map each nanoframe that is actively being built to its builder. Nanoframes
	-- with a builder are skipped on save; the builder's own command queue
	-- (factory build orders / Repair / Guard) will recreate them after restart.
	local beingBuilt = {}
	for i = 1, #allUnits do
		local bID = allUnits[i]
		local targetID = Spring.GetUnitIsBuilding and Spring.GetUnitIsBuilding(bID)
		if targetID then
			beingBuilt[targetID] = bID
		end
	end
	for i = 1, #allUnits do
		local uID = allUnits[i]
		local uDefID = Spring.GetUnitDefID(uID)
		if uDefID then
			local uDef = UnitDefs[uDefID]
			local x, y, z = Spring.GetUnitPosition(uID)
			local transporter = Spring.GetUnitTransporter and Spring.GetUnitTransporter(uID)
			-- Skip units without a valid world position (nil), that are being
			-- transported (their reported position is the transport's, not theirs),
			-- or nanoframes that have an active builder (the builder's queue will
			-- recreate them).
			if x and not transporter and not beingBuilt[uID] then
				local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(uID)
				local teamID = Spring.GetUnitTeam(uID)
				local heading = Spring.GetUnitHeading(uID) or 0
				local buildFacing = Spring.GetUnitBuildFacing(uID)
				local exp = Spring.GetUnitExperience(uID) or 0
				local states = Spring.GetUnitStates(uID) or {}
				-- Builder Priority (low/high) is a custom command; the gadget stores
				-- the active value in the "builderPriority" rules param (0=low, 1=high).
				local builderPriority = Spring.GetUnitRulesParam(uID, "builderPriority")
				-- BAR uses its own CMD_WANT_CLOAK (GameCMD.WANT_CLOAK) instead of
				-- CMD.CLOAK; the active state lives in the "wantcloak" rules param.
				local wantCloak = Spring.GetUnitRulesParam(uID, "wantcloak")
				local commands = Spring.GetUnitCommands(uID, -1) or {}
				local cmdsClean = {}
				for j = 1, #commands do
					local c = commands[j]
					-- Copy params by explicit 1-based index to avoid any key-0 artifacts
					-- from Spring's internal tables being serialised via pairs().
					local paramsCopy = nil
					if c.params and #c.params > 0 then
						paramsCopy = {}
						for pi = 1, #c.params do
							paramsCopy[pi] = c.params[pi]
						end
					end
					cmdsClean[j] = {
						id = c.id,
						params = paramsCopy,
						coded = (c.options and c.options.coded) or 0,
					}
				end
				-- Factories keep their unit-build queue in a separate list. We save
				-- it independently and re-issue after restart.
				local factoryCmdsClean = nil
				if uDef and uDef.isFactory and Spring.GetFactoryCommands then
					local fcmds = Spring.GetFactoryCommands(uID, -1) or {}
					if #fcmds > 0 then
						factoryCmdsClean = {}
						for j = 1, #fcmds do
							local c = fcmds[j]
							local paramsCopy = nil
							if c.params and #c.params > 0 then
								paramsCopy = {}
								for pi = 1, #c.params do
									paramsCopy[pi] = c.params[pi]
								end
							end
							factoryCmdsClean[j] = {
								id = c.id,
								params = paramsCopy,
								coded = (c.options and c.options.coded) or 0,
							}

						end
					end
				end
				-- canFly / isFloating units should keep their saved y (or the engine
				-- will snap them); ground/sub units should be snapped to ground so they
				-- don't fall from a stale mid-air position.
				local canFly = uDef and uDef.canFly
				data.units[#data.units + 1] = {
					unitID        = uID,
					unitDefID     = uDefID,
					teamID        = teamID,
					canFly        = canFly and true or false,
					x = x, y = y, z = z,
					heading       = heading,
					facing        = buildFacing or 0,
					health        = health,
					maxHealth     = maxHealth,
					buildProgress = buildProgress or 1,
					experience    = exp,
					states        = {
						firestate  = states.firestate,
						movestate  = states.movestate,
						["repeat"] = states["repeat"],
						cloak      = states.cloak,
						active     = states.active,
						trajectory = states.trajectory,
					},
					builderPriority = builderPriority,
					wantCloak     = wantCloak,
					commands      = cmdsClean,
					factoryCommands = factoryCmdsClean,
				}
			end
		end
	end
	return data
end

local function sendStateToUnsynced(data)
	local s = serialize(data)
	SendToUnsynced("rws_begin")
	for i = 1, #s, CHUNK_SIZE do
		SendToUnsynced("rws_chunk", s:sub(i, i + CHUNK_SIZE - 1))
	end
	SendToUnsynced("rws_commit")
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == "restart_with_state" then
		local data = collectUnitState()
		sendStateToUnsynced(data)
		return true
	end
	if msg == "rws_restore_begin" then
		restoreBuffer = {}
		return true
	end
	local chunk = msg:match("^rws_restore_chunk:(.*)")
	if chunk then
		if restoreBuffer then restoreBuffer[#restoreBuffer + 1] = chunk end
		return true
	end
	if msg == "rws_restore_commit" then
		if not restoreBuffer then return true end
		local content = table.concat(restoreBuffer)
		restoreBuffer = nil
		local fn, err = loadstring("return " .. content)
		if not fn then
			Spring.Echo("[Restart With State] Failed to parse state: " .. tostring(err))
			return true
		end
		local ok, data = pcall(fn)
		if not ok or type(data) ~= "table" or type(data.units) ~= "table" then
			Spring.Echo("[Restart With State] State data invalid; ignoring.")
			return true
		end
		pendingRestore = data
		-- restore after initial commander warp-in is complete
		restoreFrame = (Game.spawnWarpInFrame or 90) + 10
		Spring.Echo("[Restart With State] State received (" .. tostring(#data.units) .. " units). Will restore at frame " .. restoreFrame)
		return true
	end
	return false
end

local function restoreUnits()
	if not pendingRestore then return end
	local data = pendingRestore
	pendingRestore = nil

	-- Snapshot existing units BEFORE creating any new ones.
	-- We create restored units first so the engine never sees zero units
	-- (which would immediately trigger a defeat condition).
	local oldUnits = Spring.GetAllUnits()

	local idMap = {}
	local createdCount = 0

	-- Pass 1: create units, set health/progress/experience/states
	for i = 1, #data.units do
		local u = data.units[i]
		if not UnitDefs[u.unitDefID] then
			Spring.Echo("[Restart With State] Unknown unitDefID " .. tostring(u.unitDefID) .. ", skipping.")
		else
			local createY = u.y
			-- For ground/sea units, snap to the actual ground height so they don't
			-- spawn floating in mid-air at a stale position (the saved y is the
			-- unit's last in-game y, which for moving units is mid-flight/jump).
			if not u.canFly then
				createY = Spring.GetGroundHeight(u.x, u.z)
			end
			-- Spawn unfinished units as nanoframes (build=true), otherwise as completed.
			local isUnderConstruction = u.buildProgress and u.buildProgress < 1
			local ok, newID = pcall(Spring.CreateUnit, u.unitDefID, u.x, createY, u.z, u.facing or 0, u.teamID, isUnderConstruction and true or false)
			if ok and newID then
				idMap[u.unitID] = newID
				createdCount = createdCount + 1
				Spring.SetUnitHeadingAndUpDir(newID, u.heading, 0, 1, 0)

				-- Restore health and build progress together so nanoframes keep both.
				if u.health then
					Spring.SetUnitHealth(newID, { health = u.health, build = u.buildProgress or 1 })
				end
				if u.experience and u.experience > 0 then
					Spring.SetUnitExperience(newID, u.experience)
				end

				local s = u.states
				if s then
					if s.firestate then Spring.GiveOrderToUnit(newID, CMD.FIRE_STATE, { s.firestate }, 0) end
					if s.movestate then Spring.GiveOrderToUnit(newID, CMD.MOVE_STATE, { s.movestate }, 0) end
					if s["repeat"] ~= nil then Spring.GiveOrderToUnit(newID, CMD.REPEAT,     { s["repeat"] and 1 or 0 }, 0) end
					if s.active     ~= nil then Spring.GiveOrderToUnit(newID, CMD.ONOFF,      { s.active     and 1 or 0 }, 0) end
					if s.trajectory ~= nil then Spring.GiveOrderToUnit(newID, CMD.TRAJECTORY, { s.trajectory and 1 or 0 }, 0) end
				end

				-- Builder Priority: re-issue via the custom CMD so the gadget
				-- (unit_builder_priority) updates its rules param and cmd desc.
				if u.builderPriority ~= nil and GameCMD and GameCMD.PRIORITY then
					Spring.GiveOrderToUnit(newID, GameCMD.PRIORITY, { u.builderPriority }, 0)
				end

				-- Cloak (BAR-specific): unit_cloak.lua rejects vanilla CMD.CLOAK
				-- and only honors GameCMD.WANT_CLOAK, which sets the "wantcloak"
				-- rules param and actually cloaks the unit.
				if u.wantCloak ~= nil and GameCMD and GameCMD.WANT_CLOAK then
					Spring.GiveOrderToUnit(newID, GameCMD.WANT_CLOAK, { u.wantCloak }, 0)
				end
			else
				Spring.Echo("[Restart With State] CreateUnit failed for defID " .. tostring(u.unitDefID) .. ": " .. tostring(newID))
			end
		end
	end

	-- Now that restored units exist, safely remove the old pre-restore units.
	for i = 1, #oldUnits do
		Spring.DestroyUnit(oldUnits[i], false, true)
	end

	-- Pass 2: re-issue command queues, remapping any old unitID params to new ones
	for i = 1, #data.units do
		local u = data.units[i]
		local newID = idMap[u.unitID]
		if newID and u.commands and #u.commands > 0 then
			local firstIssued = false
			for j = 1, #u.commands do
				local c = u.commands[j]
				local params = c.params
				local origCoded = c.coded or 0
				-- Skip engine-internal sub-orders; they are managed by the engine
				-- and re-issuing them confuses the AI/movement (e.g. nano-build,
				-- internal attack-move steps, etc.). Exceptions:
				--   * WAIT-family commands get the internal bit flipped on while
				--     "active", but we still want to restore them.
				--   * Factory unit-build orders (negative cmd IDs) have the internal
				--     bit set while the unit is being built; we want them back so
				--     the queue restarts where it was.
				-- Strip the bit and re-issue.
				local isInternal = (math.floor(origCoded / 8) % 2) == 1
				if isInternal and (WAIT_CMDS[c.id] or NO_PARAM_CMDS[c.id] or c.id < 0) then
					origCoded = origCoded - 8
					isInternal = false
				end
				if isInternal then
					-- skip
				else
					-- Only remap unit-targeting commands (same whitelist as
					-- unit_evolution.lua). Other single-param commands pass through.
					local skip = false
					local isUnitTarget = UNIT_TARGET_ALWAYS[c.id] or
						(UNIT_TARGET_SINGLE[c.id] and params and #params == 1)
					if isUnitTarget then
						local mapped = idMap[params[1]]
						if mapped then
							params = { mapped }
						else
							skip = true  -- target no longer exists
						end
					elseif params then
						-- Position-type command: validate no param serialised as nil.
						for pi = 1, #params do
							if params[pi] == nil then skip = true; break end
						end
					end
					if not skip then
						-- First order clears the queue (use saved opts as-is);
						-- subsequent ones must shift-append.
						local coded
						if not firstIssued then
							coded = origCoded
							firstIssued = true
						else
							-- preserve original flags AND ensure shift bit is set
							local hasShift = (math.floor(origCoded / 32) % 2) == 1
							coded = hasShift and origCoded or (origCoded + CMD.OPT_SHIFT)
						end
						local issueParams = params or {}

						pcall(Spring.GiveOrderToUnit, newID, c.id, issueParams, coded)
					end
				end
			end
		end
		-- Re-issue factory unit-build queue (separate from the normal command
		-- queue). Build orders use negative cmd IDs (-unitDefID).
		if newID and u.factoryCommands and #u.factoryCommands > 0 then
			for j = 1, #u.factoryCommands do
				local c = u.factoryCommands[j]
				local origCoded = c.coded or 0
				-- For factory build orders the modifier bits change meaning:
				-- SHIFT = queue x5, CTRL = queue x20, ALT = insert at front.
				-- The default (no modifier) is "append one to the end", which is
				-- exactly what we want when re-issuing the saved queue. Strip
				-- SHIFT/CTRL/ALT so each saved entry produces exactly one queued
				-- unit, and strip OPT_INTERNAL (set on the unit currently being
				-- built) so it re-enters the queue normally.
				local function clearBit(v, bit) if (math.floor(v / bit) % 2) == 1 then return v - bit end return v end
				local coded = clearBit(origCoded, 8)   -- INTERNAL
				coded = clearBit(coded, 32)             -- SHIFT (x5)
				coded = clearBit(coded, 64)             -- CTRL  (x20)
				coded = clearBit(coded, 128)            -- ALT   (insert front)
				pcall(Spring.GiveOrderToUnit, newID, c.id, c.params or {}, coded)
			end
		end
	end

	Spring.Echo("[Restart With State] Restored " .. tostring(createdCount) .. "/" .. tostring(#data.units) .. " units.")
end

-- Restore path is driven by LuaUI sending chunks via Spring.SendLuaRulesMsg;
-- no direct filesystem access needed in synced code.

function gadget:GameFrame(n)
	if restoreFrame and n >= restoreFrame then
		restoreFrame = nil
		restoreUnits()
	end
end

-------------------------------------------------------------------------------
else  -- UNSYNCED
-------------------------------------------------------------------------------

local saveBuffer = {}
local UI_CHUNK_SIZE = 4000

local function rwsBegin()
	saveBuffer = {}
end

local function rwsChunk(_, s)
	saveBuffer[#saveBuffer + 1] = s
end

local function rwsCommit()
	-- io/os are not available in LuaRules; forward to the companion widget via SendLuaUIMsg
	local data = table.concat(saveBuffer)
	saveBuffer = {}
	Spring.SendLuaUIMsg("rws:begin")
	for i = 1, #data, UI_CHUNK_SIZE do
		Spring.SendLuaUIMsg("rws:chunk:" .. data:sub(i, i + UI_CHUNK_SIZE - 1))
	end
	Spring.SendLuaUIMsg("rws:commit")
end

local function rwsClear()
	Spring.SendLuaUIMsg("rws:clear")
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("rws_begin",  rwsBegin)
	gadgetHandler:AddSyncAction("rws_chunk",  rwsChunk)
	gadgetHandler:AddSyncAction("rws_commit", rwsCommit)
	gadgetHandler:AddSyncAction("rws_clear",  rwsClear)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("rws_begin")
	gadgetHandler:RemoveSyncAction("rws_chunk")
	gadgetHandler:RemoveSyncAction("rws_commit")
	gadgetHandler:RemoveSyncAction("rws_clear")
end

-------------------------------------------------------------------------------
end
-------------------------------------------------------------------------------
