include("keysym.h.lua")

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Transport AI",
		desc = "Automatically transports units going to factory waypoint.\n" ..
			"Adds embark=call for transport and disembark=unload from transport command",
		author = "Licho",
		date = "1.11.2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
	}
end

local CONST_IGNORE_BUILDERS = false -- should automated factory transport ignore builders?
local CONST_IGNORE_GROUNDSCOUTS = true -- should automated factory transport ignore scouts?
local CONST_HEIGHT_MULTIPLIER = 3 -- how many times to multiply height difference when evaluating distance
local CONST_TRANSPORT_PICKUPTIME = 9 -- how long (in seconds) does transport land and takeoff with unit
local CONST_PRIORITY_BENEFIT = 10000 -- how much more important are priority transfers
local CONST_BENEFIT_LIMIT = 5  -- what is the lowest benefit treshold to use transport (in sec difference with transport against without it)
local CONST_TRANSPORT_STOPDISTANCE = 150 -- how close by has transport be to stop the unit
local CONST_UNLOAD_RADIUS = 400 -- how big is the radious for unload command for factory transports

local idleTransports = {} -- list of idle transports key = id, value = {defid}
local waitingUnits = {} -- list of units waiting for traqnsport - key = unitID, {unit state, unitDef, factory}
local priorityUnits = {} -- lists of priority units waiting for key= unitId, value = state
local toPick = {} -- list of units waiting to be picked - key = transportID, value = {id, stoppedState}
local toPickRev = {} -- list of units waiting to be picked - key = unitID, value=transportID
local storedQueue = {} -- unit keyed stored queues
local hackIdle = {} -- temp field to overcome unitIdle problem


local ST_ROUTE = 1 -- unit is enroute from factory
local ST_PRIORITY = 2 -- unit is in need of priority transport
local ST_STOPPED = 3 -- unit is enroute from factory but stopped


local timer = 0
local myTeamID

local GetUnitPosition = Spring.GetUnitPosition
local GetUnitDefID = Spring.GetUnitDefID
local Echo = Spring.Echo
local GetPlayerInfo = Spring.GetPlayerInfo
local GetUnitCommands = Spring.GetUnitCommands
local GetUnitSeparation = Spring.GetUnitSeparation
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitDefDimensions = Spring.GetUnitDefDimensions
local GetTeamUnits = Spring.GetTeamUnits
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitIsTransporting = Spring.GetUnitIsTransporting
local GetGroundHeight = Spring.GetGroundHeight
local math_sqrt = math.sqrt

local isFactory = {}
local isTransport = {}
local isTransportable = {}
local unitAssistBuilder = {}
local isGroundscout = {}
local unitSpeed = {}
local unitXsize = {}
local unitMass = {}
local unitTransportSize = {}
local unitTransportCapacity = {}
local unitTransportMass = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.isFactory then
		isFactory[uDefID] = true
	end
	if uDef.isTransport and uDef.canFly and uDef.transportCapacity > 0 then
		isTransport[uDefID] = true
	end
	if not uDef.canFly and uDef.speed > 0 and uDef.springCategories ~= nil then
		isTransportable[uDefID] = true
	end
	if uDef.isBuilder and uDef.canAssist then
		unitAssistBuilder[uDefID] = true
	end
	if uDef.modCategories.groundscout then
		isGroundscout[uDefID] = true
	end
	unitSpeed[uDefID] = uDef.speed
	unitXsize[uDefID] = uDef.xsize
	unitMass[uDefID] = uDef.mass
	unitTransportSize[uDefID] = uDef.transportSize
	unitTransportCapacity[uDefID] = uDef.transportCapacity
	unitTransportMass[uDefID] = uDef.transportMass
end

function IsEmbarkCommand(unitID)
	local queue = GetUnitCommands(unitID, 20);
	if queue ~= nil and #queue >= 1 and IsEmbark(queue[1]) then
		return true
	end
	return false
end

function IsEmbark(cmd)
	if cmd.id == CMD.WAIT and cmd.options.alt and not cmd.options.ctrl then
		return true
	end
	return false
end

function IsDisembark(cmd)
	if cmd.id == CMD.WAIT and cmd.options.alt and cmd.options.ctrl then
		return true
	end
	return false
end

function IsWaitCommand(unitID)
	local queue = GetUnitCommands(unitID, 20);
	if queue ~= nil and queue[1].id == CMD.WAIT and not queue[1].options.alt then
		return true
	end
	return false
end

--function IsIdle(unitID)
--  local queue = GetUnitCommands(unitID,20)
--  if (queue == nil or #queue==0) then
--    return true
--  else
--    return false
--  end
--end

function GetToPickTransport(unitID)
	local x = toPickRev[unitID]
	if x ~= nil then
		return x
	else
		return 0
	end
end

function GetToPickUnit(transportID)
	local x = toPick[transportID]
	if x ~= nil then
		if x[1] ~= nil then
			return x[1]
		else
			return 0
		end
	end
	return 0
end

function DeleteToPickTran(transportID)
	local tr = toPick[transportID]
	if tr ~= nil then
		local uid = tr[1]
		if uid ~= nil then
			toPickRev[uid] = nil
		end
	end
	toPick[transportID] = nil
end

function DeleteToPickUnit(unitID)
	local tr = toPickRev[unitID]
	if tr ~= nil then
		toPick[tr] = nil
	end
	toPickRev[unitID] = nil
end

function AddToPick(transportID, unitID, stopped, fact)
	toPick[transportID] = { unitID, stopped, fact }
	toPickRev[unitID] = transportID
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		widget:PlayerChanged()
	end

	local _, _, _, teamID = GetPlayerInfo(Spring.GetMyPlayerID(), false)
	myTeamID = teamID
	widgetHandler:RegisterGlobal('taiEmbark', taiEmbark)

	for _, unitID in ipairs(GetTeamUnits(teamID)) do
		-- init existing transports
		if AddTransport(unitID, GetUnitDefID(unitID)) then
			AssignTransports(unitID, 0)
		end
	end
end

function widget:GameStart()
	widget:PlayerChanged()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('taiEmbark')
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
	if teamID == myTeamID then
		if AddTransport(unitID, unitDefID) then
			AssignTransports(unitID, 0)
		end
	end
end

--[[function widget:UnitCreated(unitID, unitDefID, teamID)
  if teamID == myTeamID then
    if AddTransport(unitID, unitDefID) then
       AssignTransports(unitID, 0)
    end
  end
end]]--

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if teamID == myTeamID then
		--     Echo("unit destroyed " ..unitID)
		idleTransports[unitID] = nil
		priorityUnits[unitID] = nil
		local tuid = GetToPickUnit(unitID)
		if tuid ~= 0 then
			-- transport which was about to pick something was destroyed
			local state = toPick[unitID][2]
			local fact = toPick[unitID][3]
			if state == ST_PRIORITY then
				waitingUnits[tuid] = { ST_PRIORITY, GetUnitDefID(tuid) }
			else
				waitingUnits[tuid] = { ST_ROUTE, GetUnitDefID(tuid), fact }
				if state == ST_STOPPED then
					GiveOrderToUnit(tuid, CMD.WAIT, {}, 0)
				end
			end
			DeleteToPickTran(unitID)
			AssignTransports(0, tuid)
		else
			-- unit which was about to be picked was destroyed
			local pom = GetToPickTransport(unitID)
			if pom ~= 0 then
				DeleteToPickUnit(unitID)
				GiveOrderToUnit(pom, CMD.STOP, {}, 0)
			end  -- delete form toPick list
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeamID, teamID)
	widget:UnitDestroyed(unitID, unitDefID, teamID)
end

function AddTransport(unitID, unitDefID)
	if isTransport[unitDefID] then
		-- and IsIdle(unitID)
		idleTransports[unitID] = unitDefID
		--Echo ("transport added " .. unitID)
		return true
	end
	return false
end

function widget:UnitIdle(unitID, unitDefID, teamID)
	if teamID ~= myTeamID then
		return
	end
	if WG.FerryUnits and WG.FerryUnits[unitID] then
		return
	end
	if hackIdle[unitID] ~= nil then
		hackIdle[unitID] = nil
		return
	end
	if AddTransport(unitID, unitDefID) then
		AssignTransports(unitID, 0)
	else
		if isTransportable[unitDefID] then
			priorityUnits[unitID] = nil

			local marked = GetToPickTransport(unitID)
			if waitingUnits[unitID] ~= nil then
				-- unit was waiting for transport and now its suddenly idle (stopped) - delete it
				--        Echo("waiting unit idle "..unitID)
				waitingUnits[unitID] = nil
			end

			if marked ~= 0 then
				--        Echo("to pick unit idle "..unitID)
				DeleteToPickTran(marked)
				GiveOrderToUnit(marked, CMD.STOP, {}, 0)  -- and stop it (when it becomes idle it will be assigned)
			end
		end
	end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	if unitTeam == myTeamID then
		if CONST_IGNORE_BUILDERS and unitAssistBuilder then
			return
		end
		if CONST_IGNORE_GROUNDSCOUTS and isGroundscout[unitDefID] then
			return
		end
		if isTransportable[unitDefID] and not userOrders then
			--      Echo ("new unit from factory "..unitID)
			local commands = GetUnitCommands(unitID, 20)
			for i = 1, #commands do
				local v = commands[i]
				if IsEmbark(v) then
					priorityUnits[unitID] = unitDefID
					return
				end
			end

			waitingUnits[unitID] = { ST_ROUTE, unitDefID, factID }
			AssignTransports(0, unitID)
		end
	end
end

function widget:CommandNotify(id, params, options)
	local sel = nil
	if not options.shift then
		sel = GetSelectedUnits()
		for i = 1, #sel do
			local uid = sel[i]
			widget:UnitDestroyed(uid, GetUnitDefID(uid), myTeamID)
		end
	end

	if id == CMD.WAIT and options.alt then
		if (sel == nil) then
			sel = GetSelectedUnits()
		end
		for i = 1, #sel do
			local uid = sel[i]
			priorityUnits[uid] = GetUnitDefID(uid)
		end
	end

	return false
end

function widget:Update(deltaTime)
	timer = timer + deltaTime
	if timer < 1 then
		return
	end
	StopCloseUnits()

	local todel = {}
	local todelCount = 0
	for i, d in pairs(priorityUnits) do
		--    Echo ("checking prio " ..i)
		if IsEmbarkCommand(i) then
			--      Echo ("prio called " ..i)
			waitingUnits[i] = { ST_PRIORITY, d }
			AssignTransports(0, i)
			todelCount = todelCount + 1
			todel[todelCount] = i
		end
	end
	for _, x in ipairs(todel) do
		priorityUnits[x] = nil
	end

	timer = 0
end

function StopCloseUnits()
	-- stops dune units which are close to transport
	for transportID, val in pairs(toPick) do
		local unitID = val[1]
		local state = val[2]
		if state == ST_ROUTE then
			local dist = GetUnitSeparation(transportID, unitID, true)
			if dist ~= nil and dist < CONST_TRANSPORT_STOPDISTANCE then
				local canStop = true
				if val[3] ~= nil then
					local fd = GetUnitDefID(val[3])
					local ud = GetUnitDefID(unitID)
					if fd ~= nil and ud ~= nil then
						local fd = GetUnitDefDimensions(fd)
						local ud = GetUnitDefDimensions(ud)
						if fd ~= nil and ud ~= nil then
							if GetUnitSeparation(unitID, val[3], true) < fd.radius + ud.radius then
								--                Echo ("Cant stop - too close to factory")
								canStop = false
							end
						end
					end
				end
				if canStop then
					if not IsWaitCommand(unitID) then
						GiveOrderToUnit(unitID, CMD.WAIT, {}, 0)
					end
					toPick[transportID][2] = ST_STOPPED
				end
			end
		end
	end
end

function widget:UnitLoaded(unitID, unitDefID, teamID, transportID)
	if teamID ~= myTeamID or toPick[transportID] == nil then
		return
	end

	local queue = GetUnitCommands(unitID, 20);
	if queue == nil then
		return
	end

	--  Echo("unit loaded " .. transportID .. " " ..unitID)
	local torev = {}
	local torevCount = 0
	local vl = nil

	local ender = false

	storedQueue[unitID] = {}
	DeleteToPickTran(transportID)
	hackIdle[transportID] = true
	local cnt = 0
	for i = 1, #queue do
		local v = queue[i]
		if not v.options.internal then
			if (v.id == CMD.MOVE or v.id == CMD.WAIT) and not ender then
				cnt = cnt + 1
				if v.id == CMD.MOVE then
					GiveOrderToUnit(transportID, CMD.MOVE, v.params, { "shift" })
					torevCount = torevCount + 1
					torev[torevCount] = { v.params[1], v.params[2], v.params[3] + 20 }
					vl = v.params
				end
				if IsDisembark(v) then
					ender = true
				end
			else
				if not ender then
					ender = true
				end
				if v.ID ~= CMD.WAIT then
					local opts = { "shift" }
					if v.options.alt then
						opts[#opts + 1] = "alt"
					end
					if v.options.ctrl then
						opts[#opts + 1] = "ctrl"
					end
					if v.options.right then
						opts[#opts + 1] = "right"
					end
					storedQueue[unitID][#storedQueue[unitID] + 1] = { v.id, v.params, opts }
					--table.insert(storedQueue[unitID], {v.id, v.params, opts})
				end
			end
		end
	end

	GiveOrderToUnit(unitID, CMD.STOP, {}, 0)

	if vl ~= nil then
		GiveOrderToUnit(transportID, CMD.UNLOAD_UNITS, { vl[1], vl[2], vl[3], CONST_UNLOAD_RADIUS }, { "shift" })

		local i = #torev
		while i > 0 do
			GiveOrderToUnit(transportID, CMD.MOVE, torev[i], { "shift" })
			i = i - 1
		end

		local x, y, z = GetUnitPosition(transportID)
		GiveOrderToUnit(transportID, CMD.MOVE, { x, y, z }, { "shift" })
	end

end

function widget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if teamID ~= myTeamID or storedQueue[unitID] == nil then
		return
	end
	GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	for _, x in ipairs(storedQueue[unitID]) do
		GiveOrderToUnit(unitID, x[1], x[2], x[3])
	end
	storedQueue[unitID] = nil
	local cmdID = Spring.GetUnitCurrentCommand(unitID, 1) --GetUnitCommands(unitID,2) -- not sure if bug or that this old code actually meant to get the 2nd cmd in queue
	if cmdID and cmdID == CMD.WAIT then
		GiveOrderToUnit(unitID, CMD.WAIT, {}, 0)  -- workaround: clears wait order if STOP fails to do so
	end
end

function CanTransport(transportID, unitID)
	local udef = GetUnitDefID(unitID)
	local tdef = GetUnitDefID(transportID)

	if not udef or not tdef then
		return false
	end
	if unitXsize[udef] > unitTransportSize[tdef] * 2 then
		-- unit size check
		--    Echo ("size failed")
		return false
	end

	local trans = GetUnitIsTransporting(transportID) -- capacity check
	if unitTransportCapacity[tdef] <= #trans then
		--    Echo ("count failed")
		return false
	end

	local mass = 0 -- mass check
	for _, a in ipairs(trans) do
		mass = mass + unitMass[GetUnitDefID(a)]
	end
	if mass > unitTransportMass[tdef] then
		--    Echo ("mass failed")
		return false
	end
	return true
end

function AssignTransports(transportID, unitID)
	local best = {}
	local bestCount = 0
	--  Echo ("assigning " .. transportID .. " " ..unitID)
	if transportID ~= 0 then
		local transpeed = unitSpeed[GetUnitDefID(transportID)]
		for id, val in pairs(waitingUnits) do
			if CanTransport(transportID, id) then
				local ud = GetPathLength(id)
				local td = GetUnitSeparation(id, transportID, true)

				local ttime = (td + ud) / transpeed + CONST_TRANSPORT_PICKUPTIME
				local utime = (ud) / unitSpeed[val[2]]
				local benefit = utime - ttime
				if val[1] == ST_PRIORITY then
					benefit = benefit + CONST_PRIORITY_BENEFIT
				end
				--       Echo ("   "..transportID .. " " .. id .. "  " .. benefit)

				if benefit > CONST_BENEFIT_LIMIT then
					bestCount = bestCount + 1
					best[bestCount] = { benefit, transportID, id }
				end
			end
		end
	elseif unitID ~= 0 then
		local uspeed = unitSpeed[GetUnitDefID(unitID)]
		local state = waitingUnits[unitID][1]
		local ud = GetPathLength(unitID)
		for id, def in pairs(idleTransports) do
			if CanTransport(id, unitID) then
				local td = GetUnitSeparation(unitID, id, true)

				local ttime = (td + ud) / unitSpeed[def] + CONST_TRANSPORT_PICKUPTIME
				local utime = (ud) / uspeed
				local benefit = utime - ttime
				if (state == ST_PRIORITY) then
					benefit = benefit + CONST_PRIORITY_BENEFIT
				end

				--         Echo ("   "..id.. " " .. unitID .. "  " .. benefit)

				if benefit > CONST_BENEFIT_LIMIT then
					bestCount = bestCount + 1
					best[bestCount] = { benefit, id, unitID }
				end
			end
		end
	end

	table.sort(best, function(a, b)
		return a[1] > b[1]
	end)
	local i = 1
	local used = {}
	while i <= bestCount do
		local tid = best[i][2]
		local uid = best[i][3]
		i = i + 1
		if (used[tid] == nil and used[uid] == nil) then
			used[tid] = 1
			used[uid] = 1
			--      Echo ("ordering " .. tid .. " " .. uid )

			if (waitingUnits[uid][1] == ST_PRIORITY) then
				AddToPick(tid, uid, ST_PRIORITY)
			else
				AddToPick(tid, uid, ST_ROUTE, waitingUnits[uid][3])
			end
			waitingUnits[uid] = nil
			idleTransports[tid] = nil
			GiveOrderToUnit(tid, CMD.LOAD_UNITS, { uid }, 0)
		end
	end
end

function Dist(x, y, z, x2, y2, z2)
	local xd = x2 - x
	local yd = y2 - y
	local zd = z2 - z
	return math_sqrt(xd * xd + yd * yd + zd * zd)
end

function GetPathLength(unitID)
	local mini = math.huge
	local maxi = -math.huge
	local px, py, pz = GetUnitPosition(unitID)

	local h = GetGroundHeight(px, pz)
	if h < mini then
		mini = h
	end
	if h > maxi then
		maxi = h
	end

	local d = 0
	local queue = GetUnitCommands(unitID, 20);
	if queue == nil then
		return 0
	end
	for i = 1, #queue do
		local v = queue[i]
		if v.id == CMD.MOVE or v.id == CMD.WAIT then
			if v.id == CMD.MOVE then
				d = d + Dist(px, py, pz, v.params[1], v.params[2], v.params[3])
				px = v.params[1]
				py = v.params[2]
				pz = v.params[3]
				local h = GetGroundHeight(px, pz)
				if h < mini then
					mini = h
				end
				if h > maxi then
					maxi = h
				end
			end
		else
			break
		end
	end

	d = d + (maxi - mini) * CONST_HEIGHT_MULTIPLIER
	return d
end


--[[
function widget:KeyPress(key, modifier, isRepeat)
  if (key == KEYSYMS.Q and not modifier.ctrl) then
    if (not modifier.alt) then
      local opts = {"alt"}
      if (modifier.shift) then table.insert(opts, "shift") end

      for _, id in ipairs(GetSelectedUnits()) do -- embark
        local def = GetUnitDefID(id)
        if (isTransportable[def] or isFactory[def]) then
          GiveOrderToUnit(id, CMD.WAIT, {}, opts)
          if (not isFactory[def]) then priorityUnits[id] = def end
        end
      end
    else
      local opts = {"alt", "ctrl"}
      if (modifier.shift) then table.insert(opts, "shift") end
      for _, id in ipairs(GetSelectedUnits()) do --disembark
        local def = GetUnitDefID(id)
        if (isTransportable[def]  or isFactory[def]) then GiveOrderToUnit(id, CMD.WAIT, {}, opts) end
      end

    end
  end
end ]]--



function taiEmbark(unitID, teamID, embark, shift)
	-- called by gadget
	if teamID ~= myTeamID then
		return
	end

	if not shift then
		widget:UnitDestroyed(unitID, GetUnitDefID(unitID), myTeamID)
	end

	if embark then
		local def = GetUnitDefID(unitID)
		if isFactory[def] then
			priorityUnits[unitID] = def
		end
	end
end

