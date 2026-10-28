local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Team Death Effect",
		desc = "blows up a teams units in a gradual/wave like manner",
		author = "Floris", -- original: KDR_11k (David Becker)",
		date = "September 2021",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

-- this gadget won't do: Spring.KillTeam(...)

if not gadgetHandler:IsSyncedCode() then
	return
end

local wavePeriod = 550
local noCratersWhenGameOver = true -- units of the last losing allyteam leave the terrain alone, craters cost sim time

local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_random = math.random
local distance2DSquared = math.distance2dSquared

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spDestroyUnit = Spring.DestroyUnit

local DISTANCE_LIMIT = math_max(Game.mapSizeX, Game.mapSizeZ) * math_max(Game.mapSizeX, Game.mapSizeZ)
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
GG.wipeoutWithWreckage = GG.wipeoutWithWreckage or false -- FFA can enable this

local isCommander = {}
local unitDecoration = {}
local weaponCount = {}
for udefID, def in ipairs(UnitDefs) do
	if def.customParams.iscommander then
		isCommander[udefID] = true
	end
	if def.customParams.decoration then
		unitDecoration[udefID] = true
	end
	weaponCount[udefID] = #def.weapons
end

local wipedoutTeams = {}
local destroyUnitQueue = {} ---@type table<UnitID, UnitID|false> unitID : attackerID|false
local destroyByFrame = {} ---@type table<integer, UnitID[]?>

---Neutralizes a team's units and queues them to explode
---@param teamID TeamID
---@param originX number? Wave epicentre; when omitted the death frames are randomized.
---@param originZ number? Wave epicentre; when omitted the death frames are randomized.
---@param attackerUnitID UnitID? Credited as the killer of the destroyed units.
---@param periodMult number? Scales how long the wave takes. Defaults to `1.0`.
---@param noCraters boolean? The death explosions don't deform the terrain.
local function wipeoutTeam(teamID, originX, originZ, attackerUnitID, periodMult, noCraters) -- only teamID is required
	local setUnitNeutral, setUnitSensorRadius = Spring.SetUnitNeutral, Spring.SetUnitSensorRadius
	local setUnitTarget, setUnitWeaponHoldFire = Spring.SetUnitTarget, Spring.UnitWeaponHoldFire
	local setUnitWeaponDamages = Spring.SetUnitWeaponDamages
	periodMult = periodMult or 1
	local gameFrame = Spring.GetGameFrame()
	local maxDeathFrame = 0
	local teamUnits = Spring.GetTeamUnits(teamID)
	local armed, armedCount = {}, 0
	for i = 1, #teamUnits do
		local unitID = teamUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if not unitDecoration[unitDefID] then
			local x, _, z = spGetUnitPosition(unitID)
			local deathFrame
			if originX and originZ then
				deathFrame = 6
					+ math_floor(
						(
							math_min(
								((distance2DSquared(x, z, originX, originZ) / DISTANCE_LIMIT) * wavePeriod * 0.6),
								wavePeriod
							) + math_random(0, wavePeriod / 2.5)
						) * periodMult
					)
			else
				deathFrame = 6
					+ math_floor((math_random(1, wavePeriod * 0.3) + math_random(0, wavePeriod / 2.5)) * periodMult)
			end
			maxDeathFrame = math_max(maxDeathFrame, deathFrame)
			if destroyUnitQueue[unitID] == nil then
				destroyUnitQueue[unitID] = attackerUnitID or false
				local destroyFrame = gameFrame + deathFrame + 1
				local units = destroyByFrame[destroyFrame]
				if not units then
					units = {}
					destroyByFrame[destroyFrame] = units
				end
				units[#units + 1] = unitID
			end

			-- units are in a terminal state so we can skip the controller and set their attributes directly
			setUnitNeutral(unitID, true)
			setUnitSensorRadius(unitID, "los", 0)
			setUnitSensorRadius(unitID, "airLos", 0)
			setUnitSensorRadius(unitID, "radar", 0)
			setUnitSensorRadius(unitID, "sonar", 0)
			if noCraters then
				setUnitWeaponDamages(unitID, "selfDestruct", "craterMult", 0)
				setUnitWeaponDamages(unitID, "explode", "craterMult", 0)
			end
			local weapons = weaponCount[unitDefID]
			if weapons > 0 then
				for weaponNum = 1, weapons do
					setUnitWeaponHoldFire(unitID, weaponNum)
				end
				setUnitTarget(unitID, nil)
				armedCount = armedCount + 1
				armed[armedCount] = unitID
			end
		end
	end
	if armedCount > 0 then
		Spring.GiveOrderToUnitArray(armed, CMD.FIRE_STATE, 0)
		Spring.GiveOrderToUnitArray(armed, GameCMD.UNIT_CANCEL_TARGET)
	end
	wipedoutTeams[teamID] = math_max(wipedoutTeams[teamID] or 0, gameFrame + math_max(maxDeathFrame, 300))
	GG.maxDeathFrame = GG.maxDeathFrame and math_max(GG.maxDeathFrame, maxDeathFrame) or maxDeathFrame -- storing frame of total unit wipeout
end

---Whether at most one allyteam is left standing once this one is gone.
---@param allyTeamID AllyTeamID
---@return boolean
local function isGameDecidedWithout(allyTeamID)
	local survivors = 0
	for _, otherAllyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if otherAllyTeamID ~= allyTeamID and otherAllyTeamID ~= gaiaAllyTeamID then
			for _, teamID in ipairs(Spring.GetTeamList(otherAllyTeamID)) do
				if not wipedoutTeams[teamID] and not select(3, Spring.GetTeamInfo(teamID, false)) then
					survivors = survivors + 1
					break
				end
			end
		end
	end
	return survivors <= 1
end

---Wipes out every team in an allyteam, shortening the wave when few units remain.
---@param allyTeamID AllyTeamID
---@param attackerUnitID UnitID? Credited as the killer of the destroyed units.
---@param originX number? Wave epicentre; when omitted the death frames are randomized.
---@param originZ number? Wave epicentre; when omitted the death frames are randomized.
---@param periodMult number? Scales how long the wave takes. Defaults to `1.0`.
local function wipeoutAllyTeam(allyTeamID, attackerUnitID, originX, originZ, periodMult) -- only allyTeamID is required
	-- xmas gadget uses this (to prevent creating xmasballs)
	if not _G.destroyingTeam then
		_G.destroyingTeam = {}
	end
	_G.destroyingTeam[allyTeamID] = true

	-- define smaller destruction period when few units
	local totalUnits = 0
	for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
		totalUnits = totalUnits + Spring.GetTeamUnitCount(teamID)
	end
	periodMult = (periodMult or 1.0) * math.clamp(totalUnits / 300, 0.33, 1.0) -- make low unitcount blow up faster

	local noCraters = noCratersWhenGameOver and isGameDecidedWithout(allyTeamID)

	-- destroy all teams
	for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
		wipeoutTeam(teamID, originX, originZ, attackerUnitID, periodMult, noCraters)
	end
end

GG.wipeoutTeam = wipeoutTeam
GG.wipeoutAllyTeam = wipeoutAllyTeam

function gadget:GameFrame(frame)
	local units = destroyByFrame[frame]
	if not units then
		return
	end
	destroyByFrame[frame] = nil

	local selfD = not GG.wipeoutWithWreckage
	for i = 1, #units do
		local unitID = units[i]
		local attackerUnitID = destroyUnitQueue[unitID]
		destroyUnitQueue[unitID] = nil
		if attackerUnitID then
			spDestroyUnit(unitID, selfD, false, attackerUnitID)
		else
			if selfD and isCommander[spGetUnitDefID(unitID)] then
				spDestroyUnit(unitID, false, false) -- always leave commander wreckage (ffa reclaims all on early dropped players now)
			else
				spDestroyUnit(unitID, selfD, false) -- if 4th arg is given, it cannot be nil (or engine complains)
			end
		end
	end
end

local function denyAndDestroyUnit(_, unitID, _, unitTeam)
	if wipedoutTeams[unitTeam] and wipedoutTeams[unitTeam] >= spGetGameFrame() then
		spDestroyUnit(unitID, not GG.wipeoutWithWreckage, false)
	end
end
gadget.UnitCreated = denyAndDestroyUnit
gadget.UnitFinished = denyAndDestroyUnit

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	---@diagnostic disable-next-line -- OK: leaving second return `nil` is better
	return not wipedoutTeams[builderTeam] or wipedoutTeams[builderTeam] < spGetGameFrame()
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	return not wipedoutTeams[newTeam] or wipedoutTeams[newTeam] < spGetGameFrame() -- exit-only
end
