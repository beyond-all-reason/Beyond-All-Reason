--- The mission_name option: which mission the Mission game mode runs. Its
--- items are discovered at parse time from modules/missions/, so this spec
--- asserts the SHAPE, not a roster — the roster grows a row whenever a
--- mission directory does, and that is the point.

local fragment = VFS.Include("modules/missions/modoptions.lua")

describe("missions modoptions", function()
	local option = fragment[1]

	it("ships exactly the mission picker, on the game section", function()
		assert.are.equal(1, #fragment)
		assert.are.equal("mission_name", option.key)
		assert.are.equal("list", option.type)
		assert.are.equal("game", option.section)
		assert.are.equal("none", option.def)
	end)

	it("leads with none — an ordinary game arms nothing", function()
		assert.are.equal("none", option.items[1].key)
	end)

	it("lifts each manifest's lobby facts onto its item", function()
		for i = 2, #option.items do
			local item = option.items[i]
			local path = "modules/missions/" .. item.key .. "/mission.lua"
			if VFS.FileExists(path) then
				local manifest = VFS.Include(path)
				assert.are.equal(manifest.title or item.key, item.name)
				if manifest.sides ~= nil then
					-- the manifest speaks sides_enum prefixes; the item
					-- carries the resolved display name and lobby index
					local Sides = VFS.Include("modules/missions/lib/sides.lua")
					assert.are.equal(Sides.Resolve(manifest.sides.player).name, item.side_player)
					assert.are.equal(Sides.Resolve(manifest.sides.enemy).name, item.side_enemy)
					assert.is_number(item.side_player_index)
					assert.is_number(item.side_enemy_index)
				end
			end
		end
	end)

	it("lists exactly the directories that hold triggers", function()
		for i = 2, #option.items do
			local item = option.items[i]
			local triggers = VFS.DirList("modules/missions/" .. item.key .. "/triggers/", "*.lua")
			assert.is_true(#triggers > 0, item.key .. " listed without triggers")
		end
	end)
end)
