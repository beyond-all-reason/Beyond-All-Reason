local Transport = VFS.Include("modules/transport/api.lua") ---@type TransportApi

describe("transport api asks", function()
	local savedSpring, savedUnitDefs
	local units, defs

	local function unit(id, fields)
		units[id] = fields
		return id
	end

	before_each(function()
		units, defs = {}, {}
		savedSpring, savedUnitDefs = _G.Spring, _G.UnitDefs
		local fake = setmetatable({
			GetUnitPosition = function(id)
				return units[id].x or 0, units[id].y or 0, units[id].z or 0
			end,
			GetUnitHeight = function(id)
				return units[id].height or 10
			end,
			GetUnitTeam = function(id)
				return units[id].team
			end,
			GetUnitDefID = function(id)
				return units[id] and units[id].defID or nil
			end,
			GetUnitVelocity = function(id)
				local v = units[id].speed or 0
				return v, 0, 0, v
			end,
			AreTeamsAllied = function(a, b)
				return a == b or (a % 2) == (b % 2)
			end,
			GetUnitIsTransporting = function(id)
				return units[id].cargo
			end,
			GetModOptions = function()
				return { comm_trans_slow = true }
			end,
			GetGroundNormal = function()
				return 0, 1, 0
			end,
		}, { __index = savedSpring })
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring = fake
		---@diagnostic disable-next-line: global-in-non-module
		_G.UnitDefs = defs
	end)

	after_each(function()
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring, _G.UnitDefs = savedSpring, savedUnitDefs
	end)

	local function def(id, fields)
		fields.customParams = fields.customParams or {}
		fields.xsize = fields.xsize or 2
		fields.zsize = fields.zsize or 2
		defs[id] = fields
		return id
	end

	it("MayCarry refuses a submerged passenger and allows one on dry ground", function()
		local carrier = def(1, { isTransport = true, canFly = true, name = "carrier" })
		local tank = def(2, { name = "tank" })
		local dry = unit(10, { defID = tank, y = 50, height = 10 })
		local wet = unit(11, { defID = tank, y = -50, height = 10 })
		assert.is_true(Transport.MayCarry(carrier, dry, tank))
		assert.is_false(Transport.MayCarry(carrier, wet, tank))
	end)

	it("MayOrderLoad refuses an allied team's nano turret and allows your own", function()
		local carrier = def(1, { isTransport = true, canFly = true })
		local nano = def(3, { customParams = { isnanoturret = "1" } })
		local carrierUnit = unit(20, { defID = carrier, team = 0 })
		local ownNano = unit(21, { defID = nano, team = 0, y = 10 })
		local alliedNano = unit(22, { defID = nano, team = 2, y = 10 })
		assert.is_true(Transport.MayOrderLoad(carrierUnit, carrier, 0, ownNano))
		assert.is_false(Transport.MayOrderLoad(carrierUnit, carrier, 0, alliedNano))
	end)

	it("LoadedSpeed is the carrier's speed, dragged to 120 with a commander aboard", function()
		local carrier = def(1, { isTransport = true, canFly = true, speed = 300 })
		local commander = def(4, { customParams = { iscommander = "1" } })
		local tank = def(2, {})
		local com = unit(30, { defID = commander })
		local grunt = unit(31, { defID = tank })
		local withCom = unit(40, { defID = carrier, cargo = { com } })
		local withTank = unit(41, { defID = carrier, cargo = { grunt } })
		local empty = unit(42, { defID = carrier })
		assert.is.near(120 / Game.gameSpeed, Transport.LoadedSpeed(withCom), 1e-9)
		assert.is.near(300 / Game.gameSpeed, Transport.LoadedSpeed(withTank), 1e-9)
		assert.is_nil(Transport.LoadedSpeed(empty))
	end)
end)
