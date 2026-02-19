local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = 'Area Timed Damage Handler',
        desc = '',
        author = 'Damgam',
        version = '1.0',
        date = '2022',
        license = 'GNU GPL, v2 or later',
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageInterval = 0.7333 ---@type number in seconds, time between procs
local damageLimit = 120 ---@type number in damage per second, soft-cap across multiple areas
local damageExcessRate = 0.2 ---@type number %damage dealt above limit [0, 1)
local damageCegMinScalar = 30 ---@type number in damage, minimum to show hit CEG
local damageCegMinMultiple = 1 / 3 ---@type number in %damage, minimum to show hit CEG
local factoryWaitTime = damageInterval ---@type number in seconds, immunity period for factory-built units

-- Since I couldn't figure out totally arbitrary-radius variable CEGs for fire,
-- we're left with this static list, which is repeated in the expgen def files:
local areaSizePresets = {
    37.5,  46,  54,  63,  75,
      88, 100, 125, 150, 175,
     200, 225, 250, 275, 300,
}

-- Customparams and defaults:
local prefixes = { unit = 'area_ondeath_', weapon = 'area_onhit_' }
local damage, time, range, resistance = 30, 10, 75, "none"

--[[
    customparams = {
        <prefix>_damage     := <number>    The damage done per second
        <prefix>_time       := <number>    Duration of the timed area
        <prefix>_range      := <number>    The radius of the timed area
        <prefix>_damageCeg  := <ceg_name>  Spawns repeatedly for duration
        <prefix>_resistance := <string>    Matched against areadamageresistance
    }
    prefix := area_ondeath | area_onhit  Units use ondeath; weapons use onhit.

    When adding timed areas to existing weapons, you should tweak the weapon's
    explosion ceg, too. There's a short delay between the hit and the area ceg,
    which you can mask/make look nice with an explosion lasting about 0.5 secs.
]]--

--------------------------------------------------------------------------------
-- Cached globals --------------------------------------------------------------

local max                     = math.max
local min                     = math.min
local floor                   = math.floor
local sqrt                    = math.sqrt
local round                   = math.round
local diag                    = math.diag
local normalize               = math.normalize
local stringFind              = string.find
local stringGsub              = string.gsub
local stringLower             = string.lower
local tableInsert             = table.insert
local tableRemove             = table.remove

local spAddUnitDamage         = Spring.AddUnitDamage
local spGetFeatureHealth      = Spring.GetFeatureHealth
local spGetFeaturePosition    = Spring.GetFeaturePosition
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetGroundHeight       = Spring.GetGroundHeight
local spGetGroundNormal       = Spring.GetGroundNormal
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitPosition       = Spring.GetUnitPosition
local spGetUnitsInCylinder    = Spring.GetUnitsInCylinder
local spSetFeatureHealth      = Spring.SetFeatureHealth
local spSpawnCEG              = Spring.SpawnCEG
local spDestroyFeature        = Spring.DestroyFeature

local gameSpeed               = Game.gameSpeed

--------------------------------------------------------------------------------
-- Local variables -------------------------------------------------------------

local frameInterval = round(Game.gameSpeed * damageInterval)
local frameCegShift = round(Game.gameSpeed * damageInterval * 0.5)
local frameWaitTime = round(Game.gameSpeed * factoryWaitTime)

local timedDamageWeapons = {}
local unitDamageImmunity = {}
local featureDamageImmunity = {}
local isFactory = {}

local aliveExplosions = {}
local frameExplosions = {}
local frameNumber = 0

local unitData = {}
local featureData = {}
local unitDamageReset = {}
local featDamageReset = {}

local regexArea, regexRepeat = '%-area%-', '%-repeat'
local regexDigits = "%d+"
local regexCegRadius = regexArea..regexDigits..regexRepeat
local regexCegToRadius = regexArea.."("..regexDigits..")"..regexRepeat

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function getExplosionParams(def, prefix)
    local params = {
        ceg        = def.customParams[ prefix.."ceg"        ],
        damageCeg  = def.customParams[ prefix.."damageceg"  ],
        resistance = def.customParams[ prefix.."resistance" ] or resistance,
        damage     = def.customParams[ prefix.."damage"     ] or damage,
        frames     = def.customParams[ prefix.."time"       ] or time,
        range      = def.customParams[ prefix.."range"      ] or range,
    }
    params.damage = tonumber(params.damage) * (frameInterval/Game.gameSpeed)
    params.frames = tonumber(params.frames) * Game.gameSpeed
    params.frames = round(params.frames / frameInterval) * frameInterval
    params.range = tonumber(params.range)
    params.resistance = stringLower(params.resistance)
    return params
end

local function getNearestCEG(params)
    local ceg, range = params.ceg, params.range

    -- We can't check properties of the ceg, so use the name to compare 'size'. Yes, "that is bad".
    if stringFind(ceg, "-"..floor(range).."-", nil, true) then
        local _, _, _, namedRange = stringFind(ceg, regexCegToRadius, nil, true)
        if tonumber(namedRange) == floor(range) then
            return ceg, range
        end
    end

    -- User tweaks have modified the ceg and/or range; update both to the best-fitting preset.
    local sizeBest, diffBest = math.huge, math.huge
    for ii = 1, #areaSizePresets do
        local size = areaSizePresets[ii]
        local diff = math.abs(range / size - size / range)
        if diff < diffBest then
            diffBest = diff
            sizeBest = size
        end
    end
    if sizeBest < math.huge then
        ceg = stringGsub(ceg, regexDigits, sizeBest, 1)
        return ceg, sizeBest
    end
end

---The ordering of areas, if left arbitrary, penalizes high-damage areas.
---This gives a faster insert when ordering areas from low to high damage
---without favoring newly created areas (effectively penalizing duration).
local function bisectDamage(array, damage, low, high)
    if low < high then
        local indexMiddle = floor((low + high) * 0.5)
        local areaMiddle = array[indexMiddle]
        local damageMiddle = areaMiddle and areaMiddle.damage

        if damageMiddle then
            if damageMiddle == damage then
                return indexMiddle
            else
                if damageMiddle > damage then
                    high = indexMiddle - 1
                else
                    low = indexMiddle + 1
                end
                return bisectDamage(array, damage, low, high)
            end
        end
    end
    return low
end

local function addTimedExplosion(weaponDefID, px, py, pz, attackerID, projectileID)
    local explosion = timedDamageWeapons[weaponDefID]
    local elevation = max(spGetGroundHeight(px, pz), 0)

    if py <= elevation + explosion.range then
        local dx, dy, dz
        if elevation > 0 then
            dx, dy, dz = spGetGroundNormal(px, pz, true)
        else
            dx, dy, dz = 0, 1, 0
        end

        local minY = elevation - explosion.range
        if minY < 0 then
            minY = minY * (1 - dy * 0.5) -- avoid damage to submerged targets
        end

        local area = {
            weapon     = weaponDefID,
            owner      = attackerID,
            x          = px,
            y          = elevation,
            z          = pz,
            ymin       = minY,
            ymax       = elevation + explosion.range,
            dx         = dx,
            dy         = dy,
            dz         = dz,
            ceg        = explosion.ceg,
            range      = explosion.range,
            resistance = explosion.resistance,
            damage     = explosion.damage,
            damageCeg  = explosion.damageCeg,
            endFrame   = explosion.frames + frameNumber,
        }

        local index = bisectDamage(frameExplosions, area.damage, 1, #frameExplosions)
        tableInsert(frameExplosions, index, area)
    end
end

local function spawnAreaCEGs(loopIndex)
    for index, area in pairs(aliveExplosions[loopIndex]) do
        spSpawnCEG(area.ceg, area.x, area.y, area.z, area.dx, area.dy, area.dz)
    end
end

---We prefer the target's midpoint if it is in the radius since the damaged CEGs are easier to see higher up
---on the model, but if it is too high/awkward then the base position is fine, with a small vertical offset.
---@param area table contains the timed area properties
---@param baseX? number unit base position coordinates <x, y, z>
---@param baseY number
---@param baseZ number
---@param midX number unit midpoint position coordinates <x, y, z>
---@param midY number
---@param midZ number
---@return number? hitX reference coordinates <x, y, z>
---@return number? hitY
---@return number? hitZ
local function getAreaHitPosition(area, baseX, baseY, baseZ, midX, midY, midZ)
	if not baseX then
		return
	end

	local radius = area.range

	if midY >= area.ymin and midY <= area.ymax then
		if diag(midX - area.x, midY - area.y, midZ - area.z) <= radius then
			return midX, midY, midZ
		end
	end

	if baseY >= area.ymin and baseY <= area.ymax then
		local dx = baseX - area.x
		local dy = baseY - area.y
		local dz = baseZ - area.z

		if diag(dx, dy, dz) <= radius then
			-- The unit base point is in the area and the mid point is not.
			-- Find the intersection of a ray from mid->base onto the area.
			local rx, ry, rz = normalize(baseX - midX, baseY - midY, baseZ - midZ)

			local a = rx * rx + ry * ry + rz * rz
			local b = (dx * rx + dy * ry + dz * rz) * 2
			local c = dx * dx + dy * dy + dz * dz - radius * radius

			-- We already know the discriminant is positive:
			local discriminant = b * b - 4 * a * c
			local t = (b + sqrt(discriminant)) / (2 * a)

			return
				midX + t * rx,
				midY + t * ry,
				midZ + t * rz
		end
	end
end

---Applies a simple formula to keep damage under a limit when many areas of effect overlap.
---Stronger areas partially ignore the preset limit but not damage accumulation on the target.
---Damage may be reduced enough that the CEG effect for indicating damage should not be shown.
---@param incoming number The area weapon's damage to the target
---@param accumulated number The target's area damage taken in the current interval
---@return number damageDealt
---@return boolean showDamageCeg
local function getLimitedDamage(incoming, accumulated)
    local ignoreLimit = max(0, incoming - damageLimit - accumulated)
    local belowLimit = max(0, min(damageLimit - accumulated, incoming))
    local aboveLimit = incoming - belowLimit - ignoreLimit

	local damageDealt = ignoreLimit + belowLimit + aboveLimit * damageExcessRate

	return damageDealt, damageDealt >= incoming * damageCegMinMultiple or damageDealt >= damageCegMinScalar
end

local function damageTargetsInAreas(timedAreas, gameFrame)
    local length = #timedAreas

    local reset = {}
    local count = 0

    for index = length, 1, -1 do
        local area = timedAreas[index]
        local x, z, radius = area.x, area.z, area.range

        local unitsInRange = spGetUnitsInCylinder(x, z, radius)

        for j = 1, #unitsInRange do
            local unitID = unitsInRange[j]
			local data = unitData[unitID]
            if data and not data.resistances[area.resistance] and data.immuneUntil < gameFrame then
                local hitX, hitY, hitZ = getAreaHitPosition(area, spGetUnitPosition(unitID, true))

				if hitX then
					local damageTaken = data.damageTaken
					if damageTaken == 0 then
						count = count + 1
						reset[count] = data
					end
					local damage, showDamageCeg = getLimitedDamage(area.damage, damageTaken)
					if showDamageCeg then
						spSpawnCEG(area.damageCeg, hitX, hitY, hitZ)
					end
					data.damageTaken = damageTaken + damage
					spAddUnitDamage(unitID, damage, nil, area.owner, area.weapon)
				end
            end
        end
    end

	for _, data in ipairs(unitDamageReset[gameFrame]) do
		data.damageTaken = 0
	end

    unitDamageReset[gameFrame] = nil
    unitDamageReset[gameFrame + gameSpeed] = reset

    reset = {}
    count = 0

    for index = length, 1, -1 do
        local area = timedAreas[index]
        local x, z, radius = area.x, area.z, area.range

        local featuresInRange = spGetFeaturesInCylinder(x, z, radius)

        for j = 1, #featuresInRange do
            local featureID = featuresInRange[j]
			local data = featureData[featureID]

            if data and not data.damageImmune then
                local hitX, hitY, hitZ = getAreaHitPosition(area, spGetFeaturePosition(featureID, true))

                if hitX then
                    local damageTaken = data.damageTaken
                    if damageTaken == 0 then
                        count = count + 1
                        reset[count] = data
                    end
                    local damageDealt, showDamageCeg = getLimitedDamage(area.damage, damageTaken)
                    if showDamageCeg then
                        spSpawnCEG(area.damageCeg, hitX, hitY, hitZ)
                    end
                    local health = spGetFeatureHealth(featureID) - damageDealt
                    if health > 1 then
                        spSetFeatureHealth(featureID, health)
                        data.damageTaken = damageTaken + damageDealt
                    else
                        spDestroyFeature(featureID)
                    end
                end
            end
        end

        if area.endFrame <= gameFrame then
            tableRemove(timedAreas, index)
        end
    end

	for _, data in ipairs(featDamageReset[gameFrame]) do
		data.damageTaken = 0
	end

    featDamageReset[gameFrame] = nil
    featDamageReset[gameFrame + gameSpeed] = reset
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

function gadget:Initialize()
    timedDamageWeapons = {}
    for weaponDefID = 0, #WeaponDefs do
        local weaponDef = WeaponDefs[weaponDefID]
        if weaponDef.customParams and weaponDef.customParams[prefixes.weapon.."ceg"] then
            timedDamageWeapons[weaponDefID] = getExplosionParams(weaponDef, prefixes.weapon)
        end
    end
    for unitDefID, unitDef in ipairs(UnitDefs) do
        if unitDef.customParams[prefixes.unit.."ceg"] then
            local params = getExplosionParams(unitDef, prefixes.unit)
            timedDamageWeapons[WeaponDefNames[unitDef.deathExplosion].id] = params
            timedDamageWeapons[WeaponDefNames[unitDef.selfDExplosion].id] = params
        end
        if unitDef.isFactory then
            isFactory[unitDefID] = true
        end
    end

    -- This simplifies writing tweakdefs to modify area_on[x]_range for balance,
    -- e.g. setting all ranges to 80% their original amount will work correctly.
    for weaponDefID, params in pairs(timedDamageWeapons) do
        if string.find(params.ceg, regexCegRadius, nil, false) then
            local ceg, range = getNearestCEG(params)
            local name = WeaponDefs[weaponDefID].name
            if ceg and range then
                if params.ceg ~= ceg or params.range ~= range then
                    params.ceg = ceg
                    params.range = range
                    Spring.Log(gadget:GetInfo().name, LOG.INFO, 'Set '..name..' to range, ceg = '..range..', '..ceg)
                end
            else
                timedDamageWeapons[weaponDefID] = nil
                Spring.Log(gadget:GetInfo().name, LOG.WARN, 'Removed '..name..' from area timed damage weapons.')
            end
        end
    end

    if not next(timedDamageWeapons) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No timed areas found. Removing gadget.")
        gadgetHandler:RemoveGadget(self)
		return
	end

	for weaponDefID in pairs(timedDamageWeapons) do
		Script.SetWatchExplosion(weaponDefID, true)
	end

    unitDamageImmunity = {}
    local areaDamageTypes = {}
    for weaponDefID, params in pairs(timedDamageWeapons) do
        if params.resistance == nil then
            params.resistance = "none"
        elseif params.resistance ~= "none" then
            areaDamageTypes[params.resistance] = true
        end
    end
    local immunities = { all = areaDamageTypes, none = {} }
    for unitDefID, unitDef in ipairs(UnitDefs) do
        local unitImmunity
        if unitDef.canFly or unitDef.armorType == Game.armorTypes.indestructible then
            unitImmunity = immunities.all
        elseif unitDef.customParams.areadamageresistance == nil then
            unitImmunity = immunities.none
        else
            local resistance = string.lower(unitDef.customParams.areadamageresistance)
            if immunities[resistance] then
                unitImmunity = immunities[resistance]
            else
                unitImmunity = {}
                for damageType in pairs(areaDamageTypes) do
                    if string.find(resistance, damageType, nil, false) then
                        unitImmunity[damageType] = true
                    end
                end
                if not next(unitImmunity) then
                    unitImmunity = immunities.none
                end
                immunities[resistance] = unitImmunity
            end
        end
        unitDamageImmunity[unitDefID] = unitImmunity
    end

    featureDamageImmunity = {}
	for featureDefID, featureDef in ipairs(FeatureDefs) do
		featureDamageImmunity[featureDefID] = featureDef.indestructible or featureDef.geoThermal
	end

	aliveExplosions = {}
	for ii = 1, frameInterval do
		aliveExplosions[ii] = {}
	end

	frameNumber = Spring.GetGameFrame()
	frameExplosions = aliveExplosions[1 + (frameNumber % frameInterval)]
	for frame = frameNumber - 1, frameNumber + gameSpeed do
		unitDamageReset[frame] = {}
		featDamageReset[frame] = {}
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end

	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		gadget:FeatureCreated(featureID)
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, attackerID, projectileID)
    if timedDamageWeapons[weaponDefID] then
        addTimedExplosion(weaponDefID, px, py, pz, attackerID, projectileID)
    end
end

function gadget:GameFrame(frame)
    local indexDamage = 1 + (frame % frameInterval)
    local indexExpGen = 1 + ((frame + frameCegShift) % frameInterval)
    local frameAreas = aliveExplosions[indexDamage]

    spawnAreaCEGs(indexExpGen)
    damageTargetsInAreas(frameAreas, frame)

    frameExplosions = frameAreas
    frameNumber = frame
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	unitData[unitID] = {
		damageTaken = 0,
		immuneUntil = (builderID and isFactory[spGetUnitDefID(builderID)] and frameNumber + frameWaitTime) or 0,
		resistances = unitDamageImmunity[unitDefID],
	}
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	unitData[unitID] = nil
end

function gadget:FeatureCreated(featureID, allyTeam)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	featureData[featureID] = {
		damageTaken = 0,
		damageImmune = featureDamageImmunity[featureDefID],
	}
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	featureData[featureID] = nil
end
