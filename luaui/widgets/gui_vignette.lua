function widget:GetInfo()
    return {
        name      = "Vignette",
        desc      = "renders a vignette (fading to black at screen edges)",
        author    = "Floris",
        date      = "12 Sept 2015",
        license   = "GNU GPL, v2 or whatever",
        layer     = 111,
        enabled   = true
    }
end

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

local vignetteTexture	= ":n:"..LUAUI_DIRNAME.."Images/vignette.dds"
local vignetteColor		= {0,0,0,0.2}

--------------------------------------------------------------------------------

function createList()
	local vsx, vsy = gl.GetViewSizes()
	dList = gl.CreateList(function()
        gl.PushMatrix()
			gl.Color(vignetteColor)
			gl.Texture(vignetteTexture)
			gl.TexRect(0, 0, vsx, vsy)
			gl.Texture(false)
		gl.PopMatrix()
	end)
end


function widget:Initialize()
	createList()
end


function widget:ViewResize(newX,newY)
	if dList ~= nil then
		gl.DeleteList(dList)
	end
	createList()
end


function widget:DrawScreen()
	gl.CallList(dList)
end


function widget:Shutdown()
	if dList ~= nil then
		gl.DeleteList(dList)
	end
end
