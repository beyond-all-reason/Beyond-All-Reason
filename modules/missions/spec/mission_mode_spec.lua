local ModuleHandler = VFS.Include("modules/module_handler.lua")
local ModeDSL = VFS.Include("modules/missions/lib/mode_dsl.lua")

local mission = VFS.Include("modules/missions/modes/mission.lua")

describe("missions mode preset", function()
	it("is a missions-category preset with a snake_case key", function()
		assert.equal("mission", mission.key)
		assert.equal("missions", mission.category)
		assert.equal(false, mission.allowRanked)
	end)

	it("serializes to exactly the options its policies own", function()
		assert.same({
			deathmode = { value = "neverend", locked = true },
		}, mission.modOptions)
	end)

	it("rejects a second owner of the same modoption", function()
		local Mode, Match = ModeDSL.Mode, ModeDSL.Match
		local ok, err = pcall(function()
			Mode("Twice").Own(Match.End).Own(Match.End)
		end)
		assert.is_false(ok)
		assert.truthy(tostring(err):find("two policies own modoption deathmode", 1, true))
	end)

	it("ModeDirs aggregates the missions preset dir", function()
		ModuleHandler.ResetCaches()
		local found = false
		for _, dir in ipairs(ModuleHandler.ModeDirs()) do
			if dir == "modules/missions/modes/" then
				found = true
			end
		end
		assert.is_true(found)
	end)
end)
