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

-- Notes

-- Folder that are one level down from the "Widgets" or "Gadgets" folder
-- load all files ending with ".main.lua" without a parent
-- (for example, this widget here does not have a parent)

---Checked for and called just after GetInfo() during initialization to see if there are child widgets to load
---
---Returns one of:
---* a list of paths to load as children of this widget, paths are relative and **may only** point to child folders or files.
---  Paths that point to folders result in all files ending with ".main.lua" being loaded as children of this widget.
---* boolean value "true" to load all other .lua files in the current folder as children of this widget
---@return string[] | boolean
function widget:GetChildPaths()
	-- paths to child widgets
	--return {'test_DPAT.lua', 'test_dpat_minimal_example.lua'}

	-- paths to child widgets with leading './' ('../' is not allowed)
	--return {'./test_DPAT.lua', './test_dpat_minimal_example.lua', '/bad_path.lua'}
	return {'./test_DPAT.lua', './test_dpat_minimal_example.lua'}

	-- load all other in .lua files in this folder as child widgets
	-- return true
end
