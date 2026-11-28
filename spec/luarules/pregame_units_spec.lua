local new = assert(loadfile("luarules/callins/pregame_units.lua"))().new

describe("Pregame unit lifecycle isolation", function()
	local api ---@type PregameUnits
	local spring ---@type table
	local rules ---@type table<integer, table<string, number>>
	local calls ---@type boolean[]
	local frame ---@type integer
	local fail ---@type boolean|string
	before_each(function()
		rules, calls, frame = {}, {}, 0
		fail = false
		spring = {
			GetGameFrame = function()
				return frame
			end,
			SetUnitRulesParam = function(id, key, value, visibility)
				assert.is_true(visibility.public)
				rules[id] = rules[id] or {}
				rules[id][key] = value
			end,
			CreateUnit = function(def, x, y, z, facing, team, built, flatten, id)
				if fail == "error" then
					error("creation failed")
				end
				if fail then
					return nil
				end
				id = id or 10
				rules[id] = {}
				calls[#calls + 1] = api.created(id, def, team)
				calls[#calls + 1] = api.contains(id)
				return id
			end,
		}
		api = new(spring)
	end)

	it("marks a proxy during UnitCreated, before CreateUnit returns", function()
		assert.equal(10, api.create(1, 0, 0, 0, 0, 0))
		assert.same({ true, true }, calls)
		assert.equal(1, rules[10].pregame_proxy)
		assert.is_true(api.destroyed(10))
		assert.is_false(api.contains(10))
	end)

	it("delivers a real commander's lifecycle after recycling the proxy ID", function()
		api.create(1, 0, 0, 0, 0, 0, false, false, 42)
		assert.is_true(api.destroyed(42))
		spring.CreateUnit(2, 100, 0, 200, 0, 0, false, true, 42)
		assert.same({ true, true, false, false }, calls)
		assert.is_nil(rules[42].pregame_proxy)
		assert.is_false(api.destroyed(42))
	end)

	it("does not suppress unrelated creation inside AllowUnitCreation", function()
		local create = spring.CreateUnit
		spring.CreateUnit = function(...)
			assert.is_false(api.created(11, 99, 0))
			assert.is_false(api.created(12, 1, 1))
			assert.is_false(api.created(13, 1, 0))
			return create(...)
		end
		api.create(1, 0, 0, 0, 0, 0, false, false, 42)
		assert.is_true(api.contains(42))
		assert.is_nil(rules[11])
	end)

	it("clears a rejected creation context", function()
		fail = true
		assert.is_nil(api.create(1, 0, 0, 0, 0, 0))
		assert.is_false(api.created(10, 1, 0))
	end)

	it("clears a throwing creation context", function()
		fail = "error"
		assert.has_error(function()
			api.create(1, 0, 0, 0, 0, 0)
		end)
		assert.is_false(api.created(10, 1, 0))
		fail = false
		assert.equal(10, api.create(1, 0, 0, 0, 0, 0))
	end)

	it("refuses new proxies after simulation starts", function()
		frame = 1
		assert.has_error(function()
			api.create(1, 0, 0, 0, 0, 0)
		end)
		assert.same({}, calls)
	end)
end)
