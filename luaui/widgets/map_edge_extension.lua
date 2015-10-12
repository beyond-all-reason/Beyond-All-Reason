--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
  return {
    name      = "Map Edge Extension",
    version   = "v0.5",
    desc      = "Draws a mirrored map next to the edges of the real map",
    author    = "Pako",
    date      = "2010.10.27 - 2011.10.29", --YYYY.MM.DD, created - updated
    license   = "GPL",
    layer     = 0,
    enabled   = true,
    --detailsDefault = 3
  }
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if VFS.FileExists("nomapedgewidget.txt") then
	return
end

local spGetGroundHeight = Spring.GetGroundHeight
local spTraceScreenRay = Spring.TraceScreenRay
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local gridTex = "LuaUI/Images/vr_grid_large.dds"
--local gridTex = "bitmaps/PD/shield3hex.png"
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

local island = nil -- Later it will be checked and set to true of false
local drawingEnabled = true

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

options_path = 'Settings/Graphics/Map Exterior'
options_order = {'mapBorderStyle', 'drawForIslands', 'gridSize',  'fogEffect', 'curvature', 'textureBrightness', 'useShader'}
options = {
	--when using shader the map is stored once in a DL and drawn 8 times with vertex mirroring and bending
    --when not, the map is drawn mirrored 8 times into a display list
	mapBorderStyle = {
		type='radioButton', 
		name='Exterior Effect',
		items = {
			{name = 'Texture',  key = 'texture', desc = "Mirror the heightmap and texture.",              hotkey=nil},
			{name = 'Grid',     key = 'grid',    desc = "Mirror the heightmap with grid texture.",        hotkey=nil},
			{name = 'Cutaway',  key = 'cutaway', desc = "Draw the edge of the map with a cutaway effect", hotkey=nil},
			{name = 'Disable',  key = 'disable', desc = "Draw no edge extension",                         hotkey=nil},
		},
		value = 'grid',  --default at start of widget is to be disabled!
		OnChange = function(self)
			Spring.SendCommands("mapborder " .. ((self.value == 'cutaway') and "1" or "0"))
			drawingEnabled = (self.value == "texture") or (self.value == "grid") 
			ResetWidget()
		end,
	},
	drawForIslands = {
		name = "Draw for islands",
		type = 'bool',
		value = true,
		desc = "Draws mirror map when map is an island",		
	},
	useShader = {
		name = "Use shader",
		type = 'bool',
		value = true,
		advanced = true,
		desc = 'Use a shader when mirroring the map',
		OnChange = ResetWidget,
	},
	gridSize = {
		name = "Heightmap tile size",
		type = 'number',
		min = 32, 
		max = 512, 
		step = 32,
		value = 32,
		desc = '',
		OnChange = ResetWidget,
	},
	textureBrightness = {
		name = "Texture Brightness",
		advanced = true,
		type = 'number',
		min = 0, 
		max = 1, 
		step = 0.01,
		value = 0.27,
		desc = 'Sets the brightness of the realistic texture (doesn\'t affect the grid)',
		OnChange = ResetWidget,
	},
	fogEffect = {
		name = "Edge Fog Effect",
		type = 'bool',
		value = false,
		desc = 'Blurs the edges of the map slightly to distinguish it from the extension.',
		OnChange = ResetWidget,
	},
	curvature = {
		name = "Curvature Effect",
		type = 'bool',
		value = false,
		desc = 'Add a curvature to the extension.',
		OnChange = ResetWidget,
	},
	
}
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
	  vertex = (options.curvature.value and "#define curvature \n" or '')
		.. (options.fogEffect.value and "#define edgeFog \n" or '')
		.. [[
		// Application to vertex shader
		uniform float mirrorX;
		uniform float mirrorZ;
		uniform float lengthX;
	  uniform float lengthZ;
		uniform float left;
		uniform float up;
		uniform float brightness;

		varying vec4 vertex;
		varying vec4 color;
  
		void main()
		{
		gl_TexCoord[0]= gl_TextureMatrix[0]*gl_MultiTexCoord0;
		gl_Vertex.x = abs(mirrorX-gl_Vertex.x);
		gl_Vertex.z = abs(mirrorZ-gl_Vertex.z);
		
		float alpha = 1.0;
		#ifdef curvature
		  if(mirrorX)gl_Vertex.y -= pow(abs(gl_Vertex.x-left*mirrorX)/150.0, 2.0);
		  if(mirrorZ)gl_Vertex.y -= pow(abs(gl_Vertex.z-up*mirrorZ)/150.0, 2.0);
		  alpha = 0.0;
			if(mirrorX) alpha -= pow(abs(gl_Vertex.x-left*mirrorX)/lengthX, 2.0);
			if(mirrorZ) alpha -= pow(abs(gl_Vertex.z-up*mirrorZ)/lengthZ, 2.0);
			alpha = 1.0 + (6.0 * (alpha + 0.18));
		#endif
  
		float ff = 20000.0;
		if((mirrorZ && mirrorX))
		  ff=ff/(pow(abs(gl_Vertex.z-up*mirrorZ)/150.0, 2.0)+pow(abs(gl_Vertex.x-left*mirrorX)/150.0, 2.0)+2.0);
		else if(mirrorX)
		  ff=ff/(pow(abs(gl_Vertex.x-left*mirrorX)/150.0, 2.0)+2.0);
		else if(mirrorZ)
		  ff=ff/(pow(abs(gl_Vertex.z-up*mirrorZ)/150.0, 2.0)+2.0);
  
		gl_Position  = gl_ModelViewProjectionMatrix*gl_Vertex;
		//gl_Position.z+ff;
		
		#ifdef edgeFog
		  gl_FogFragCoord = length((gl_ModelViewMatrix * gl_Vertex).xyz)+ff; //see how Spring shaders do the fog and copy from there to fix this
		#endif
		
		gl_FrontColor = vec4(brightness * gl_Color.rgb, alpha);

		color = gl_FrontColor;
		vertex = gl_Vertex;
		}
	  ]],
	 --  fragment = [[
	 --  uniform float mirrorX;
	 --  uniform float mirrorZ;
	 --  uniform float lengthX;
	 --  uniform float lengthZ;
		-- uniform float left;
		-- uniform float up;
		-- uniform int grid;
		-- uniform sampler2D tex0;

		-- varying vec4 vertex;
		-- varying vec4 color;

		-- void main()
		-- {
		-- 	float alpha = 0.0;
		-- 	if(mirrorX) alpha -= pow(abs(vertex.x-left*mirrorX)/lengthX, 2);
		-- 	if(mirrorZ) alpha -= pow(abs(vertex.z-up*mirrorZ)/lengthZ, 2);
		-- 	alpha = 1.0 + (4.0 * (alpha + 0.28));
		-- 	gl_FragColor = vec4(mix(gl_Fog.color, color.rgb, clamp((gl_Fog.end - gl_FogFragCoord) * gl_Fog.scale, 0.0, 1.0)), clamp(alpha, 0.0, 1.0)) * texture2D(tex0, gl_TexCoord[0].xy);
		-- }
	 --  ]],
  }
end


local function GetGroundHeight(x, z)
	return spGetGroundHeight(x,z)
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
		local Scale = options.gridSize.value
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
        if options.mapBorderStyle.value == "texture" then 
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

function widget:Initialize()
	
	if not drawingEnabled then
		return
	end
	
	
	Spring.SendCommands("mapborder " .. ((options and (options.mapBorderStyle.value == 'cutaway')) and "1" or "0"))
	
	if island == nil then
		island = IsIsland()
	end

	SetupShaderTable()
	Spring.SendCommands("luaui disablewidget External VR Grid")
	if gl.CreateShader and options.useShader.value then
		mirrorShader = gl.CreateShader(shaderTable)
		if (mirrorShader == nil) then
			Spring.Log(widget:GetInfo().name, LOG.ERROR, "Map Edge Extension widget: mirror shader error: "..gl.GetShaderLog())
		end
	end
	if not mirrorShader then
		widget.DrawWorldPreUnit = function()
			if (not island) or options.drawForIslands.value then
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
	--Spring.SetDrawGround(true)
	gl.DeleteList(dList)
	if mirrorShader then
		gl.DeleteShader(mirrorShader)
	end
end

local function DrawWorldFunc() --is overwritten when not using the shader
    if (not island) or options.drawForIslands.value then
        local glTranslate = gl.Translate
        local glUniform = gl.Uniform
        local GamemapSizeZ, GamemapSizeX = Game.mapSizeZ,Game.mapSizeX
        
        gl.Fog(true)
        gl.FogCoord(1)
        gl.UseShader(mirrorShader)
        gl.PushMatrix()
        gl.DepthMask(true)
        if options.mapBorderStyle.value == "texture" then 
        		gl.Texture(realTex)
        		glUniform(ubrightness, options.textureBrightness.value)
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
        gl.CallList(dList)
        glUniform(uleft , 0)
        glTranslate(GamemapSizeX*2,0,0)
        gl.CallList(dList)
        gl.Uniform(uup, 0)
        glTranslate(0,0,GamemapSizeZ*2)
        gl.CallList(dList)
        glUniform(uleft, 1)
        glTranslate(-GamemapSizeX*2,0,0)
        gl.CallList(dList)
        
        glUniform(umirrorX, 0)
        glTranslate(GamemapSizeX,0,0)
        gl.CallList(dList)
        glUniform(uleft, 0)
        glUniform(uup, 1)
        glTranslate(0,0,-GamemapSizeZ*2)
        gl.CallList(dList)
        
        glUniform(uup, 0)
        glUniform(umirrorZ, 0)
        glUniform(umirrorX, GamemapSizeX)
        glTranslate(GamemapSizeX,0,GamemapSizeZ)
        gl.CallList(dList)
        glUniform(uleft, 1)
        glTranslate(-GamemapSizeX*2,0,0)
        gl.CallList(dList)
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
	if drawingEnabled then
		DrawWorldFunc()
	end
end
function widget:DrawWorldRefraction()
	if drawingEnabled then
		DrawWorldFunc()
	end
end

function widget:MousePress(x, y, button)
	local _, mpos = spTraceScreenRay(x, y, true) --//convert UI coordinate into ground coordinate.
	if mpos==nil then --//activate epic menu if mouse position is outside the map
		local _, _, meta, _ = Spring.GetModKeyState()
		if meta then  --//show epicMenu when user also press the Spacebar
			WG.crude.OpenPath(options_path) --click + space will shortcut to option-menu
			WG.crude.ShowMenu() --make epic Chili menu appear.
			return false
		end
	end
end