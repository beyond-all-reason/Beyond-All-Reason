
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Explosion Spawner",
		desc = "Spawns units using an explosion as a trigger.",
		author = "KDR_11k (David Becker), lurker",
		date = "2007-11-18",
		license = "None",
		layer = 50,
		enabled = true
	}
end

-- unit defs guide
-- spawns_name = the string of the unit you want to spawn. If you list multiple, also include a spawns_mode entry example: "CORAK ARMPW CORJUGG"
-- spawns_surface = sting. SEA and LAND are the only supported options
-- spawns_mode = if you have multiple entries, use one of these strings: "random" "random_locked" or "sequential"
-- spawns_expire = how long before your unit is destroyed in seconds
-- spawns_ceg = use to spawn an arbitrary ceg in addition to the explosion effect used in the weapondefs. uses Spring.SpawnCEG()
-- spawns_stun = a number, use it to define how long a unit will be stunned for after landing.


local spCreateFeature         = Spring.CreateFeature
local spCreateUnit            = Spring.CreateUnit
local spDestroyUnit           = Spring.DestroyUnit
local spGetGameFrame          = Spring.GetGameFrame
local spGetProjectileDefID    = Spring.GetProjectileDefID
local spGetProjectileTeamID   = Spring.GetProjectileTeamID
local spGetUnitShieldState    = Spring.GetUnitShieldState
local spGiveOrderToUnit       = Spring.GiveOrderToUnit
local spSetFeatureDirection   = Spring.SetFeatureDirection
local spSetUnitRulesParam     = Spring.SetUnitRulesParam
local spSpawnCEG 			  = Spring.SpawnCEG
local spGetUnitHealth 		  = Spring.GetUnitHealth
local spSetUnitHealth		  = Spring.SetUnitHealth
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetGroundHeight       = Spring.GetGroundHeight
local spGetUnitTeam           = Spring.GetUnitTeam
local spSetUnitDirection      = Spring.SetUnitDirection
local spAddUnitImpulse        = Spring.AddUnitImpulse
local spEcho                  = Spring.Echo

local mapsizeX 				  = Game.mapSizeX
local mapsizeZ 				  = Game.mapSizeZ

local random = math.random
local sin    = math.sin
local cos    = math.cos
local mathMax = math.max
local mathSqrt = math.sqrt
local stringFind = string.find
local strSplit = string.split

local GAME_SPEED = Game.gameSpeed
local TAU = 2 * math.pi
local PRIVATE = { private = true }
local CMD_WAIT = CMD.WAIT
local EMPTY_TABLE = {}

local noCreate = false

local spawnDefs = {}
local shieldCollide = {}
local wantedList = {}

-- using a bunch of ([index] = number) tables instead of one ([index] = {number, number}) to reduce subtable allocations
local expireList = {} -- [index] = frame
local expireID = {} -- [index] = unitID
local expireByID = {} -- [unitID] = index
local expireCount = 0

local spawnList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
local spawnCount = 0
local spawnNames = {}
local minWaterDepth = -12 --calibrated off of the armpw's (minimum found) maxwaterdepth value

for weaponDefID = 1, #WeaponDefs do
	local wdcp = WeaponDefs[weaponDefID].customParams
	if wdcp.spawns_name then
		local unitNames = strSplit(wdcp.spawns_name)
		spawnDefs[weaponDefID] = {
			name = wdcp.spawns_name,
			unitNames = unitNames, -- pre-split for performance
			expire = wdcp.spawns_expire and (tonumber(wdcp.spawns_expire) * GAME_SPEED),
			feature = wdcp.spawns_feature,
			surface = wdcp.spawns_surface,
			mode = wdcp.spawns_mode,
			ceg = wdcp.spawns_ceg,
			stun = wdcp.spawns_stun,
		}
		if wdcp.spawn_blocked_by_shield then
			shieldCollide[weaponDefID] = WeaponDefs[weaponDefID].damages[Game.armorTypes.shield]
		end
		wantedList[#wantedList + 1] = weaponDefID
	end
end

local scavengerAITeamID = 999
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengerAITeamID = i - 1
		break
	end
end

function gadget:Explosion_GetWantedWeaponDef()
	return wantedList
end

local function SpawnUnit(spawnData)
	local spawnDef = spawnData.spawnDef
	if spawnDef then
		if spawnDef.feature then
			local featureID = spCreateFeature(spawnDef.name, spawnData.x, spawnData.y, spawnData.z, 0, spawnData.teamID)
			if not featureID then
				return
			end

			local rot = random() * TAU
			spSetFeatureDirection(featureID, cos(rot), 0, sin(rot))
		else
			-- Early validation checks
			local x, z = spawnData.x, spawnData.z
			if x <= 0 or x >= mapsizeX or z <= 0 or z >= mapsizeZ then
				return -- Out of bounds
			end
			
			local validSurface = false
			local y = spGetGroundHeight(x, z)
			
			if not spawnDef.surface then
				validSurface = true
			elseif spawnData.y < mathMax(y+32, 32) then
				local surface = spawnDef.surface
				if stringFind(surface, "LAND", 1, true) and y > minWaterDepth then
					validSurface = true
				elseif stringFind(surface, "SEA", 1, true) and y <= 0 then
					validSurface = true
				end
			end

			if not validSurface then
				return
			end

			-- Cache owner/weapon lookup
			local ownerID = spawnData.ownerID
			local weaponDefID = spawnData.weaponDefID
			local weaponSpawnData = ownerID and weaponDefID and spawnNames[ownerID] and spawnNames[ownerID].weapon[weaponDefID]
			
			local spawnUnitName
			if weaponSpawnData then
				local mode = spawnDef.mode
				if mode == "random" then
					local randomUnit = random(#weaponSpawnData.names)
					spawnUnitName = weaponSpawnData.names[randomUnit]
				elseif mode == "sequential" then
					local unitNumber = weaponSpawnData.unitSequence
					spawnUnitName = weaponSpawnData.names[unitNumber]
					local namesCount = #weaponSpawnData.names
					if unitNumber < namesCount then
						weaponSpawnData.unitSequence = unitNumber + 1
					else
						weaponSpawnData.unitSequence = 1
					end
				elseif mode == "random_locked" then
					spawnUnitName = weaponSpawnData.names[weaponSpawnData.unitSequence]
				else
					spawnUnitName = weaponSpawnData.names[1]
				end
			else
				-- Fallback: use pre-split names
				spawnUnitName = spawnDef.unitNames and spawnDef.unitNames[1]
			end
			
			if not spawnUnitName or not UnitDefNames[spawnUnitName] then
				spEcho('INVALID UNIT NAME IN UNIT EXPLOSION SPAWNER', spawnUnitName)
				return
			end
			
			local unitID = spCreateUnit(spawnUnitName, x, spawnData.y, z, 0, spawnData.teamID)
			if not unitID then
				return -- Unit limit hit
			end

			if spawnDef.ceg then
				spSpawnCEG(spawnDef.ceg, x, spawnData.y, z, 0,0,0)
			end

			if spawnDef.stun then
				local maxHealth = select(2, spGetUnitHealth(unitID))
				local paralyzeTime = maxHealth + ((maxHealth/30)*spawnDef.stun)
				spSetUnitHealth(unitID, {paralyze = paralyzeTime })
			end

			if ownerID then
				spSetUnitRulesParam(unitID, "parent_unit_id", ownerID, PRIVATE)
				
				local ownx, owny, ownz = spGetUnitPosition(ownerID)
				if ownx then
					local dx = (x - ownx)
					local dz = (z - ownz)
					local l = mathSqrt((dx*dx) + (dz*dz))
					dx = dx/l
					dz = dz/l
					spSetUnitDirection(unitID, dx, 0, dz)
					spAddUnitImpulse(unitID, dx, 0.5, dz, 1.0)
				end
			end

			if spawnDef.expire then
				expireCount = expireCount + 1
				expireByID[unitID] = expireCount
				expireID[expireCount] = unitID
				local currentFrame = spGetGameFrame()
				if spGetUnitTeam(unitID) ~= scavengerAITeamID then
					expireList[expireCount] = currentFrame + spawnDef.expire
				else
					expireList[expireCount] = currentFrame + 99999
				end
			end

			-- Force a slowupdate to make the unit act immediately
			spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY_TABLE, 0)
			spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY_TABLE, 0)


		end
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
	-- Catch units that are expirable right before they die, so they don't create wreck on death.
	if expireByID[unitID] then
		-- Cache health call to avoid calling twice
		local health = spGetUnitHealth(unitID)
		if health and damage and damage > health then
			if attackerID then
				Spring.DestroyUnit(unitID, true, false, attackerID)
			else
				Spring.DestroyUnit(unitID, true)
			end
		end
	end

end

function gadget:Initialize()
	for i = 1, #wantedList do
		Script.SetWatchExplosion(wantedList[i], true)
	end
end

function gadget:Explosion(weaponDefID, x, y, z, ownerID, proID)
	if noCreate then
		noCreate = false
		return
	end

	if spawnDefs[weaponDefID] then
		local spawnDef = spawnDefs[weaponDefID] -- guaranteed not nil by Explosion_GetWantedWeaponDef
		local teamID = spGetProjectileTeamID(proID)

		-- Don't let awakening children embrace the glory of their birthright
		-- i.e. relegate spawn to GameFrame not to be damaged by the very explosion that bore them
		spawnCount = spawnCount + 1
		local spawnData = spawnList[spawnCount] or {}
		spawnData.spawnDef = spawnDef
		spawnData.x = x
		spawnData.y = y
		spawnData.z = z
		spawnData.ownerID = ownerID
		spawnData.teamID = teamID
		spawnData.weaponDefID = weaponDefID
		spawnList[spawnCount] = spawnData
	end
end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile)
	if not proID or proID < 0 then -- beamlasers; nil in older engines and -1 in more recent
		return
	end

	local proDefID = spGetProjectileDefID(proID)
	local shieldDmg = shieldCollide[proDefID]
	if not shieldDmg then
		return
	end

	local shieldOn, shieldCharge = spGetUnitShieldState(shieldCarrierUnitID)
	if shieldCharge < shieldDmg then
		return true
	end

	noCreate = true -- not a per-projectile map because Explosion() is guaranteed to follow
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]
	local weaponList = unitDef.weapons
	local weaponCount = #weaponList

	for i = 1, weaponCount do
		local weapon = weaponList[i]
		local weaponDefID = weapon.weaponDef
		if weaponDefID and spawnDefs[weaponDefID] then

			local spawnDef = spawnDefs[weaponDefID]
			if not spawnNames[unitID] then
			    spawnNames[unitID] = {
			        weapon = {}
			    }
			end
			if spawnNames[unitID] then
    			-- Use pre-split unitNames from spawnDef instead of splitting on every unit creation
    			spawnNames[unitID].weapon[weaponDefID] = {
    			    names = spawnDef.unitNames,
    			    unitSequence = 1,
    			}
    			if spawnDef.mode == "random_locked" then
    			    spawnNames[unitID].weapon[weaponDefID].unitSequence = random(#spawnNames[unitID].weapon[weaponDefID].names)
    			end
		    end

		end
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	-- Clean up spawn names
	if spawnNames[unitID] then
	    spawnNames[unitID] = nil
	end

	-- Clean up expire tracking
	local index = expireByID[unitID]
	if not index then
		return
	end

	local lastUnitID = expireID[expireCount]

	-- Swap with last element for O(1) deletion
	expireList[index] = expireList[expireCount]
	expireID[index] = lastUnitID
	expireByID[lastUnitID] = index
	expireByID[unitID] = nil
	expireCount = expireCount - 1

	-- last element not nil'd on purpose
	-- no point wasting time doing that as the array won't shrink anyway
end

function gadget:GameFrame(f)
	-- Cache spawnCount to avoid repeated table lookups
	local localSpawnCount = spawnCount
	if localSpawnCount > 0 then
		for i = 1, localSpawnCount do
			SpawnUnit(spawnList[i])
			-- NB: no subtable deallocation, they are reused to avoid having to alloc them again anyway
		end
		spawnCount = 0
	end

	if f % GAME_SPEED ~= 0 then
		return
	end

	-- Cache expireCount for loop optimization
	local localExpireCount = expireCount
	local i = 1
	while i <= localExpireCount do -- not for-loop because Destroy decrements count
		if expireList[i] < f then
			spDestroyUnit(expireID[i], true)
			localExpireCount = expireCount -- update after destruction
		else
			i = i + 1 -- conditional because Destroy replaces current element with last
		end
	end
end
