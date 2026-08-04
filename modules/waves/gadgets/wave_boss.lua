local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Wave Boss",
		desc = "Referees every director's boss fight: resistance, the stagger bank, the shared health bar",
		author = "Damgam, Beyond All Reason",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		-- Above the flavor gadgets: their damage modifiers apply first, and
		-- the boss's own arithmetic is the last word on what a boss takes.
		layer = 10,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local BossReferee = VFS.Include("modules/waves/lib/boss_referee.lua")

local referees = {} ---@type table<string, table> director name -> referee
local cycles = {} ---@type table<string, integer>
local bossHost = {} ---@type table<integer, string> bossID -> director name
local staggerMultiplier = {} ---@type table<integer, number>
for defID, unitDef in ipairs(UnitDefs) do
	staggerMultiplier[defID] = tonumber(unitDef.customParams.bossStaggerMultiplier) or 1
end

local HOT_CALLINS = { "GameFrame", "UnitPreDamaged", "UnitDamaged" }
local hot = {}

---Install once and leave installed: unhooking from inside a callin is how
---the handler ends up calling a nil.
local function installCallins()
	for _, name in ipairs(HOT_CALLINS) do
		if gadget[name] == nil then
			gadget[name] = hot[name]
			gadgetHandler:UpdateCallIn(name)
		end
	end
end

local function radiation(x, y, z, spread, count)
	for _ = 1, count do
		local px = x + math.random(-spread, spread)
		local pz = z + math.random(-spread, spread)
		if GG.SpawnEnvironmentalLightning then
			GG.SpawnEnvironmentalLightning("scavradiation", px, y + 100, pz)
		else
			Spring.SpawnCEG("scavradiation-lightning", px, y + 100, pz, 0, 0, 0)
		end
	end
end

---@param host table a GG.Waves.Hosts() view
---@return table referee
local function refereeFor(host)
	local referee = referees[host.name]
	if referee == nil then
		referee = BossReferee.New({
			resistanceMult = host.params.bossResistanceMult,
			stagger = host.params.bossStagger,
			staggerDivisor = host.boss.staggerDivisor,
			expectedBosses = host.boss.count,
		})
		referees[host.name] = referee
		cycles[host.name] = host.cycle
	end
	if cycles[host.name] ~= host.cycle then
		cycles[host.name] = host.cycle
		referee.policy.resistanceMult = host.params.bossResistanceMult
		referee.policy.stagger = host.params.bossStagger
		referee.NextCycle()
		Spring.SetGameRulesParam(host.names.bossHealth, 0)
	end
	return referee
end

---@param host table
---@param referee table
local function tick(host, referee)
	for bossID in pairs(host.bossIDs) do
		if bossHost[bossID] == nil then
			bossHost[bossID] = host.name
			referee.Track(bossID)
		end
	end
	local alive = 0
	for _ in pairs(host.bossIDs) do
		alive = alive + 1
	end
	if alive == 0 and next(referee.statuses) == nil then
		return
	end

	local stagger = referee.TickStagger()
	if stagger then
		for bossID in pairs(host.bossIDs) do
			if stagger.active then
				local x, y, z = Spring.GetUnitPosition(bossID)
				Spring.AddUnitDamage(bossID, 0, 1600000)
				Spring.SetUnitHealth(bossID, { paralyze = 16000000 })
				radiation(x, y, z, stagger.down and 1000 or 500, stagger.down and 50 or 10)
			else
				Spring.SetUnitHealth(bossID, { paralyze = 0 })
			end
		end
		Spring.SetGameRulesParam(host.names.bossStaggerPercentage, stagger.percent)
		Spring.SetGameRulesParam(host.names.bossStaggerActive, stagger.active)
	end

	local percent = referee.UpdateHealth(function(bossID)
		return Spring.GetUnitHealth(bossID)
	end)
	Spring.SetGameRulesParam(host.names.bossHealth, percent)
	Spring.SetGameRulesParam("pveBossInfo", Json.encode(referee.Info()))

	if host.hooks.onBossTick then
		for bossID in pairs(host.bossIDs) do
			host.hooks.onBossTick(bossID, host.state, stagger ~= nil and stagger.active)
		end
	end
end

hot.GameFrame = function(_, n)
	if n % 30 ~= 16 or GG.Waves == nil then
		return
	end
	for _, host in ipairs(GG.Waves.Hosts()) do
		if host.boss ~= nil then
			tick(host, refereeFor(host))
		end
	end
end

hot.UnitPreDamaged = function(_, unitID, _, _, damage, _, weaponID, _, attackerID, attackerDefID)
	local name = bossHost[unitID]
	if name ~= nil then
		local referee = referees[name]
		local host = GG.Waves and GG.Waves.Host(name)
		local taken, notify = referee.Incoming(damage, weaponID, attackerDefID, staggerMultiplier[attackerDefID])
		if notify and host and host.events.toLuaUI then
			SendToUnsynced(
				"WaveEvent",
				host.events.toLuaUI,
				(host.events.bossKind or "boss") .. "Resistance",
				attackerDefID
			)
		end
		if referee.stagger and referee.stagger.active then
			local x, y, z = Spring.GetUnitPosition(unitID)
			radiation(x, y, z, 500, 1)
		end
		return taken, 1
	end
	if attackerID and bossHost[attackerID] then
		return referees[bossHost[attackerID]].Outgoing(damage), 1
	end
	return damage, 1
end

hot.UnitDamaged = function(_, unitID, _, unitTeam, damage, _, _, _, _, _, attackerTeam)
	local name = bossHost[unitID]
	if name ~= nil and attackerTeam and attackerTeam ~= unitTeam then
		referees[name].Tally(attackerTeam, damage)
	end
end

function gadget:UnitDestroyed(unitID)
	local name = bossHost[unitID]
	if name == nil then
		return
	end
	bossHost[unitID] = nil
	referees[name].Died(unitID)
	local host = GG.Waves and GG.Waves.Host(name)
	if host then
		local percent = referees[name].UpdateHealth(function(bossID)
			return Spring.GetUnitHealth(bossID)
		end)
		Spring.SetGameRulesParam(host.names.bossHealth, percent)
		Spring.SetGameRulesParam("pveBossInfo", Json.encode(referees[name].Info()))
	end
end

function gadget:Initialize()
	installCallins()
end
