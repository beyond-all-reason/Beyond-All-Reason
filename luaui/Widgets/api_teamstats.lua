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
--                                  history = fn(teamID, h), units = fn(teamID, u),
--                                  reset = fn() })   -- every callback optional
--   WG.teamStats.unsubscribe(name)
--   WG.teamStats.isSubscribed(name)
--   WG.teamStats.getLive([teamID])   -> the last hand-over (one team or all), and its frame
--   WG.teamStats.getMilestones(teamID)
--   WG.teamStats.requestHistory(teamID [, fromIndex])  -- answered through `history`
--   WG.teamStats.requestUnits(teamID)                  -- answered through `units`
--   WG.teamStats.getUnits(teamID)    -> the team's units by type as last handed over
--   WG.teamStats.getInfo()           -> { period, keys, buckets, milestones, energyPerMetal }
--   WG.teamStats.isAvailable()       -> whether the gadget is there to hand over
--
-- A live table is keyed by team and holds the keys `getInfo().keys` plus `dead` and
-- `milestones` ({ key, frame, unitDefID, unitID }, in order). A history is
-- { period, from, frames = {...}, values = { [key] = {...} } } from `fromIndex` on, so a
-- caller holding the first n samples asks for what came after them. The gadget hands the
-- values over flat - `flat[(k - 1) * #frames + i]` is `keys[k]` at the i-th frame, `keys`
-- being the layout's - and `values` is made from them the first time it is read. A team's units are
-- { [unitDefID] = { built, builtValue, lost, lostValue, killed, damage } }: how many of
-- the type it built and their value, how many an enemy killed and their value, the value
-- they destroyed and the damage they dealt. `reset` says the gadget started over - a reload
-- it could not pick up from - so a history or records copied from it are another run's.
--
-- Through a LuaRules reload the gadget hands this widget what it gathered as it shuts down, and
-- takes it back as it starts again: held here whether or not anyone listens.

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
-- Each team's milestones as last handed over: the gadget leaves out a team's while they have
-- not changed, once this widget says it keeps them - by being there to ask whether it wants
-- all of them again (it does when it begins to listen) - and then hands over only those
-- from the first that changed on, `milestonesFrom` saying where they go.
---@type table<integer, table>
local keptMilestones = {}
local milestonesWanted = true
-- History asked for and not yet handed to the gadget: teamID -> from index.
---@type table<integer, integer>
local pending = {}
local pendingAny = false
-- Units by type asked for and not yet handed to the gadget, and each team's as last handed over.
---@type table<integer, boolean>
local unitsPending = {}
local unitsPendingAny = false
---@type table<integer, table>
local unitsOf = {}
local listening = false
-- What the gadget handed over as LuaRules shut down, until it starts again and takes it back;
-- and which run of the gadget the values come from.
---@type table?
local stash
---@type number?
local session

-- The layout's receiver, below with the others.
---@type function
local receiveInfo

-- The gadget started over: what was kept from its old run is dropped, the layout asked for
-- again, and the subscribers told.
local function restarted()
	keptMilestones, milestonesSeen, unitsOf = {}, {}, {}
	milestonesWanted = true
	info = nil
	if listening then
		widgetHandler:RegisterGlobal("TeamStatsInfo", receiveInfo)
	end
	for _, callbacks in pairs(subscribers) do
		if callbacks.reset then
			callbacks.reset()
		end
	end
end

local function receiveLive(all, frame, from)
	if from ~= nil then
		if session ~= nil and from ~= session then
			restarted()
		end
		session = from
	end
	for teamID, team in pairs(all) do
		local marks = team.milestones
		if marks then
			local from = team.milestonesFrom
			if from and from > 1 then
				-- The ones before `from` are the ones kept; a new list, as a whole one would be.
				local kept = keptMilestones[teamID]
				if kept and #kept >= from - 1 then
					local merged = {}
					for i = 1, from - 1 do
						merged[i] = kept[i]
					end
					for i = 1, #marks do
						merged[from - 1 + i] = marks[i]
					end
					marks = merged
				else
					-- Out of step: the ones kept for now, and all of them asked for again.
					marks = kept
					milestonesWanted = true
				end
				team.milestones = marks
			end
			team.milestonesFrom = nil
			keptMilestones[teamID] = marks
		else
			team.milestones = keptMilestones[teamID]
		end
	end
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

local function milestoneRequest()
	local wanted = milestonesWanted
	milestonesWanted = false
	return wanted
end

-- The gadget describes its layout once; after that the global is taken down again.
function receiveInfo(described)
	info = described
	widgetHandler:DeregisterGlobal("TeamStatsInfo")
end

local function stashed(data)
	stash = data
end

local function unstash()
	local data = stash
	stash = nil
	return data
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

-- A flat history's runs by key, made when a subscriber reads `values`.
local lazyValues = {
	__index = function(h, field)
		if field ~= "values" or not h.flat or not h.keys then
			return nil
		end
		local values, flat, keys, n = {}, h.flat, h.keys, #h.frames
		for k = 1, #keys do
			local run, base = {}, (k - 1) * n
			for i = 1, n do
				run[i] = flat[base + i]
			end
			values[keys[k]] = run
		end
		rawset(h, "values", values)
		return values
	end,
}

local function receiveHistory(teamID, history)
	if type(history) == "table" and history.flat then
		history.keys = history.keys or (info and info.keys)
		setmetatable(history, lazyValues)
	end
	for _, callbacks in pairs(subscribers) do
		if callbacks.history then
			callbacks.history(teamID, history)
		end
	end
end

local function unitsRequest()
	if not unitsPendingAny then
		return nil
	end
	local wanted = unitsPending
	unitsPending = {}
	unitsPendingAny = false
	return wanted
end

local function receiveUnits(teamID, units)
	unitsOf[teamID] = units
	for _, callbacks in pairs(subscribers) do
		if callbacks.units then
			callbacks.units(teamID, units)
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
		milestonesWanted = true
		widgetHandler:RegisterGlobal("TeamStatsMilestoneRequest", milestoneRequest)
		widgetHandler:RegisterGlobal("TeamStatsHistoryRequest", historyRequest)
		widgetHandler:RegisterGlobal("TeamStatsHistory", receiveHistory)
		widgetHandler:RegisterGlobal("TeamStatsUnitsRequest", unitsRequest)
		widgetHandler:RegisterGlobal("TeamStatsUnits", receiveUnits)
		if not info then
			widgetHandler:RegisterGlobal("TeamStatsInfo", receiveInfo)
		end
		askedFrame = spGetGameFrame()
	else
		widgetHandler:DeregisterGlobal("TeamStatsLive")
		widgetHandler:DeregisterGlobal("TeamStatsMilestoneRequest")
		widgetHandler:DeregisterGlobal("TeamStatsHistoryRequest")
		widgetHandler:DeregisterGlobal("TeamStatsHistory")
		widgetHandler:DeregisterGlobal("TeamStatsUnitsRequest")
		widgetHandler:DeregisterGlobal("TeamStatsUnits")
		widgetHandler:DeregisterGlobal("TeamStatsInfo")
		unitsPending, unitsPendingAny = {}, false
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

function api.requestUnits(teamID)
	if not listening then
		return false
	end
	unitsPending[teamID] = true
	unitsPendingAny = true
	return true
end

function api.getUnits(teamID)
	return unitsOf[teamID]
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
	widgetHandler:RegisterGlobal("TeamStatsStash", stashed)
	widgetHandler:RegisterGlobal("TeamStatsUnstash", unstash)
end

function widget:Shutdown()
	listen(false)
	widgetHandler:DeregisterGlobal("TeamStatsStash")
	widgetHandler:DeregisterGlobal("TeamStatsUnstash")
	WG.teamStats = nil
end
