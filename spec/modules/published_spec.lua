local Published = VFS.Include("modules/published.lua")

local function fakeSpring()
	local params = {}
	return {
		SetTeamRulesParam = function(teamID, key, value)
			params[teamID] = params[teamID] or {}
			params[teamID][key] = value
		end,
		GetTeamRulesParam = function(teamID, key)
			return params[teamID] and params[teamID][key]
		end,
	}
end

describe("Published", function()
	local sent
	local savedSend

	before_each(function()
		sent = {}
		savedSend = _G.SendToUnsynced
		---@diagnostic disable-next-line: global-in-non-module
		_G.SendToUnsynced = function(event, key, teamID)
			sent[#sent + 1] = { event = event, key = key, teamID = teamID }
		end
	end)

	after_each(function()
		---@diagnostic disable-next-line: global-in-non-module
		_G.SendToUnsynced = savedSend
	end)

	describe("the codec", function()
		local fields =
			{ name = Published.String, count = Published.Number, on = Published.Boolean, tags = Published.List }

		it("round-trips every wire type", function()
			local record = { name = "x", count = 2.5, on = true, tags = { "a", "b" } }
			assert.are.same(record, Published.Decode(fields, Published.Encode(fields, record)))
		end)

		it("omits nil fields and reads them back as nil", function()
			local decoded = Published.Decode(fields, Published.Encode(fields, { name = "only" }))
			assert.are.equal("only", decoded.name)
			assert.is_nil(decoded.count)
			assert.is_nil(decoded.tags)
		end)

		it("reads false back as false", function()
			assert.is_false(Published.Decode(fields, Published.Encode(fields, { on = false })).on)
		end)

		it("merges extras into the result", function()
			assert.are.equal(7, Published.Decode(fields, "name:x", { extra = 7 }).extra)
		end)
	end)

	describe("a per-team record", function()
		local fields = { modes = Published.List, active = Published.Boolean, amount = Published.Number }

		it("reads nil where nothing was published", function()
			local record = Published.PerTeam("spec_never", fields)
			assert.is_nil(record.Read(fakeSpring(), 1))
		end)

		it("reads back what synced wrote, typed", function()
			local spring, record = fakeSpring(), Published.PerTeam("spec_roundtrip", fields)
			record.Write(spring, 3, { modes = { "all", "combat" }, active = true, amount = 12 })
			assert.are.same({ modes = { "all", "combat" }, active = true, amount = 12 }, record.Read(spring, 3))
		end)

		it("the first write is a baseline, a changed write is an event, an unchanged one is not", function()
			local spring, record = fakeSpring(), Published.PerTeam("spec_events", fields)
			assert.is_false(record.Write(spring, 1, { active = true }))
			assert.are.equal(0, #sent)
			assert.is_true(record.Write(spring, 1, { active = false }))
			assert.are.same({ { event = Published.EVENT, key = "spec_events", teamID = 1 } }, sent)
			assert.is_false(record.Write(spring, 1, { active = false }))
			assert.are.equal(1, #sent)
		end)

		it("changesOn narrows what counts as a change", function()
			local spring, record = fakeSpring(), Published.PerTeam("spec_narrow", fields)
			record.Write(spring, 2, { active = true, amount = 1 }, { "active" })
			assert.is_false(record.Write(spring, 2, { active = true, amount = 500 }, { "active" }))
			assert.are.equal(500, record.Read(spring, 2).amount)
			assert.is_true(record.Write(spring, 2, { active = false, amount = 500 }, { "active" }))
		end)

		it("tracks teams and keys independently", function()
			local spring = fakeSpring()
			local a, b = Published.PerTeam("spec_a", fields), Published.PerTeam("spec_b", fields)
			a.Write(spring, 1, { active = true })
			a.Write(spring, 2, { active = true })
			b.Write(spring, 1, { active = true })
			assert.is_true(a.Write(spring, 1, { active = false }))
			assert.are.equal(1, #sent)
			assert.are.equal("spec_a", sent[1].key)
			assert.are.equal(1, sent[1].teamID)
		end)
	end)
end)
