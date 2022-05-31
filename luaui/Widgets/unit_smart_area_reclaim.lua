--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_smart_area_reclaim.lua
--  brief:   Area reclaims only metal or energy depending on the center feature
--  original author: Ryan Hileman
--
--  Copyright (C) 2010.
--  Public Domain.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Smart Area Reclaim",
		desc      = "Area reclaims only metal or energy depending on the center feature",
		author    = "aegis",
		date      = "Jun 25, 2010",
		license   = "Public Domain",
		layer     = 0,
		enabled   = true
	}
end

local maxUnits = Game.maxUnits
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetCommandQueue = Spring.GetCommandQueue
local GetUnitPosition = Spring.GetUnitPosition
local GetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local GetFeaturePosition = Spring.GetFeaturePosition
local GetFeatureRadius = Spring.GetFeatureRadius
local GetFeatureResources = Spring.GetFeatureResources
local GiveOrderToUnit = Spring.GiveOrderToUnit

local WorldToScreenCoords = Spring.WorldToScreenCoords
local TraceScreenRay = Spring.TraceScreenRay

local sort = table.sort

local RECLAIM = CMD.RECLAIM
local MOVE = CMD.MOVE
local OPT_SHIFT = CMD.OPT_SHIFT

local abs = math.abs
local sqrt = math.sqrt
local atan2 = math.atan2

local gameStarted

local unitCanReclaim = {}
local unitCanMove = {}
local unitBuildDistance = {}
for udefID, def in ipairs(UnitDefs) do
	if def.canReclaim then
		unitCanReclaim[udefID] = true
		unitCanMove[udefID] = def.canMove
		unitBuildDistance[udefID] = def.buildDistance
	end
end


local function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

local function tsp(rList, tList, dx, dz)
	dx = dx or 0
	dz = dz or 0
	tList = tList or {}

	if rList == nil then return end

	local closestDist
	local closestItem
	local closestIndex

	for i=1, #rList do
		local item = rList[i]
		if item ~= nil and item ~= 0 then
			local distx, distz, uid, fid = item[1]-dx, item[2]-dz, item[3], item[4]
			local dist = abs(distx) + abs(distz)
			if closestDist == nil or dist < closestDist then
				closestDist = dist
				closestItem = item
				closestIndex = i
			end
		end
	end

	if closestItem == nil then return tList end

	tList[#tList+1] = closestItem
	rList[closestIndex] = 0
	return tsp(rList, tList, closestItem[1], closestItem[2])
end

local function stationary(rList)
	local sList = {}
	local sKeys = {}
	local sKeysCount = 0
	local lastKey, lastItem
	local lastItemCount = 0
	for i=1, #rList do
		local item = rList[i]
		local dx, dz = item[1], item[2]

		local theta = atan2(dx, dz)
		if lastKey ~= theta then
			sKeysCount = sKeysCount + 1
			sKeys[sKeysCount] = theta
			lastItem = {item}
			lastItemCount = 1
			sList[theta] = lastItem
		else
			lastItemCount = lastItemCount + 1
			lastItem[lastItem] = item
			sList[theta] = lastItem
		end
	end

	local oList = {}
	local oListCount = 0
	sort(sKeys)
	for i=1, #sKeys do
		local theta = sKeys[i]
		local values = sList[theta]
		for j=1, #values do
			oListCount = oListCount + 1
			oList[oListCount] = values[j]
		end
	end
	return oList
end


local function issue(rList, shift)
	local opts = {}

	for i=1, #rList do
		local item = rList[i]
		local uid, fid = item[3], item[4]

		local opt = {}
		if opts[uid] ~= nil or shift then
			opt = OPT_SHIFT
		end

		GiveOrderToUnit(uid, RECLAIM, {fid+maxUnits}, opt)
		opts[uid] = 1
	end
end

function widget:CommandNotify(id, params, options)
	if id == RECLAIM then
		local mobiles, stationaries = {}, {}
		local mobileb, stationaryb = false, false

		local rUnits = {}
		local rUnitsCount = 0
		local sUnits = GetSelectedUnits()
		for i=1, #sUnits do
			local uid = sUnits[i]
			local udid = GetUnitDefID(uid)
			if unitCanReclaim[udid] then
				if not unitCanMove[udid] then
					stationaries[uid] = unitBuildDistance[udid]
					stationaryb = true
				else
					mobiles[uid] = unitBuildDistance[udid]
					mobileb = true
				end

				local ux, uy, uz = GetUnitPosition(uid)
				if options.shift then
					local cmds = GetCommandQueue(uid,100)
					for ci=#cmds, 1, -1 do
						local cmd = cmds[ci]
						if cmd.id == MOVE then
							ux, uy, uz = cmd.params[1], cmd.params[2], cmd.params[3]
							break
						end
					end
				end
				rUnitsCount = rUnitsCount + 1
				rUnits[rUnitsCount] = {uid=uid, ux=ux, uz=uz}
			end
		end

		if #rUnits > 0 then
			local len = #params
			local retw, rmtw, retg, rmtg = {}, {}, {}, {}
			local retwCount, rmtwCount, retgCount, rmtgCount = 0, 0, 0, 0

			if len == 4 then
				local x, y, z, r = params[1], params[2], params[3], params[4]
				local xmin, xmax, zmin, zmax = (x-r), (x+r), (z-r), (z+r)
				--local rx, rz = (xmax - xmin), (zmax - zmin)

				local units = GetFeaturesInRectangle(xmin, zmin, xmax, zmax)

				local mx, my, mz = WorldToScreenCoords(x, y, z)
				local wy = Spring.GetGroundHeight(x, z)
				local ct, id = TraceScreenRay(mx, my)

				if ct == "feature" then
					local cu = id

					for i=1,#units,1 do
						local uid = units[i]
						local ux, uy, uz = GetFeaturePosition(uid)
						local ur = GetFeatureRadius(uid)
						local urx, urz = abs(ux - x), abs(uz - z)
						local ud = sqrt((urx * urx) + (urz * urz))-ur*.5

						if ud < r then
						local mr, _, er, _, _ = GetFeatureResources(uid)
							if uy < 0 then
								if mr > 0 then
									rmtwCount = rmtwCount + 1
									rmtw[rmtwCount] = uid
								elseif er > 0 then
									retwCount = retwCount + 1
									retw[retwCount] = uid
								end
							elseif uy > 0 then
								if mr > 0 then
									rmtgCount = rmtgCount + 1
									rmtg[rmtgCount] = uid
								elseif er > 0 then
									retgCount = retgCount + 1
									retg[retgCount] = uid
								end
							end
						end
					end

					local mr, _, er, _, _ = GetFeatureResources(cu)
					-- if (mr > 0)and(er > 0) then return end

					local mList, sList = {}, {}
					local mListCount, sListCount = 0, 0
					local source = {}

					if rmtgCount > 0 and mr > 0 and wy > 0 then
						source = rmtg
					elseif retgCount > 0 and er > 0 and wy > 0 then
						source = retg
					elseif rmtwCount > 0 and mr > 0 and wy < 0 then
						source = rmtw
					elseif retwCount > 0 and er > 0 and wy < 0 then
						source = retw
					end

					for i=1,#source do
						local fid = source[i]
						if fid ~= nil then
							local fx, _, fz = GetFeaturePosition(fid)
							for ui=1,#rUnits do
								local unit = rUnits[ui]
								local uid, ux, uz = unit.uid, unit.ux, unit.uz
								local dx, dz = ux-fx, uz-fz
								--local dist = dx + dz
								local item = {dx, dz, uid, fid}
								if mobiles[uid] ~= nil then
									mListCount = mListCount + 1
									mList[mListCount] = item
								elseif stationaries[uid] ~= nil then
									if sqrt((dx*dx)+(dz*dz)) <= stationaries[uid] then
										sListCount = sListCount + 1
										sList[sListCount] = item
									end
								end
							end
						end
					end

					local issued = false
					if mobileb then
						mList = tsp(mList)
						issue(mList, options.shift)
						issued = true
					end

					if stationaryb then
						sList = stationary(sList)
						issue(sList, options.shift)
						issued = true
					end

					return issued
				end
			end
		end
	end
	return false
end
