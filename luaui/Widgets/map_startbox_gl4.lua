--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    minimap_startbox.lua
--  brief:   shows the startboxes in the minimap
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Start Boxes GL4",
		desc = "Displays Start Boxes and Start Points",
		author = "trepan, jK, Beherith GL4",
		date = "2007-2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if Game.startPosType ~= 2 then
	--return false
end

if Spring.GetGameFrame() > 1 then
	--widgetHandler:RemoveWidget(self)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  config options
--

-- enable simple version by default though
local drawGroundQuads = true

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = 0.5 + (vsx * vsy / 5700000)
local fontfileSize = 50
local fontfileOutlineSize = 8
local fontfileOutlineStrength = 1.65
local fontfileOutlineStrength2 = 10
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
local shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.5)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength2)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local useThickLeterring = false
local heightOffset = 50
local fontSize = 18
local fontShadow = true        -- only shows if font has a white outline
local shadowOpacity = 0.35

local infotext = Spring.I18N('ui.startSpot.anywhere')
local infotextBoxes = Spring.I18N('ui.startSpot.startbox')
local infotextFontsize = 13

local comnameList = {}
local drawShadow = fontShadow
local usedFontSize = fontSize

local widgetScale = (1 + (vsx * vsy / 5500000))

local gl = gl  --  use a local copy for faster access

local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local xformList = 0
local startboxDListStencil = 0
local startboxDListColor = 0

local isSpec = Spring.GetSpectatingState() or Spring.IsReplay()
local myTeamID = Spring.GetMyTeamID()

local placeVoiceNotifTimer = false
local amPlaced = false

local gaiaTeamID
local gaiaAllyTeamID

local startTimer = Spring.GetTimer()

local texName = LUAUI_DIRNAME .. 'Images/highlight_strip.png'
local texScale = 512

local infotextList, chobbyInterface

local GetUnitTeam = Spring.GetUnitTeam
local GetTeamInfo = Spring.GetTeamInfo
local GetPlayerInfo = Spring.GetPlayerInfo
local GetPlayerList = Spring.GetPlayerList
local GetTeamColor = Spring.GetTeamColor
local GetVisibleUnits = Spring.GetVisibleUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetAllUnits = Spring.GetAllUnits
local IsUnitInView = Spring.IsUnitInView
local GetCameraPosition = Spring.GetCameraPosition
local GetUnitPosition = Spring.GetUnitPosition
local GetFPS = Spring.GetFPS

local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glDepthTest = gl.DepthTest
local glAlphaTest = gl.AlphaTest
local glColor = gl.Color
local glText = gl.Text
local glTranslate = gl.Translate
local glBillboard = gl.Billboard
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local glDrawListAtUnit = gl.DrawListAtUnit
local GL_GREATER = GL.GREATER
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local glBlending = gl.Blending
local glScale = gl.Scale

local glCreateList = gl.CreateList
local glBeginEnd = gl.BeginEnd
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList

--------------------------------------------------------------------------------

GL.KEEP = 0x1E00
GL.INCR_WRAP = 0x8507
GL.DECR_WRAP = 0x8508
GL.INCR = 0x1E02
GL.DECR = 0x1E03
GL.INVERT = 0x150A

local stencilBit1 = 0x01
local stencilBit2 = 0x10
local hasStartbox = false

--------------------------------------------------------------------------------
------ GL4 STUFF-----
--------------------------------------------------------------------------------
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")
local coneShader = nil
local coneInstanceVBO = nil
local coneVAO = nil
local coneSegments = 32

local minimapRectShader = nil
local minimapRectInstanceVBO = nil
local minimapRectVAO = nil

local minimapCircleShader = nil
local minimapCircleInstanceVBO = nil
local minimapCircleVAO = nil
local minimapCircleSegments = 32

local rectShader = nil
local rectInstanceVBO = nil
local rectVAO = nil



local conevsSrc = [[
#version 420
#line 10000
layout (location = 0) in vec4 localpos_progress;
layout (location = 1) in vec4 worldposscale;
layout (location = 2) in vec4 color;

out DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000
void main() {
	vec3 newWorldPos = localpos_progress.xyz + worldposscale.xyz;
	blendedcolor = color;
	localpos = localpos_progress;
	gl_Position = cameraViewProj * vec4(newWorldPos, 1.0);
}
]]

local conefsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D perlin;

in DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

out vec4 fragColor;

#line 20000
void main() {
	vec4 perlinnoise = texture(perlin, vec2(localpos.w + 0.1*blendedcolor.a, localpos.y*0.005 +  0.5*blendedcolor.a ));
	float second01 = fract(blendedcolor.a*2.0);
	second01 = sin(blendedcolor.b+localpos.y*0.08-localpos.w*6.2831)*0.3+0.5;
	float second02 = sin(blendedcolor.a+localpos.y*0.08+localpos.w*6.2831)*0.3+0.5;
	// this is pretty much a screw you to anyone who reads this
	float lightning = clamp(1.0- abs(perlinnoise.b-second01)*8,0.0,1.0);
	lightning = clamp(1.0- abs(perlinnoise.a-second02)*8,lightning,1.0);
	fragColor = mix(blendedcolor,vec4(1.0),lightning*lightning*lightning*lightning*lightning*lightning);
	fragColor.a = lightning	;

	if (fragColor.a < 0.05) discard;
}
]]

local rectvsSrc = [[
#version 420
#line 10000
layout (location = 0) in vec4 localpos_progress;
layout (location = 1) in vec4 startpos;
layout (location = 2) in vec4 endpos;
layout (location = 3) in vec4 color;

out DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000
void main() {
	vec3 newWorldPos = localpos_progress.xyz * (endpos.xyz - startpos.xyz) + startpos.xyz;  
	blendedcolor = color;
	localpos = localpos_progress;
	gl_Position = cameraViewProj * vec4(newWorldPos.xyz, 1.0);
}
]]

local rectfsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

out vec4 fragColor;

#line 20000
void main() {
	//float decoralpha = fract(blendedcolor.a*50 - timeInfo.y);
	fragColor = blendedcolor;
}
]]

local minimaprectvsSrc = [[
#version 420
#line 10000
layout (location = 0) in vec4 localpos_progress;
layout (location = 1) in vec4 startpos;
layout (location = 2) in vec4 endpos;
layout (location = 3) in vec4 color;

out DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000
void main() {
	vec3 newWorldPos = localpos_progress.xyz * (endpos.xyz - startpos.xyz) + startpos.xyz;  
	blendedcolor = color;
	localpos = localpos_progress;
	gl_Position = cameraViewProj * vec4(newWorldPos.xyz, 1.0);
}
]]

local minimaprectfsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

out vec4 fragColor;

#line 20000
void main() {
	//float decoralpha = fract(blendedcolor.a*50 - timeInfo.y);
	fragColor = blendedcolor;
}
]]

local minimapcirclevsSrc = [[
#version 420
#line 10000
layout (location = 0) in vec4 localpos_progress;
layout (location = 1) in vec4 startpos;
layout (location = 2) in vec4 endpos;
layout (location = 3) in vec4 color;

out DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000
void main() {
	vec3 newWorldPos = localpos_progress.xyz * (endpos.xyz - startpos.xyz) + startpos.xyz;  
	blendedcolor = color;
	localpos = localpos_progress;
	gl_Position = cameraViewProj * vec4(newWorldPos.xyz, 1.0);
}
]]

local minimapcirclefsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 blendedcolor;
	vec4 localpos;
};

out vec4 fragColor;

#line 20000
void main() {
	//float decoralpha = fract(blendedcolor.a*50 - timeInfo.y);
	fragColor = blendedcolor;
}
]]

local function goodbye(reason)
  Spring.Echo("Map Startbox GL4 widget exiting with reason: "..reason)
  gadgetHandler:RemoveGadget(self)
end

local function makeShaders()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	coneShader =  LuaShader(
		{
			vertex = conevsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			fragment =  conefsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		
		uniformInt = {
			perlin = 0,-- rgb + alpha
		},
		},
		"coneShader GL4"
	)
	local shaderCompiled = coneShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile coneShader GL4 ") end
	
	minimapRectShader =  LuaShader(
		{
			vertex = minimaprectvsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			fragment =  minimaprectfsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		},
		"minimapRectShader GL4"
	)
	shaderCompiled = minimapRectShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile minimapRectShader GL4 ") end
	
	minimapCircleShader =  LuaShader(
		{
			vertex = minimapcirclevsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			fragment =  minimapcirclefsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			uniformFloat = {
				pointsizes = {1,1,1,1},
			},
		},
		"minimapCircleShader GL4"
	)
	shaderCompiled = minimapCircleShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile rectShader GL4 ") end
	
	rectShader =  LuaShader(
		{
			vertex = rectvsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			fragment =  rectfsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),

		},
		"rectShader GL4"
	)
	shaderCompiled = rectShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile rectShader GL4 ") end
end


local function initGL4()
	coneInstanceVBO = makeInstanceVBOTable({
		{id = 1, name = 'worldposscale', size = 4},
		{id = 2, name = 'color', size = 4},
		}, 16, "coneInstanceVBO")
	local coneVBO, numVertices = makeConeVBO(64, 3000, 25) --numsegments, height, radius
	coneInstanceVBO.vertexVBO = coneVBO
	coneInstanceVBO.numVertices = numVertices
	coneInstanceVBO.VAO = makeVAOandAttach(coneInstanceVBO.vertexVBO,coneInstanceVBO.instanceVBO)
	
	rectInstanceVBO = makeInstanceVBOTable({
		{id = 1, name = 'startpos', size = 4},
		{id = 2, name = 'endpos', size = 4},
		{id = 3, name = 'color', size = 4},
	}, 16, "rectInstanceVBO")
	local rectVBO, numVertices = makeBoxVBO(0,0,0,1,1,1) --minXZY, maxXYZ
	rectInstanceVBO.vertexVBO = rectVBO
	rectInstanceVBO.numVertices = numVertices
	rectInstanceVBO.VAO = makeVAOandAttach(rectInstanceVBO.vertexVBO,rectInstanceVBO.instanceVBO)
	
	minimapRectInstanceVBO = makeInstanceVBOTable({
		{id = 1, name = 'startend', size = 4},
		{id = 3, name = 'color', size = 4},
	}, 16, "minimapRectInstanceVBO")
	local minimaprectVBO, numVertices = makeRectVBO() --minXZY, maxXYZ
	minimapRectInstanceVBO.vertexVBO = minimaprectVBO
	minimapRectInstanceVBO.numVertices = numVertices
	minimapRectInstanceVBO.VAO = makeVAOandAttach(minimapRectInstanceVBO.vertexVBO,minimapRectInstanceVBO.instanceVBO)
	
	minimapCircleInstanceVBO = makeInstanceVBOTable({
		{id = 1, name = 'centerpossize', size = 4},
		{id = 3, name = 'color', size = 4},
	}, 16, "minimapCircleInstanceVBO")
	local minimapCircleVBO, numVertices = makeCircleVBO(minimapCircleSegments) --minXZY, maxXYZ
	minimapCircleInstanceVBO.vertexVBO = minimapCircleVBO
	minimapCircleInstanceVBO.numVertices = numVertices
	minimapCircleInstanceVBO.VAO = makeVAOandAttach(minimapCircleInstanceVBO.vertexVBO,minimapCircleInstanceVBO.instanceVBO)
	
	
	-- add testing examples
	
	pushElementInstance(coneInstanceVBO,{
		500,500,500,0,
		1.0,0.0,1.0,0.2
		},"testid")
	
	pushElementInstance(rectInstanceVBO,{ 
		1000,0,1000.0,0,
		1200.0,200.0,1200.0,0.0,
		1.0,1.0,0.0, 0.2
		},"testid")
	
	
	pushElementInstance(minimapRectInstanceVBO,{ 
		0.25,0.25,0.75,0.75,
		1.0, 0.0, 1.0, 0.5,
		},"testid")
		
	pushElementInstance(minimapCircleInstanceVBO,{ 
		0.5,0.5,0.5,10,
		1.0, 0.0, 1.0, 0.5,
		},"testidw")
	
	pushElementInstance(minimapCircleInstanceVBO,{ 
		0.5,0.5,0.2,15,
		0.0, 1.0, 0.0, 1.0,
		},"testidl")
	
	makeShaders()
	
	
end




----- Old Stuff ---- 
function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

local function DrawMyBox(minX, minY, minZ, maxX, maxY, maxZ)
	gl.BeginEnd(GL.QUADS, function()
		--// top
		gl.Vertex(minX, maxY, minZ);
		gl.Vertex(maxX, maxY, minZ);
		gl.Vertex(maxX, maxY, maxZ);
		gl.Vertex(minX, maxY, maxZ);
		--// bottom
		gl.Vertex(minX, minY, minZ);
		gl.Vertex(minX, minY, maxZ);
		gl.Vertex(maxX, minY, maxZ);
		gl.Vertex(maxX, minY, minZ);
	end);
	gl.BeginEnd(GL.QUAD_STRIP, function()
		--// sides
		gl.Vertex(minX, minY, minZ);
		gl.Vertex(minX, maxY, minZ);
		gl.Vertex(minX, minY, maxZ);
		gl.Vertex(minX, maxY, maxZ);
		gl.Vertex(maxX, minY, maxZ);
		gl.Vertex(maxX, maxY, maxZ);
		gl.Vertex(maxX, minY, minZ);
		gl.Vertex(maxX, maxY, minZ);
		gl.Vertex(minX, minY, minZ);
		gl.Vertex(minX, maxY, minZ);
	end);
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function createComnameList(x, y, name, teamID, color)
	comnameList[teamID] = {}
	comnameList[teamID]['x'] = math.floor(x)
	comnameList[teamID]['y'] = math.floor(y)
	comnameList[teamID]['list'] = gl.CreateList(function()
		local outlineColor = { 0, 0, 0, 1 }
		if (color[1] + color[2] * 1.2 + color[3] * 0.4) < 0.68 then
			outlineColor = { 1, 1, 1, 1 }
		end
		if useThickLeterring then
			if outlineColor[1] == 1 and fontShadow then
				glTranslate(0, -(usedFontSize / 44), 0)
				shadowFont:Begin()
				shadowFont:SetTextColor({ 0, 0, 0, shadowOpacity })
				shadowFont:SetOutlineColor({ 0, 0, 0, shadowOpacity })
				shadowFont:Print(name, x, y, usedFontSize, "con")
				shadowFont:End()
				glTranslate(0, (usedFontSize / 44), 0)
			end
			font2:Begin()
			font2:SetTextColor(outlineColor)
			font2:SetOutlineColor(outlineColor)

			font2:Print(name, x - (usedFontSize / 38), y - (usedFontSize / 33), usedFontSize, "con")
			font2:Print(name, x + (usedFontSize / 38), y - (usedFontSize / 33), usedFontSize, "con")
			font2:End()
		end
		font2:Begin()
		font2:SetTextColor(color)
		font2:SetOutlineColor(outlineColor)
		font2:Print(name, x, y, usedFontSize, "con")
		font2:End()
	end)
end

local function DrawName(x, y, name, teamID, color)
	-- not optimal, everytime you move camera the x and y are different so it has to recreate the drawlist
	if comnameList[teamID] == nil or comnameList[teamID]['x'] ~= math.floor(x) or comnameList[teamID]['y'] ~= math.floor(y) then
		-- using floor because the x and y values had a a tiny change each frame
		if comnameList[teamID] ~= nil then
			gl.DeleteList(comnameList[teamID]['list'])
		end
		createComnameList(x, y, name, teamID, color)
	end
	glCallList(comnameList[teamID]['list'])
end

function createInfotextList()
	if infotextList then
		gl.DeleteList(infotextList)
	end
	infotextList = gl.CreateList(function()
		font:Begin()
		font:SetTextColor(0.9, 0.9, 0.9, 1)
		font:Print(hasStartbox and infotextBoxes or infotext, 0, 0, infotextFontsize * widgetScale, "cno")
		font:End()
	end)
end

function widget:Initialize()
	initGL4()
	-- only show at the beginning
	if (Spring.GetGameFrame() > 1) then
		--widgetHandler:RemoveWidget(self)
		--return
	end

	-- get the gaia teamID and allyTeamID
	gaiaTeamID = Spring.GetGaiaTeamID()
	if (gaiaTeamID) then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	end

	-- flip and scale  (using x & y for gl.Rect())
	xformList = gl.CreateList(function()
		gl.LoadIdentity()
		gl.Translate(0, 1, 0)
		gl.Scale(1 / msx, -1 / msz, 1)
	end)

	
	if (drawGroundQuads) then
			local minY, maxY = Spring.GetGroundExtremes()
			minY = minY - 200;
			maxY = maxY + 500;

	for _, at in ipairs(Spring.GetAllyTeamList()) do
		if (true or at ~= gaiaAllyTeamID) then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
			if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then
				local color = {1,0,0,0.2}
				if (at == Spring.GetMyAllyTeamID()) then
					color = {0,1,0,0.2}
				end
				pushElementInstance(rectInstanceVBO,{ 
					xn-1,minY,zn-1,0,
					xp+1,maxY,zp+1,0.0,
					color[1],color[2],color[3],color[4],
				},at)
	
	makeShaders()
				
			end
		end
	end
	
	
	
		startboxDListStencil = gl.CreateList(function()
			local minY, maxY = Spring.GetGroundExtremes()
			minY = minY - 200;
			maxY = maxY + 500;
			for _, at in ipairs(Spring.GetAllyTeamList()) do
				if (true or at ~= gaiaAllyTeamID) then
					local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
					if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then

						if (at == Spring.GetMyAllyTeamID()) then
							gl.StencilMask(stencilBit2);
							gl.StencilFunc(GL.ALWAYS, 0, stencilBit2);
						else
							gl.StencilMask(stencilBit1);
							gl.StencilFunc(GL.ALWAYS, 0, stencilBit1);
						end
						DrawMyBox(xn - 1, minY, zn - 1, xp + 1, maxY, zp + 1)
						
					end
				end
			end
		end)

		startboxDListColor = gl.CreateList(function()
			local minY, maxY = Spring.GetGroundExtremes()
			minY = minY - 200;
			maxY = maxY + 500;
			for _, at in ipairs(Spring.GetAllyTeamList()) do
				if (true or at ~= gaiaAllyTeamID) then
					local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
					if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then

						if (at == Spring.GetMyAllyTeamID()) then
							gl.Color(0, 1, 0, 0.22)  --  green
							gl.StencilMask(stencilBit2);
							gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit2);
							hasStartbox = true
						else
							gl.Color(1, 0, 0, 0.22)  --  red
							gl.StencilMask(stencilBit1);
							gl.StencilFunc(GL.NOTEQUAL, 0, stencilBit1);
						end
						DrawMyBox(xn - 1, minY, zn - 1, xp + 1, maxY, zp + 1)

					end
				end
			end
		end)
	end

	createInfotextList()
end

function removeLists()
	gl.DeleteList(infotextList)
	gl.DeleteList(xformList)
	gl.DeleteList(startboxDListStencil)
	gl.DeleteList(startboxDListColor)
	removeTeamLists()
end

function widget:Shutdown()
	removeLists()
	gl.DeleteFont(font)
	gl.DeleteFont(shadowFont)
end

function removeTeamLists()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if comnameList[teamID] ~= nil then
			gl.DeleteList(comnameList[teamID].list)
		end
	end
	comnameList = {}
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local teamColors = {}

local function GetTeamColor(teamID)
	local color = teamColors[teamID]
	if (color) then
		return color
	end
	local r, g, b = Spring.GetTeamColor(teamID)

	color = { r, g, b }
	teamColors[teamID] = color
	return color
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local teamColorStrs = {}

local function GetTeamColorStr(teamID)
	local colorSet = teamColorStrs[teamID]
	if (colorSet) then
		return colorSet[1], colorSet[2]
	end

	local outlineChar = ''
	local r, g, b = Spring.GetTeamColor(teamID)
	if (r and g and b) then
		local function ColorChar(x)
			local c = math.floor(x * 255)
			c = ((c <= 1) and 1) or ((c >= 255) and 255) or c
			return string.char(c)
		end
		local colorStr
		colorStr = '\255'
		colorStr = colorStr .. ColorChar(r)
		colorStr = colorStr .. ColorChar(g)
		colorStr = colorStr .. ColorChar(b)
		local i = (r * 0.299) + (g * 0.587) + (b * 0.114)
		outlineChar = ((i > 0.25) and 'o') or 'O'
		teamColorStrs[teamID] = { colorStr, outlineChar }
		return colorStr, "s", outlineChar
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawStartboxes3dWithStencil()
	gl.DepthMask(false);
	if (gl.DepthClamp) then
		gl.DepthClamp(true);
	end

	gl.DepthTest(true);
	gl.StencilTest(true);
	gl.ColorMask(false, false, false, false);
	gl.Culling(false);

	gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP);

	gl.CallList(startboxDListStencil);   --// draw

	gl.Culling(GL.BACK);
	gl.DepthTest(false);

	gl.ColorMask(true, true, true, true);

	gl.CallList(startboxDListColor);   --// draw

	if (gl.DepthClamp) then
		gl.DepthClamp(false);
	end
	gl.StencilTest(false);
	gl.DepthTest(true);
	gl.Culling(false);
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawWorld()

	gl.StencilMask(stencilBit2);
	gl.StencilFunc(GL.ALWAYS, 0, stencilBit2);
			

	gl.DepthMask(false);
	if (gl.DepthClamp) then
		gl.DepthClamp(true);
	end

	gl.DepthTest(true);
	gl.StencilTest(true);
	gl.ColorMask(false, false, false, false);
	gl.Culling(false);

	gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP);

	rectShader:Activate()
	rectInstanceVBO.VAO:DrawArrays(GL.TRIANGLES,rectInstanceVBO.numVertices,0,rectInstanceVBO.usedElements,0)
	rectShader:Deactivate()

	gl.Culling(GL.BACK);
	gl.DepthTest(false);

	gl.ColorMask(true, true, true, true);

	rectShader:Activate()
	rectInstanceVBO.VAO:DrawArrays(GL.TRIANGLES,rectInstanceVBO.numVertices,0,rectInstanceVBO.usedElements,0)
	rectShader:Deactivate()

	if (gl.DepthClamp) then
		gl.DepthClamp(false);
	end
	gl.StencilTest(false);
	gl.DepthTest(true);
	gl.Culling(false);
			
			
	rectShader:Activate()
	rectInstanceVBO.VAO:DrawArrays(GL.TRIANGLES,rectInstanceVBO.numVertices,0,rectInstanceVBO.usedElements,0)
	rectShader:Deactivate()

	--gl.Fog(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	local ostime = Spring.DiffTimers(Spring.GetTimer(), startTimer)

	-- show the ally startboxes
	DrawStartboxes3dWithStencil()

	-- show the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, spec = Spring.GetPlayerInfo(select(2, Spring.GetTeamInfo(teamID, false)), false)
		if ((not spec) and (teamID ~= gaiaTeamID)) then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			--if y < 0 then
			--  y = 0
			--end
			local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
			if (x ~= nil and x > 0 and z > 0 and y > -500) and not isNewbie then
				local color = GetTeamColor(teamID)
				local alpha = 0.5 + math.abs(((ostime * 3) % 1) - 0.5)
				pushElementInstance(coneInstanceVBO, {x,y-10,z,0, color[1],color[2],color[3],ostime}, teamID,true,true) -- first use of noupload :)
				if teamID == myTeamID then
					amPlaced = true
				end
			end
		end
	end
		
	uploadAllElements(coneInstanceVBO)
	--Spring.Echo("Cones:",coneInstanceVBO.usedElements)
	gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Texture(0, "LuaUI/Images/perlin_noise_rgba_512.png")
	coneShader:Activate()
	coneInstanceVBO.VAO:DrawArrays(GL.TRIANGLES,coneInstanceVBO.numVertices,0,coneInstanceVBO.usedElements,0)
	coneShader:Deactivate()
	gl.Texture(0, false)
	
	
    gl.DepthTest(GL.ALWAYS)
    gl.DepthMask(false)

	--gl.Fog(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreenEffects()
	-- show the names over the team start positions
	--gl.Fog(false)
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local name, _, spec = Spring.GetPlayerInfo(select(2, Spring.GetTeamInfo(teamID, false)), false)
		local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
		if (name ~= nil) and ((not spec) and (teamID ~= gaiaTeamID)) and not isNewbie then
			local colorStr, outlineStr = GetTeamColorStr(teamID)
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			if (x ~= nil and x > 0 and z > 0 and y > -500) then
				local sx, sy, sz = Spring.WorldToScreenCoords(x, y + 120, z)
				if (sz < 1) then

					DrawName(sx, sy, name, teamID, GetTeamColor(teamID))

				end
			end
		end
	end
	--gl.Fog(true)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end

	if not isSpec then
		gl.PushMatrix()
		gl.Translate(vsx / 2, vsy / 6.2, 0)
		gl.Scale(1 * widgetScale, 1 * widgetScale, 1)
		gl.CallList(infotextList)
		gl.PopMatrix()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawInMiniMap(sx, sz)
	-- only show at the beginning
	--if (Spring.GetGameFrame() > 1) then
	--	widgetHandler:RemoveWidget(self)
	--end

	gl.PushMatrix()
	gl.CallList(xformList)

	gl.LineWidth(1.49)

	local gaiaAllyTeamID
	local gaiaTeamID = Spring.GetGaiaTeamID()
	if (gaiaTeamID) then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	end

	-- show all start boxes
	for _, at in ipairs(Spring.GetAllyTeamList()) do
		if (at ~= gaiaAllyTeamID) then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
			if (xn and ((xn ~= 0) or (zn ~= 0) or (xp ~= msx) or (zp ~= msz))) then
				local color
				if (at == Spring.GetMyAllyTeamID()) then
					color = { 0, 1, 0, 0.1 }  --  green
				else
					color = { 1, 0, 0, 0.1 }  --  red
				end
				
				pushElementInstance(minimapRectInstanceVBO,{ 
					xn,zn,xp,zp,
					color[1],color[2],color[3],color[4],
				},at, true,true)
				
				--[[
				gl.Color(color)
				gl.Rect(xn, zn, xp, zp)
				color[4] = 0.5  --  pump up the volume
				gl.Color(color)
				gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
				gl.Rect(xn, zn, xp, zp)
				gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
				]]--
			end
		end
	end
	
	minimapRectShader:Activate()
	uploadAllElements(minimapRectInstanceVBO)
	minimapRectInstanceVBO.VAO:DrawArrays(GL.TRIANGLES,minimapRectInstanceVBO.numVertices,0,minimapRectInstanceVBO.usedElements,0)
	minimapRectShader:Deactivate()
	
	
	gl.PushAttrib(GL_HINT_BIT)
	--gl.Smoothing(true) --enable point smoothing

	-- show the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, spec = Spring.GetPlayerInfo(select(2, Spring.GetTeamInfo(teamID, false)), false)
		if ((not spec) and (teamID ~= gaiaTeamID)) then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			local isNewbie = (Spring.GetTeamRulesParam(teamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
			if (x ~= nil and x > 0 and z > 0 and y > -500) and not isNewbie then
				local color = GetTeamColor(teamID)
				local r, g, b = color[1], color[2], color[3]
				local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)
				local i = 2 * math.abs(((time * 3) % 1) - 0.5)
				--[[gl.PointSize(11)
				gl.Color(i, i, i)
				gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
				gl.PointSize(7.5)
				gl.Color(r, g, b)
				gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
				]]--
				pushElementInstance(minimapCircleInstanceVBO,{
						x,z,0.5,10,
						r,g,b,1.0
					}, teamID+256,true, true)
				pushElementInstance(minimapCircleInstanceVBO,{
						x,z,0.5,15,
						i,i,i,1.0
					}, teamID, true,true)
			end
		end
	end
	
	minimapCircleShader:Activate()
	uploadAllElements(minimapCircleInstanceVBO)
	minimapCircleInstanceVBO.VAO:DrawArrays(GL.TRIANGLE_FAN,minimapCircleInstanceVBO.numVertices,0,minimapCircleInstanceVBO.usedElements,0)
	minimapCircleShader:Deactivate()

	gl.LineWidth(1.0)
	gl.PointSize(1.0)
	gl.PopAttrib() --reset point smoothing
	gl.PopMatrix()
end

function widget:ViewResize(x, y)
	vsx, vsy = x, y
	widgetScale = (0.75 + (vsx * vsy / 7500000))
	removeTeamLists()
	usedFontSize = fontSize * widgetScale
	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		gl.DeleteFont(shadowFont)
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength2)
		shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.6)
		createInfotextList()
	end
end


-- reset needed when waterlevel has changed by gadget (modoption)
local resetsec = 0
local resetted = false
local doWaterLevelCheck = false
if (Spring.GetModOptions() ~= nil and Spring.GetModOptions().map_waterlevel ~= 0) then
	doWaterLevelCheck = true
end

local groundHeightPoint = Spring.GetGroundHeight(0, 0)
function widget:Update(dt)
	if not placeVoiceNotifTimer then
		placeVoiceNotifTimer = os.clock() + 20
	end

	if (doWaterLevelCheck and not resetted) or (Spring.IsCheatingEnabled() and Spring.GetGroundHeight(0, 0) ~= groundHeightPoint) then
		resetsec = resetsec + dt
		if resetsec > 1 then
			groundHeightPoint = Spring.GetGroundHeight(0, 0)
			resetted = true
			removeLists()
			widget:Initialize()
		end
	end
	if not isSpec and not amPlaced and placeVoiceNotifTimer < os.clock() and WG['notifications'] then
		WG['notifications'].addEvent('ChooseStartLoc')
		placeVoiceNotifTimer = os.clock() + 20
	end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
