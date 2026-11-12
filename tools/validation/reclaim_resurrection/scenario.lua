function gadget:GetInfo()
	return {
		name = "Reclaim resurrection policy test",
		desc = "Headless policy matrix",
		author = "Eunice3x",
		layer = 100000,
		enabled = true,
	}
end
if not gadgetHandler:IsSyncedCode() then
	return
end
local cases = {
	{ name = "reclaim_first" },
	{ name = "rez_first", rezFirst = true },
	{ name = "same_team", same = true },
	{ name = "enemy", enemy = true },
	{ name = "abandoned_rez", rezFirst = true, abandon = true },
	{ name = "build_first", build = true },
	{ name = "rez_before_build", build = true, rezFirst = true },
	{ name = "two_rezzers", rezFirst = true, two = true },
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
local function reclaim(c)
	if c.build then
		order(c.builder, -UnitDefNames.armllt.id, { c.x, 100, c.z, 0 })
	else
		order(c.builder, CMD.RECLAIM, { Game.maxUnits + c.feature })
	end
end
local function rez(c)
	order(c.rez, CMD.RESURRECT, { Game.maxUnits + c.feature })
	if c.extra then
		order(c.extra, CMD.RESURRECT, { Game.maxUnits + c.feature })
	end
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
			c.counts = { 0, 0, 0, 0 }
			c.simultaneous = 0
			c.feature = assert(Spring.CreateFeature("armfboy_dead", c.x, 100, c.z, 0, 1))
			Spring.SetFeatureResurrect(c.feature, "armfboy", 0)
			Spring.SetFeatureReclaim(c.feature, 0.7)
			c.builder = assert(Spring.CreateUnit("armck", c.x - 90, 100, c.z, 0, 0))
			c.rez = assert(Spring.CreateUnit("cornecro", c.x + 90, 100, c.z, 0, c.enemy and 2 or (c.same and 0 or 1)))
			if c.two then
				c.extra = assert(Spring.CreateUnit("cornecro", c.x + 100, 100, c.z + 60, 0, 1))
			end
			order(c.builder, CMD.FIRE_STATE, { 0 })
			order(c.rez, CMD.FIRE_STATE, { 0 })
			log("SETUP", c.name, c.builder, c.rez, c.feature)
		end
	end
	if f == 80 then
		for _, c in ipairs(cases) do
			Spring.SetUnitBuildSpeed(c.builder, 200, 200, 30)
			Spring.SetUnitBuildSpeed(c.rez, 200, 200, 200, 60)
			if c.extra then
				Spring.SetUnitBuildSpeed(c.extra, 200, 200, 200, 60)
			end
		end
	end
	if f == 90 then
		for _, c in ipairs(cases) do
			if c.rezFirst then
				rez(c)
			else
				reclaim(c)
			end
		end
	end
	if f == 170 then
		for _, c in ipairs(cases) do
			if c.abandon then
				order(c.rez, CMD.STOP)
			end
		end
	end
	if f == 180 then
		for _, c in ipairs(cases) do
			if c.rezFirst then
				reclaim(c)
			else
				rez(c)
			end
		end
	end
	if f == 300 then
		for _, c in ipairs(cases) do
			if c.two then
				order(c.rez, CMD.STOP)
			end
		end
	end
	if f == 360 then
		for _, c in ipairs(cases) do
			local mode = Spring.GetModOptions().experimental_reclaim_resurrection
			local rezWins = mode == "resurrect"
				or (mode == "first" and c.rezFirst and not c.abandon)
				or (mode == "last" and not c.rezFirst)
			order(rezWins and c.rez or c.builder, CMD.STOP)
			if rezWins and c.extra then
				order(c.extra, CMD.STOP)
			end
		end
	end
	if f >= 210 and f % 30 == 0 then
		for _, c in ipairs(cases) do
			local b = Spring.GetUnitCurrentCommand(c.builder)
			local r = Spring.GetUnitCurrentCommand(c.rez)
			log("STATE", f, c.name, b, r, unpack(c.counts))
		end
	end
	if f == 600 then
		local mode = Spring.GetModOptions().experimental_reclaim_resurrection
		for _, c in ipairs(cases) do
			log("RESULT", c.name, unpack(c.counts))
			log("SIMULTANEOUS", c.name, c.simultaneous)
			if c.enemy then
				assert(c.counts[1] > 0 and c.counts[2] > 0, "enemy behavior changed")
			elseif mode ~= "off" then
				local rezWins = not c.abandon
					and (mode == "resurrect" or (mode == "first" and c.rezFirst) or (mode == "last" and not c.rezFirst))
				assert(c.counts[rezWins and 2 or 1] > 0, c.name .. ": winner did not work")
				assert(c.counts[rezWins and 1 or 2] == 0, c.name .. ": loser still worked")
				assert(c.simultaneous == 0, c.name .. ": concurrent allied work")
				if not c.abandon then
					assert(c.counts[rezWins and 3 or 4] > 0, c.name .. ": waiting worker did not resume")
					assert(c.counts[rezWins and 4 or 3] == 0, c.name .. ": stopped winner still worked")
				end
			end
		end
		log("DIAG_DONE")
	end
end
function gadget:AllowFeatureBuildStep(u, t, id, d, part)
	local f = Spring.GetGameFrame()
	for _, c in ipairs(cases) do
		if c.feature == id and f >= 90 then
			local dir = part > 0 and 1 or -1
			if c.lastFrame == f and c.lastDir ~= dir then
				c.simultaneous = c.simultaneous + 1
			end
			c.lastFrame = f
			c.lastDir = dir
			local index = (f >= 390 and 2 or 0) + (part > 0 and 2 or 1)
			if f >= 210 and (f < 350 or f >= 390) then
				c.counts[index] = c.counts[index] + 1
			end
		end
	end
	return true
end
