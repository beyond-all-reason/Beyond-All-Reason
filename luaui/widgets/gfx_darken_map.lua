
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Darken map",
    desc      = "Darkens map",
    author    = "Floris",
    date      = "2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

local mapMargin = 20000
local darkenMapOpacity = 0.08
local darkenWorldOpacity = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local glCreateList	= gl.CreateList
local glDeleteList	= gl.DeleteList
local glCallList	= gl.CallList

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:Initialize()
    darken = glCreateList(function()
		gl.PushMatrix()
		gl.Translate(0,0,0)
		gl.Rotate(90,1,0,0)
		gl.Rect(-mapMargin, -mapMargin, msx+mapMargin, msz+mapMargin)
		gl.PopMatrix()
    end)
end


function widget:Shutdown()
	glDeleteList(darken)
end


function widget:DrawWorldPreUnit()
	if darken ~= nil and darkenMapOpacity > 0 then
		gl.Color(0,0,0,darkenMapOpacity)
		glCallList(darken)
		gl.Color(1,1,1,1)
	end
end

function widget:DrawWorld()
	if darken ~= nil and darkenWorldOpacity > 0 then
		gl.Color(0,0,0,darkenWorldOpacity)
		glCallList(darken)
		gl.Color(1,1,1,1)
	end
end

