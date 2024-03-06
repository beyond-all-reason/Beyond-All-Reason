function widget:GetInfo()
	return {
		name = "Subfolder Example",
		desc = "Minimal example to demonstrate and document loading widgets from a subfolder",
		author = "ChrisFloofyKitsune",
		date = "2024",
		license = "Unlicense",
		layer = -1,
		enabled = false,
	}
end

---Checked for and called just after GetInfo() during initialization to see if there are child widgets to load
---
---Returns one of:
---* a list of paths to load as children of this widget, paths *can* be absolute or relative and **may only** point to child folders or files
---* boolean value "true" to load all other .lua files in the current folder as children of this widget
---@param path string path from context root to the current folder
---@return string[] | boolean
function widget:GetChildPaths(path)
	return true
end
