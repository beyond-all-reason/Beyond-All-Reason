if addon.InGetInfo then
	return {
		name = "Preload Textures",
		desc = "Loads the big unit normal maps and FlowUI2's textures while the game loads",
		author = "Floris",
		date = "November 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- CUS GL4 binds these and each takes 50-110 ms to load: in pregame that is a stutter, here it overlaps the loading
-- thread. Named textures are cached engine-wide by exact path, so these must match what cus_gl4.lua binds.
---@type table<integer, string>
local textures = {
	"unittextures/Arm_normal.dds",
	"unittextures/Arm_wreck_color_normal.dds",
	"unittextures/cor_normal.dds",
	"unittextures/cor_color_wreck_normal.dds",
}
-- the other setups that load Legion (Scavengers, ruins, ...) leave its maps to the pregame warm-up
if Spring.GetModOptions().experimentallegionfaction == true then
	textures[#textures + 1] = "unittextures/leg_normal.dds"
	textures[#textures + 1] = "unittextures/leg_wreck_normal.dds"
end

-- FlowUI2's textures (luaui/Include/flowui2/textures.lua writes the file): the resized variants its panels drew last
-- game, for the view height, UI scale and supersampling they were drawn at. ~2 ms each to load: in game a panel's
-- first draw of a few of them stalled its frame (the order menu's first commands: 35 ms)
---@type table<integer, string>
local flowui2 = {}
do
	local text = VFS.LoadFile("LuaUI/Config/flowui2_textures.txt")
	if text then
		local _, vsy = Spring.GetViewGeometry()
		local signature = string.format(
			"%d/%.4f/%d",
			vsy,
			Spring.GetConfigFloat("ui_scale", 1),
			Spring.GetConfigInt("ui_supersample", 2) or 2
		)
		if text:match("^[^\r\n]*") == "signature=" .. signature then
			for line in text:gmatch("[^\r\n]+") do
				local path = line:match("^:[^:]*:(.+)$")
				if path and VFS.FileExists(path) then
					flowui2[#flowui2 + 1] = line
				end
			end
		end
	end
end
local FLOWUI2_BUDGET_MS = 4 -- per load screen frame (they are small: a few each)

local nextTexture = 1
local nextFlowui2 = 1

-- one per frame: the loading thread waits for the GL lock a load screen frame holds
function addon.DrawLoadScreen()
	if nextTexture <= #textures then
		gl.Texture(0, textures[nextTexture])
		gl.Texture(0, false)
		nextTexture = nextTexture + 1
	elseif nextFlowui2 <= #flowui2 then
		local start = Spring.GetTimer()
		repeat
			gl.Texture(0, flowui2[nextFlowui2])
			nextFlowui2 = nextFlowui2 + 1
		until nextFlowui2 > #flowui2 or Spring.DiffTimers(Spring.GetTimer(), start, true) >= FLOWUI2_BUDGET_MS
		gl.Texture(0, false)
	end
end
