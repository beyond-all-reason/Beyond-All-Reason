local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Deferred shading test",
      layer     = 0,
      enabled   = false,
   }
end

local vsx, vsy

function widget:Initialize()
	vsx, vsy = widgetHandler:GetViewSizes()
end

function widget:Shutdown()
end

function widget:DrawGenesis()
end

--local texName = "$model_gbuffer_normtex"
--local texName = "$model_gbuffer_difftex"
--local texName = "$model_gbuffer_spectex"
--local texName = "$model_gbuffer_emittex"
local texName = "$model_gbuffer_misctex"

function widget:DrawScreenEffects()
	gl.Texture(0, texName)
	gl.TexRect(0, 0, vsx, vsy, false, true)
	gl.Texture(0, false)
end
