function widget:GetInfo()
	return {
		name = "Test Subfolder Example",
		desc = "This is just a test",
		author = "ChrisFloofyKitsune",
		date = "2024",
		license = "Unlicense",
		layer = -1,
		enabled = false,
	}
end

function widget:GetChildWidgets()
	return true
end
