local ModuleHandler = VFS.Include("modules/module_handler.lua")
local ModeDSL = VFS.Include("modules/missions/lib/mode_dsl.lua")

local mission = VFS.Include("modules/missions/modes/mission.lua")

describe("missions mode preset", function()
	it("is a game-axis preset with a snake_case key", function()
		assert.equal("mission", mission.key)
		assert.equal("game", mission.category)
		assert.equal(false, mission.allowRanked)
	end)

	it("serializes to exactly the options its policies own", function()
		assert.same({
			deathmode = { value = "neverend", locked = true },
			-- Scavenger defs are derived only when something asks; the mode asks so
			-- nobody has to tick a lobby box (or reach for ruins=enabled, which scatters
			-- derelict bases over the map).
			forceallunits = { value = true, locked = true },
			-- a mission is never a rated game, and the host does not get a say
			ranked_game = { value = false, locked = true },
			-- Unlocked so the lobby renders the mission list.
			mission_name = { value = "none", locked = false },
		}, mission.modOptions)
	end)

	it("fields the seat-filler, because a mission needs an enemy team, not an enemy player", function()
		assert.are.same({ "NullAI" }, mission.bots)
	end)

	it("rejects a second owner of the same modoption", function()
		local Mode = ModeDSL.Mode
		local MatchFlow = VFS.Include("modules/matchflow/mode_dsl.lua")
		local ok, err = pcall(function()
			Mode("Twice").Own(MatchFlow.End).Own(MatchFlow.End)
		end)
		assert.is_false(ok)
		assert.truthy(tostring(err):find("two policies own modoption deathmode", 1, true))
	end)

	it("is selectable on the game axis", function()
		-- The lobby writes the choice into game_mode (the axis the modes
		-- module owns). Without the preset's key in that selector's items the
		-- preset is unreachable and everything it pins silently never happens
		-- — which is exactly how forceallunits went missing from every game.
		ModuleHandler.ResetCaches()
		local found
		for _, entry in ipairs(ModuleHandler.ModOptions()) do
			if entry.key == "game_mode" then
				found = entry
			end
		end
		assert.is_table(found, "game_mode must exist or the mode cannot be selected")
		assert.are.equal("game", found.section)
		assert.are.equal("standard", found.def)
		local keys = {}
		for _, item in ipairs(found.items) do
			keys[#keys + 1] = item.key
		end
		assert.is_truthy(table.concat(keys, ","):find(mission.key, 1, true), "the preset's own key must be selectable")
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
