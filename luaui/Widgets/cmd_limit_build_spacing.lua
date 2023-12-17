function widget:GetInfo()
  return {
    name      = "Limit Build Spacing",
    desc      = "Limits buildspacing to a maximum distance",
    author    = "Floris",
    date      = "June 2023",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

local limit = 16
function widget:Update()
    local _, cmdID = Spring.GetActiveCommand()
    if cmdID and cmdID < 0 then
		if Spring.GetBuildSpacing() > limit then
			Spring.SetBuildSpacing(limit)
		end
    end
end
