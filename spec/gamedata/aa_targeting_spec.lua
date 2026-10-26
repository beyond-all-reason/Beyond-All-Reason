local RealUnitDefs = VFS.Include("spec/support/real_unit_defs.lua")

describe("AA independent targeting", function()
	it("enables mobile, static, naval and mixed-role AA across all factions", function()
		local defs = RealUnitDefs.byName({})
		local slots = {
			armyork = 2,
			corsent = 2,
			legvflak = 1,
			armflak = 1,
			corflak = 1,
			legflak = 1,
			armaas = 2,
			armepoch = 6,
			armjeth = 1,
			corcrash = 1,
			legaabot = 1,
			armfig = 1,
			corveng = 1,
		}
		for name, slot in pairs(slots) do
			assert.is_true(defs[name].weapons[slot].independentautotargeting, name)
		end
	end)

	it("preserves movement helpers and ground weapons", function()
		local defs = RealUnitDefs.byName({})
		for _, name in ipairs({ "armyork", "corsent", "armaas", "armepoch", "corgol", "legkark" }) do
			assert.is_nil(defs[name].weapons[1].independentautotargeting, name)
		end
	end)
end)
