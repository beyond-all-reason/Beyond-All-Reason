-- Do NOT use Spring.GetSideData() to display the faction names defined here on the UI,
-- as these names do not support I18N translations. Use the appropriate I18N entry instead.

local SIDES = VFS.Include("gamedata/sides_enum.lua")
if not SIDES then
    error("[Sidedata] Failed to load sides_enum.lua!")
end

-- NOTE: Don't change the ordering here until
-- chobby fixed to accept arbitrary ordering, otherwise
-- AI will crash.
local sideOptions = {
    {
        name = "Armada",
        startunit = SIDES.ARM .. 'com',
    },
    {
        name = "Cortex",
        startunit = SIDES.CORE .. 'com',
    },
    {
        name = "Random",
        startunit = 'dummycom',
    },
    {
        name = "Legion",
        startunit = SIDES.LEGION .. 'com',
    },
}

return sideOptions
