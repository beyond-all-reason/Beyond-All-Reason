if addon.InGetInfo then
	return {
		name = "Preload Textures",
		desc = "Loads the big unit normal maps while the game loads",
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

local nextTexture = 1

-- one per frame: the loading thread waits for the GL lock a load screen frame holds
function addon.DrawLoadScreen()
	if nextTexture <= #textures then
		gl.Texture(0, textures[nextTexture])
		gl.Texture(0, false)
		nextTexture = nextTexture + 1
	end
end
