
local ModeDSL = VFS.Include("modules/matchflow/mode_dsl.lua")

describe("matchflow mode vocabulary", function()
	it("exposes the end as its noun", function()
		assert.are.equal("end", ModeDSL.End.domain)
	end)

	it("serializes a scripted end to a locked neverend deathmode", function()
		local options = ModeDSL.Serializers["end.scripted"]({}, { structure = true, dial = false })
		assert.are.same({ deathmode = { value = "neverend", locked = true } }, options)
	end)

	it("leaves the deathmode open when the policy is unlocked", function()
		local options = ModeDSL.Serializers["end.scripted"]({}, { structure = false, dial = false })
		assert.is_false(options.deathmode.locked)
	end)
end)
