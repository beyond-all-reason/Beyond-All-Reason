-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {
		name = "Portal worlds tests",
		desc = "Opt-in BAR portal fixtures",
		author = "Codex",
		license = "GPL v2 or later",
		layer = 10000,
		enabled = true,
	}
end
local options = Spring.GetModOptions()
if options.portal_worlds_test ~= "four" and options.portal_worlds_test ~= "baseline" then
	return false
end
if not gadgetHandler:IsSyncedCode() then
	function gadget:Update()
		if Spring.GetGameRulesParam("portal_test_done") == 1 then
			Spring.SendCommands("quitforce")
		end
	end
	return
end
local checks, failures = 0, 0
---@type table<string, UnitID>
local units = {}
---@type UnitID[]
local approach = {}
---@type {x: number, y: number, z: number}?
local loss
---@type UnitID?
local gate
---@type {x: number, z: number}?
local target
---@type number
local areaHealth = 0
---@param id UnitID
---@return number x
---@return number y
---@return number z
local function Position(id)
	local x, y, z = Spring.GetUnitPosition(id)
	assert(x and y and z, "Fixture unit has no position: " .. id)
	return x, y, z
end
local function Check(key, value, detail)
	checks = checks + 1
	if not value then
		failures = failures + 1
	end
	Spring.Echo(
		"[BAR_PORTAL_TEST] ASSERT " .. key .. " pass=" .. tostring(not not value) .. " " .. tostring(detail or "")
	)
end
local function Commander(team)
	for _, id in ipairs(Spring.GetTeamUnits(team) or {}) do
		if UnitDefs[Spring.GetUnitDefID(id)].customParams.iscommander then
			return id
		end
	end
end
local function Spawn(name, x, z, team, air)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z) + (air and 150 or 0), z, 0, team)
	assert(id, "Fixture could not spawn " .. name)
	Spring.SetUnitHealth(id, { paralyze = 0 })
	Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0)
	return id
end
local function Arrived(id, region)
	local x, y, z = Position(id)
	return GG.PortalWorlds.home[id] == region and GG.PortalWorlds.world.Region(x, z) == region
end
local function QueueStays(id, region)
	for _, order in ipairs(Spring.GetUnitCommands(id, -1)) do
		if
			order.params
			and #order.params >= 3
			and GG.PortalWorlds.world.Region(order.params[1], order.params[3]) ~= region
		then
			return false
		end
	end
	return true
end
function gadget:GameFrame(f)
	if options.portal_worlds_test == "baseline" then
		if f == 180 then
			Check("ordinary_portal_rules_absent", GG.PortalWorlds == nil and GG.PortalIsolation == nil)
			Check("ordinary_two_commanders", Commander(0) and Commander(1))
			Spring.SetGameRulesParam("portal_test_done", 1)
		end
		return
	end
	local portal = GG.PortalWorlds
	if not portal then
		if f == 180 then
			Check("rules_loaded", false)
			Spring.SetGameRulesParam("portal_test_done", 1)
		end
		return
	end
	local world = portal.world
	if f == 150 then
		Check("four_regions", #world.regions == 4)
		Check("initially_closed", Spring.GetGameRulesParam("portal_open") == 0)
		for _, entry in ipairs(world.teams) do
			local id = Commander(entry.team)
			local x, z
			local y
			-- Preserve all three return values; Lua's and-expression keeps only one.
			if id then
				x, _, z = Position(id)
			end
			Check("commander_home_" .. entry.team, id and world.Region(x, z) == entry.region)
		end
	elseif f == 180 then
		local id = assert(Commander(1))
		local x, y, z = Position(id)
		loss = { x = x, y = y, z = z }
		Spring.SetUnitHealth(id, 1)
		Spring.AddUnitDamage(id, 100000, 0, Commander(0))
	elseif f == 240 then
		local loss = assert(loss, "Commander death was not captured")
		Check("commander_loss_opened", portal.openEdges[1])
		local mouth = portal.mouths[1] and portal.mouths[1][1]
		if not mouth then
			Spring.SetGameRulesParam("portal_test_done", 1)
			return
		end
		Check("mouth_at_death", math.abs(mouth.x - loss.x) < 1 and math.abs(mouth.z - loss.z) < 1)
		for id, data in pairs(portal.beacons) do
			if data.region == 1 then
				gate = id
			end
		end
		Check("portal_is_neutral", gate and Spring.GetUnitNeutral(gate))
		local r = world.regions[2]
		target = { x = (r.x0 + r.x1) / 2 + 400, z = (r.z0 + r.z1) / 2 + 100 }
		for _, name in ipairs({ "nearby", "move", "fight", "attack", "click", "air", "cancel", "ui" }) do
			units[name] = Spawn(name == "air" and "armpeep" or "armflea", mouth.x + 100, mouth.z + 60, 0, name == "air")
		end
		approach = {}
		for i = 1, 8 do
			local id = Spawn("armflea", mouth.x + 800 + (i % 4) * 40, mouth.z - 500 - math.floor(i / 4) * 40, 0)
			approach[i] = id
			Spring.SetGameRulesParam("portal_test_approach_" .. i, id)
			local x, _, z = Position(id)
			Check("group_starts_far_" .. i, (x - mouth.x) ^ 2 + (z - mouth.z) ^ 2 > 700 ^ 2)
		end
		Spring.SetGameRulesParam("portal_test_ui", units.ui)
		Spring.SetGameRulesParam("portal_test_gate", gate)
		units.transport = Spawn("armatlas", mouth.x + 80, mouth.z + 40, 0, true)
		units.cargo = Spawn("armflea", mouth.x + 80, mouth.z + 40, 0)
		Spring.UnitAttach(units.transport, units.cargo, 0)
		units.carrier = Spawn("legvcarry", mouth.x + 110, mouth.z + 80, 0)
		units.foreign = Spawn("armllt", target.x + 500, target.z, 2)
	elseif f == 270 then
		local loss = assert(loss)
		local target = assert(target)
		Check("no_proximity_travel", portal.home[units.nearby] == 1)
		for name, cmd in pairs({
			move = CMD.MOVE,
			fight = CMD.FIGHT,
			attack = CMD.ATTACK,
			air = CMD.MOVE,
			transport = CMD.MOVE,
			carrier = CMD.MOVE,
		}) do
			local id = units[name]
			Spring.GiveOrderToUnit(id, cmd, { target.x, Spring.GetGroundHeight(target.x, target.z), target.z }, 0)
			Spring.GiveOrderToUnit(id, CMD.MOVE, { loss.x, loss.y, loss.z }, CMD.OPT_SHIFT)
		end
		Spring.GiveOrderToUnit(units.click, CMD.ATTACK, { gate }, 0)
		Spring.GiveOrderToUnit(units.cancel, CMD.MOVE, { target.x, 0, target.z }, 0)
		Spring.GiveOrderToUnit(units.cancel, CMD.STOP, {}, 0)
	elseif f == 285 then
		local target = assert(target)
		local retained = false
		for _, order in ipairs(Spring.GetUnitCommands(units.move, -1)) do
			if
				order.id == CMD.MOVE
				and order.params
				and order.params[1] == target.x
				and order.params[3] == target.z
			then
				retained = true
			end
		end
		Check("destination_order_retained", retained)
	elseif f == 390 then
		for _, name in ipairs({ "move", "fight", "attack", "click", "air", "transport", "cargo", "carrier" }) do
			local id = units[name]
			Check("arrived_" .. name, Arrived(id, 2), portal.home[id])
			Check("queue_clean_" .. name, QueueStays(id, 2))
		end
		local droneCount = 0
		for _, id in ipairs(Spring.GetTeamUnits(0) or {}) do
			if UnitDefs[Spring.GetUnitDefID(id)].name == "legdrone" then
				droneCount = droneCount + 1
				Check("carrier_drone_arrived_" .. droneCount, Arrived(id, 2))
			end
		end
		Check("carrier_roster_present", droneCount >= 3, droneCount)
		Check("cancel_stayed", portal.home[units.cancel] == 1)
		Check("nearby_still_home", portal.home[units.nearby] == 1)
		local health = Spring.GetUnitHealth(units.foreign)
		Spring.AddUnitDamage(units.foreign, 250, 0, units.nearby)
		Check("foreign_damage_blocked", Spring.GetUnitHealth(units.foreign) == health)
		Spring.AddUnitDamage(units.foreign, 250, 0, units.move)
		Check("local_damage_works", Spring.GetUnitHealth(units.foreign) < health)
		local gateHealth = Spring.GetUnitHealth(assert(gate))
		Spring.AddUnitDamage(assert(gate), 250, 0, units.nearby)
		Check("portal_damage_blocked", Spring.GetUnitHealth(assert(gate)) == gateHealth)
	elseif f == 420 then
		local r = world.regions[1]
		units.shieldLocal = Spawn("armgate", r.x1 - 32, 2000, 0)
		units.shieldForeign = Spawn("armgate", world.regions[2].x0 + 16, 2000, 2)
		Spring.SetUnitShieldState(units.shieldLocal, 1, true, 5000)
		Spring.SetUnitShieldState(units.shieldForeign, 1, true, 5000)
		units.areaTarget = Spawn("armsolar", 3000, 1000, 2)
		Spring.SetUnitMaxHealth(units.areaTarget, 100000)
		Spring.SetUnitHealth(units.areaTarget, 100000)
		---@type WeaponDefID?
		local weapon
		for id, wd in pairs(WeaponDefs) do
			if
				tonumber(wd.customParams.area_onhit_damage or 0) > 0
				and tonumber(wd.customParams.area_onhit_range or 0) <= 300
			then
				weapon = id
				break
			end
		end
		Check("timed_area_weapon_present", weapon ~= nil)
		if weapon then
			local x, y, z = Position(units.areaTarget)
			local projectile = assert(Spring.SpawnProjectile(weapon, {
				pos = { x, y + 1, z },
				speed = { 0, 0, 0 },
				owner = units.nearby,
				ttl = 300,
				gravity = 0,
				team = 0,
			}))
			Spring.SetProjectileCollision(projectile)
		end
	elseif f == 430 then
		areaHealth = assert(Spring.GetUnitHealth(units.areaTarget))
		Spring.GiveOrderToUnit(units.nearby, GameCMD.PORTAL_TRAVEL, { 1 }, 0)
	elseif f == 450 then
		local sx, sy, sz = GG.Shields.GetUnitShieldPosition(units.shieldForeign)
		Check("custom_shields_registered", sx ~= nil)
		if sx then
			local x = world.regions[1].x1 - 8
			local shields = GG.Shields.GetCoveringShieldUnits(x, sy, sz, 1, true)
			local localPresent, foreignPresent = false, false
			for _, id in ipairs(shields) do
				localPresent = localPresent or id == units.shieldLocal
				foreignPresent = foreignPresent or id == units.shieldForeign
			end
			Check("local_shield_query_works", localPresent)
			Check("foreign_shield_query_excluded", not foreignPresent)
		end
	elseif f == 550 then
		Check("real_ui_click_arrived", Arrived(units.ui, 2))
	elseif f == 600 then
		Check("timed_area_owner_travelled", portal.home[units.nearby] == 2)
		Check("timed_area_keeps_origin_after_transit", Spring.GetUnitHealth(units.areaTarget) < areaHealth)
		for _, team in ipairs({ 3, 5, 7 }) do
			local id = Commander(team)
			if id then
				Spring.DestroyUnit(id, false, true)
			end
		end
	elseif f == 660 then
		for i in ipairs(world.connections) do
			Check("opened_edge_" .. i, portal.openEdges[i])
		end
	elseif f == 1100 then
		for i, id in ipairs(approach) do
			Check("group_walked_and_arrived_" .. i, Arrived(id, 2))
		end
	elseif f == 1500 then
		Spring.Echo("[BAR_PORTAL_TEST] DONE checks=" .. checks .. " failures=" .. failures)
		Spring.SetGameRulesParam("portal_test_failures", failures)
		Spring.SetGameRulesParam("portal_test_done", 1)
	end
end
