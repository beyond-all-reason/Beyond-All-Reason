if not Spring.Utilities.IsDevMode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Gadget Auto Reloader",
		desc = "Reloads all gadgets that have changed after the mouse returned to the game window",
		author = "Beherith, Floris",
		date = "2026.04.01",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

local SELF_NAME = "Gadget Auto Reloader"

local spEcho = Engine.Shared.Echo

local gadgetContents = {}
local gadgetFileNames = {}
local failedGadgets = {}
local gadgetDependents = {} -- gadgetName -> {dependentName1, dependentName2, ...}

local function CacheGadgets()
	for _, g in pairs(gadgetHandler.gadgets) do
		local ghInfo = g.ghInfo
		local name = ghInfo.name
		if name ~= SELF_NAME then
			gadgetFileNames[name] = ghInfo.filename
			if not gadgetContents[name] then
				gadgetContents[name] = VFS.LoadFile(ghInfo.filename)
			end
			if g.GetInfo then
				local info = g:GetInfo()
				if info.dependents then
					gadgetDependents[name] = info.dependents
				end
			end
		end
	end
end

local pendingReHook = {}

local function ReHookProfiler(gadgetName)
	local g = gadgetHandler:FindGadget(gadgetName)
	if not g then
		return
	end
	for key, value in pairs(gadgetHandler) do
		if type(value) == "table" then
			local i = string.find(key, "List", 1, true)
			if i then
				local callinName = string.sub(key, 1, i - 1)
				if type(g[callinName]) == "function" then
					gadgetHandler:UpdateGadgetCallIn(callinName, g)
				end
			end
		end
	end
end

local function ReloadGadget(gadgetName, label)
	spEcho("Reloading gadget (" .. label .. "): " .. gadgetName)
	gadgetHandler:DisableGadget(gadgetName)
	gadgetHandler:EnableGadget(gadgetName)
	pendingReHook[gadgetName] = true
end

local function CheckForChanges(gadgetName, fileName, label)
	local newContents = VFS.LoadFile(fileName)
	if newContents ~= gadgetContents[gadgetName] then
		gadgetContents[gadgetName] = newContents
		local chunk, err = loadstring(newContents, fileName)
		if chunk == nil then
			spEcho("Failed to load: " .. fileName .. "  (" .. err .. ")")
			failedGadgets[gadgetName] = fileName
			return
		end
		failedGadgets[gadgetName] = nil
		ReloadGadget(gadgetName, label)
		-- Reload dependents
		local deps = gadgetDependents[gadgetName]
		if deps then
			for i = 1, #deps do
				local depName = deps[i]
				if gadgetHandler:FindGadget(depName) then
					ReloadGadget(depName, label .. ", dependent of " .. gadgetName)
				end
			end
		end
	end
end

if gadgetHandler:IsSyncedCode() then
	local updateQueue = {}

	function gadget:Initialize()
		CacheGadgets()
	end

	local lastCheckFrame = 0
	local lastFullScanFrame = 0
	function gadget:GameFrame(frame)
		if next(pendingReHook) then
			for name in pairs(pendingReHook) do
				ReHookProfiler(name)
			end
			pendingReHook = {}
		end

		local numGadgets = 15
		while numGadgets > 0 and next(updateQueue) do
			local gadgetName, fileName = next(updateQueue)
			CheckForChanges(gadgetName, fileName, "synced")
			updateQueue[gadgetName] = nil
			numGadgets = numGadgets - 1
		end

		if frame - lastCheckFrame < 30 then
			return
		end
		lastCheckFrame = frame
		for name, fileName in pairs(failedGadgets) do
			CheckForChanges(name, fileName, "synced")
		end
		-- Full scan every ~3 seconds to catch synced-side changes
		if frame - lastFullScanFrame >= 90 then
			lastFullScanFrame = frame
			CacheGadgets()
			updateQueue = {}
			for gadgetName, fileName in pairs(gadgetFileNames) do
				updateQueue[gadgetName] = fileName
			end
		end
	end
else
	local spGetMouseState = Engine.Unsynced.GetMouseState
	local mouseOffscreen = select(6, spGetMouseState())

	function gadget:Initialize()
		CacheGadgets()
	end

	local timeSinceCheck = 0
	local updateQueue = {}
	function gadget:Update(dt)
		if next(pendingReHook) then
			for name in pairs(pendingReHook) do
				ReHookProfiler(name)
			end
			pendingReHook = {}
		end

		if next(updateQueue) then
			local startTime = Engine.Unsynced.GetTimer()
			-- 3 ms budget per frame
			while next(updateQueue) and (Engine.Unsynced.DiffTimers(Engine.Unsynced.GetTimer(), startTime, true) < 3.0) do
				local gadgetName, fileName = next(updateQueue)
				CheckForChanges(gadgetName, fileName, "unsynced")
				updateQueue[gadgetName] = nil
			end
		end

		timeSinceCheck = timeSinceCheck + dt
		if timeSinceCheck < 1 then
			return
		end
		timeSinceCheck = 0

		local prevMouseOffscreen = mouseOffscreen
		mouseOffscreen = select(6, spGetMouseState())

		if not mouseOffscreen and prevMouseOffscreen then
			CacheGadgets()
			updateQueue = {}
			for gadgetName, fileName in pairs(gadgetFileNames) do
				updateQueue[gadgetName] = fileName
			end
		else
			for name, fileName in pairs(failedGadgets) do
				CheckForChanges(name, fileName, "unsynced")
			end
		end
	end
end
