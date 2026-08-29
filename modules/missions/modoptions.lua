
local Sides = VFS.Include("modules/missions/lib/sides.lua")

local function missionItems()
	local names = {}
	for _, dir in ipairs(VFS.SubDirs("modules/missions/", "*") or {}) do
		if #VFS.DirList(dir .. "triggers/", "*.lua") > 0 then
			local name = dir:gsub("^modules/missions/", ""):gsub("[/\\]+$", "")
			-- smoke_* are the headless scenario suite's fixtures, not player content
			if not name:find("^smoke_") then
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)

	local items = { { key = "none", name = "None", desc = "No mission armed at start." } }
	for _, name in ipairs(names) do
		local item = { key = name, name = name, desc = "modules/missions/" .. name }
		local manifestPath = "modules/missions/" .. name .. "/mission.lua"
		if VFS.FileExists(manifestPath) then
			local ok, manifest = pcall(VFS.Include, manifestPath)
			if ok and type(manifest) == "table" then
				item.name = manifest.title or name
				if type(manifest.sides) == "table" then
					local player = Sides.Resolve(manifest.sides.player)
					local enemy = Sides.Resolve(manifest.sides.enemy)
					item.side_player = player and player.name
					item.side_enemy = enemy and enemy.name
					item.side_player_index = player and player.index
					item.side_enemy_index = enemy and enemy.index
				end
			end
		end
		items[#items + 1] = item
	end
	return items
end

return {
	{
		key = "mission_name",
		name = "Mission",
		desc = "Which mission the Mission game mode runs; armed at game start.",
		type = "list",
		section = "game",
		def = "none",
		items = missionItems(),
	},
}
