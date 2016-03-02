--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Sun Handler",
		version   = "v0.00001",
		desc      = "Handles the Sun.",
		author    = "GoogleFrog",
		date      = "2 March 2016", 
		license   = "GPL",
		layer     = -1,	--higher layer is loaded last
		enabled   = true,  
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	if Spring.SetSunLighting then
		Spring.Echo("SetSunLighting")
		Spring.SetSunLighting({groundSpecularColor = {0,0,0,0}})
	end
	widgetHandler:RemoveWidget()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
