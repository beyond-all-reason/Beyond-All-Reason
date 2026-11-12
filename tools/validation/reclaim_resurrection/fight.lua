function gadget:GetInfo()
	return {
		name = "Cancelled reclaim regression",
		desc = "Natural fight/patrol/area commands; no build orders",
		author = "Codex",
		layer = 100000,
		enabled = true,
	}
end
if not gadgetHandler:IsSyncedCode() then
	return
end
local cases = {
	{ name = "fight", unit = "corcom", cmd = CMD.FIGHT },
	{ name = "fight_here", unit = "corcom", cmd = CMD.FIGHT, here = true },
	{ name = "patrol", unit = "corcom", cmd = CMD.PATROL },
	{ name = "nano_fight", unit = "cornanotc", cmd = CMD.FIGHT },
	{ name = "area", unit = "corcom", cmd = CMD.RECLAIM, area = true },
	{ name = "explicit", unit = "corcom", cmd = CMD.RECLAIM },
	{ name = "enemy_rez", unit = "corcom", cmd = CMD.FIGHT, enemy = true },
	{ name = "normal_fight", unit = "corcom", cmd = CMD.FIGHT, norez = true },
}
local function log(...)
	local a = { ... }
	for i = 1, #a do
		a[i] = tostring(a[i])
	end
	Spring.Echo("REZ_TEST|" .. table.concat(a, "|"))
end
local function order(u, c, p)
	Spring.GiveOrderToUnit(u, c, p or {}, 0)
end
function gadget:GameFrame(f)
	if f == 30 then
		for _, u in ipairs(Spring.GetAllUnits()) do
			Spring.DestroyUnit(u, false, true)
		end
		for _, id in ipairs(Spring.GetAllFeatures()) do
			Spring.DestroyFeature(id)
		end
		Spring.LevelHeightMap(512, 512, 6000, 4000, 100)
		for t = 0, 2 do
			Spring.SetTeamResource(t, "ms", 100000)
			Spring.SetTeamResource(t, "es", 100000)
			Spring.SetTeamResource(t, "m", 1000)
			Spring.SetTeamResource(t, "e", 100000)
		end
		for i, c in ipairs(cases) do
			c.x = 1024 + ((i - 1) % 4) * 1280
			c.z = 1024 + math.floor((i - 1) / 4) * 1536
			c.steps = 0
			c.after = 0
			c.repair = 0
			c.feature = assert(Spring.CreateFeature("armfboy_dead", c.x, 100, c.z, 0, 1))
			Spring.SetFeatureResurrect(c.feature, "armfboy", 0)
			c.builder = assert(Spring.CreateUnit(c.unit, c.x - 90, 100, c.z, 0, 0))
			c.rez = assert(Spring.CreateUnit("cornecro", c.x + 90, 100, c.z, 0, c.enemy and 2 or 1))
			order(c.builder, CMD.FIRE_STATE, { 0 })
			order(c.rez, CMD.FIRE_STATE, { 0 })
			log("SETUP", c.name, c.builder, c.rez, c.feature)
		end
	end
	if f == 80 then
		for _, c in ipairs(cases) do
			Spring.SetUnitBuildSpeed(c.builder, 200, 200, 30)
			Spring.SetUnitBuildSpeed(c.rez, 200, 200, 200, 60)
		end
	end
	if f == 90 then
		for _, c in ipairs(cases) do
			if c.area then
				order(c.builder, c.cmd, { c.x, 100, c.z, 150 })
			elseif c.cmd == CMD.RECLAIM then
				order(c.builder, c.cmd, { Game.maxUnits + c.feature })
			else
				order(c.builder, c.cmd, { c.here and c.x - 90 or c.x + 300, 100, c.z })
			end
		end
	end
	if f == 180 then
		for _, c in ipairs(cases) do
			if not c.norez then
				order(c.rez, CMD.RESURRECT, { Game.maxUnits + c.feature })
			end
		end
		log("REZ_START", f)
	end
	if f >= 90 and f % 15 == 0 then
		for _, c in ipairs(cases) do
			local q = Spring.GetUnitCommands(c.builder, -1)
			local seq = {}
			for _, v in ipairs(q) do
				seq[#seq + 1] = v.id .. ":" .. v.options.coded
			end
			local task, target = Spring.GetUnitWorkerTask(c.builder)
			local rt, rp = Spring.GetUnitWorkerTask(c.rez)
			if f % 30 == 0 then
				log(
					"STATE",
					f,
					c.name,
					table.concat(seq, ","),
					task or "none",
					rt or "none",
					c.steps,
					c.after,
					c.repair
				)
			end
		end
	end
	if f == 600 then
		local mode = Spring.GetModOptions().experimental_reclaim_resurrection
		for _, c in ipairs(cases) do
			log("RESULT", c.name, c.steps, c.after, c.repair)
			if mode == "first" or mode == "reclaim" then
				assert(c.after > 0, c.name .. ": first reclaimer stopped")
				if not c.enemy and not c.norez then
					assert(c.repair == 0, c.name .. ": losing rez worked")
				end
			elseif mode == "resurrect" and not c.enemy and not c.norez then
				assert(c.after == 0 and c.repair > 0, c.name .. ": rez priority failed")
			end
		end
		log("DIAG_DONE")
	end
end
function gadget:AllowFeatureBuildStep(u, t, id, d, part)
	for _, c in ipairs(cases) do
		if c.feature == id then
			if u == c.builder and part < 0 then
				c.steps = c.steps + 1
				if Spring.GetGameFrame() >= 210 then
					c.after = c.after + 1
				end
				if Spring.GetGameFrame() >= 180 and Spring.GetGameFrame() < 220 then
					log("STEP", Spring.GetGameFrame(), c.name, part, Spring.GetUnitCurrentCommand(u))
				end
			elseif u == c.rez and part > 0 then
				c.repair = c.repair + 1
			end
		end
	end
	return true
end
function gadget:UnitCmdDone(u, d, t, cmd, p, o)
	if cmd == CMD.RECLAIM then
		for _, c in ipairs(cases) do
			if c.builder == u then
				log("RECLAIM_DONE", Spring.GetGameFrame(), c.name, o.coded)
			end
		end
	end
end
