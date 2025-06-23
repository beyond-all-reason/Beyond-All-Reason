if not Spring.Utilities.IsDevMode() then -- and not Spring.Utilities.ShowDevUI() then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Engine Shader Auto Reloader",
		desc = "Reloads all engine shaders on file change (unzip base/springcontent.sdz -> base/springcontent.sdd/)",
		author = "Beherith",
		date = "2024.11.01",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true, --  loaded by default?
	}
end

local shaderContents = {} -- maps shader filename to raw contents
local interval = 10 -- seconds
function widget:Initialize()
    local shaders = VFS.DirList("Shaders/GLSL/", "*.glsl")
    for i, filename in ipairs(shaders) do
        shaderContents[filename] = VFS.LoadFile(filename)
    end
end

local lastUpdate = Spring.GetTimer()
function widget:Update()
	if Spring.DiffTimers(Spring.GetTimer() , lastUpdate) < interval then return end
	lastUpdate = Spring.GetTimer()
    local changed = false
    for fileName, oldContents in pairs(shaderContents) do
        local newContents = VFS.LoadFile(fileName)
        if newContents ~= oldContents then
            interval = 1
            changed = true
            shaderContents[fileName] = newContents
            Spring.Echo("Reloading shader: " .. fileName)
        end
    end
    if changed then
        Spring.SendCommands("reloadshaders")
    end
end
