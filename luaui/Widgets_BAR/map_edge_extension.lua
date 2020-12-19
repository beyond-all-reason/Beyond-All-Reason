
function widget:GetInfo()
  return {
    name      = "Map Edge Extension Old",
    version   = "v0.6",
    desc      = "Draws a mirrored map next to the edges of the real map",
    author    = "Pako",
    date      = "2010.10.27",
    license   = "GPL",
    layer     = 0,
    enabled   = true,
    --detailsDefault = 3
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local brightness = 0.3
local curvature = true
local fogEffect = true
local drawForIslands = true

local mapBorderStyle = 'texture'	-- either 'texture' or 'cutaway'

local gridSize = 32
local useShader = true
local wiremap = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetGroundHeight = Spring.GetGroundHeight
local spTraceScreenRay = Spring.TraceScreenRay

local gridTex = "LuaUI/Images/vr_grid_large.dds"
local realTex = '$grass'

local dList
local mirrorShader

local umirrorX
local umirrorZ
local ulengthX
local ulengthZ
local uup
local uleft
local ugrid
local ubrightness
local spIsAABBInView = Spring.IsAABBInView
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local isInView = true

local island = nil -- Later it will be checked and set to true of false
local voidGround = nil
local drawingEnabled = true
local borderMargin = 40
local checkInView = true
local restoreMapBorder = true

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function ResetWidget()
	if dList and not drawingEnabled then
		gl.DeleteList(dList)
	end
	if mirrorShader and not drawingEnabled then
		gl.DeleteShader(mirrorShader)
	end
	widget:Initialize()
end

--options = {
--	--when using shader the map is stored once in a DL and drawn 8 times with vertex mirroring and bending
--    --when not, the map is drawn mirrored 8 times into a display list
--	mapBorderStyle = {
--		type='radioButton',
--		name='Exterior Effect',
--		items = {
--			{name = 'Texture',  key = 'texture', desc = "Mirror the heightmap and texture.",              hotkey=nil},
--			{name = 'Grid',     key = 'grid',    desc = "Mirror the heightmap with grid texture.",        hotkey=nil},
--			{name = 'Cutaway',  key = 'cutaway', desc = "Draw the edge of the map with a cutaway effect", hotkey=nil},
--			{name = 'Disable',  key = 'disable', desc = "Draw no edge extension",                         hotkey=nil},
--		},
--		value = 'texture',  --default at start of widget is to be disabled!
--		OnChange = function(self)
--			Spring.SendCommands("mapborder " .. ((self.value == 'cutaway') and "1" or "0"))
--			drawingEnabled = (self.value == "texture") or (self.value == "grid")
--			ResetWidget()
--		end,
--	},
--}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local shaderTable
local function SetupShaderTable()
  shaderTable = {
	  uniform = {
		mirrorX = 0,
		mirrorZ = 0,
		lengthX = 0,
		lengthZ = 0,
		tex0 = 0,
		up = 0,
		left = 0,
		grid = 0,
		brightness = 1.0,
	  },
	  vertex = [[
		#line 155
		// Application to vertex shader
		uniform float mirrorX;
		uniform float mirrorZ;
		uniform float lengthX;
		uniform float lengthZ;
		uniform float left;
		uniform float up;

		out float fogFactor;
		out float alpha;

		void main()
		{
		gl_TexCoord[0]= gl_TextureMatrix[0]*gl_MultiTexCoord0;
		vec4 worldPos = gl_Vertex;
		worldPos.x = abs(mirrorX-worldPos.x);
		worldPos.z = abs(mirrorZ-worldPos.z);

		alpha = 1.0;
		#ifdef curvature
			if(mirrorX != 0.0) worldPos.y -= pow(abs(worldPos.x-left*mirrorX)/150.0, 2.0);
			if(mirrorZ != 0.0) worldPos.y -= pow(abs(worldPos.z-up*mirrorZ)/150.0, 2.0);
			alpha = 0.0;
			if(mirrorX != 0.0) alpha -= pow(abs(worldPos.x-left*mirrorX)/lengthX, 2.0);
			if(mirrorZ != 0.0) alpha -= pow(abs(worldPos.z-up*mirrorZ)/lengthZ, 2.0);
			alpha = 1.0 + (6.0 * (alpha + 0.18));
			alpha = clamp(alpha, 0.0, 1.0);
		#endif

		float ff = 20000.0;
		if((mirrorZ != 0.0 && mirrorX != 0.0))
		  ff=ff/(pow(abs(worldPos.z-up*mirrorZ)/150.0, 2.0)+pow(abs(worldPos.x-left*mirrorX)/150.0, 2.0)+2.0);
		else if(mirrorX != 0.0)
		  ff=ff/(pow(abs(worldPos.x-left*mirrorX)/150.0, 2.0)+2.0);
		else if(mirrorZ != 0.0)
		  ff=ff/(pow(abs(worldPos.z-up*mirrorZ)/150.0, 2.0)+2.0);

		gl_Position = gl_ModelViewProjectionMatrix * worldPos;
		//gl_Position.z+ff;

		fogFactor = 1.0;
		#ifdef edgeFog
			gl_ClipVertex = gl_ModelViewMatrix * worldPos;
			// emulate linear fog
			float fogCoord = length(gl_ClipVertex.xyz);
			fogFactor = (gl_Fog.end - fogCoord) * gl_Fog.scale; // gl_Fog.scale == 1.0 / (gl_Fog.end - gl_Fog.start)
			fogFactor = clamp(fogFactor, 0.0, 1.0);
		#endif

		worldPos = gl_Vertex;
		}
	  ]],
	  fragment = [[
		#line 209
		uniform float brightness;
		uniform float mirrorX;
		uniform float mirrorZ;
		uniform float lengthX;
		uniform float lengthZ;
		uniform float left;
		uniform float up;
		uniform int grid;
		uniform sampler2D tex0;

		in float fogFactor;
		in float alpha;

		const mat3 RGB2YCBCR = mat3(
			0.2126, -0.114572, 0.5,
			0.7152, -0.385428, -0.454153,
			0.0722, 0.5, -0.0458471);

		const mat3 YCBCR2RGB = mat3(
			1.0, 1.0, 1.0,
			0.0, -0.187324, 1.8556,
			1.5748, -0.468124, -5.55112e-17);


		void main()
		{
			gl_FragColor = texture2D(tex0, gl_TexCoord[0].xy);

			#if 1
				vec3 yCbCr = RGB2YCBCR * gl_FragColor.rgb;
				yCbCr.x = clamp(yCbCr.x * brightness, 0.0, 1.0);
				gl_FragColor.rgb = YCBCR2RGB * yCbCr;
			#else
				gl_FragColor.rgb *= brightness;
			#endif

			gl_FragColor = mix(gl_Fog.color, gl_FragColor, fogFactor);
			gl_FragColor.a = alpha;
		 }
		]],
  }
end


local function GetGroundHeight(x, z)
	return spGetGroundHeight(x,z)
end


local function IsVoidGround()
	local sampleDist = 512
	for i=1,Game.mapSizeX,sampleDist do
		-- top edge
		if select(2, Spring.GetGroundInfo(i,0)) == 'Space' then
			return true
		end
		-- bottom edge
		if select(2, Spring.GetGroundInfo(i,Game.mapSizeZ)) == 'Space' then
			return true
		end
	end
	for i=1,Game.mapSizeZ,sampleDist do
		-- left edge
		if select(2, Spring.GetGroundInfo(0,i)) == 'Space' then
			return true
		end
		-- right edge
		if select(2, Spring.GetGroundInfo(Game.mapSizeX,i)) == 'Space' then
			return true
		end
	end
	return false
end

local function IsIsland()
	local sampleDist = 512
	for i=1,Game.mapSizeX,sampleDist do
		-- top edge
		if GetGroundHeight(i, 0) > 0 then
			return false
		end
		-- bottom edge
		if GetGroundHeight(i, Game.mapSizeZ) > 0 then
			return false
		end
	end
	for i=1,Game.mapSizeZ,sampleDist do
		-- left edge
		if GetGroundHeight(0, i) > 0 then
			return false
		end
		-- right edge
		if GetGroundHeight(Game.mapSizeX, i) > 0 then
			return false
		end
	end
	return true
end

local function DrawMapVertices(useMirrorShader)

	local floor = math.floor
	local ceil = math.ceil
	local abs = math.abs

	gl.Color(1,1,1,1)

	local function doMap(dx,dz,sx,sz)
		local Scale = gridSize
		local sggh = Spring.GetGroundHeight
		local Vertex = gl.Vertex
		local glColor = gl.Color
		local TexCoord = gl.TexCoord
		local Normal = gl.Normal
		local GetGroundNormal = Spring.GetGroundNormal
		local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

		local sten = {0, floor(Game.mapSizeZ/Scale)*Scale, 0}--do every other strip reverse
		local xm0, xm1 = 0, 0
		local xv0, xv1 = 0,math.abs(dx)+sx
		local ind = 0
		local zv
		local h

		if not useMirrorShader then
		gl.TexCoord(0, sten[2]/Game.mapSizeZ)
		Vertex(xv1, sggh(0,sten[2]),abs(dz+sten[2])+sz)--start and end with a double vertex
		end

		for x=0,Game.mapSizeX-Scale,Scale do
			xv0, xv1 = xv1, abs(dx+x+Scale)+sx
			xm0, xm1 = xm1, xm1+Scale
			ind = (ind+1)%2
			for z=sten[ind+1], sten[ind+2], (1+(-ind*2))*Scale do
				zv = abs(dz+z)+sz
				TexCoord(xm0/mapSizeX, z/mapSizeZ)
       -- Normal(GetGroundNormal(xm0,z))
        h = sggh(xm0,z)
				Vertex(xv0,h,zv)
				TexCoord(xm1/mapSizeX, z/mapSizeZ)
        --Normal(GetGroundNormal(xm1,z))
				h = sggh(xm1,z)
				Vertex(xv1,h,zv)
			end
		end
		if not useMirrorShader then
			Vertex(xv1,h,zv)
		end
	end

	if useMirrorShader then
		doMap(0,0,0,0)
	else
		doMap(-Game.mapSizeX,-Game.mapSizeZ,-Game.mapSizeX,-Game.mapSizeZ)
		doMap(0,-Game.mapSizeZ,0,-Game.mapSizeZ)
		doMap(-Game.mapSizeX,-Game.mapSizeZ,Game.mapSizeX,-Game.mapSizeZ)

		doMap(-Game.mapSizeX,0,-Game.mapSizeX,0)
		doMap(-Game.mapSizeX,0,Game.mapSizeX,0)

		doMap(-Game.mapSizeX,-Game.mapSizeZ,-Game.mapSizeX,Game.mapSizeZ)
		doMap(0,-Game.mapSizeZ,0,Game.mapSizeZ)
		doMap(-Game.mapSizeX,-Game.mapSizeZ,Game.mapSizeX,Game.mapSizeZ)
	end
end

local function DrawOMap(useMirrorShader)
	gl.Blending(GL.SRC_ALPHA,GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(GL.LEQUAL)
        if mapBorderStyle == "texture" then
			gl.Texture(realTex)
		else
			gl.Texture(gridTex)
		end
	gl.BeginEnd(GL.TRIANGLE_STRIP,DrawMapVertices, useMirrorShader)
	gl.DepthTest(false)
	gl.Color(1,1,1,1)
	gl.Blending(GL.SRC_ALPHA,GL.ONE_MINUS_SRC_ALPHA)

	----draw map compass text
	gl.PushAttrib(GL.ALL_ATTRIB_BITS)
	gl.Texture(false)
	gl.DepthMask(false)
	gl.DepthTest(false)
	gl.Color(1,1,1,1)
	gl.PopAttrib()
	----
end


local maxGroundHeights = {top=0,bottom=0,left=0,right=0}
local minGroundHeights = {top=-50,bottom=-50,left=-50,right=-50}
function GetMaxGroundHeights()
	maxGroundHeights.topleft = spGetGroundHeight(0,0)
	maxGroundHeights.topright = spGetGroundHeight(Game.mapSizeX,0)
	maxGroundHeights.bottomleft = spGetGroundHeight(0,Game.mapSizeZ)
	maxGroundHeights.bottomright = spGetGroundHeight(Game.mapSizeX,Game.mapSizeZ)

	local sampleDist = 512
	for i=1,Game.mapSizeX,sampleDist do
		-- top edge
		if spGetGroundHeight(i, 0) > maxGroundHeights.top then
			maxGroundHeights.top = spGetGroundHeight(i,0)
		end
		if spGetGroundHeight(i, 0) < minGroundHeights.top then
			minGroundHeights.top = spGetGroundHeight(i,0)
		end
		-- bottom edge
		if spGetGroundHeight(i, Game.mapSizeZ) > maxGroundHeights.bottom then
			maxGroundHeights.bottom = spGetGroundHeight(i,0)
		end
		if spGetGroundHeight(i, Game.mapSizeZ) < minGroundHeights.bottom then
			minGroundHeights.bottom = spGetGroundHeight(i,0)
		end
	end
	for i=1,Game.mapSizeZ,sampleDist do
		-- left edge
		if spGetGroundHeight(0, i) > maxGroundHeights.left then
			maxGroundHeights.left = spGetGroundHeight(0,i)
		end
		if spGetGroundHeight(0, i) < minGroundHeights.left then
			minGroundHeights.left = spGetGroundHeight(0,i)
		end
		-- right edge
		if spGetGroundHeight(Game.mapSizeX, i) > maxGroundHeights.right then
			maxGroundHeights.right = spGetGroundHeight(Game.mapSizeX,i)
		end
		if spGetGroundHeight(Game.mapSizeX, i) < minGroundHeights.right then
			minGroundHeights.right = spGetGroundHeight(Game.mapSizeX,i)
		end
	end
	minGroundHeights.top = minGroundHeights.top - 50
	minGroundHeights.bottom = minGroundHeights.bottom - 50
	minGroundHeights.left = minGroundHeights.bottom - 50
	minGroundHeights.right = minGroundHeights.right - 50
	minGroundHeights.topleft = math.min(minGroundHeights.top, minGroundHeights.left)
	minGroundHeights.topright = math.min(minGroundHeights.top, minGroundHeights.right)
	minGroundHeights.bottomleft = math.min(minGroundHeights.bottom, minGroundHeights.left)
	minGroundHeights.bottomright = math.min(minGroundHeights.bottom, minGroundHeights.right)
end

function widget:Initialize()

	WG['mapedgeextension'] = {}
	WG['mapedgeextension'].getBrightness = function()
		return brightness
	end
	WG['mapedgeextension'].setBrightness = function(value)
		brightness = value
		ResetWidget()
	end
	WG['mapedgeextension'].getCurvature = function()
		return curvature
	end
	WG['mapedgeextension'].setCurvature = function(value)
		curvature = value
		ResetWidget()
	end

	if not drawingEnabled then
		return
	end

	Spring.SendCommands("mapborder " .. (mapBorderStyle == 'cutaway' and "1" or "0"))

	if island == nil then
		island = IsIsland()
	end
	if voidGround == nil then
		voidGround = IsVoidGround()
	end
	if island and voidGround then
		restoreMapBorder = false
		widgetHandler:RemoveWidget(self)
	end

	GetMaxGroundHeights()

	SetupShaderTable()
	Spring.SendCommands("luaui disablewidget External VR Grid")
	if gl.CreateShader and useShader then

		local defs = {
			"#version 150 compatibility \n",
			curvature and "#define curvature \n",
			fogEffect and "#define edgeFog \n",
		}
		shaderTable.definitions = defs

		mirrorShader = gl.CreateShader(shaderTable)
		if (mirrorShader == nil) then
			Spring.Log(widget:GetInfo().name, LOG.ERROR, "Map Edge Extension widget: mirror shader error: "..gl.GetShaderLog())
		end
	end
	if not mirrorShader then
		widget.DrawWorldPreUnit = function()
			if (not island) or drawForIslands then
				gl.DepthMask(true)
				--gl.Texture(tex)
				gl.CallList(dList)
				gl.Texture(false)
			end
		end
	else
		umirrorX = gl.GetUniformLocation(mirrorShader,"mirrorX")
		umirrorZ = gl.GetUniformLocation(mirrorShader,"mirrorZ")
		ulengthX = gl.GetUniformLocation(mirrorShader,"lengthX")
		ulengthZ = gl.GetUniformLocation(mirrorShader,"lengthZ")
		uup = gl.GetUniformLocation(mirrorShader,"up")
		uleft = gl.GetUniformLocation(mirrorShader,"left")
		ugrid = gl.GetUniformLocation(mirrorShader,"grid")
		ubrightness = gl.GetUniformLocation(mirrorShader,"brightness")
	end
	dList = gl.CreateList(DrawOMap, mirrorShader)
	--Spring.SetDrawGround(false)
end

function widget:Shutdown()
	if restoreMapBorder then
		Spring.SendCommands('mapborder '..(restoreMapBorder and '1' or '0'))
	end

	--Spring.SetDrawGround(true)
	gl.DeleteList(dList)
	if mirrorShader then
		gl.DeleteShader(mirrorShader)
	end
end

-- reset needed when waterlevel has changed by gadget (modoption)
local resetsec = 0
local resetted = false
local doWaterLevelCheck = false
if (Spring.GetModOptions() ~= nil and Spring.GetModOptions().map_waterlevel ~= 0) then
	doWaterLevelCheck = true
end

local inViewParts = {}
local groundHeightPoint = Spring.GetGroundHeight(0,0)
function widget:Update(dt)
	if (doWaterLevelCheck and not resetted) or (Spring.IsCheatingEnabled() and Spring.GetGroundHeight(0,0) ~= groundHeightPoint)then
		resetsec = resetsec + dt
		if resetsec > 1 then
			groundHeightPoint = Spring.GetGroundHeight(0,0)
			resetted = true
			ResetWidget()
		end
	end
	if checkInView then
		inViewParts.topleft = spIsAABBInView(-Game.mapSizeX,minGroundHeights.topleft,-Game.mapSizeZ, borderMargin,maxGroundHeights.topleft,borderMargin)
		inViewParts.topright = spIsAABBInView(Game.mapSizeX-borderMargin,minGroundHeights.topright,-Game.mapSizeZ, Game.mapSizeX*2,maxGroundHeights.topright,borderMargin)
		inViewParts.bottomleft = spIsAABBInView(-Game.mapSizeX,minGroundHeights.bottomleft,Game.mapSizeZ-borderMargin, borderMargin,maxGroundHeights.bottomleft,Game.mapSizeZ*2)
		inViewParts.bottomright = spIsAABBInView(Game.mapSizeX-borderMargin,minGroundHeights.bottomright,Game.mapSizeZ-borderMargin, Game.mapSizeX*2,maxGroundHeights.bottomright,Game.mapSizeZ*2)
		inViewParts.top = spIsAABBInView(-borderMargin,minGroundHeights.top,-Game.mapSizeZ, Game.mapSizeX+borderMargin,maxGroundHeights.top,borderMargin)
		inViewParts.bottom = spIsAABBInView(-borderMargin,minGroundHeights.bottom,Game.mapSizeZ*2, Game.mapSizeX+borderMargin,maxGroundHeights.bottom,Game.mapSizeZ-borderMargin)
		inViewParts.left = spIsAABBInView(-Game.mapSizeX,minGroundHeights.left,-borderMargin, 0,maxGroundHeights.left,Game.mapSizeZ)
		inViewParts.right = spIsAABBInView(Game.mapSizeX-borderMargin,minGroundHeights.right,-borderMargin, Game.mapSizeX*2,maxGroundHeights.right,Game.mapSizeZ)
		if	inViewParts.top or inViewParts.bottom or inViewParts.left or inViewParts.right or
			inViewParts.topleft or inViewParts.topright or inViewParts.bottomleft or inViewParts.bottomright then
			isInView = true
		else
			isInView = false
		end
	end
end

--local function DrawMyBox(minX,minY,minZ, maxX,maxY,maxZ)
--	gl.BeginEnd(GL.QUADS, function()
--		--// top
--		gl.Vertex(minX, maxY, minZ);
--		gl.Vertex(maxX, maxY, minZ);
--		gl.Vertex(maxX, maxY, maxZ);
--		gl.Vertex(minX, maxY, maxZ);
--		--// bottom
--		gl.Vertex(minX, minY, minZ);
--		gl.Vertex(minX, minY, maxZ);
--		gl.Vertex(maxX, minY, maxZ);
--		gl.Vertex(maxX, minY, minZ);
--	end);
--	gl.BeginEnd(GL.QUAD_STRIP, function()
--		--// sides
--		gl.Vertex(minX, minY, minZ);
--		gl.Vertex(minX, maxY, minZ);
--		gl.Vertex(minX, minY, maxZ);
--		gl.Vertex(minX, maxY, maxZ);
--		gl.Vertex(maxX, minY, maxZ);
--		gl.Vertex(maxX, maxY, maxZ);
--		gl.Vertex(maxX, minY, minZ);
--		gl.Vertex(maxX, maxY, minZ);
--		gl.Vertex(minX, minY, minZ);
--		gl.Vertex(minX, maxY, minZ);
--	end);
--end
--function widget:DrawWorld()
--	--gl.Color(1,0,0,0.5)
--	--DrawMyBox(-9999,0,-9999, borderMargin,1,borderMargin)
--	--gl.Color(1,0,1,0.5)
--	--DrawMyBox(Game.mapSizeX-borderMargin,0,-9999, Game.mapSizeX*2,1,borderMargin)
--	--gl.Color(1,1,0,0.5)
--	--DrawMyBox(-9999,0,Game.mapSizeZ-borderMargin, borderMargin,1,Game.mapSizeZ*2)
--	--gl.Color(1,1,1,0.5)
--	--DrawMyBox(Game.mapSizeX-borderMargin,0,Game.mapSizeZ-borderMargin, Game.mapSizeX*2,1,Game.mapSizeZ*2)
--
--	--gl.Color(1,0,0,0.5)
--	--DrawMyBox(-9999,0,-9999, Game.mapSizeX*2,1,borderMargin)
--	--gl.Color(1,1,0,0.5)
--	--DrawMyBox(-9999,0,-borderMargin, 0,1,Game.mapSizeZ)
--	--gl.Color(0,1,0,0.5)
--	--DrawMyBox(Game.mapSizeX-borderMargin,0,-borderMargin, Game.mapSizeX*2,1,Game.mapSizeZ)
--	--gl.Color(0,0,1,0.5)
--	--DrawMyBox(-9999,0,Game.mapSizeZ*2, Game.mapSizeX*2,1,Game.mapSizeZ-borderMargin)
--	--gl.Color(1,1,1,1)
--end


local function DrawWorldFunc() --is overwritten when not using the shader
    if (not island) or drawForIslands then
        local glTranslate = gl.Translate
        local glUniform = gl.Uniform
        local GamemapSizeZ, GamemapSizeX = Game.mapSizeZ,Game.mapSizeX

		gl.Fog(true)
		gl.UseShader(mirrorShader)
		gl.PushMatrix()
		gl.DepthMask(true)
		if mapBorderStyle == "texture" then
			gl.Texture(realTex)
			glUniform(ubrightness, brightness)
			glUniform(ugrid, 0)
		else
			gl.Texture(gridTex)
			glUniform(ubrightness, 1.0)
			glUniform(ugrid, 1)
		end
		if wiremap then
			gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
		end
		glUniform(umirrorX, GamemapSizeX)
		glUniform(umirrorZ, GamemapSizeZ)
		glUniform(ulengthX, GamemapSizeX)
		glUniform(ulengthZ, GamemapSizeZ)
		glUniform(uleft, 1)
		glUniform(uup, 1)
		glTranslate(-GamemapSizeX,0,-GamemapSizeZ)
		if inViewParts.topleft then
			gl.CallList(dList)
		end
		glUniform(uleft , 0)
		glTranslate(GamemapSizeX*2,0,0)
		if inViewParts.topright then
			gl.CallList(dList)
		end
		glUniform(uup, 0)
		glTranslate(0,0,GamemapSizeZ*2)
		if inViewParts.bottomright then
			gl.CallList(dList)
		end
		glUniform(uleft, 1)
		glTranslate(-GamemapSizeX*2,0,0)
		if inViewParts.bottomleft then
			gl.CallList(dList)
		end

		glUniform(umirrorX, 0)
		glTranslate(GamemapSizeX,0,0)
		if inViewParts.bottom then
			gl.CallList(dList)
		end
		glUniform(uleft, 0)
		glUniform(uup, 1)
		glTranslate(0,0,-GamemapSizeZ*2)
		if inViewParts.top then
			gl.CallList(dList)
		end

		glUniform(uup, 0)
		glUniform(umirrorZ, 0)
		glUniform(umirrorX, GamemapSizeX)
		glTranslate(GamemapSizeX,0,GamemapSizeZ)
		if inViewParts.right then
			gl.CallList(dList)
		end
		glUniform(uleft, 1)
		glTranslate(-GamemapSizeX*2,0,0)
		if inViewParts.left then
			gl.CallList(dList)
		end
		if wiremap then
			gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
		end
		gl.DepthMask(false)
		gl.Texture(false)
		gl.PopMatrix()
		gl.UseShader(0)

		gl.Fog(false)
    end
end

function widget:DrawWorldPreUnit()
	if drawingEnabled and isInView then
		DrawWorldFunc()
	end
end
function widget:DrawWorldRefraction()
	if drawingEnabled and isInView then
		DrawWorldFunc()
	end
end


function widget:GetConfigData(data)
	return {
		brightness = brightness,
		curvature = curvature,
		fogEffect = fogEffect
	}
end


function widget:SetConfigData(data)
	if data.brightness ~= nil then
		brightness = data.brightness
	end
	if data.curvature ~= nil then
		curvature = data.curvature
	end
	if data.fogEffect ~= nil then
		fogEffect = data.fogEffect
	end
end
