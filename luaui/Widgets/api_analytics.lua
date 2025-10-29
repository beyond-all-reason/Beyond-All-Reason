local widget = widget --- @type Widget

function widget:GetInfo()
	return {
		name    = "Analytics API",
		desc    = "Provides an API for sending analytics events using SendLuaUIMsg ",
		author  = "uBdead",
		date    = "Oct 2025",
		license = "GPL-v2",
		layer   = -1,
		enabled = true,
	}
end

local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetGameFrame = Spring.GetGameFrame
local spLog = Spring.Log
local spSendLuaUIMsg = Spring.SendLuaUIMsg

local pendingAnalytics = {}

local function analyticsCoroutine(eventType, eventData)
	local myPlayerName = spGetPlayerInfo(spGetMyPlayerID())
	local frameNumber = spGetGameFrame()
	local jsondict = {}
	-- Add static fields
	jsondict.eventtype = eventType
	jsondict.username = myPlayerName
	jsondict.frame = frameNumber

	-- Add eventData incrementally
	if type(eventData) == "table" then
		local keys = {}
		for k in pairs(eventData) do keys[#keys+1] = k end
		local i = 1
		while i <= #keys do
			local k = keys[i]
			if jsondict[k] == nil then
				jsondict[k] = eventData[k]
			else
				spLog("Analytics API", LOG.WARNING, "Key conflict, skipping", k)
			end
			i = i + 1
		end
	end

	local jsonstr = Json.encode(jsondict)
	coroutine.yield()
	
	local b64str = string.base64Encode(jsonstr)
	coroutine.yield()

	local complexMatchEvent = "complex-match-event:" .. b64str
	-- Spring.Echo(complexMatchEvent)
	-- TODO would ideally be forwarded via lobby, for privacy and to avoid bloating replays
	spSendLuaUIMsg(complexMatchEvent)
end

local function sendAnalyticsEvent(eventType, eventData)
	local co = coroutine.create(function() analyticsCoroutine(eventType, eventData) end)
	table.insert(pendingAnalytics, co)
end

function widget:Update()
	-- Process one step of each pending analytics coroutine per frame
	local finished = {}
	for i, co in ipairs(pendingAnalytics) do
		local status, res = coroutine.resume(co)
		if coroutine.status(co) == "dead" then
			finished[#finished+1] = i
		end
	end
	-- Remove finished coroutines
	for j = #finished, 1, -1 do
		table.remove(pendingAnalytics, finished[j])
	end
end

function widget:Initialize()
	local Analytics = {}

	---
	--- Sends an analytics event to the telemetry system.
	--  WARNING: Do NOT include any personal information in eventType or eventData.
	--  WARNING: Data sent via this function may be intercepted by other players (including opponents!).
	--  Only send anonymized, non-personal game-related data.
	--  This function is intended for gameplay analytics and debugging, not for user tracking.
	--  @param eventType string: The type of event to send (must not contain personal info)
	--  @param eventData table: Additional event data (must not contain personal info)
	Analytics.SendEvent = sendAnalyticsEvent

	-- Initialize the analytics API
	if not WG.Analytics then
		WG.Analytics = Analytics
	end
end

function widget:Shutdown()
	WG.Analytics = nil
end
