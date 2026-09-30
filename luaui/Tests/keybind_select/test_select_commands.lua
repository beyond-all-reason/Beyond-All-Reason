-- What the select builder writes, run through the engine and held to its words.
-- In game: /runtests keybind_select (the mouse cases need a window).
local Select = require("luaui/Include/keybind_select")
-- BAR is missing from the test sandbox but not from the widget handler's environment.
local translate = debug.getfenv(widgetHandler.FindWidget).BAR.I18N

local NEAR = {
	"armcom",
	"armck",
	"armpw",
	"armpw",
	"armpw",
	"armrectr",
	"armfig",
	"armatlas",
	"armrad",
	"armjamt",
	"armsolar",
	"armlab",
	"armspy",
	"armnanotc",
	"armmark",
	"armflea",
	"armllt",
	"corak",
	"corck",
}
local FAR = { "armpw", "armck" }

local function skip()
	return Spring.GetGameFrame() <= 0
end

local function setup()
	Test.clearMap()
end

local function cleanup()
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function spawn(names, cx, cz, team)
	-- Not a tail call: SyncedRun reads the locals of the function calling it.
	local ids = SyncedRun(function(locals)
		local out = {}
		for i, name in ipairs(locals.names) do
			local x = locals.cx + ((i - 1) % 5) * 120
			local z = locals.cz + math.floor((i - 1) / 5) * 120
			out[i] = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, 0, locals.team)
		end

		return out
	end)

	return ids
end

-- Kept apart from the test body, whose locals SyncedRun would otherwise send to the synced side.
local function prepare(state)
	SyncedRun(function(locals)
		local s = locals.state
		local _, maxHealth = Spring.GetUnitHealth(s.hurt)
		Spring.SetUnitHealth(s.hurt, maxHealth * 0.2)
		Spring.GiveOrderToUnit(s.waiting, CMD.WAIT, {}, 0)
		Spring.GiveOrderToUnit(s.guard, CMD.GUARD, { s.guarded }, 0)
		local x, y, z = Spring.GetUnitPosition(s.patrol)
		assert(x and y and z)
		Spring.GiveOrderToUnit(s.patrol, CMD.PATROL, { x + 400, y, z }, 0)
		Spring.GiveOrderToUnit(s.spy, CMD.CLOAK, { 1 }, 0)
	end)
end

local function commandAt(id, depth)
	local out = {}
	local commands = Spring.GetUnitCommands(id, depth)
	for i, cmd in ipairs(type(commands) == "table" and commands or {}) do
		out[i] = cmd.id
	end

	return out
end

-- Squared distance from where the cursor meets the ground to a unit, or nil with nothing to point.
local function cursorDistance(unitID, withHeight)
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if type(pos) ~= "table" then
		return nil
	end
	local gx, gy, gz = pos[1], pos[2], pos[3]
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not (gx and gy and gz and x and y and z) then
		return nil
	end
	local dy = withHeight and (y - gy) or 0

	return (x - gx) ^ 2 + dy ^ 2 + (z - gz) ^ 2
end

-- What each filter's words promise, asked of the unit directly rather than of the engine's filter.
local means = {
	Builder = function(u)
		return u.def.isBuilder
	end,
	Buildoptions = function(u)
		return #u.def.buildOptions > 0
	end,
	Building = function(u)
		return u.def.isBuilding
	end,
	Aircraft = function(u)
		return u.def.isAirUnit
	end,
	Transport = function(u)
		return u.def.isTransport
	end,
	Weapons = function(u)
		return #u.def.weapons > 0
	end,
	ManualFireUnit = function(u)
		return u.def.canManualFire
	end,
	Resurrect = function(u)
		return u.def.canResurrect
	end,
	Radar = function(u)
		return u.def.radarDistance > 0 or u.def.sonarDistance > 0
	end,
	Jammer = function(u)
		return u.def.radarDistanceJam > 0
	end,
	Stealth = function(u)
		return u.def.stealth
	end,
	Cloak = function(u)
		return u.def.canCloak
	end,
	Cloaked = function(u)
		return Spring.GetUnitIsCloaked(u.id)
	end,
	Idle = function(u)
		return #commandAt(u.id, 1) == 0
	end,
	Waiting = function(u)
		return commandAt(u.id, 1)[1] == CMD.WAIT
	end,
	Guarding = function(u)
		return commandAt(u.id, 1)[1] == CMD.GUARD
	end,
	Patrolling = function(u)
		for _, id in ipairs(commandAt(u.id, 100)) do
			if id == CMD.PATROL then
				return true
			end
		end

		return false
	end,
	InHotkeyGroup = function(u)
		return Spring.GetUnitGroup(u.id) ~= nil
	end,
	InPrevSel = function(u, _, ctx)
		return ctx.preTypes[u.def.id]
	end,
	InGroup = function(u, args)
		return Spring.GetUnitGroup(u.id) == tonumber(args[1])
	end,
	RelativeHealth = function(u, args)
		local health, maxHealth = Spring.GetUnitHealth(u.id)

		return assert(health) / maxHealth > assert(tonumber(args[1])) / 100
	end,
	AbsoluteHealth = function(u, args)
		return (Spring.GetUnitHealth(u.id)) > tonumber(args[1])
	end,
	WeaponRange = function(u, args)
		return (u.def.maxWeaponRange or 0) > tonumber(args[1])
	end,
	IdMatches = function(u, args)
		return u.def.name == args[1]
	end,
}

local function passes(u, spec, ctx)
	local names = {}
	for _, f in ipairs(spec.filters) do
		if f.id == "IdMatches" and not f.negate then
			names[f.args[1]] = true
		end
	end
	if next(names) and not names[u.def.name] then
		return false
	end
	for _, f in ipairs(spec.filters) do
		if not (f.id == "IdMatches" and not f.negate) then
			if (means[f.id](u, f.args, ctx) and true or false) == f.negate then
				return false
			end
		end
	end

	return true
end

local function test()
	local team = Spring.GetMyTeamID()
	local cx, cz = math.floor(Game.mapSizeX / 2), math.floor(Game.mapSizeZ / 2)
	local nearIds = spawn(NEAR, cx, cz, team)
	local farIds = spawn(FAR, 300, 300, team)

	local units, byName, nameOf = {}, {}, {}
	for i, id in ipairs(nearIds) do
		units[#units + 1] = { id = id, def = UnitDefs[Spring.GetUnitDefID(id)] }
		byName[NEAR[i]] = byName[NEAR[i]] or {}
		table.insert(byName[NEAR[i]], id)
	end
	for i, id in ipairs(farIds) do
		units[#units + 1] = { id = id, def = UnitDefs[Spring.GetUnitDefID(id)] }
		byName[FAR[i]] = byName[FAR[i]] or {}
		table.insert(byName[FAR[i]], id)
	end
	for _, u in ipairs(units) do
		nameOf[u.id] = u.def.name
	end

	local pw, ck, com = assert(byName.armpw), assert(byName.armck), assert(byName.armcom)[1]
	local state = {
		hurt = pw[2],
		waiting = pw[3],
		guard = ck[1],
		guarded = com,
		patrol = byName.armflea[1],
		spy = byName.armspy[1],
	}
	prepare(state)
	Spring.SetUnitGroup(pw[1], 1)
	Spring.SetUnitGroup(byName.armfig[1], 2)
	Test.waitFrames(10)

	local lines, failures = {}, 0
	local function names(set)
		local out = {}
		for id in pairs(set) do
			out[#out + 1] = nameOf[id] or tostring(id)
		end
		table.sort(out)

		return table.concat(out, ",")
	end
	local function asSet(list)
		local out = {}
		for _, id in ipairs(list) do
			out[id] = true
		end

		return out
	end
	local function size(set)
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end

		return n
	end
	local function report(status, label, action, detail)
		if status == "FAIL" then
			failures = failures + 1
		end
		lines[#lines + 1] = ("%s | %s | %s | %s"):format(status, label, action, detail)
	end

	local function run(action, pre)
		Spring.SelectUnitArray(pre or {})
		Spring.SendCommands(action)

		return asSet(Spring.GetSelectedUnits())
	end

	local function source(spec, pre)
		local out = {}
		for _, u in ipairs(units) do
			local take = spec.source == "AllMap"
				or (spec.source == "PrevSelection" and pre[u.id])
				or (spec.source == "Visible" and Spring.IsUnitInView(u.id))
			if spec.source == "FromMouse" or spec.source == "FromMouseC" then
				local d2 = cursorDistance(u.id, spec.source == "FromMouse")
				take = d2 ~= nil and d2 < assert(tonumber(spec.sourceArg)) ^ 2
			end
			if take then
				out[#out + 1] = u
			end
		end

		return out
	end

	local function candidates(spec, preList)
		local pre = asSet(preList or {})
		local ctx = { preTypes = {} }
		for id in pairs(pre) do
			ctx.preTypes[Spring.GetUnitDefID(id)] = true
		end
		local out = {}
		for _, u in ipairs(source(spec, pre)) do
			if passes(u, spec, ctx) then
				out[u.id] = true
			end
		end

		return out
	end

	-- Selects exactly the units the words name.
	local function exact(spec, preList)
		local action = Select.format(spec)
		local want = candidates(spec, preList)
		if not spec.clear then
			for _, id in ipairs(preList or {}) do
				want[id] = true
			end
		end
		local got = run(action, preList)
		local extra, missing = {}, {}
		for id in pairs(got) do
			if not want[id] then
				extra[id] = true
			end
		end
		for id in pairs(want) do
			if not got[id] then
				missing[id] = true
			end
		end
		local ok = next(extra) == nil and next(missing) == nil
		local detail = ("want %d got %d"):format(size(want), size(got))
		if not ok then
			detail = detail .. (" | extra: %s | missing: %s"):format(names(extra), names(missing))
		elseif next(want) == nil then
			detail = detail .. " | vacuous: nothing to select either way"
		end
		report(ok and "PASS" or "FAIL", Select.describe(spec, translate), action, detail)
	end

	-- Selects some number of the units the words name, and none it doesn't.
	local function counted(spec, n)
		local action = Select.format(spec)
		local pool = candidates(spec)
		local got = run(action)
		local stray = {}
		for id in pairs(got) do
			if not pool[id] then
				stray[id] = true
			end
		end
		local ok = size(got) == n and next(stray) == nil
		report(
			ok and "PASS" or "FAIL",
			Select.describe(spec, translate),
			action,
			("of %d, want %s got %d%s"):format(
				size(pool),
				tostring(n),
				size(got),
				next(stray) and (" | outside the filter: " .. names(stray)) or ""
			)
		)
	end

	local function spec(sourceId, filters, conclusion, extra)
		local s = { source = sourceId, filters = filters or {}, clear = true, conclusion = conclusion or "SelectAll" }
		for k, v in pairs(extra or {}) do
			s[k] = v
		end

		return s
	end
	local function f(id, negate, ...)
		return { id = id, negate = negate or false, args = { ... } }
	end

	local argsFor = {
		InGroup = { "1" },
		RelativeHealth = { "50" },
		AbsoluteHealth = { "1000" },
		WeaponRange = { "400" },
		IdMatches = { "armpw" },
	}
	local pre = { pw[1] }
	for _, filter in ipairs(Select.filters) do
		for _, negate in ipairs({ false, true }) do
			local args = argsFor[filter.id] or {}
			exact(spec("AllMap", { f(filter.id, negate, unpack(args)) }), filter.id == "InPrevSel" and pre or nil)
		end
	end

	exact(spec("AllMap", { f("WeaponRange", false, "300"), f("WeaponRange", true, "700") }))
	exact(spec("AllMap", { f("RelativeHealth", false, "10"), f("RelativeHealth", true, "50") }))
	exact(spec("AllMap", { f("IdMatches", false, "armpw"), f("IdMatches", false, "armck") }))
	exact(spec("AllMap", { f("Idle"), f("IdMatches", false, "armpw"), f("IdMatches", false, "armck") }))
	exact(spec("AllMap", { f("IdMatches", false, "armpw"), f("Idle"), f("IdMatches", false, "armck") }))
	exact(spec("AllMap", { f("IdMatches", true, "armpw"), f("IdMatches", true, "armck") }))
	exact(spec("AllMap", { f("IdMatches", false, "armpw"), f("IdMatches", true, "armck") }))
	exact(
		spec(
			"AllMap",
			{ f("IdMatches", false, "armpw"), f("IdMatches", false, "corak"), f("IdMatches", true, "corak") }
		)
	)
	exact(spec("AllMap", { f("Builder"), f("Building", true) }))
	exact(spec("AllMap", { f("Building", true), f("Builder") }))
	exact(spec("AllMap", { f("Weapons"), f("Aircraft", true), f("Building", true), f("Idle") }))

	local half = {}
	for i = 1, #units, 2 do
		half[#half + 1] = units[i].id
	end
	exact(spec("AllMap"))
	exact(spec("PrevSelection"), half)
	exact(spec("PrevSelection", { f("Weapons") }), half)
	Spring.SetCameraTarget(cx + 240, Spring.GetGroundHeight(cx, cz), cz + 240, 0)
	Test.waitFrames(2)
	exact(spec("Visible"))
	exact(spec("Visible", { f("IdMatches", false, "armpw") }))

	exact(spec("AllMap", { f("IdMatches", false, "armpw") }, "SelectAll", { clear = false }), { com })
	exact(spec("AllMap", { f("IdMatches", false, "armpw") }, "SelectAll"), { com })

	local pawns = { f("IdMatches", false, "armpw") }
	counted(spec("AllMap", pawns, "SelectNum", { conclusionArg = "2" }), 2)
	counted(spec("AllMap", pawns, "SelectNum", { conclusionArg = "10" }), 4)
	counted(spec("AllMap", pawns, "SelectPart", { conclusionArg = "50" }), 2)
	-- A part rounds down, so a part of too few units selects none.
	counted(spec("AllMap", pawns, "SelectPart", { conclusionArg = "30" }), 1)
	counted(spec("AllMap", { f("IdMatches", false, "armcom") }, "SelectPart", { conclusionArg = "50" }), 0)
	counted(spec("AllMap", pawns, "SelectOne"), 1)

	local oneAction = Select.format(spec("AllMap", pawns, "SelectOne"))
	local seen = {}
	for _ = 1, #pw do
		for id in pairs(run(oneAction)) do
			seen[id] = true
		end
	end
	report(
		size(seen) == #pw and "PASS" or "FAIL",
		Select.describe(spec("AllMap", pawns, "SelectOne"), translate) .. ", pressed " .. #pw .. " times",
		oneAction,
		("want all %d in turn got %d: %s"):format(#pw, size(seen), names(seen))
	)

	if Platform.gl then
		Spring.SetCameraTarget(cx + 240, Spring.GetGroundHeight(cx, cz), cz + 240, 0)
		Test.waitFrames(2)
		local x, y, z = Spring.GetUnitPosition(com)
		assert(x and y and z)
		local sx, sy = Spring.WorldToScreenCoords(x, y, z)
		Spring.WarpMouse(math.floor(sx), math.floor(sy))
		Test.waitFrames(2)
		exact(spec("FromMouse", nil, "SelectAll", { sourceArg = "200" }))
		exact(spec("FromMouseC", nil, "SelectAll", { sourceArg = "200" }))
		exact(spec("FromMouse", { f("Weapons") }, "SelectAll", { sourceArg = "300" }))

		local closest = spec("AllMap", pawns, "SelectClosestToCursor")
		local best, bestD
		for _, id in ipairs(pw) do
			local d = cursorDistance(id, true)
			if d and (not bestD or d < bestD) then
				best, bestD = id, d
			end
		end
		local got = run(Select.format(closest))
		report(
			(size(got) == 1 and got[best]) and "PASS" or "FAIL",
			Select.describe(closest, translate),
			Select.format(closest),
			("want unit %s got %s"):format(tostring(best), names(got))
		)
	else
		lines[#lines + 1] = "SKIP | sources and conclusions aimed with the mouse | no window"
	end

	for _, line in ipairs(lines) do
		Spring.Echo("[keybind_select] " .. line)
	end
	assert(
		failures == 0,
		failures .. " selections did not do what their words say; see [keybind_select] in the infolog"
	)
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup }
