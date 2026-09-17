local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Team stats API",
		desc = "WG.teamStats: the team stats gadget's live values, history and milestones, for any widget",
		author = "Floris",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = -828889,
		enabled = true,
	}
end

-- The one place the team stats gadget (luarules/gadgets/api_teamstats.lua) hands over to.
-- A widget cannot call into a gadget, so the gadget calls LuaUI: while a receiver global
-- is registered here it is handed the live values of every team the viewer may see every
-- second, and a history request is answered with the backlog. Only one widget can hold
-- that global, so this one holds it for everyone: a widget subscribes with the callbacks
-- it wants, and the receiver exists only while someone has subscribed, so nothing is
-- handed over while no widget asks.
--
--   WG.teamStats.subscribe(name, { live = fn(all, frame), milestone = fn(teamID, m),
--                                  history = fn(teamID, h) })   -- every callback optional
--   WG.teamStats.unsubscribe(name)
--   WG.teamStats.isSubscribed(name)
--   WG.teamStats.getLive([teamID])   -> the last hand-over (one team or all), and its frame
--   WG.teamStats.getMilestones(teamID)
--   WG.teamStats.requestHistory(teamID [, fromIndex])  -- answered through `history`
--   WG.teamStats.getInfo()           -> { period, keys, buckets, milestones, energyPerMetal }
--   WG.teamStats.isAvailable()       -> whether the gadget is there to hand over
--
-- A live table is keyed by team and holds the keys `getInfo().keys` plus `dead` and
-- `milestones` ({ key, frame, unitDefID, unitID }, in order). A history is
-- { period, from, frames = {...}, values = { [key] = {...} } } from `fromIndex` on, so a
-- caller holding the first n samples asks for what came after them.

local spGetGameFrame = Spring.GetGameFrame

-- Hand-overs come every 30 frames while asked for; this long without one, the gadget
-- counts as gone rather than quiet.
local STALE_FRAMES = 90

---@type table<string, table>
local subscribers = {}
local subscriberCount = 0
-- The last hand-over and its frame; kept after the last unsubscribe, so a late reader
-- still gets the last known values.
---@type table?, number?
local live, liveFrame
-- The frame the receiver was last registered at.
---@type number?
local askedFrame
---@type table?
local info
-- How many milestones of each team have been seen, so new ones raise an event.
---@type table<integer, integer>
local milestonesSeen = {}
-- History asked for and not yet handed to the gadget: teamID -> from index.
---@type table<integer, integer>
local pending = {}
local pendingAny = false
local listening = false

local function receiveLive(all, frame)
	live, liveFrame = all, frame
	for _, callbacks in pairs(subscribers) do
		if callbacks.live then
			callbacks.live(all, frame)
		end
	end
	for teamID, team in pairs(all) do
		local marks = team.milestones
		local seen = milestonesSeen[teamID] or 0
		if marks and #marks > seen then
			for i = seen + 1, #marks do
				for _, callbacks in pairs(subscribers) do
					if callbacks.milestone then
						callbacks.milestone(teamID, marks[i])
					end
				end
			end
			milestonesSeen[teamID] = #marks
		end
	end
end

-- The gadget describes its layout once; after that the global is taken down again.
local function receiveInfo(described)
	info = described
	widgetHandler:DeregisterGlobal("TeamStatsInfo")
end

local function historyRequest()
	if not pendingAny then
		return nil
	end
	local wanted = pending
	pending = {}
	pendingAny = false
	return wanted
end

local function receiveHistory(teamID, history)
	for _, callbacks in pairs(subscribers) do
		if callbacks.history then
			callbacks.history(teamID, history)
		end
	end
end

local function listen(on)
	if on == listening then
		return
	end
	listening = on
	if on then
		widgetHandler:RegisterGlobal("TeamStatsLive", receiveLive)
		widgetHandler:RegisterGlobal("TeamStatsHistoryRequest", historyRequest)
		widgetHandler:RegisterGlobal("TeamStatsHistory", receiveHistory)
		if not info then
			widgetHandler:RegisterGlobal("TeamStatsInfo", receiveInfo)
		end
		askedFrame = spGetGameFrame()
	else
		widgetHandler:DeregisterGlobal("TeamStatsLive")
		widgetHandler:DeregisterGlobal("TeamStatsHistoryRequest")
		widgetHandler:DeregisterGlobal("TeamStatsHistory")
		widgetHandler:DeregisterGlobal("TeamStatsInfo")
	end
end

local api = {}

function api.subscribe(name, callbacks)
	if type(name) ~= "string" or type(callbacks) ~= "table" then
		return false
	end
	if not subscribers[name] then
		subscriberCount = subscriberCount + 1
	end
	subscribers[name] = callbacks
	listen(true)
	return true
end

function api.unsubscribe(name)
	if not subscribers[name] then
		return false
	end
	subscribers[name] = nil
	subscriberCount = subscriberCount - 1
	if subscriberCount == 0 then
		listen(false)
	end
	return true
end

function api.isSubscribed(name)
	return subscribers[name] ~= nil
end

function api.getLive(teamID)
	if teamID ~= nil then
		return live and live[teamID], liveFrame
	end
	return live, liveFrame
end

function api.getMilestones(teamID)
	local team = live and live[teamID]
	return team and team.milestones
end

function api.requestHistory(teamID, fromIndex)
	if not listening then
		return false
	end
	pending[teamID] = fromIndex or 1
	pendingAny = true
	return true
end

function api.getInfo()
	return info
end

-- Whether the gadget is there: taken to be until it has been asked for this long
-- without a hand-over, or the hand-overs stopped. Asking again gives it that long again,
-- so a subscriber arriving after a quiet spell does not see it gone for a second.
-- Meaningful while someone is subscribed: nobody asking means nothing arrives.
function api.isAvailable()
	local last = liveFrame
	if askedFrame and (not last or askedFrame > last) then
		last = askedFrame
	end
	if not last then
		return true
	end
	return spGetGameFrame() - last <= STALE_FRAMES
end

function widget:Initialize()
	WG.teamStats = api
end

function widget:Shutdown()
	listen(false)
	WG.teamStats = nil
end
