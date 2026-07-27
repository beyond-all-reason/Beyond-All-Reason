--- Mod options owned by the missions module: one option, which mission the
--- Mission game mode runs.
---
--- It lives in the game section — the axis's own — so a lobby's mode panel
--- shows it exactly while a preset claims it, and the Mission preset is the
--- one that does. The items are DISCOVERED at parse time: a mission is a
--- directory under modules/missions/ with triggers in it, and this file is
--- executed Lua everywhere the option set is read (unitsync, lobby, game),
--- so the list is always the archive's own missions. "none" is the wire
--- value for no mission; the loader arms anything else at game start, and
--- the chat command and editor can still arm whatever they like later.

local Sides = VFS.Include("modules/missions/lib/sides.lua")

local function missionItems()
	local names = {}
	for _, dir in ipairs(VFS.SubDirs("modules/missions/", "*") or {}) do
		if #VFS.DirList(dir .. "triggers/", "*.lua") > 0 then
			names[#names + 1] = dir:gsub("^modules/missions/", ""):gsub("[/\\]+$", "")
		end
	end
	table.sort(names)

	local items = { { key = "none", name = "None", desc = "No mission armed at start." } }
	for _, name in ipairs(names) do
		local item = { key = name, name = name, desc = "modules/missions/" .. name }
		-- A mission may ship a manifest: the lobby-facing facts (title, the
		-- story's factions) that must exist before the game does.
		local manifestPath = "modules/missions/" .. name .. "/mission.lua"
		if VFS.FileExists(manifestPath) then
			local ok, manifest = pcall(VFS.Include, manifestPath)
			if ok and type(manifest) == "table" then
				item.name = manifest.title or name
				-- Manifests speak sides_enum prefixes; items carry BOTH views
				-- (display name for humans, 0-based index for a battle
				-- status) so the lobby never touches sidedata itself.
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
