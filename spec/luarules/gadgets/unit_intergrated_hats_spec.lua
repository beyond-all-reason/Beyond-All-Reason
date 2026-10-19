local GADGET_PATH = "luarules/gadgets/unit_intergrated_hats.lua"

local IDENTITY = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

-- Runs the gadget file against the world table, which the stubs read from and record into.
-- Returns the gadget, or false when the gadget chose not to load.
local function loadGadget(synced, world)
	local env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return synced
			end,
		},
		UnitDefs = world.unitDefs,
		Spring = {
			GetUnitPieceMap = function(unitID)
				return world.pieceMaps[unitID]
			end,
			SetUnitPieceVisible = function(unitID, piece, visible)
				world.calls[#world.calls + 1] = { "visible", unitID, piece, visible }
			end,
			SetUnitPieceMatrix = function(unitID, piece, matrix)
				world.calls[#world.calls + 1] = { "matrix", unitID, piece, matrix }
			end,
		},
	}
	setmetatable(env, { __index = _G })

	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	if chunk() == false then
		return false
	end
	return env.gadget
end

-- Hats h1..hN sit at piece indices 11..10+N, so a call names its hat by index.
local function hatPieceMap(count)
	local map = { base = 1 }
	for i = 1, count do
		map["h" .. i] = 10 + i
	end
	return map
end

-- The one hat each unit kept, from the calls recorded for it.
local function shownHat(world, unitID, count)
	local hidden, zeroed = {}, {}
	for _, call in ipairs(world.calls) do
		if call[2] == unitID then
			local hat = call[3] - 10
			if call[1] == "visible" and call[4] == false then
				hidden[hat] = true
			elseif call[1] == "matrix" then
				assert.same(IDENTITY, call[4])
				zeroed[hat] = true
			end
		end
	end

	local shown
	for hat = 1, count do
		assert.is_true(hidden[hat] ~= zeroed[hat], "hat " .. hat .. " must be either hidden or zeroed, not both")
		if zeroed[hat] then
			assert.is_nil(shown, "more than one hat is shown")
			shown = hat
		end
	end
	return shown
end

describe("Integrated Hats", function()
	local world ---@type table

	before_each(function()
		world = {
			unitDefs = {
				[1] = { name = "hatted", customParams = { holidayhatcount = "3" } },
				[2] = { name = "bare", customParams = {} },
			},
			pieceMaps = {},
			calls = {},
		}
	end)

	it("does not load in unsynced code", function()
		assert.is_false(loadGadget(false, world))
	end)

	it("does not load when no unit has a positive hat count", function()
		for _, count in ipairs({ false, "0" }) do
			world.unitDefs[1].customParams.holidayhatcount = count or nil
			assert.is_false(loadGadget(true, world), tostring(count))
		end
	end)

	describe("with a unit that has three hats", function()
		local gadget ---@type table

		before_each(function()
			gadget = loadGadget(true, world) --[[@as table]]
			assert.is_table(gadget)
		end)

		it("shows exactly one hat and zeroes its placement", function()
			world.pieceMaps[100] = hatPieceMap(3)
			gadget:UnitCreated(100, 1, 0)
			assert.is_number(shownHat(world, 100, 3))
		end)

		it("gives every hat a turn", function()
			local seen = {}
			for unitID = 101, 130 do
				world.pieceMaps[unitID] = hatPieceMap(3)
				gadget:UnitCreated(unitID, 1, 0)
				seen[shownHat(world, unitID, 3)] = true
			end
			assert.same({ true, true, true }, seen)
		end)

		it("leaves units without hats alone", function()
			gadget:UnitCreated(300, 2, 0)
			assert.same({}, world.calls)
		end)
	end)
end)
