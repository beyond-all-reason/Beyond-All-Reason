
function widget:GetInfo()
	return {
		name      = "Analytics Handler",
		desc      = "Handles analytics events for BAR",
		author    = "GoogleFrog, Beherith, adapter for in-game by uBdead",
		date      = "20 February 2017",
		license   = "GPL-v2",
		layer     = 0,
		handler   = true,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Vars

local onetimeEvents = {}
local indexedRepeatEvents = {}

local ANALYTICS_EVENT = "analyticsEvent_"

-- Do not send analytics for dev versions as they will likely be nonsense.
local ACTIVE = true -- means that we either have an unauthed or an authed connection to server.

local PRINT_DEBUG = false
------------------------ Connection ---------------------

local machineHash = "DEADBEEF"
local osinfo = ""
local lastMessageSend = 0

local function MachineHash()
	--Spring.Echo("DEADBEEF", debug.getinfo(1).short_src, debug.getinfo(1).source, VFS.GetFileAbsolutePath("infolog.txt"))
	local hashstr = ""
	if Platform and Platform.gpu then
		hashstr = hashstr .."|".. Platform.gpu
	end
	if Platform and Platform.osFamily then
		hashstr = hashstr .."|" ..Platform.osFamily
		osinfo = Platform.osFamily
	end
	if Platform and Platform.osName then
		hashstr = hashstr .."|" ..Platform.osName
		osinfo = osinfo .. ":" .. Platform.osName

	end
	local hashstr = hashstr .. "|" .. tostring(VFS.GetFileAbsolutePath("infolog.txt") or "")

	local cpustr = Platform.hwConfig

	hashstr = hashstr .. "|" ..cpustr

	machineHash = string.base64Decode(VFS.CalculateHash(hashstr,0))

	if PRINT_DEBUG then Spring.Echo("This machine's analytics hash is:", hashstr, machineHash) end
end

local client
--local HOST = "server4.beyondallreason.info"
local HOST = "localhost"
local PORT = 8200
local LAZY_CONNECT_KEEP_ALIVE = 3 -- seconds

local function SocketClose()
    lastMessageSend = Spring.GetTimer()
    if client then
        client:close()
        client = nil
        if PRINT_DEBUG then Spring.Echo("Analytics disconnected") end
    end
end

local function SocketConnect(host, port)
	if client then
		client:close()
	end
	client=socket.tcp()
	client:settimeout(0)
	res, err = client:connect(host, port)
	if not res and err ~= "timeout" then
		if PRINT_DEBUG then Spring.Echo("Error in connection to Analytics server: "..err) end
		client:close()
		client = nil
		return false
	end
	if PRINT_DEBUG then Spring.Echo("Analytics connected") end
	return true
end

-- we want a socket that opens temporarily when we have data to send and closes again so we dont keep connections open unnecessarily
local function LazySocketConnect()
    if client then
        return true
    end

    SocketConnect(HOST, PORT)
end

function SendBARAnalytics(cmdName,args,isEvent)
	if PRINT_DEBUG then Spring.Log("Chobby", LOG.WARNING, "Analytics Event", cmdName, args, isEvent, client, "C/A", ACTIVE) end

	if client == nil then
		LazySocketConnect()
	end
    lastMessageSend = Spring.GetTimer()
	cmdName = string.gsub(cmdName, " ", "_") -- remove spaces from event names
	-- events are always tables, properties always just string
	local message
	local istest = ""
	if PRINT_DEBUG then istest = "_test" end
	if isEvent then
		if type(args) ~= "table" then args = {value = args or 0} end
		args = Json.encode(args)
		args = string.base64Encode(args)		
		message = "c.telemetry.log_client_event".. istest .. " " .. cmdName .. " " ..args.." ".. machineHash .. "\n"
	else
		args = string.base64Encode(tostring(args or "nil"))
		message = "c.telemetry.update_client_property".. istest .." " .. cmdName .. " " ..args.." ".. machineHash .. "\n"
	end
	if PRINT_DEBUG then Spring.Log("Chobby", LOG.WARNING, "Message:",message) end
	if ACTIVE then
        client:send(message)
    end
end

function widget:Update()
    if ACTIVE then
        local nowtime = Spring.GetTimer()
        if client and Spring.DiffTimers(nowtime, lastMessageSend) > LAZY_CONNECT_KEEP_ALIVE then
            SocketClose()
        end
    end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

local Analytics = {}

function Analytics.SendOnetimeEvent(eventName, value)
	if PRINT_DEBUG then Spring.Echo("BAR Analytics.SendOnetimeEvent(eventName, value)", eventName, value) end

	-- Do not send onetimeEvents when they dont change. This is to prevent spamming the server with the same data.
	if onetimeEvents[eventName] and (onetimeEvents[eventName] == (value or true)) then
		return
	end
	onetimeEvents[eventName] = value or true

	SendBARAnalytics(eventName, value, false)
end

function Analytics.SendIndexedRepeatEvent(eventName, value, suffix)
	if PRINT_DEBUG then Spring.Echo("BAR Analytics.SendIndexedRepeatEvent(eventName, value)", eventName, value,  suffix) end
	indexedRepeatEvents[eventName] = (indexedRepeatEvents[eventName] or 0) + 1
	eventName = eventName .. "_" .. indexedRepeatEvents[eventName]

	SendBARAnalytics(eventName, value, true)
end

function Analytics.SendRepeatEvent(eventName, value)
	if PRINT_DEBUG then Spring.Echo("BAR Analytics.SendIndexedRepeatEvent(eventName, value)", eventName, value) end

	SendBARAnalytics(eventName, value, true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function HandleAnalytics(msg)
	if string.find(msg, ANALYTICS_EVENT) == 1 then
		msg = string.sub(msg, 16)
		local pipe = string.find(msg, "|")
		if pipe then
			Analytics.SendOnetimeEvent(string.sub(msg, 0, pipe - 1), string.sub(msg, pipe + 1))
		else
			Analytics.SendOnetimeEvent(msg)
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

function widget:RecvLuaMsg(msg)
	if HandleAnalytics(msg) then
		return
	end
end

function widget:Initialize()
	MachineHash()
	WG.Analytics = Analytics
end

