local function loadGadget(state)
	local state = state or { units = {}, terrain = {}, defaultHeight = 10, frame = 0, levels = {} }
	local env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RemoveGadget = function()
				state.removed = true
			end,
		},
		Game = { squareSize = 8, mapSizeX = 1024, mapSizeZ = 1024, mapDamage = state.mapDamage ~= false },
		UnitDefs = {
			{ isImmobile = true, levelGround = true, xsize = 4, zsize = 8, customParams = {} },
			{ isImmobile = false, levelGround = false, xsize = 4, zsize = 4, customParams = {} },
			{ isImmobile = true, levelGround = true, floatOnWater = true, xsize = 4, zsize = 4, customParams = {} },
		},
		WeaponDefs = {
			{ craterAreaOfEffect = 128, damageAreaOfEffect = 256, explosionSpeed = 4, damages = { craterMult = 1 } },
		},
		Script = { SetWatchExplosion = function() end },
	}
	local function ground(x, z)
		return state.terrain[x .. "," .. z] or state.defaultHeight
	end
	env.Spring = {
		ValidUnitID = function(id)
			return state.units[id] ~= nil
		end,
		GetUnitIsDead = function(id)
			return not state.units[id] or state.units[id].dead
		end,
		GetUnitIsBeingBuilt = function(id)
			return state.units[id].progress < 1
		end,
		GetUnitHealth = function(id)
			local u = state.units[id]
			if u then
				return 100, 100, 0, 0, u.progress
			end
		end,
		GetUnitPosition = function(id)
			local u = state.units[id]
			return u.x, 99, u.z
		end,
		GetGroundHeight = ground,
		GetUnitBuildFacing = function(id)
			return state.units[id].facing
		end,
		GetUnitRulesParam = function(id, key)
			return state.units[id][key]
		end,
		SetUnitRulesParam = function(id, key, value)
			state.units[id][key] = value
		end,
		GetUnitBlocking = function()
			return true, false, true, false, true, false, true
		end,
		SetUnitBlocking = function(id, ...)
			state.units[id].blocking = { ... }
		end,
		GetUnitDefID = function(id)
			return state.units[id].def
		end,
		GetGameFrame = function()
			return state.frame
		end,
		GetAllUnits = function()
			local ids = {}
			for id in pairs(state.units) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			return ids
		end,
		GetUnitsInRectangle = function(x1, z1, x2, z2)
			local ids = {}
			for id, u in pairs(state.units) do
				if u.x >= x1 and u.x <= x2 and u.z >= z1 and u.z <= z2 then
					ids[#ids + 1] = id
				end
			end
			table.sort(ids)
			return ids
		end,
		LevelHeightMap = function(x1, z1, x2, z2, height)
			state.levels[#state.levels + 1] = { x1, z1, x2, z2, height }
			for x = x1, x2, 8 do
				for z = z1, z2, 8 do
					state.terrain[x .. "," .. z] = height
				end
			end
		end,
	}
	setmetatable(env, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/map_explosion_deformation_fix.lua"))
	setfenv(chunk, env)
	chunk()
	env.gadget:Initialize()
	return {
		state = state,
		gadget = env.gadget,
		create = function(id, def, facing, progress)
			state.units[id] = { x = 128, z = 128, def = def or 1, facing = facing or 0, progress = progress or 1 }
			env.gadget:UnitCreated(id, def or 1)
		end,
		tick = function(frame)
			state.frame = frame
			env.gadget:GameFrame(frame)
		end,
	}
end

describe("Explosion foundation restoration", function()
	it("records the flattened ground after creation and repairs an edge-only crater", function()
		local t = loadGadget()
		t.create(1)
		t.state.defaultHeight = 20 -- engine flattening happens after UnitCreated
		t.tick(1)
		assert.same({ true, false, true, false, true, false, false }, t.state.units[1].blocking)
		assert.equals(0, #t.state.levels)
		t.state.terrain["144,160"] = 17 -- center remains unchanged
		t.tick(301)
		assert.same({ { 112, 96, 144, 160, 20 } }, t.state.levels)
		t.tick(601)
		assert.equals(1, #t.state.levels)
	end)

	it("rotates rectangular foundations with build facing", function()
		local t = loadGadget()
		t.create(1, 1, 1)
		t.tick(1)
		t.state.terrain["160,144"] = 7
		t.tick(301)
		assert.same({ { 96, 112, 160, 144, 10 } }, t.state.levels)
	end)

	it("waits for initial terraforming and does not flatten unfinished buildings", function()
		local t = loadGadget()
		t.create(1, 1, 0, 0)
		t.tick(1)
		assert.is_nil(t.state.units[1].explosion_foundation_height)
		t.state.defaultHeight = 20
		t.state.units[1].progress = 0.1
		t.tick(2)
		t.state.terrain["128,128"] = 17
		t.tick(301)
		assert.equals(0, #t.state.levels)
		t.state.units[1].progress = 1
		t.tick(601)
		assert.equals(20, t.state.levels[1][5])
	end)

	it("preserves the recorded height across gadget reload", function()
		local t = loadGadget()
		t.create(1)
		t.tick(1)
		t.state.terrain["128,128"] = 7
		local reloaded = loadGadget(t.state)
		reloaded.tick(301)
		assert.equals(10, t.state.levels[1][5])
	end)

	it("does not restore destroyed buildings, including pending ones and reused IDs", function()
		local t = loadGadget()
		t.create(1)
		t.gadget:UnitDestroyed(1)
		t.state.units[1] = nil
		t.tick(1)
		t.create(1)
		t.tick(2)
		t.gadget:UnitDestroyed(1)
		t.state.units[1] = nil
		t.state.terrain["128,128"] = 7
		t.tick(301)
		assert.equals(0, #t.state.levels)
		t.create(1)
		t.tick(302) -- new building records its own height
		assert.equals(7, t.state.units[1].explosion_foundation_height)
	end)

	it("defers restoration past delayed explosion damage and cancels it on death", function()
		local t = loadGadget()
		t.create(1)
		t.tick(1)
		t.tick(300)
		t.state.terrain["128,128"] = 7
		t.gadget:Explosion(1, 128, 10, 128)
		t.tick(301)
		assert.equals(0, #t.state.levels)
		t.gadget:UnitDestroyed(1)
		t.state.units[1] = nil
		t.tick(601)
		assert.equals(0, #t.state.levels)
	end)

	it("restores a survivor after its explosion damage window", function()
		local t = loadGadget()
		t.create(1)
		t.tick(1)
		t.tick(300)
		t.state.terrain["128,128"] = 7
		t.gadget:Explosion(1, 128, 10, 128)
		t.tick(301)
		t.tick(601)
		assert.equals(1, #t.state.levels)
	end)

	it("does not let distant explosions delay restoration", function()
		local t = loadGadget()
		t.create(1)
		t.tick(1)
		t.tick(300)
		t.state.terrain["128,128"] = 7
		t.gadget:Explosion(1, 900, 10, 900)
		t.tick(301)
		assert.equals(1, #t.state.levels)
	end)

	it("leaves mobiles and floating buildings' seabeds alone", function()
		local t = loadGadget()
		t.create(1, 2)
		t.create(2, 3)
		t.state.defaultHeight = -20
		t.tick(1)
		t.state.terrain["128,128"] = -30
		t.tick(301)
		t.tick(302)
		assert.equals(0, #t.state.levels)
	end)

	it("disables itself when map deformation is disabled", function()
		local t = loadGadget({ mapDamage = false, units = {} })
		assert.is_true(t.state.removed)
	end)
end)
