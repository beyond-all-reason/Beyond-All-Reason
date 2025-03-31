--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Lups Shield",
		desc    = "Draws variable shields for shielded units",
		author  = "ivand, GoogleFrog",
		date    = "2019",
		license = "GNU GPL, v2 or later",
		layer   = 1500, -- Call ShieldPreDamaged after gadgets which change whether interception occurs
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-----------------------------------------------------------------
-- Global consts
-----------------------------------------------------------------

local GAMESPEED = Game.gameSpeed
local SHIELDARMORID = 4
local SHIELDARMORIDALT = 0
local SHIELDONRULESPARAMINDEX = 531313 -- not a string due to perfmaxxing

-----------------------------------------------------------------
-- Small vector math lib
-----------------------------------------------------------------

local function Distance(x1, y1, z1, x2, y2, z2)
	local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function Norm(x, y, z)
	return math.sqrt(x*x + y*y + z*z)
end

local function Normalize(x, y, z)
	local N = Norm(x, y, z)
	return x/N, y/N, z/N
end

-- presumes normalized vectors
local function DotProduct(x1, y1, z1, x2, y2, z2)
	return x1*x2 + y1*y2 + z1*z2
end

-- presumes normalized vectors
local function CrossProduct(x1, y1, z1, x2, y2, z2)
	return
		-y2*z1 + y1*z2,
		 x2*z1 - x1*z2,
		-x2*y1 + x1*y2
end

-- presumes normalized vectors
local function AngleBetweenVectors(x1, y1, z1, x2, y2, z2)
	-- Note: this function oftern returns nan, cause numerical instability causes the dot product to be greater than 1!
	local rawDot = DotProduct(x1, y1, z1, x2, y2, z2)

	-- protection from numerical instability
	local dot = math.clamp(rawDot, -1, 1)

	return math.acos(dot)
end

-- presumes normalized vectors
local ALMOST_ONE = 0.999
local function GetSLerpedPoint(x1, y1, z1, x2, y2, z2, w1, w2)
	-- Below check is not really required for the sane AOE_SAME_SPOT value (less than PI)
--[[
	local EPS = 1E-3
	local dotP
	repeat
		dotP = DotProduct(x1, y1, z1, x2, y2, z2)
		--check if {x1, y1, z1} and {x2, y2, z2} are not collinear
		local ok = math.abs( math.abs(dotP) - 1) >= EPS
		if not ok then -- absolutely or almost collinear. Need to do something.
			Spring.Echo("Error in GetSLerpedPoint. This should never happen!!!")
			x1 = x1 + (math.random() * 2 - 1) * EPS
			y1 = y1 + (math.random() * 2 - 1) * EPS
			z1 = z1 + (math.random() * 2 - 1) * EPS
			x1, y1, z1 = Normalize(x, y, z)
		end
	until ok
]]--
	local dotP = DotProduct(x1, y1, z1, x2, y2, z2)

	if dotP >= ALMOST_ONE then --avoid div by by sinA == zero
		return x1, y1, z1
	end
	-- Do spherical linear interpolation
	local A = math.acos(dotP)
	local sinA = math.sin(A)

	local w = 1.0 - (w1 / (w1 + w2)) --the more is relative weight the less this value should be

	local x = (math.sin((1.0 - w) * A) * x1 + math.sin(w * A) * x2) / sinA
	local y = (math.sin((1.0 - w) * A) * y1 + math.sin(w * A) * y2) / sinA
	local z = (math.sin((1.0 - w) * A) * z1 + math.sin(w * A) * z2) / sinA

	-- everything was normalized, no need to normalize again
	return x, y, z
end

-----------------------------------------------------------------
-- Synced part of gadget
-----------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local INLOS_ACCESS = {inlos = true}
	local gameFrame = 0

	function gadget:GameFrame(n)
		gameFrame = n
	end

	local unitBeamWeapons = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		local hasbeamweapon = false
		for i=1,#weapons do
			local weaponDefID = weapons[i].weaponDef
			if WeaponDefs[weaponDefID].type == "LightningCannon" or
				WeaponDefs[weaponDefID].type == "BeamLaser" then
				hasbeamweapon = true
			end
		end
		if hasbeamweapon then
			unitBeamWeapons[unitDefID] = {}
			for i=1,#weapons do
				unitBeamWeapons[unitDefID][i] = weapons[i].weaponDef
			end
		end
	end
	local weaponType = {}
	local weaponDamages = {}
	local weaponBeamtime = {}
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		weaponType[weaponDefID] = weaponDef.type
		weaponDamages[weaponDefID] = {[SHIELDARMORIDALT] = weaponDef.damages[SHIELDARMORIDALT], [SHIELDARMORID] = weaponDef.damages[SHIELDARMORID]}
		weaponBeamtime[weaponDefID] = weaponDef.beamtime
	end

	function gadget:ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
		local dmgMod = 1
		local weaponDefID
		if proID and proID ~= -1 then
			weaponDefID = Spring.GetProjectileDefID(proID)
		elseif beamEmitterUnitID then -- hitscan weapons
			local uDefID = Spring.GetUnitDefID(beamEmitterUnitID)
			if unitBeamWeapons[ uDefID ] and unitBeamWeapons[ uDefID ][beamEmitterWeaponNum] then
				weaponDefID = unitBeamWeapons[ uDefID ][beamEmitterWeaponNum]
				if weaponType[weaponDefID] ~= "LightningCannon" then
					dmgMod = 1 / (weaponBeamtime[weaponDefID] * GAMESPEED)
				end
			end
		end

		if weaponDefID then
			local dmg = weaponDamages[weaponDefID][SHIELDARMORID]
			if dmg <= 0.1 then --some stupidity here: llt has 0.0001 dmg in weaponDamages[weaponDefID][SHIELDARMORID]
				dmg = weaponDamages[weaponDefID][SHIELDARMORIDALT]
			end

			local x, y, z = Spring.GetUnitPosition(shieldCarrierUnitID)
			local dx, dy, dz
			local onlyMove = false
			if bounceProjectile then
				onlyMove = ((hitX == 0) and (hitY == 0) and (hitZ == 0)) --don't apply as additional damage
				dx, dy, dz = startX - x, startY - y, startZ - z
			else
				dx, dy, dz = hitX - x, hitY - y, hitZ - z
			end
			-- We are reasonably fast, about 1us up to here
			SendToUnsynced("AddShieldHitDataHandler", gameFrame, shieldCarrierUnitID, dmg * dmgMod, dx, dy, dz, onlyMove)
		end

		spSetUnitRulesParam(shieldCarrierUnitID, "shieldHitFrame", gameFrame, INLOS_ACCESS)
		return false
	end

	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetMyAllyTeamID     = Spring.GetMyAllyTeamID
local spGetSpectatingState  = Spring.GetSpectatingState

local IterableMap = VFS.Include("LuaRules/Gadgets/Include/IterableMap.lua")

local shieldUnitDefs

local Lups
local LupsAddParticles
local LOS_UPDATE_PERIOD = 10
local HIT_UPDATE_PERIOD = 2

local highEnoughQuality = false

local hitUpdateNeeded = false

local myAllyTeamID = spGetMyAllyTeamID()

local shieldUnits = IterableMap.New()

local function GetVisibleSearch(x, z, search)
	if not x then
		return false
	end
	for i = 1, #search do
		if Spring.IsPosInAirLos(x + search[i][1], 0, z + search[i][2], myAllyTeamID) then
			return true
		end
	end
	return false
end

local function UpdateVisibility(unitID, unitData, unitVisible, forceUpdate)
	unitVisible = unitVisible or (myAllyTeamID == unitData.allyTeamID)
	if not unitVisible then
		local ux,_,uz = Spring.GetUnitPosition(unitID)
		unitVisible = GetVisibleSearch(ux, uz, unitData.search)
	end

	local unitIsActive = Spring.GetUnitIsActive(unitID)
	if unitIsActive ~= unitData.isActive then
		forceUpdate = true
		unitData.isActive = unitIsActive
	end

	local shieldEnabled = Spring.GetUnitRulesParam (unitID, SHIELDONRULESPARAMINDEX)
	if shieldEnabled == 1 then
		unitVisible = true
	elseif shieldEnabled == 0 then
		unitVisible = false
	end

	if unitVisible == unitData.unitVisible and not forceUpdate then
		return
	end
	unitData.unitVisible = unitVisible

	for i = 1, #unitData.fxTable do
		local fxID = unitData.fxTable[i]
		local fx = Lups.GetParticles(fxID)
		if fx then
			fx.visibleToMyAllyTeam = unitIsActive and unitVisible
		end
	end
end

local function AddUnit(unitID, unitDefID)
	local def = shieldUnitDefs[unitDefID]
	local defFx = def.fx
	local fxTable = {}
	for i = 1, #defFx do
		local fx = defFx[i]
		local options = table.copy(fx.options)
		options.unit = unitID
		options.shieldCapacity = def.shieldCapacity
		local fxID = LupsAddParticles(fx.class, options)
		if fxID ~= -1 then
			fxTable[#fxTable + 1] = fxID
		end
	end

	local unitData = {
		unitDefID  = unitDefID,
		search     = def.search,
		capacity   = def.shieldCapacity,
		radius     = def.shieldRadius,
		fxTable    = fxTable,
		allyTeamID = Spring.GetUnitAllyTeam(unitID)
	}

	if highEnoughQuality then
		unitData.shieldPos  = def.shieldPos
		unitData.hitData = {}
		unitData.needsUpdate = false
	end

	IterableMap.Add(shieldUnits, unitID, unitData)

	local _, fullview = spGetSpectatingState()
	UpdateVisibility(unitID, unitData, fullview, true)
end

local function RemoveUnit(unitID)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	if unitData then
		for i = 1, #unitData.fxTable do
			local fxID = unitData.fxTable[i]
			Lups.RemoveParticles(fxID)
		end
		IterableMap.Remove(shieldUnits, unitID)
	end
end

local AOE_MAX = math.pi / 8.0 -- ~0.4

local LOG10 = math.log(10)

local BIASLOG = 2.5
local LOGMUL = AOE_MAX / BIASLOG

local function CalcAoE(dmg, capacity)
	local ratio = dmg / capacity
	local aoe = (BIASLOG + math.log(ratio)/LOG10) * LOGMUL
	return (aoe > 0 and aoe or 0)
end

local AOE_SAME_SPOT = AOE_MAX / 3 -- ~0.13, angle threshold in radians. 

local AOE_SAME_SPOT_COS = math.cos(AOE_SAME_SPOT) -- about 0.99

local HIT_POINT_FOLLOWS_PROJECTILE = false

--x, y, z here are normalized vectors
local function DoAddShieldHitData(unitData, hitFrame, dmg, x, y, z, onlyMove)
	local hitData = unitData.hitData
	local radius = unitData.radius

	local found = false

	for _, hitInfo in ipairs(hitData) do
		if hitInfo then

			local dist = hitInfo.x * x +  hitInfo.y * y + hitInfo.z *  z -- take dot product of normed vectors to get the cosine of their angle
			-- AoE radius in radians

			if dist >= AOE_SAME_SPOT_COS then
				found = true

				if onlyMove then -- usually true when we are bouncing a projectile
					if HIT_POINT_FOLLOWS_PROJECTILE then
						hitInfo.x, hitInfo.y, hitInfo.z = x, y, z
					end
					hitInfo.dmg = dmg
				else -- this is not a bounced projectile, 
					--this vector is very likely normalized :)
					hitInfo.x, hitInfo.y, hitInfo.z = GetSLerpedPoint(x, y, z, hitInfo.x, hitInfo.y, hitInfo.z, dmg, hitInfo.dmg)
					hitInfo.dmg = dmg + hitInfo.dmg
				end

				hitInfo.aoe = CalcAoE(hitInfo.dmg, unitData.capacity)

				break
			end
		end
	end

	if not found then
		local aoe = CalcAoE(dmg, unitData.capacity)
		--Spring.Echo("DoAddShieldHitData", dmg, aoe, mag)
		table.insert(hitData, {
			hitFrame = hitFrame,
			dmg = dmg,
			aoe = aoe,
			x = x,
			y = y,
			z = z,
		})
	end
	hitUpdateNeeded = true
	unitData.needsUpdate = true
end

local DECAY_FACTOR = 0.2
local MIN_DAMAGE = 3

local function GetShieldHitPositions(unitID)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	return (((unitData and unitData.hitData) and unitData.hitData) or nil)
end

local function ProcessHitTable(unitData, gameFrame)
	unitData.needsUpdate = false
	local hitData = unitData.hitData

	--apply decay over time first
	for i = #hitData, 1, -1 do
		local hitInfo = hitData[i]
		if hitInfo then
			local mult = math.exp(-DECAY_FACTOR*(gameFrame - hitInfo.hitFrame))
			--Spring.Echo(gameFrame, hitInfo.dmg, mult, hitInfo.dmg * mult)
			hitInfo.dmg = hitInfo.dmg * mult
			hitInfo.hitFrame = gameFrame

			hitInfo.aoe = CalcAoE(hitInfo.dmg, unitData.capacity)

			if hitInfo.dmg <= MIN_DAMAGE then
			--if hitInfo.aoe <= 0 then
				--Spring.Echo("MIN_DAMAGE", tostring(unitData), i, hitInfo.dmg)
				table.remove(hitData, i)
				hitInfo = nil
			else
				unitData.needsUpdate = true
			end
		end
	end
	if unitData.needsUpdate then
		hitUpdateNeeded = true
		table.sort(hitData, function(a, b) return (((a and b) and a.dmg > b.dmg) or false) end)
	end
	return unitData.needsUpdate
end

local function AddShieldHitData(_, hitFrame, unitID, dmg, dx, dy, dz, onlyMove)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	if unitData and unitData.hitData then
		--Spring.Echo(hitFrame, unitID, dmg)
		local rdx, rdy, rdz = dx - unitData.shieldPos[1], dy - unitData.shieldPos[2], dz - unitData.shieldPos[3]
		local norm = Norm(rdx, rdy, rdz)
		if math.abs(norm - unitData.radius) <= unitData.radius * 0.05 then --only animate projectiles nearby the shield surface
			rdx, rdy, rdz = rdx / norm, rdy / norm, rdz / norm
			-- This seems reasonably fast up to here still
			DoAddShieldHitData(unitData, hitFrame, dmg, rdx, rdy, rdz, onlyMove)
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	RemoveUnit(unitID)
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if shieldUnitDefs[unitDefID] then
		AddUnit(unitID, unitDefID)
	end
end

function gadget:UnitTaken(unitID, unitDefID, newTeam, oldTeam)
	local unitData = IterableMap.Get(shieldUnits, unitID)
	if unitData then
		unitData.allyTeamID = Spring.GetUnitAllyTeam(unitID)
	end
end

function gadget:PlayerChanged()
	myAllyTeamID = spGetMyAllyTeamID()
end

function gadget:GameFrame(n)
	if highEnoughQuality and hitUpdateNeeded and (n % HIT_UPDATE_PERIOD == 0) then
		hitUpdateNeeded = false
		for unitID, unitData in IterableMap.Iterator(shieldUnits) do
			if unitData and unitData.hitData then
				--Spring.Echo(n, unitID, unitData.unitID)
				local phtRes = ProcessHitTable(unitData, n)
				hitUpdateNeeded = hitUpdateNeeded or phtRes
			end
		end
	end

	if n % LOS_UPDATE_PERIOD == 0 then
		local _, fullview = spGetSpectatingState()
		for unitID, unitData in IterableMap.Iterator(shieldUnits) do
			UpdateVisibility(unitID, unitData, fullview)
		end
	end
end

function gadget:Initialize(n)
	if not Lups then
		Lups = GG.Lups
		LupsAddParticles = Lups.AddParticles
	end

	shieldUnitDefs = include("LuaRules/Configs/lups_shield_fxs.lua")
	highEnoughQuality = true--(Lups.Config.quality or 2) >= 3 --Require High(or Ultra?) quality to render hit positions
	--highEnoughQuality = false

	if highEnoughQuality then
		gadgetHandler:AddSyncAction("AddShieldHitDataHandler", AddShieldHitData)
		GG.GetShieldHitPositions = GetShieldHitPositions
	end

	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitFinished(unitID, unitDefID)
	end
end

function gadget:Shutdown()
	if highEnoughQuality then
		gadgetHandler:RemoveSyncAction("AddShieldHitDataHandler", AddShieldHitData)
		GG.GetShieldHitPositions = nil
	end

	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitDestroyed(unitID, unitDefID)
	end
end
