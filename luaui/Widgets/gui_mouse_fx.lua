local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Mouse FX",
      desc      = "Adds glow effect at mouse clicks",
      author    = "Floris",
      date      = "13 may 2015",
      license   = "GNU GPL, v2 or later",
      layer     = 2,
      enabled   = true,
   }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local scaleWithCamera			= true
local showMouseclicks			= true

local generalSize 				= 45		-- overall size
local generalOpacity 			= 0.7		-- overall opacity
local generalDuration			= 0.66		-- overall duration

local imageDir					= ":n:LuaUI/Images/"

local chobbyInterface

local types = {
	leftclick = {
		size			= 0.82,
		endSize			= 0.25,
		duration		= 0.85,
		baseColor 		= {0.66 ,1 ,0.15 ,0.5}
	},
	rightclick = {
		size			= 0.82,
		endSize			= 0.25,
		duration		= 0.85,
		baseColor		= {1.00 ,0.85 ,0.15 ,0.55}
	},
	leftclick2 = {
		size			= 1.33,
		endSize			= 0.82,
		duration		= 1.65,
		baseColor 		= {0.7 ,1 ,0.15 ,0.18}
	},
	rightclick2 = {
		size			= 1.33,
		endSize			= 0.82,
		duration		= 1.65,
		baseColor		= {1.00 ,0.85 ,0.15 ,0.20}
	}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetCameraPosition		= Spring.GetCameraPosition
local spTraceScreenRay			= Spring.TraceScreenRay
local spGetMouseState			= Spring.GetMouseState

local glCreateList				= gl.CreateList
local glDeleteList				= gl.DeleteList
local glCallList				= gl.CallList

local diag						= math.diag

local commands = {}
local commandCount = 0
local mouseButton = false
local baseDlist

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function DrawGroundquad(x,y,z,size)
	gl.TexCoord(0,0)
	gl.Vertex(x-size,y,z-size)
	gl.TexCoord(0,1)
	gl.Vertex(x-size,y,z+size)
	gl.TexCoord(1,1)
	gl.Vertex(x+size,y,z+size)
	gl.TexCoord(1,0)
	gl.Vertex(x+size,y,z-size)
end


local function AddCommandSpotter(cmdType, x, y, z, osClock)
	commandCount = commandCount + 1
	commands[commandCount] = {
		cmdType		= cmdType,
		x			= x,
		y			= y,
		z			= z,
		osClock		= osClock
	}
end


------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

--	Engine Triggers

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------


function widget:Initialize()
	baseDlist = glCreateList(function()
		gl.Texture(imageDir..'glow.dds')
		gl.BeginEnd(GL.QUADS,DrawGroundquad,0,0,0,1)
		gl.Texture(false)
	end)
end


function widget:Shutdown()
	glDeleteList(baseDlist)
end


function widget:MousePress(x, y, button)
	if button == 1 then
		mouseButton = button
	end
	local _, tracedScreenRay = spTraceScreenRay(x, y, true)
	if button == 3 and tracedScreenRay  and tracedScreenRay[3] then
		AddCommandSpotter('rightclick', tracedScreenRay[1], tracedScreenRay[2], tracedScreenRay[3], os.clock())
		AddCommandSpotter('rightclick2', tracedScreenRay[1], tracedScreenRay[2], tracedScreenRay[3], os.clock())
	end
end


function mouseRelease(x, y, button)
	if showMouseclicks then
		local _, tracedScreenRay = spTraceScreenRay(x, y, true)
		if button == 1 and tracedScreenRay  and tracedScreenRay[3] then
			AddCommandSpotter('leftclick', tracedScreenRay[1], tracedScreenRay[2], tracedScreenRay[3], os.clock())
			AddCommandSpotter('leftclick2', tracedScreenRay[1], tracedScreenRay[2], tracedScreenRay[3], os.clock())
		end
	end
end

function widget:Update()
	if mouseButton then
		local x,y,m1,m2,m3 = spGetMouseState()
		if not m1 and not m3 then
			mouseRelease(x,y, mouseButton)
			mouseButton = false
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
  if Spring.IsGUIHidden() then return end

	local osClock = os.clock()
	local camX, camY, camZ = spGetCameraPosition()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)
	gl.PushMatrix()

	for cmdKey, cmdValue in pairs(commands) do

		local duration		= types[cmdValue.cmdType].duration * generalDuration
		local durationProcess = (osClock - cmdValue.osClock) / duration

		-- remove when duration has passed
		if osClock - cmdValue.osClock > duration  then
			commands[cmdKey] = nil

		-- draw all
		elseif  types[cmdValue.cmdType].baseColor[4] > 0 then
			local size = generalSize * types[cmdValue.cmdType].size   +   ((generalSize * types[cmdValue.cmdType].endSize - generalSize * types[cmdValue.cmdType].size) * durationProcess)
			local a = (1 - durationProcess) * generalOpacity
			local baseColor = types[cmdValue.cmdType].baseColor
			a = a * baseColor[4]

			gl.Translate(cmdValue.x, cmdValue.y, cmdValue.z)

			local camDistance = diag(camX-cmdValue.x, camY-cmdValue.y, camZ-cmdValue.z)

			-- set scale   (based on camera distance)
			local scale = 1
			if scaleWithCamera and camZ then
				scale = 0.82 + camDistance / 20000
				gl.Scale(scale,scale,scale)
			end

			-- base glow
			if baseColor[4] > 0 then
				gl.Color(baseColor[1],baseColor[2],baseColor[3],a)
				gl.Scale(size,1,size)
				glCallList(baseDlist)
				gl.Scale(1/size,1,1/size)
			end
			if scaleWithCamera and camZ then
				gl.Scale(1/scale,1/scale,1/scale)
			end
			gl.Translate(-cmdValue.x, -cmdValue.y, -cmdValue.z)
		end
	end

	gl.PopMatrix()
end

