local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "AI Raptor Hive Standoff",
		desc = "Rewrites AI attack commands on raptor hives into standoff orders in Raptors mode",
		author = "Codex",
		date = "2026-02-17",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

local spGetGameFrame = Spring.GetGameFrame
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spValidUnitID = Spring.ValidUnitID

local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP

local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi
local mathRandom = math.random

local WATCH_UPDATE_FRAMES = 10
local REISSUE_COOLDOWN_FRAMES = 15
local HIVE_RADIUS = 48
local SAFETY_BUFFER = 24

local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ

local raptorHiveDefID = UnitDefNames["raptor_hive"] and UnitDefNames["raptor_hive"].id
if not raptorHiveDefID then
	return false
end

local managedTeams = {}
local watchStandoff = {}  -- [unitID] = { targetID = <unitID>, desired = <distance>, nextFrame = <frame> }
local ignoreCommandUntil = {}  -- [unitID] = <frame>

local unitMaxRange = {}
local unitRadius = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitMaxRange[unitDefID] = unitDef.maxWeaponRange or 0
	unitRadius[unitDefID] = unitDef.radius or 0
end

local function ClampToMap(x, z)
	x = mathMin(MAP_SIZE_X - 16, mathMax(16, x))
	z = mathMin(MAP_SIZE_Z - 16, mathMax(16, z))
	return x, z
end

local function RefreshManagedTeams()
	local gaiaTeamID = spGetGaiaTeamID()
	for k in pairs(managedTeams) do
		managedTeams[k] = nil
	end

	for _, teamID in ipairs(spGetTeamList()) do
		if teamID ~= gaiaTeamID then
			local luaAI = spGetTeamLuaAI(teamID) or ""
			local _, _, _, isAI = spGetTeamInfo(teamID, false)
			if (isAI or luaAI ~= "")
				and not string.find(luaAI, "Raptor")
				and not string.find(luaAI, "Scavenger")
			then
				managedTeams[teamID] = true
			end
		end
	end
end

local function ComputeStandoffPosition(unitID, unitDefID, targetID)
	local ux, _, uz = spGetUnitPosition(unitID)
	local tx, _, tz = spGetUnitPosition(targetID)
	if not ux or not tx then
		return nil
	end

	local maxRange = unitMaxRange[unitDefID] or 0
	local radius = unitRadius[unitDefID] or 0
	local minSafeDistance = HIVE_RADIUS + radius + SAFETY_BUFFER

	-- If this unit cannot reasonably attack from outside the hive center area, keep normal behavior.
	if maxRange <= (minSafeDistance + 16) then
		return nil
	end

	local desiredDistance = mathMax(minSafeDistance, mathMin(maxRange - 16, maxRange * 0.70))

	local dx = ux - tx
	local dz = uz - tz
	local length = mathSqrt(dx * dx + dz * dz)
	if length < 0.001 then
		-- Fallback direction if unit is at (or extremely close to) hive center.
		local heading = spGetUnitHeading(unitID)
		local angle = heading and (heading * ((2 * mathPi) / 65536.0)) or (mathRandom() * 2 * mathPi)
		dx = mathSin(angle)
		dz = mathCos(angle)
		length = 1
	end

	dx = dx / length
	dz = dz / length

	local sx = tx + dx * desiredDistance
	local sz = tz + dz * desiredDistance
	sx, sz = ClampToMap(sx, sz)
	local sy = spGetGroundHeight(sx, sz)

	return sx, sy, sz, desiredDistance
end

local function IssueStandoffOrders(unitID, unitDefID, targetID, queueWithShift)
	local sx, sy, sz, desired = ComputeStandoffPosition(unitID, unitDefID, targetID)
	if not sx then
		return false
	end

	ignoreCommandUntil[unitID] = spGetGameFrame() + 1

	local moveOpts
	local attackOpts
	if queueWithShift then
		moveOpts = { "shift" }
		attackOpts = { "shift" }
	else
		moveOpts = {}
		attackOpts = { "shift" }
	end

	spGiveOrderToUnit(unitID, CMD_MOVE, { sx, sy, sz }, moveOpts)
	spGiveOrderToUnit(unitID, CMD_ATTACK, { targetID }, attackOpts)

	watchStandoff[unitID] = {
		targetID = targetID,
		desired = desired,
		nextFrame = spGetGameFrame() + REISSUE_COOLDOWN_FRAMES,
	}
	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
	gadgetHandler:RegisterAllowCommand(CMD_STOP)
	RefreshManagedTeams()
end

function gadget:TeamDied()
	RefreshManagedTeams()
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if not managedTeams[teamID] then
		return true
	end

	local frame = spGetGameFrame()
	if (ignoreCommandUntil[unitID] or 0) >= frame then
		return true
	end

	if cmdID == CMD_STOP then
		watchStandoff[unitID] = nil
		return true
	end

	if cmdID ~= CMD_ATTACK then
		watchStandoff[unitID] = nil
		return true
	end

	if not cmdParams or cmdParams[2] then
		-- Ground attacks and area attacks are left unchanged.
		watchStandoff[unitID] = nil
		return true
	end

	local targetID = cmdParams[1]
	if not targetID or not spValidUnitID(targetID) then
		watchStandoff[unitID] = nil
		return true
	end

	if spGetUnitDefID(targetID) ~= raptorHiveDefID then
		watchStandoff[unitID] = nil
		return true
	end

	local queueWithShift = (cmdOptions and cmdOptions.shift) and true or false
	if IssueStandoffOrders(unitID, unitDefID, targetID, queueWithShift) then
		return false
	end
	return true
end

function gadget:GameFrame(n)
	if n % WATCH_UPDATE_FRAMES ~= 0 then
		return
	end

	for unitID, data in pairs(watchStandoff) do
		local targetID = data.targetID
		if (not spValidUnitID(unitID)) or (spGetUnitIsDead(unitID))
			or (not spValidUnitID(targetID)) or (spGetUnitIsDead(targetID))
		then
			watchStandoff[unitID] = nil
		elseif n >= data.nextFrame then
			local ux, _, uz = spGetUnitPosition(unitID)
			local tx, _, tz = spGetUnitPosition(targetID)
			if not ux or not tx then
				watchStandoff[unitID] = nil
			else
				local dx = ux - tx
				local dz = uz - tz
				local dist = mathSqrt(dx * dx + dz * dz)
				if dist < (data.desired * 0.85) then
					local unitDefID = spGetUnitDefID(unitID)
					if unitDefID then
						if not IssueStandoffOrders(unitID, unitDefID, targetID, false) then
							watchStandoff[unitID] = nil
						end
					else
						watchStandoff[unitID] = nil
					end
				else
					data.nextFrame = n + REISSUE_COOLDOWN_FRAMES
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID)
	watchStandoff[unitID] = nil
	ignoreCommandUntil[unitID] = nil
	for uID, data in pairs(watchStandoff) do
		if data.targetID == unitID then
			watchStandoff[uID] = nil
		end
	end
end
