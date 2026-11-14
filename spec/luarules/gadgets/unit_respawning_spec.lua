local function loadRespawning()
	local units, rules, orders = {}, {}, {}
	local nextID, seconds, featureTeam, workerTask = 10, 0, 0, nil
	local gadgets = {}
	local env = setmetatable({
		UnitDefs = {
			[1] = {
				name = "armcom",
				isBuilder = true,
				customParams = {
					iscommander = true,
					respawn_condition = "health",
					effigy = "comeffigylvl1",
					effigy_offset = 1,
				},
			},
			[2] = { name = "comeffigylvl1", isBuilding = true, customParams = { iseffigy = true } },
			[3] = { name = "cornecro", isBuilder = true, customParams = {} },
		},
		CMD = { RESURRECT = 125, STOP = 0, WAIT = 5, FIRE_STATE = 45, MOVE_STATE = 50 },
		Engine = { FeatureSupport = { noOffsetForFeatureID = true } },
		Game = { gameSpeed = 30 },
		GG = { ComSpawnDefoliate = function() end },
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		math = setmetatable({
			diag = function(x, z)
				return math.sqrt(x * x + z * z)
			end,
		}, { __index = math }),
	}, { __index = _G })
	local function create(def, x, y, z, facing, team, builder)
		if type(def) == "string" then
			def = def == "comeffigylvl1" and 2 or 1
		end
		nextID = nextID + 1
		local id = nextID
		units[id] = { def = def, team = team, x = x, y = y, z = z, health = 4000, maxHealth = 4000 }
		rules[id] = {}
		for _, g in ipairs(gadgets) do
			g:UnitCreated(id, def, team, builder)
		end
		return id
	end
	env.Spring = {
		CreateUnit = create,
		DestroyUnit = function(id)
			local u = units[id]
			for _, g in ipairs(gadgets) do
				g:UnitDestroyed(id, u.def, u.team)
			end
			units[id] = nil
		end,
		GetUnitDefID = function(id)
			return units[id] and units[id].def
		end,
		GetUnitTeam = function(id)
			return units[id].team
		end,
		GetUnitPosition = function(id)
			local u = units[id]
			return u.x, u.y, u.z
		end,
		SetUnitPosition = function(id, x, z)
			units[id].x, units[id].z = x, z
		end,
		GetUnitHealth = function(id)
			local u = units[id]
			return u.health, u.maxHealth, 0, 0, 1
		end,
		SetUnitHealth = function(id, value)
			units[id].health = type(value) == "table" and value.health or value
		end,
		GetUnitRulesParam = function(id, key)
			return rules[id][key]
		end,
		SetUnitRulesParam = function(id, key, value)
			rules[id][key] = value
		end,
		GetGameSeconds = function()
			return seconds
		end,
		GetGameFrame = function()
			return seconds * 30
		end,
		GetGroundBlocked = function()
			return false
		end,
		GetGroundHeight = function()
			return 0
		end,
		GetUnitWorkerTask = function()
			return workerTask, 100
		end,
		GetFeatureRulesParam = function() end,
		GetFeatureTeam = function()
			return featureTeam
		end,
		SetUnitExperience = function() end,
		GetUnitExperience = function()
			return 0
		end,
		GetUnitStates = function()
			return {}
		end,
		GetUnitNearestEnemy = function() end,
		AreTeamsAllied = function(a, b)
			return a == b
		end,
		GiveOrderToUnit = function(id, cmd)
			orders[#orders + 1] = { id, cmd }
		end,
		SetUnitCosts = function() end,
		GetPlayerList = function()
			return {}
		end,
		SpawnCEG = function() end,
		PlaySoundFile = function() end,
	}
	for _, path in ipairs({ "unit_resurrected", "unit_respawning" }) do
		local e = setmetatable({ gadget = {} }, { __index = env })
		setfenv(assert(loadfile("luarules/gadgets/" .. path .. ".lua")), e)()
		gadgets[#gadgets + 1] = e.gadget
	end
	assert.is_true(gadgets[1]:GetInfo().layer < gadgets[2]:GetInfo().layer)
	local function resurrect(team, oldTeam)
		featureTeam, workerTask = oldTeam, env.CMD.RESURRECT
		local rezbot = create(3, 100, 0, 100, 0, team)
		local commander = create(1, 150, 0, 150, 0, team, rezbot)
		workerTask = nil
		return commander
	end
	return {
		create = create,
		resurrect = resurrect,
		units = units,
		rules = rules,
		respawn = gadgets[2],
		spring = env.Spring,
		advance = function()
			seconds = 10
		end,
		effigyCount = function()
			local n = 0
			for _, u in pairs(units) do
				if u.def == 2 then
					n = n + 1
				end
			end
			return n
		end,
	}
end

describe("Commander effigies after resurrection", function()
	it("still gives a newly spawned commander its starting effigy", function()
		local t = loadRespawning()
		local commander = t.create(1, 1000, 0, 1000, 0, 0)
		assert.equals(1, t.effigyCount())
		assert.is_not_nil(t.rules[commander].unit_effigy)
	end)
	for _, oldTeam in ipairs({ 0, 1 }) do
		it(
			"does not grant a free effigy for a resurrected "
				.. (oldTeam == 0 and "friendly" or "enemy")
				.. " commander",
			function()
				local t = loadRespawning()
				local commander = t.resurrect(0, oldTeam)
				assert.equals(1, t.rules[commander].resurrected)
				assert.equals(0, t.effigyCount())
				assert.is_nil(t.rules[commander].unit_effigy)
			end
		)
	end
	it("allows a resurrected commander to build and use an effigy", function()
		local t = loadRespawning()
		local commander = t.resurrect(0, 1)
		assert.equals(0, t.effigyCount())
		local effigy = t.create(2, 1000, 0, 1000, 0, 0, commander)
		assert.equals(effigy, t.rules[commander].unit_effigy)
		t.advance()
		local damage, impulse = t.respawn:UnitPreDamaged(commander, 1, 0, 10000, false, -1)
		assert.equals(0, damage)
		assert.equals(0, impulse)
		assert.equals(1000, t.units[commander].x)
		assert.equals(1000, t.units[commander].z)
		assert.equals(1, t.units[commander].health)
		assert.equals(0, t.effigyCount())
		assert.is_nil(t.rules[commander].unit_effigy)
	end)
	it("does not give a resurrected commander without an effigy a respawn", function()
		local t = loadRespawning()
		local commander = t.resurrect(0, 0)
		t.advance()
		assert.is_nil(t.respawn:UnitPreDamaged(commander, 1, 0, 10000, false, -1))
		assert.equals(150, t.units[commander].x)
	end)
end)
