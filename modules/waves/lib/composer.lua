
local Composer = {}

local SUPER_SQUAD_ROLL = 1
local SUPER_SQUAD_LOOKAHEAD = 30
local SUPER_SQUAD_MIN_FLOOR = 10
local SUPER_SQUAD_MAX_FLOOR = 40

---@param entry WaveBucketEntry
---@param anger number
---@param super boolean
---@return boolean
local function inBracket(entry, anger, super)
	if entry.minAnger <= anger and entry.maxAnger >= anger then
		return true
	end
	if not super then
		return false
	end
	return math.max(SUPER_SQUAD_MIN_FLOOR, entry.minAnger - SUPER_SQUAD_LOOKAHEAD) <= anger
		and math.max(SUPER_SQUAD_MAX_FLOOR, entry.maxAnger - SUPER_SQUAD_LOOKAHEAD) >= anger
end

---@param bucket WaveBucketEntry[]|nil
---@param anger number
---@param super boolean widen the bracket (the super-squad roll)
---@param rng WaveRng
---@return WaveBucketEntry|nil
function Composer.Pick(bucket, anger, super, rng)
	if bucket == nil or #bucket == 0 then
		return nil
	end
	local eligible = {}
	for i = 1, #bucket do
		if inBracket(bucket[i], anger, super) then
			eligible[#eligible + 1] = bucket[i]
		end
	end
	if #eligible == 0 then
		return nil
	end
	return eligible[rng(1, #eligible)]
end

---@param surface WaveSurface
---@param air boolean
---@param special boolean
---@return WaveBucketName|nil nil when the surface has no pool (mixed/death ground)
function Composer.BucketFor(surface, air, special)
	if surface ~= "land" and surface ~= "sea" then
		return nil
	end
	local sea = surface == "sea"
	if air then
		if special then
			return sea and "specialAirSea" or "specialAirLand"
		end
		return sea and "basicAirSea" or "basicAirLand"
	end
	if special then
		return sea and "specialSea" or "specialLand"
	end
	return sea and "basicSea" or "basicLand"
end

---@class WaveExpandContext
---@field burrow integer
---@field team integer
---@field spawnChance number
---@field wave integer
---@field rng WaveRng

---squadID counts WITHIN the squad: the drain reads 1 as "start a new squad here", so the counter must restart per squad.
---@param entries WaveQueueEntry[] appended to
---@param squad WaveBucketEntry
---@param ctx WaveExpandContext
---@return integer added
function Composer.Expand(entries, squad, ctx)
	local squadCounter = 0
	for _, slot in ipairs(squad.units) do
		if slot.count and slot.count > 0 then
			for j = 1, slot.count do
				if j == 1 or ctx.rng() <= ctx.spawnChance then
					squadCounter = squadCounter + 1
					entries[#entries + 1] = {
						burrow = ctx.burrow,
						unitName = slot.def,
						team = ctx.team,
						squadID = squadCounter,
						wave = ctx.wave,
					}
				end
			end
		end
	end
	return squadCounter
end

---@class WavePopulationSlot
---@field def UnitDefName
---@field minAnger number
---@field maxAnger number
---@field maxAlive integer

---@class WaveComposeInput
---@field buckets table<WaveBucketName, WaveBucketEntry[]>
---@field populations table<string, WavePopulationSlot[]> ordered lists — pairs order is not a wire value
---@field burrows integer[]
---@field surfaceOf fun(burrowID: integer): WaveSurface
---@field unitDefCount fun(defName: UnitDefName): integer
---@field shape WaveShape
---@field ceiling number how many entries this wave may reach
---@field spawnChance number
---@field spawnMultiplier number
---@field airStartAnger number
---@field techAnger number the raw roster clock — the commander cap reads it
---@field teamCount integer
---@field teamID integer
---@field wave integer
---@field rng WaveRng
---@field populationCounts table<string, integer> how many of each population are already alive
---@field capScale number 1 for waves, 0.5 for the off-wave squads a burrow throws out

---@param input WaveComposeInput
---@param entries WaveQueueEntry[]
---@param burrowID integer
---@param key string which population
---@param claimed table<string, boolean> defs already claimed by this wave
---@param claimedCount integer
---@return integer added
local function tryPopulation(input, entries, burrowID, key, claimed, claimedCount)
	local slots = input.populations[key]
	if slots == nil or #slots == 0 then
		return 0
	end
	local alive = input.populationCounts[key] or 0
	local ceiling = input.teamCount * input.capScale * (input.techAnger * 0.01)
	for _, slot in ipairs(slots) do
		if
			input.rng() <= input.spawnChance
			and input.rng(1, #slots) == 1
			and not claimed[slot.def]
			and slot.minAnger <= input.shape.techAnger
			and slot.maxAnger >= input.shape.techAnger
			and input.unitDefCount(slot.def) < slot.maxAlive
			and alive + claimedCount < ceiling
		then
			claimed[slot.def] = true
			entries[#entries + 1] = {
				burrow = burrowID,
				unitName = slot.def,
				team = input.teamID,
				squadID = 1,
				wave = input.wave,
			}
			return 1
		end
	end
	return 0
end

---@param input WaveComposeInput
---@param entries WaveQueueEntry[]
---@param burrowID integer
---@param withHealers boolean
---@param claims { commanders: table, decoyCommanders: table, commanderCount: integer, decoyCount: integer }
---@return integer added
local function composeForBurrow(input, entries, burrowID, withHealers, claims)
	local added = 0
	local surface = input.surfaceOf(burrowID)
	local airRoll = input.rng(1, 100)
	local specialRoll = input.rng(1, 100)
	local wantsAir = input.shape.techAnger > input.airStartAnger and airRoll <= input.shape.airPercentage
	local wantsSpecial = specialRoll <= input.shape.specialPercentage
	local super = specialRoll <= SUPER_SQUAD_ROLL

	local bucketName = Composer.BucketFor(surface, wantsAir, wantsSpecial)
	if bucketName ~= nil then
		local squad = Composer.Pick(input.buckets[bucketName], input.shape.techAnger, super, input.rng)
		if squad ~= nil then
			added = added
				+ Composer.Expand(entries, squad, {
					burrow = burrowID,
					team = input.teamID,
					spawnChance = input.spawnChance,
					wave = input.wave,
					rng = input.rng,
				})
		end
	end

	-- Healers on the first pass only: one escort per burrow is support, four is a stalemate.
	if withHealers and input.rng() <= input.spawnChance and (surface == "land" or surface == "sea") then
		local healerBucket = surface == "sea" and "healerSea" or "healerLand"
		local healers = Composer.Pick(input.buckets[healerBucket], input.shape.techAnger, false, input.rng)
		if healers ~= nil then
			added = added
				+ Composer.Expand(entries, healers, {
					burrow = burrowID,
					team = input.teamID,
					spawnChance = input.spawnChance,
					wave = input.wave,
					rng = input.rng,
				})
		end
	end

	if input.rng() <= 0.5 then
		local n = tryPopulation(input, entries, burrowID, "commanders", claims.commanders, claims.commanderCount)
		claims.commanderCount = claims.commanderCount + n
		added = added + n
	else
		local n = tryPopulation(input, entries, burrowID, "decoyCommanders", claims.decoyCommanders, claims.decoyCount)
		claims.decoyCount = claims.decoyCount + n
		added = added + n
	end

	return added
end

---The guard matters — a map whose burrows all sit on ground with no bucket
---would otherwise spin forever adding nothing.
---@param input WaveComposeInput
---@return { entries: WaveQueueEntry[], count: integer }
function Composer.ComposeWave(input)
	local entries = {}
	local count = 0
	local loops = 0
	local maxLoops = math.max(1, math.floor(200 * input.spawnMultiplier))
	local claims = { commanders = {}, decoyCommanders = {}, commanderCount = 0, decoyCount = 0 }

	repeat
		loops = loops + 1
		for _, burrowID in ipairs(input.burrows) do
			if input.rng() <= input.spawnChance then
				count = count + composeForBurrow(input, entries, burrowID, loops == 1, claims)
			end
		end
	until count > input.ceiling or loops >= maxLoops

	return { entries = entries, count = count }
end

---@param input WaveComposeInput
---@return { entries: WaveQueueEntry[], count: integer }
function Composer.ComposeOffWave(input)
	local entries = {}
	local claims = { commanders = {}, decoyCommanders = {}, commanderCount = 0, decoyCount = 0 }
	local count = composeForBurrow(input, entries, input.burrows[1], true, claims)
	return { entries = entries, count = count }
end

---@param burrowID integer
---@param defName UnitDefName
---@param count integer
---@param teamID integer
---@param spawnChance number
---@param wave integer
---@param rng WaveRng
---@return WaveQueueEntry[]
function Composer.ComposeNamed(burrowID, defName, count, teamID, spawnChance, wave, rng)
	local entries = {}
	local squadCounter = 0
	for j = 1, count do
		if j == 1 or rng() <= spawnChance then
			squadCounter = squadCounter + 1
			entries[#entries + 1] = {
				burrow = burrowID,
				unitName = defName,
				team = teamID,
				squadID = squadCounter,
				wave = wave,
			}
		end
	end
	return entries
end

return Composer
