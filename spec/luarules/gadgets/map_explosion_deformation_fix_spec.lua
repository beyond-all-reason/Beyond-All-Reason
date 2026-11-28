local function loadGadget(initialState)
	local state = initialState or { units = {}, terrain = {}, defaultHeight = 10, frame = 0, writes = 0 }
	local env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RegisterExplosion = function(_, weapon)
				state.watched = weapon
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
		COB = { YARD_OPEN = 1 },
	}
	local function ground(x, z)
		return state.terrain[x .. "," .. z] or state.defaultHeight
	end
	env.Spring = {
		GetUnitIsDead = function(id)
			return not state.units[id] or state.units[id].dead
		end,
		GetUnitIsBeingBuilt = function(id)
			return state.units[id].progress < 1
		end,
		GetUnitPosition = function(id)
			local u = state.units[id]
			return u.x, u.y, u.z
		end,
		GetGroundHeight = ground,
		GetUnitBuildFacing = function(id)
			return state.units[id].facing
		end,
		MoveCtrl = {
			IsEnabled = function(id)
				return state.units[id].controlled
			end,
			Enable = function(id)
				state.units[id].controlled = true
			end,
			Disable = function(id)
				local u = state.units[id]
				u.controlled, u.tag, u.blocking, u.yard = false, nil, { false }, 0
			end,
			SetTag = function(id, tag)
				state.units[id].tag = tag
			end,
			GetTag = function(id)
				return state.units[id].tag
			end,
			SetPosition = function(id, x, y, z)
				local u = state.units[id]
				u.x, u.y, u.z = x, y, z
			end,
			SetExtrapolate = function(id, on)
				state.units[id].extrapolate = on
			end,
			SetTrackGround = function(id, on)
				state.units[id].trackGround = on
			end,
		},
		GetUnitCOBValue = function(id)
			return state.units[id].yard
		end,
		SetUnitCOBValue = function(id, _, value)
			state.units[id].yard = value
		end,
		GetUnitBlocking = function(id)
			return unpack(state.units[id].blocking)
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
		SetHeightMapFunc = function(fn, ...)
			fn(...)
		end,
		SetHeightMap = function(x, z, height)
			state.writes = state.writes + 1
			state.terrain[x .. "," .. z] = height
		end,
	}
	setmetatable(env, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/map_explosion_deformation_fix.lua"))
	setfenv(chunk, env)
	chunk()
	env.gadget:Initialize()
	return {
		state = state,
		hit = function(x)
			env.gadget:Explosion(1, x or 128, 10, 128)
		end,
		ground = ground,
		gadget = env.gadget,
		create = function(id, def, facing, progress)
			state.units[id] = {
				x = 128,
				y = 10,
				z = 128,
				controlled = false,
				yard = 1,
				blocking = { true, false, true, false, true, false, true },
				def = def or 1,
				facing = facing or 0,
				progress = progress or 1,
			}
			env.gadget:UnitCreated(id, def or 1)
			return state.units[id]
		end,
		tick = function(frame)
			state.frame = frame
			env.gadget:GameFrame(frame)
		end,
	}
end

describe("Explosion foundation settlement", function()
	it("holds a finished factory and releases its open yard on the mean footprint height", function()
		local t = loadGadget()
		local u = t.create(1, 1, 1)
		assert.equal(1, t.state.watched)
		assert.same({ true, false, true, false, true, false, false }, u.blocking)
		t.hit()
		assert.is_true(u.controlled)
		assert.is_false(u.extrapolate)
		assert.is_false(u.trackGround)
		-- Rotated footprint has nine by five height samples. Change only an edge.
		t.state.terrain["160,144"] = -35
		t.tick(64)
		assert.equal(10, u.y)
		assert.equal(0, t.state.writes)
		t.tick(65)
		assert.equal(9, u.y)
		assert.equal(9, t.ground(160, 144))
		assert.equal(9, t.ground(96, 112))
		assert.near(9 + 1 / 3, t.ground(168, 128), 0.00001)
		assert.near(9 + 2 / 3, t.ground(176, 128), 0.00001)
		assert.equal(10, t.ground(184, 128))
		assert.is_false(u.controlled)
		assert.is_true(u.blocking[1])
		assert.equal(1, u.yard)
	end)

	it("waits for the last overlapping hit and protects a neighboring footprint", function()
		local t = loadGadget()
		local u = t.create(1)
		local neighbor = t.create(2)
		neighbor.x = 168 -- near edge is x=152, one height sample past the factory
		t.hit()
		t.state.terrain["128,128"] = 1
		t.tick(40)
		t.hit()
		t.tick(65)
		assert.is_true(u.controlled)
		assert.equal(0, t.state.writes)
		t.tick(105)
		assert.is_false(u.controlled)
		assert.equal(10, t.ground(152, 128))
		assert.equal(10, neighbor.y)
	end)

	it("leaves the crater when delayed damage kills the building", function()
		local t = loadGadget()
		t.create(1)
		t.hit()
		t.state.terrain["128,128"] = -10
		t.gadget:UnitDestroyed(1)
		t.state.units[1] = nil
		local replacement = t.create(1)
		t.tick(100)
		assert.equal(0, t.state.writes)
		assert.is_false(replacement.controlled)
		assert.equal(-10, t.ground(128, 128))
	end)

	it("releases an unchanged footprint and ignores out-of-range impacts", function()
		local t = loadGadget()
		local u = t.create(1)
		t.hit(900)
		assert.is_false(u.controlled)
		t.hit()
		t.tick(65)
		assert.is_false(u.controlled)
		assert.equal(0, t.state.writes)
	end)

	it("skips unfinished units, mobiles, floating buildings over water and other MoveCtrl users", function()
		local t = loadGadget()
		t.state.defaultHeight = -10
		local unfinished = t.create(1, 1, 0, 0.5)
		local mobile = t.create(2, 2)
		local floating = t.create(3, 3)
		local scripted = t.create(4)
		scripted.controlled = true
		scripted.tag = 123
		t.hit()
		assert.is_false(unfinished.controlled)
		assert.is_false(mobile.controlled)
		assert.is_false(floating.controlled)
		t.tick(65)
		assert.equal(123, scripted.tag)
		assert.equal(0, t.state.writes)
	end)

	it("releases pending control on reverse build or shutdown", function()
		local t = loadGadget()
		local first = t.create(1)
		local second = t.create(2)
		t.hit()
		t.gadget:UnitReverseBuilt(1)
		assert.is_false(first.controlled)
		assert.is_true(second.controlled)
		t.gadget:Shutdown()
		assert.is_false(second.controlled)
	end)

	it("disables itself on maps without deformation", function()
		local t = loadGadget({ mapDamage = false, units = {} })
		assert.is_true(t.state.removed)
	end)
end)
