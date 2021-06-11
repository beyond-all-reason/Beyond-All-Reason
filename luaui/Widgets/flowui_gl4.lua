
function widget:GetInfo()
	return {
		name      = 'FlowUI GL4',
		desc      = 'FlowUI GL4 Testing',
		author    = 'Beherith',
		version   = '1.0',
		date      = '2021.05.020',
		license   = 'GNU GPL, v2 or later',
		layer     = 100,
		enabled   = true,  --  loaded by default?
	}
end

local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local GL_LINES = GL.LINES
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetActiveCommand = Spring.GetActiveCommand
local chobbyInterface

--- OO stuff
-- Each uielement should have a parent, and can have any number of childrent
-- A uiElement may consist of any combination of geometric primitives
-- A uiElement may have a table of fonts assigned to it
-- Should have a known position, and maybe even have its own highlight instance
-- A uielement can be deleted, which will result in the deletion of all of its children
-- an element can be hidden, which will also hide all of its children
-- an element can be shown, which will show all of its children
	-- this is bad because of highlighting

-- element data members:
	
	-- flatprimitives{} -- an array of VBO keys
	-- blendedprimitives{} -- an array of VBO keys
	-- TextElements{} -- this one is kinda hard, but well figure it out
	-- bool mousehits()
		-- A nice recursive call, 
	-- highlightchild?
	-- bool visible 

-- element functions:

	-- Hide() 
		-- hides self and all children
	-- Show()
		-- shows self and all children
	-- Toggle()
		-- inverts self, and sets all children to it
	-- Remove()
		-- deletes all children and self
		
	-- Update()
		-- Should update its own primitives (probably by deleting and recreating them)
		-- 
	-- Mouseover()
		-- a function on what to do when mouse is over it
	-- OnClick()
		-- 

-- element 'Callbacks'
	
	
-- Draw Implementation
-- the Z depth of any element must be greater than its childrens
-- We need 2 separate VBOS, for flat blended and alpha blended stuff. Draw the flat first, then the alpha blended one
-- we need a manager for all text type UI elements, consider replacing as much text as posssible with textures!
-- Only textures that are actually in the atlas are renderable
-- the atlas is built once, and queried

local FBElement = {}

FBElement.__index = FBElement

function FBElement.new(name, px, py, sx, sy)
	return setmetatable({}, FBElement)
end

function FBElement:SetVisible(visible)
	self.visible = visible
	for i, child in ipairs(self.children) do child:SetVisible(visible) end
end

function FBElement:Toggle()
	self.visible = not self.visible
	for i, child in ipairs(self.children) do child:SetVisible(self.visible)	end
end

function FBElement:IsMouseOver(mx, my)
	local hitsme = self.visible and mx >= self.px and mx <= self.sx and my >= self.py and my <= self.sy
	if hitsme then
		if #self.children > 1 then
			for i, child in ipairs(self.children) do
				local childhit = child:IsMouseOver(mx,my)
				if childhit then
					return childhit
				end
			end
		else
			return self
		end
	else
		return
	end
end

function FBElement.Remove()

end
	


----------------------------------------------------------------
-- GL4 STUFF
----------------------------------------------------------------

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")
local rectRoundVBO = nil
local rectRoundShader = nil
local rectRoundVAO = nil
local vsx,vsy = gl.GetViewSizes()
local atlasID = nil
local atlassedImages = {}
--local rectRoundVBO = nil

local vsSrc = [[
#version 420
#line 5000

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 screenpos; // left, bottom, right, top, in pixels
layout (location = 1) in vec4 cornersizes; // tl, tr, br, bl
layout (location = 2) in vec4 color1; // rgba
layout (location = 3) in vec4 color2; // rgba
layout (location = 4) in vec4 uvoffsets; // uvrect, bottom left, top right
layout (location = 5) in vec4 fronttexture_edge_z_progress; //  textured, edgewidth, z,progress
layout (location = 6) in vec4 hide_blendmode_globalbackground;;  

out DataVS {
	vec4 v_screenpos;
	vec4 v_cornersizes;
	vec4 v_color1;
	vec4 v_color2;
	vec4 v_uvoffsets;
	vec4 v_fronttexture_edge_z_progress;
	vec4 v_hide_blendmode_globalbackground;
};

#line 5100
void main() {
	gl_Position = vec4(screenpos.x, 0, screenpos.y,1.0);
	v_screenpos = screenpos;
	v_cornersizes = cornersizes;
	v_color1 = color1;
	v_color2 = color2;
	v_uvoffsets = uvoffsets;
	v_fronttexture_edge_z_progress = fronttexture_edge_z_progress;
	v_hide_blendmode_globalbackground = hide_blendmode_globalbackground;
}
]]

local gsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (points) in;
layout (triangle_strip, max_vertices = 32) out; // 9 tris * 3


//__ENGINEUNIFORMBUFFERDEFS__

#line 20000
in DataVS {
	vec4 v_screenpos;// left, bottom, right, top, in pixels
	vec4 v_cornersizes;
	vec4 v_color1;
	vec4 v_color2;
	vec4 v_uvoffsets;
	vec4 v_fronttexture_edge_z_progress;
	vec4 v_hide_blendmode_globalbackground;
} dataIn[];

out DataGS {
	vec4 g_screenpos;
	vec4 g_uv; // should also contain 'background texture shit'
	vec4 g_color;
	vec4 g_color2;
	vec4 g_fronttex_edge_backtex_hide;
};



#define TL_CORNERSIZE dataIn[0].v_cornersizes.x
#define TR_CORNERSIZE dataIn[0].v_cornersizes.y
#define BR_CORNERSIZE dataIn[0].v_cornersizes.z
#define BL_CORNERSIZE dataIn[0].v_cornersizes.w

#define LEFT dataIn[0].v_screenpos.x
#define BOTTOM dataIn[0].v_screenpos.y
#define RIGHT dataIn[0].v_screenpos.z
#define TOP dataIn[0].v_screenpos.w

#define UV dataIn[0].v_uvoffsets

#define PROGRESS dataIn[0].v_fronttexture_edge_z_progress.w
#define EDGE dataIn[0].v_fronttexture_edge_z_progress.y
#define DEPTH dataIn[0].v_fronttexture_edge_z_progress.z
#define FRONTTEXTURE dataIn[0].v_fronttexture_edge_z_progress.y

#define HIDE dataIn[0].hide_blendmode_globalbackground.x
#define BLENDMODE dataIn[0].hide_blendmode_globalbackground.x
#define BACKTEXTURE dataIn[0].hide_blendmode_globalbackground.x

void addvertexflowui(float spx, float spy, float distfromside){
	g_screenpos = vec4(spx, spy, DEPTH, 1.0);
	g_uv.x = UV.x + (UV.z - UV.x)*((spx - LEFT) /(RIGHT - LEFT));// horz of maintexture
	g_uv.y = UV.y + (UV.w - UV.y)*((spy - BOTTOM)/(TOP - BOTTOM));// vert of maintexture

	g_screenpos.xy = (g_screenpos.xy / viewGeometry.xy)* 2.0 - 1.0; // viewGeometry.xy contains view size in pixels
	
	g_uv.z = spx; // world uv coords for global background
	g_uv.w = spy; // world uv coords for global background
	
	float topness = (spy - BOTTOM)/(TOP - BOTTOM); // top is 1, bottom is 0
	
	g_color = mix(dataIn[0].v_color1, dataIn[0].v_color2, topness);
	
	g_fronttex_edge_backtex_hide = dataIn[0].v_fronttexture_edge_z_progress;
	
	float future_feather = 200.0;
	if (EDGE > 0.5 ) {
		float borderwidth1_0 =  distfromside - EDGE ; // 50 - 10
		future_feather = distfromside / borderwidth1_0; // WIP 50 / (50-10)
		
		//future_feather = (1.0 / EDGE) * (distfromside 
		if (distfromside > 1.0) {
			future_feather = -1.0 * distfromside/EDGE;
		}
		else {
			future_feather = 1.0;
		}
		g_color2 = mix(dataIn[0].v_color1, dataIn[0].v_color2, future_feather);
	}else{
		//g_fronttex_edge_backtex_hide.y = 200.0 ;
		g_color2 = vec4(1.0, 0.0, 1.0 , 1.0);
	}
	g_fronttex_edge_backtex_hide.y = future_feather;
	
	gl_Position = vec4(g_screenpos.x, g_screenpos.y, DEPTH, 1.0);
	
	g_screenpos = vec4(spx, spy, DEPTH, 1.0);
	EmitVertex();
}


#define HALFPI 1.570796326794896

#define PI 3.1415926535897932384626433832795

#define TWOPI 6.283185307179586476925286766559

float centerx;
float centery;


#line 20149
void main() {
	vec4 gs_cornersizes = dataIn[0].v_cornersizes;

	// for progress angles, we will be idiots and only calc it for zero corners

	float invprogress = 1.0-PROGRESS; // at a PROGRESS of 30%, we want to draw the last 70% of the element
	float progress_offset;
	// a progress of 90% means an invprogress of 10%, so we 
	float centery = (TOP + BOTTOM) * 0.5;
	float centerx = (LEFT + RIGHT) * 0.5;
	float distfromside = (TOP - BOTTOM) * 0.5;
	
	// TOPRIGHT side
	if (invprogress<0.125) {
		progress_offset = (RIGHT-LEFT - TR_CORNERSIZE) * clamp((invprogress - 0.0) * 4, 0, 1.0);
		
		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(RIGHT - TR_CORNERSIZE, TOP, 0.0);
		addvertexflowui(centerx + progress_offset , TOP, 0.0);
		EndPrimitive();
		
		//TR corner:
		if (TR_CORNERSIZE > 0.1) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(RIGHT, TOP - TR_CORNERSIZE, 0.0);
			addvertexflowui(RIGHT - TR_CORNERSIZE, TOP, 0.0);
			EndPrimitive();
		}
	}

	//RIGHT side:
	if (invprogress<0.375) {
		progress_offset = (TOP-BOTTOM - TR_CORNERSIZE - BR_CORNERSIZE) * clamp((invprogress - 0.125) * 4, 0, 1.0);
		
		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(RIGHT, BOTTOM + BR_CORNERSIZE, 0.0);
		addvertexflowui(RIGHT, TOP - TR_CORNERSIZE - progress_offset, 0.0);
		EndPrimitive();
		
		//BR corner:		
		
		if (BR_CORNERSIZE > 0.1) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(RIGHT - BR_CORNERSIZE, BOTTOM, 0.0);
			addvertexflowui(RIGHT, BOTTOM + BR_CORNERSIZE, 0.0);
			EndPrimitive();
		}
	}
	
	//BOTTOM side:
	if (invprogress<0.625) {
		progress_offset = (RIGHT-LEFT - BL_CORNERSIZE - BR_CORNERSIZE) * clamp((invprogress - 0.375) * 4, 0, 1.0);
		
		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(LEFT + BL_CORNERSIZE, BOTTOM, 0.0);
		addvertexflowui(RIGHT - BR_CORNERSIZE - progress_offset, BOTTOM, 0.0);
		EndPrimitive();

		//BL corner:
		if (BL_CORNERSIZE > 0.01) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(LEFT , BOTTOM + BL_CORNERSIZE, 0.0);
			addvertexflowui(LEFT + BL_CORNERSIZE, BOTTOM, 0.0);
			EndPrimitive();
		}
	}
	
	//LEFT side:
	if (invprogress<0.875) {
		progress_offset = (TOP-BOTTOM - BL_CORNERSIZE - TL_CORNERSIZE) * clamp((invprogress - 0.625) * 4, 0, 1.0);
		
		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(LEFT, TOP - TL_CORNERSIZE, 0.0);
		addvertexflowui(LEFT, BOTTOM + BL_CORNERSIZE + progress_offset, 0.0);
		EndPrimitive();
		
		//TL corner:
		if (TL_CORNERSIZE > 0.01) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(LEFT + TL_CORNERSIZE, TOP, 0.0);
			addvertexflowui(LEFT, TOP - TL_CORNERSIZE, 0.0);
			EndPrimitive();
		}
	}
	
	//TOPLEFT side:
	progress_offset = (RIGHT-LEFT - TL_CORNERSIZE) * clamp((invprogress - 0.875) * 4, 0, 1.0);
	addvertexflowui(centerx, centery, distfromside); //center vertex:
	addvertexflowui(centerx, TOP, 0.0);
	addvertexflowui(LEFT + TL_CORNERSIZE + progress_offset, TOP, 0.0);
	EndPrimitive();
	
	
	//for (float i = 0; i<4; i = i+1){ // LOL ROUNDING?!
	//	float a1 = HALFPI * i /4.0;
	//	float a2 = HALFPI * (i+1) /4.0;
	//	addvertexflowui((LEFT + RIGHT) * 0.5, (TOP + BOTTOM) * 0.5);//center vertex:
	//	addvertexflowui(LEFT + (1.0-sin(a1)) * BL_CORNERSIZE, BOTTOM + (1.0-cos(a1)) * BL_CORNERSIZE);
	//	addvertexflowui(LEFT + (1.0-sin(a2)) * BL_CORNERSIZE, BOTTOM + (1.0-cos(a2)) * BL_CORNERSIZE);
	//	EndPrimitive();
	//}
}

]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require


uniform sampler2D bgTex;
uniform sampler2D uiAtlas;

#define BACKGROUND_TILESIZE 64

in DataGS {
	vec4 g_screenpos;
	vec4 g_uv; // should also contain 'background texture shit'
	vec4 g_color;
	vec4 g_color2;
	vec4 g_fronttex_edge_backtex_hide; //v_fronttexture_edge_z_progress
};

out vec4 fragColor;



#line 20000
void main() {
	//vec4 bgTex = texture(bgTex, g_uv.zw/BACKGROUND_TILESIZE); // sample background texture, even if we might discard it
	vec4 fronttex = texture(uiAtlas, g_uv.xy);
	fragColor = g_color;
	//fragColor.rgb = mix(fragColor.rgb, bgTex.rgb, bgTex.a * g_fronttex_edge_backtex_hide.y);
	fragColor.rgba = mix(fragColor.rgba, fronttex.rgba, g_fronttex_edge_backtex_hide.x);// * g_fronttex_edge_backtex_hide.x );
	fragColor.a = max(fragColor.a, g_fronttex_edge_backtex_hide.x*fronttex.a);

	if (g_fronttex_edge_backtex_hide.y <= 99.0) {
		fragColor = g_color2;
		//fragColor.rgba = mix(fragColor.rgba, g_color2, clamp((g_fronttex_edge_backtex_hide.y),0.0, 1.0));
		fragColor.a = min(fragColor.a,clamp(( sign(g_fronttex_edge_backtex_hide.y)),0.0, 1.0));
	}
	//fragColor.rgb  = vec3(clamp((1.0 - g_fronttex_edge_backtex_hide.y),0.0, 1.0), fract(g_fronttex_edge_backtex_hide.y), 0.0);
	//fragColor.a = 1.0;
	//fragColor.a = min(fragColor.a,0.5);
	//fragColor.rgba = vec4(1.0,1.0,1.0,0.3);
}
]]

local function goodbye(reason)
  Spring.Echo(widget:GetInfo().name .." widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget(self)
end

local function makeRectRoundVBO()
	rectRoundVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'screenpos', size = 4},
			{id = 1, name = 'cornersizes', size = 4},
			{id = 2, name = 'color1', size = 4},
			{id = 3, name = 'color2', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'fronttexture_edge_z_progress', size = 4},
			{id = 6, name = 'hide_blendmode_globalbackground', size = 4}, -- TODO: maybe Hide, BlendMode, globalbackground
			
		},
		32000	,
		"rectRoundVBO"
	)
	if rectRoundVBO == nil then goodbye("Failed to create rectRoundVBO") end
	
	for i = 1, 0 do
		local l = math.floor(math.random() * vsx/2)
		local b = math.floor(math.random() * vsy/2)
		local r = math.floor(l + math.random() * vsx/4)
		local t = math.floor(b + math.random() * vsx/4)
		local VBOData = {
			l,b,r,t, 
			math.random() * 10, math.random() *20, math.random() * 30, math.random() * 40, 
			math.random() , math.random(), math.random() , math.random() , 
			math.random() , math.random(), math.random() , math.random() , 
			0,0,1,1, --math.random() , math.random(), math.random() , math.random() , 
			math.random() , math.random(), math.random() , math.random() , 
			0,0,0,0,
		}
		
		pushElementInstance(rectRoundVBO,VBOData,i,true)
	end
	return rectRoundVBO
end

local function makeShaders()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	gsSrc = gsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	rectRoundShader =  LuaShader(
		{
			vertex = vsSrc,
			fragment = fsSrc,
			geometry = gsSrc,
		
			uniformInt = {
				bgTex = 0,
				uiAtlas = 1,
			},
			uniformFloat = {
				--shaderParams = {gridSize, brightness, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0},
			},
		},
		"rectRoundShader GL4"
	)
	--Spring.Echo("GS ############################################################ \n",gsSrc)
	shaderCompiled = rectRoundShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile rectRoundShader GL4 ")
		
		--Spring.Echo("VS ############################################################ \n",vsSrc)
		--Spring.Echo("GS ############################################################ \n",gsSrc)
		--Spring.Echo("FS ############################################################ \n",fsSrc)
	else
		Spring.Echo("Compile OK"	)
	end
	
end


---------------------- FlowUI emulation ------------------------
-- Notes
-- the shader should be shared, but each widget should have its own:
--	VBO
--	Atlas

-- TODO:
--	TexturedRectRound:
		--texture UV calcs are wierd
--	RectRoundCircle
	--	Radius in one vertex param! (doable with tris)
	--	 implement centerOffset! 
	-- DOESNT WORK?
	-- COMPLETELY FUCKED!
--	UiElement
	-- repurpose blendalpha to bgtexture, and have that global
--	Draw.TexRect
	-- implement the UV offsets from atlastexture
-- Configints
	-- somehow mash them into this table?

	--[[			{id = 0, name = 'screenpos', size = 4},
			{id = 1, name = 'cornersizes', size = 4},
			{id = 2, name = 'color1', size = 4},
			{id = 3, name = 'color2', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'fronttexture_edge_z_progress', size = 4},]]--

local Draw = {}

Draw.TransformUVAtlasxXyY = function (atlascoordsxXyY, uvcoordsxyXY)
	if atlascoordsxXyY == nil or uvcoordsxyXY == nil then 
		return {0,0,1,1}
	end
	local a = atlascoordsxXyY[2] - atlascoordsxXyY[1]
	local b = atlascoordsxXyY[4] - atlascoordsxXyY[3]
	return {
		atlascoordsxXyY[1] + a * uvcoordsxyXY[1],
		atlascoordsxXyY[3] + b * uvcoordsxyXY[2],
		atlascoordsxXyY[1] + a * uvcoordsxyXY[3],
		atlascoordsxXyY[3] + b * uvcoordsxyXY[4],
		}
end


--[[
	RectRound
		draw rectangle with chopped off corners
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		c1, c2 = top color, bottom color
]]--
Draw.RectRound = function (VBO, instanceID, z, px, py, sx, sy,  cs,  tl, tr, br, bl,   c1, c2, progress) -- returns table of instanceIDs

	if z == nil then z = 0.5 end  -- fools depth sort
	if c1 == nil then c1 = {1.0,1.0,1.0,1.0} end
	if c2 == nil then c2 = c1 end
	progress = progress or 1
	--Spring.Echo(c1)
	--Spring.Echo(c2)
	
	--cs = 10
	local VBOData = {
		px, py, sx, sy, 
		cs*tl, cs*tr, cs*br, cs*bl, 
		c1[1], c1[2], c1[3], c1[4],
		c2[1], c2[2], c2[3], c2[4],
		0,0,0,0,
		0, 0, z, 1,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)
end

-- this is just an overload for replacing gl.TexRect
Draw.TexRect = function (VBO, instanceID, z, px, py, sx, sy,  texture, color, uvs) -- returns table of instanceIDs
	
	return Draw.TexturedRectRound(VBO, instanceID, z, px, py, sx, sy,  0,  0, 0, 0, 0,  0, 0, 0,  texture)
	--[[
	if z == nil then z = 0.5 end  -- fools depth sort
	
	local fronttextalpha = 0
	if texture == nil then 
		texture = {0,0,0,0}
	else
		fronttextalpha = 1.0
		Spring.Echo('TexRect',texture)
		texture = ({gl.GetAtlasTexture(atlasID, texture)})
		Spring.Echo(texture)
	end 
	if uvs == nil then uvs = {0,0,1,1} end
	-- remap uvs
	
	uvs = Draw.TransformUVAtlasxXyY(texture, uvs)
	
	if color == nil then color = {1,1,1,1} end
	local VBOData = {
		px, py, sx, sy, 
		0, 0, 0, 0, 
		color[1],color[2],color[3],color[4],
		color[1],color[2],color[3],color[4],
		uvs[1],uvs[4],uvs[3],uvs[2],
		fronttextalpha, 0, z, 1,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)
	]]--	
end
--[[
	TexturedRectRound
		draw rectangle with chopped off corners and a textured background tile
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		size = texture tile size
		offset, offsetY = texture offset coordinates (offsetY=offset when offsetY isnt defined)
		texture = file location
]]--

Draw.TexturedRectRound =  function (VBO, instanceID, z, px, py, sx, sy,  cs,  tl, tr, br, bl,  size, offset, offsetY,  texture, color) -- returns table of instanceIDs
	-- texture should be a table of UV coords from atlas
	local fronttextalpha = 0
	if texture == nil then 
		texture = {0,0,0,0}
	else
		fronttextalpha = 1.0
		--Spring.Echo('TexturedRectRound',texture)
		texture = ({gl.GetAtlasTexture(atlasID, texture)})
		--Spring.Echo(texture)
	end 
	
	if color == nil then color = {1,1,1,0.5} end
	--uvs = Draw.TransformUVAtlasxXyY(texture, uvs) -- DO OFFSET!
	local scale = size and (size / (sx-px)) or 1
	--local offset = offset or 0
	local csyMult = 1 / ((sy - py) / cs)
	local ycMult = (sy-py) / (sx-px)
	
	if z == nil then z = 0.50 end  -- fools depth sort
	if c2 == nil then c2 = c1 end
	local VBOData = {
		px, py, sx, sy, 
		cs*tl, cs*tr, cs*br, cs*bl, 
		color[1],color[2],color[3],color[4],
		color[1],color[2],color[3],color[4],
		texture[1],texture[4],texture[2],texture[3],
		fronttextalpha, 0, z, 1,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)
end


--[[
	RectRoundProgress
		draw rectangle pie (TODO: not with actual chopped off corners yet)
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		progress
		color
]]
Draw.RectRoundProgress =  function (VBO, instanceID, z, left, bottom, right, top, cs, progress, c1, c2) -- returns table of instanceIDs
	return Draw.RectRound(VBO, instanceID, z, left, bottom, right, top, cs, 1,1,1,1, c1, c2, progress)
	--[[
	if z == nil then z = 0.55 end  -- fools depth sort
	if c2 == nil then c2 = c1 end
	local VBOData = {
		left, bottom, right, top, 
		cs*tl, cs*tr, cs*br, cs*bl, 
		c1[1], c1[2], c1[3], c1[4],
		c1[1], c1[2], c1[3], c1[4],
		0,0,0,0,
		0, 0, z, progress,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)]]--
end



--[[
	RectRoundCircle
		draw a square with border edge/fade
	params
		x,y,z, radius
	optional
		c1 : outercolor
		c2 : innercolor
		centeroffset: the width of the highlight is gonna be radius-centeroffset

]]
Draw.RectRoundCircle = function (VBO, instanceID, z, x, y, radius, cs, centerOffset, c1, c2) -- returns table of instanceIDs
	Spring.Echo("Draw.RectRoundCircle", x, y, radius, cs, centerOffset, c1, c2)
	Spring.Echo(radius, radius - centerOffset)
	if z == nil then z = 0.5 end  -- fools depth sort
	if c1 == nil then c1 = {1.0,1.0,1.0,1.0} end
	if c2 == nil then c2 = c1 end
	if centerOffset == nil then centerOffset = 0 end
	--centerOffset = 50
	
	--local cs = radius / 2
	
	local VBOData = {
		x - radius, y - radius, x + radius, y + radius, 
		cs, cs, cs, cs, 
		c1[1], c1[2], c1[3], c1[4],
		c2[1], c2[2], c2[3], c2[4],
		0,0,0,0,
		0, radius - centerOffset , z, 1,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)
end

--[[
	Circle
		draw a circle
	params
		x,z, radius
		sides = number outside vertexes
		color1 = (center) color
	optional
		color2 = edge color
]]-- -- TODO


--[[
	UiElement
		draw a complete standardized ui element having: border, tiled background, gloss on top and bottom
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		ptl, ptr, pbr, pbl = inner border padding/size multiplier (default: 1) (set to 0 when you want to attach this ui element to another element so there is only padding done by one of the 2 elements)
		opacity = (default: ui_opacity springsetting)
		color1, color2 = (color1[4 value overrides the opacity param defined above)
		bgpadding = custom border size
]]

Draw.Element = function(VBO, instanceID, z,px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding)
	local opacity = opacity or Spring.GetConfigFloat("ui_opacity", 0.6)
	local color1 = color1 or { 0, 0, 0, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1}
	local ui_scale = Spring.GetConfigFloat("ui_scale", 1)
	local bgpadding = bgpadding or Spring.FlowUI.elementPadding
	local cs = Spring.FlowUI.elementCorner * (bgpadding/Spring.FlowUI.elementPadding)
	local glossMult = 1 + (2 - (opacity * 1.5))
	local tileopacity = Spring.GetConfigFloat("ui_tileopacity", 0.012)
	local bgtexScale = Spring.GetConfigFloat("ui_tilescale", 7)
	local bgtexSize = math.floor(Spring.FlowUI.elementPadding * bgtexScale)

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < Spring.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < Spring.FlowUI.vsy and 1 or 0) * (ptl or 1)
	
	if z == nil then z = 0.5 end  -- fools depth sort
	
	-- background
	--gl.Texture(false)
	local background1 = Draw.RectRound(VBO, nil, z-0.000, px, py, sx, sy, cs, tl, tr, br, bl, { color1[1], color1[2], color1[3], color1[4] }, { color1[1], color1[2], color1[3], color1[4] })

	cs = cs * 0.6
	local background2 = Draw.RectRound(VBO, nil, z-0.001,px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, { color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, color2[4] }, { color2[1], color2[2], color2[3], color2[4] })

	-- gloss
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	local glossHeight = math.floor(0.02 * Spring.FlowUI.vsy * ui_scale)
	-- top
	local topgloss = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, sy - syPad - glossHeight, sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.07 * glossMult })
	-- bottom
	local botgloss = Draw.RectRound(VBO, nil, z-0.003,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, cs, 0, 0, br, bl, { 1, 1, 1, 0.03 * glossMult }, { 1 ,1 ,1 , 0 })

	-- highlight edges thinly
	-- top
	local topgloss = Draw.RectRound(VBO, nil, z-0.004,px + pxPad, sy - syPad - (cs*2.5), sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.04 * glossMult })
	-- bottom
	local botgloss = Draw.RectRound(VBO, nil, z-0.005,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (cs*2), cs, 0, 0, br, bl, { 1, 1, 1, 0.02 * glossMult }, { 1 ,1 ,1 , 0 })
	-- left
	--Spring.FlowUI.Draw.RectRound(px + pxPad, py + syPad, px + pxPad + (cs*2), sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0.02 * glossMult }, { 1, 1, 1, 0 })
	-- right
	--Spring.FlowUI.Draw.RectRound(sx - sxPad - (cs*2), py + syPad, sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0.02 * glossMult }, { 1, 1, 1, 0 })

	--Spring.FlowUI.Draw.RectRound(px + (pxPad*1.6), sy - syPad - math.ceil(bgpadding*0.25), sx - (sxPad*1.6), sy - syPad, 0, tl, tr, 0, 0, { 1, 1, 1, 0.012 }, { 1, 1, 1, 0.07 * glossMult })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- darkening bottom
	local botdark = Draw.RectRound(VBO, nil, z-0.006,px, py, sx, py + ((sy-py)*0.75), cs*1.66, 0, 0, br, bl, { 0,0,0, 0.05 * glossMult }, { 0,0,0, 0 })
	local instanceIDs = {background1, background2, topgloss, botgloss, botdark}
	-- tile
	if tileopacity > 0 then
		--gl.Color(1,1,1, tileopacity)
		local bgtile = Draw.TexturedRectRound(VBO, nil, z-0.007,px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, bgtexSize, (px+pxPad)/Spring.FlowUI.vsx/bgtexSize, (py+pyPad)/Spring.FlowUI.vsy/bgtexSize, "modules/flowui/images/backgroundtile.png")
		instanceIDs[#instanceIDs + 1 ] = bgtile
	end
	return instanceIDs
end


--[[
	Button
		draw a complete standardized ui element having: border, tiled background, gloss on top and bottom
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		ptl, ptr, pbr, pbl = inner padding multiplier (default: 1) (set to 0 when you want to attach this ui element to another element so there is only padding done by one of the 2 elements)
		opacity = (default: ui_opacity springsetting)
		color1, color2 = (color1[4] alpha value overrides opacity define above)
		bgpadding = custom border size
]]
Draw.Button = function(VBO, instanceID, z,px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding)
	local opacity = opacity or 1
	local color1 = color1 or { 0, 0, 0, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1}
	local bgpadding = math.floor(bgpadding or Spring.FlowUI.buttonPadding*0.5)
	local glossMult = 1 + (2 - (opacity * 1.5))

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < Spring.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < Spring.FlowUI.vsy and 1 or 0) * (ptl or 1)
	
	if z == nil then z = 0.5 end  -- fools depth sort
	glossMult = glossMult * 1 -- TODO TESTING REMOVE!
	
	-- background
	--gl.Texture(false)
	local background = Draw.RectRound(VBO, nil, z-0.000,px, py, sx, sy, bgpadding * 1.6, tl, tr, br, bl, { color1[1], color1[2], color1[3], color1[4] }, { color2[1], color2[2], color2[3], color2[4] })
	--Spring.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, bgpadding, tl, tr, br, bl, { color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, color2[4] }, { color2[1], color2[2], color2[3], color2[4] })

	-- highlight edges thinly
	-- top
	local highlighttop = Draw.RectRound(VBO, nil, z-0.001,px + pxPad, sy - syPad - (bgpadding*2.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.04 * glossMult })
	-- bottom
	local highlightbottom = Draw.RectRound(VBO, nil, z-0.001,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (bgpadding*2), bgpadding, 0, 0, br, bl, { 1, 1, 1, 0.02 * glossMult }, { 0 ,0 ,0 , 0 })

	-- gloss
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	local glossHeight = math.floor((sy-py)*0.5)
	local gloss1 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, sy - syPad - math.floor((sy-py)*0.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.1 * glossMult })
	local gloss2 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, bgpadding, 0, 0, br, bl, { 1, 1, 1, 0.03 * glossMult }, { 1 ,1 ,1 , 0 })
	local gloss3 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + ((sy-py)*0.2), bgpadding, 0, 0, br, bl, { 1,1,1, 0.02 * glossMult }, { 1,1,1, 0 })
	local gloss4 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, sy- ((sy-py)*0.5), sx - sxPad, sy, bgpadding, tl, tr, 0, 0, { 1,1,1, 0 }, { 1,1,1, 0.07 * glossMult })
	local gloss5 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + ((sy-py)*0.5), bgpadding, 0, 0, br, bl, { 1,1,1, 0.05 * glossMult }, { 1,1,1, 0 })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	--TODO: return {background,highlighttop,highlightbottom, gloss1, gloss2, gloss3, gloss4, gloss5}
end

--[[
	Unit
		draw a unit buildpic
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		zoom = how much to enlarge/zoom into the buildpic (default:  0)
		borderSize, borderOpacity,
		texture, radarTexture, groupTexture,
		price = {metal, energy}
		queueCount
]]
Draw.Unit = function(VBO, instanceID, z, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom,  borderSize, borderOpacity,  texture, radarTexture, groupTexture, price, queueCount)
	local borderSize = borderSize~=nil and borderSize or math.min(math.max(1, math.floor((sx-px) * 0.024)), math.floor((Spring.FlowUI.vsy*0.0015)+0.5))	-- set default with upper limit
	local cs = cs~=nil and cs or math.max(1, math.floor((sx-px) * 0.024))

	-- draw unit
	--[[
	if texture then
		gl.Texture(texture)
	end
	gl.BeginEnd(GL.QUADS, DrawTexRectRound, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom)
	if texture then
		gl.Texture(false)
	end]]--
	
	if texture then
		--texture = gl.GetAtlasTexture(atlasID, texture)
	else
		--texture = {0,0,0,0}
	end
	
	local unitpic = Draw.TexturedRectRound(VBO, nil, z + 0.001,
		px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom, nil,nil, 
		texture
	)
	

	-- darken gradually
	local darken = Draw.RectRound(VBO, nil, z + 0.002, px, py, sx, sy, cs, 0, 0, 1, 1, { 0, 0, 0, 0.2 }, { 0, 0, 0, 0 })

	-- make shiny
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	
	local shiny = Draw.RectRound(VBO, nil, z + 0.003, px, sy-((sy-py)*0.4), sx, sy, cs, 1,1,0,0,{1,1,1,0}, {1,1,1,0.06})

	-- lighten feather edges
	borderOpacity = borderOpacity or 0.1
	local halfSize = ((sx-px) * 0.5)
	
	local lighten = Draw.RectRoundCircle(VBO, nil, z + 0.004,
		px + halfSize,
		py + halfSize,
		halfSize, cs*0.7, halfSize*0.82,
		--{ 1, 1, 1, 0 }, { 1, 1, 1, 0.04 } -- original
		{ 1, 1, 1, 0 }, { 1, 1, 1, 0.24 } -- original
		--{ 1, 0, 1, 1.0 }, { 0, 1, 0, 1.0 }
	)

	local elementIDs = {unitpic, darken, shiny, lighten}
	
	-- border
	
	if borderSize > 0 then
		elementIDs[#elementIDs+1] = Draw.RectRoundCircle(
			VBO, nil, z + 0.005,
			px + halfSize,
			py + halfSize,
			halfSize, cs*0.7, halfSize -  borderSize,
			{ 1, 1, 1, borderOpacity }, { 1, 1, 1, borderOpacity }
		)
	end	
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if groupTexture then
		local iconSize = math.floor((sx - px) * 0.3)
		--gl.Color(1, 1, 1, 0.9)
		--gl.Texture(groupTexture)
		--gl.TexRect(px, sy - iconSize, px + iconSize, sy)
		--gl.Texture(false)
		
		elementIDs[#elementIDs+1] = Draw.TexRect(VBO, nil, z + 0.006,
			px, sy - iconSize, px + iconSize, sy,
			groupTexture,
			{1, 1, 1, 0.9})
			
	end
	if radarTexture then
		local iconSize = math.floor((sx - px) * 0.25)
		local iconPadding = math.floor((sx - px) * 0.03)
		--gl.Color(1, 1, 1, 0.9)
		--gl.Texture(radarTexture)
		--gl.TexRect(sx - iconPadding - iconSize, py + iconPadding, sx - iconPadding, py + iconPadding + iconSize)
		--gl.Texture(false)
		
		elementIDs[#elementIDs+1] = Draw.TexRect(VBO, nil, z + 0.006,
			sx - iconPadding - iconSize, py + iconPadding, sx - iconPadding, py + iconPadding + iconSize,
			radarTexture,
			{1, 1, 1, 0.9})
	end
	if price then
		local priceSize = math.floor((sx - px) * 0.15)
		local iconPadding = math.floor((sx - px) * 0.03)
		--font2:Print("\255\245\245\245" .. price[1] .. "\n\255\255\255\000" .. price[2], px + iconPadding, py + iconPadding + (priceSize * 1.35), priceSize, "o")
	end
	if queueCount then
		local pad = math.floor(halfSize * 0.06)
		--local textWidth = math.floor(font2:GetTextWidth(cmds[cellRectID].params[1] .. '  ') * halfSize * 0.57)
		--local pad2 = 0
		--Spring.FlowUI.Draw.RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - (cellInnerSize * 0.365) - pad2, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, cs * 3.3, 0, 0, 0, 1, { 0.15, 0.15, 0.15, 0.95 }, { 0.25, 0.25, 0.25, 0.95 })
		--Spring.FlowUI.Draw.RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - (cellInnerSize * 0.15) - pad2, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, 0, 0, 0, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.05 })
		--Spring.FlowUI.Draw.RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2 + pad, cellRects[cellRectID][4] - cellPadding - iconPadding - (cellInnerSize * 0.365) - pad2 + pad, cellRects[cellRectID][3] - cellPadding - iconPadding - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - pad2, cs * 2.6, 0, 0, 0, 1, { 0.7, 0.7, 0.7, 0.1 }, { 1, 1, 1, 0.1 })
		--font2:Print("\255\190\255\190" .. cmds[cellRectID].params[1],
		--	cellRects[cellRectID][1] + cellPadding + (halfSize * 1.88) - pad2,
		--	cellRects[cellRectID][2] + cellPadding + (halfSize * 1.43) - pad2,
		--	(sx - px) * 0.29, "ro"
		--)
	end
	return elementIDs
end

--[[
	Scroller
		draw a slider
	params
		px, py, sx, sy = left, bottom, right, top
		contentHeight = content height px
	optional
		position = (default: 0) current height px
]]
Draw.Scroller = function(VBO, instanceID, z, px, py, sx, sy, contentHeight, position)
	if z == nil then z = 0.5 end
	local padding = math.floor(((sx-px)*0.25) + 0.5)
	local sliderHeight =  (sy - py - padding - padding) / contentHeight
	--if sliderHeight < 1 then
	position = position or 0
	sliderHeight = math.floor((sliderHeight * (sy - py)) + 0.5)
	local sliderPos = math.floor((sy - ((sy - py) * (position / contentHeight))) + 0.5)

	-- background
	local background = Draw.RectRound(VBO, nil, z, px, py, sx, sy, (sx-px)*0.2, 1,1,1,1, { 0,0,0,0.2 })

	-- slider
	local slider = Draw.RectRound(VBO, nil, z -0.001, px+padding, sliderPos-sliderHeight-padding, sx-padding, sliderPos-padding, (sx-px-padding-padding)*0.2, 1,1,1,1, { 1, 1, 1, 0.16 })
	
	return {background, slider}
	--end
end

--[[
	Toggle
		draw a toggle
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		state = (default: 0) 0 / 0.5 / 1
]]
Draw.Toggle = function(VBO, instanceID, z, px, py, sx, sy, state)
	local cs = (sy-py)*0.1
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))

	-- faint dark outline edge
	local outlineedge = Draw.RectRound(VBO, nil, z - 0.000, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- top
	local top = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local highlighttop = Draw.RectRound(VBO, nil, z - 0.002, px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.035 })
	-- bottom
	local highlightbottom = Draw.RectRound(VBO, nil, z - 0.003, px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.025 }, { 1,1,1,0  })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- draw state
	local padding = math.floor((sy-py)*0.2)
	local radius = math.floor((sy-py)/2) - padding
	local y = math.floor(py + ((sy-py)/2))
	local x, color, glowMult
	if state == true or state == 1 then		-- on
		x = sx - padding - radius
		color = {0.8,1,0.8,1}
		glowMult = 1
	elseif not state or state == 0 then		-- off
		x = px + padding + radius
		color = {0.95,0.66,0.66,1}
		glowMult = 0.3
	else		-- in between
		x = math.floor(px + ((sx-px)*0.42))
		color = {1,0.9,0.7,1}
		glowMult = 0.6
	end
	local sliderknob  = Draw.SliderKnob(VBO, nil, z - 0.004, x, y, radius, color)

	local instanceIDs = {outlineedge, top, highlighttop, highlightbottom}
	for _, iID in ipairs(sliderknob) do
		instanceIDs[#instanceIDs] = iID
	end
	if glowMult > 0 then
		local boolGlow = radius * 1.75
		--gl.Blending(GL.SRC_ALPHA, GL.ONE)
		--gl.Color(color[1], color[2], color[3], 0.33 * glowMult)
		--gl.Texture(":l:LuaUI/Images/glow.dds")
		--gl.TexRect(x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow)
		color[4] = 0.33 * glowMult
		local glow1 = Draw.TexRect(VBO, nil, z - 0.005, x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow,"LuaUI/Images/glow.dds", color, nil)
		
		boolGlow = boolGlow * 2.2
		--gl.Color(0.55, 1, 0.55, 0.1 * glowMult)
		--gl.TexRect(x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow)
		local glow2 = Draw.TexRect(VBO, nil, z - 0.006, x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow,"LuaUI/Images/glow.dds" ,{0.55, 1, 0.55, 0.1 * glowMult},nil)
		--gl.Texture(false)
		--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		instanceIDs[#instanceIDs] = glow1
		instanceIDs[#instanceIDs] = glow2
		
	end
	return instanceIDs
end

--[[
	Slider
		draw a slider knob
	params
		x, y, radius
	optional
		color
]]
Draw.SliderKnob = function(VBO, instanceID, z, x, y, radius, color)
	if z == nil then z = 0.5 end
	local color = color or {0.95,0.95,0.95,1}
	local color1 = {color[1]*0.55, color[2]*0.55, color[3]*0.55, color[4]}
	local edgeWidth = math.max(1, math.floor(radius * 0.05))
	local cs = math.max(1.1, radius*0.15)

	-- faint dark outline edge
	local outline = Draw.RectRound(VBO, nil, z - 0.000, x-radius-edgeWidth, y-radius-edgeWidth, x+radius+edgeWidth, y+radius+edgeWidth, cs, 1,1,1,1, {0,0,0,0.1})
	-- knob
	local knob = Draw.RectRound(VBO, nil, z - 0.001,x-radius, y-radius, x+radius, y+radius, cs, 1,1,1,1, color1, color)
	-- lighten knob inside edges
	-- TODO:
	local lighttenknob = Draw.RectRoundCircle(VBO, nil, z - 0.002, x, y, radius, cs*0.5, radius*0.85, {1,1,1,0.1})
	return {outline, knob, lighttenknob}
end


--[[
	Slider
		draw a slider
	params
		px, py, sx, sy = left, bottom, right, top
		steps = either a table of values or a number of smallest step size
		min, max = when steps is number: min/max scope of steps
]]
Draw.Slider = function(VBO, instanceID, z, px, py, sx, sy, steps, min, max)
	if z == nil then z = 0.5 end
	
	local cs = (sy-py)*0.25
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))
	-- faint dark outline edge
	local darkoutline = Draw.RectRound(VBO, nil, z - 0.000, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- top
	local top = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { 0.1, 0.1, 0.1, 0.22 }, { 0.9,0.9,0.9, 0.22 })
	-- bottom
	local bottom = Draw.RectRound(VBO, nil, z - 0.002, px, py, sx, sy, cs, 1,1,1,1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0 })
	local instanceIDs = {darkoutline, top, bottom}
	-- steps
	if steps then
		local numSteps = 0
		local sliderWidth = sx-px
		local processedSteps = {}
		if type(steps) == 'table' then
			min = steps[1]
			max = steps[#steps]
			numSteps = #steps
			for _,value in pairs(steps) do
				processedSteps[#processedSteps+1] = math.floor((px + (sliderWidth*((value-min)/(max-min)))) + 0.5)
			end
			-- remove first step at the bar start
			processedSteps[1] = nil
		elseif min and max then
			numSteps = (max-min)/steps
			for i=1, numSteps do
				processedSteps[#processedSteps+1] = math.floor((px + (sliderWidth/numSteps) * (#processedSteps+1)) + 0.5)
				i = i + 1
			end
		end
		-- remove last step at the bar end
		processedSteps[#processedSteps] = nil

		-- dont bother when steps too small
		if numSteps and numSteps < (sliderWidth/7) then
			local stepSizeLeft = math.max(1, math.floor(sliderWidth*0.01))
			local stepSizeRight = math.floor(sliderWidth*0.005)
			for _,posX in pairs(processedSteps) do
				local step = Draw.RectRound(VBO, nil, z - 0.001 * #instanceIDs,posX-stepSizeLeft, py+1, posX+stepSizeRight, sy-1, stepSizeLeft, 1,1,1,1, { 0.12,0.12,0.12,0.22 }, { 0,0,0,0.22 })
				instanceIDs[#instanceIDs] = step
			end
		end
	end

	-- add highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local tophighlight = Draw.RectRound(VBO, nil, z - 0.001 * #instanceIDs,px, sy-edgeWidth-edgeWidth, sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.06 })
	instanceIDs[#instanceIDs] = tophighlight
	-- bottom
	
	local bottomhighlight = Draw.RectRound(VBO, nil, z - 0.001 * #instanceIDs,px, py, sx, py+edgeWidth+edgeWidth, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.04 })
	instanceIDs[#instanceIDs] = bottomhighlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	return instanceIDs
end

--[[
	Selector
		draw a selector (drop-down menu)
	params
		px, py, sx, sy = left, bottom, right, top
]]
Draw.Selector = function(VBO, instanceID, z, px, py, sx, sy)
	z = z or 0.5
	local cs = (sy-py)*0.1
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))

	-- faint dark outline edge
	local darkoutline = Draw.RectRound(VBO, nil, z - 0.00, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- body
	local body = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local tophighlight = Draw.RectRound(VBO, nil, z - 0.002, px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.035 })
	-- bottom
	local bottomhighlight = Draw.RectRound(VBO, nil, z - 0.003, px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.025 }, { 1,1,1,0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- button
	local button = Draw.RectRound(VBO, nil, z - 0.004, sx-(sy-py), py, sx, sy, cs, 1, 1, 1, 1, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.14 })
	
	return {darkoutline, body, tophighlight, bottomhighlight, button}
	--Spring.FlowUI.Draw.Button(sx-(sy-py), py, sx, sy, 1, 1, 1, 1, 1,1,1,1, nil, { 1, 1, 1, 0.1 }, nil, cs)
end

--[[
	SelectHighlight
		draw a highlighted area in a selector (drop-down menu)
		(also usable to highlight some other generic area)
	params
		px, py, sx, sy = left, bottom, right, top
		cs = corner size
		opacity
		color = {1,1,1}
]]
Draw.SelectHighlight = function(VBO, instanceID, z, px, py, sx, sy,  cs, opacity, color)
	z = z or 0.5
	local cs = cs or (sy-py)*0.08
	local edgeWidth = math.max(1, math.floor((Spring.FlowUI.vsy*0.001)))
	local opacity = opacity or 0.35
	local color = color or {1,1,1}

	-- faint dark outline edge
	local darkoutline = Draw.RectRound(VBO, nil, z - 0.00, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- body
	local body = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { color[1]*0.5, color[2]*0.5, color[3]*0.5, opacity }, { color[1], color[2], color[3], opacity })

	-- highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local top = Draw.RectRound(VBO, nil, z - 0.002, px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.03 + (0.18*opacity) })
	-- bottom
	local bottom = Draw.RectRound(VBO, nil, z - 0.003, px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.015 + (0.06*opacity) }, { 1,1,1,0  })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	return {darkoutline, body, top, bottom}
end

-- remove a set of elements from the VBO
Draw.RemoveUIElements = function(VBO, instanceIDs, noUpload)
	for i,k in ipairs(instanceIDs) do
		popElementInstance(VBO, k, noUpload)
	end
	return noUpload
end

-- toggle the visibilitystate to true, or false, pass nil to toggle the original value 
Draw.ToggleUIElements = function(VBO, instanceIDs, visibilitystate, noUpload)
	local visibility_index = 4 * 6 
	for i,k in ipairs(instanceIDs) do
		local offset = VBO.intanceIDtoIndex[k]
		if k then 
			if visibilitystate ~= nil then
				VBO.instanceData[offset + visibility_index] = visibilitystate
			else
				VBO.instanceData[offset + visibility_index] = 1.0 - VBO.instanceData[offset + visibility_index]
			end
		end
	end
	if noUpload ~= true then 
		uploadAllElements(VBO)
	end
	return noUpload
end
----------------------------------------------------------------
-- Callins
----------------------------------------------------------------



local btninstance = nil


function widget:Initialize()
	makeRectRoundVBO()
	makeShaders()
	
	rectRoundVAO = gl.GetVAO()
	
	rectRoundVAO:AttachVertexBuffer(rectRoundVBO.instanceVBO)
	rectRoundVBO.instanceVAO = rectRoundVAO
	
	WG['flowui_instancevbo'] = rectRoundVBO
	WG['flowui_shader'] = rectRoundShader
	WG['flowui_draw'] = Draw

	--[[for k = 1 , 1000 do
		local x = math.floor(math.random()*vsx)
		local y = math.floor(math.random()*vsy)
		local w = x+math.floor(math.random()*200+20)
		local h = y+math.floor(math.random()*150+10)
		btninstance = Draw.Button(rectRoundVBO, nil, 0.4, x,y,w,h, 1,1,1,1, 1,1,1,1, nil, { 0.035, 0.4, 0.035, 0.8 }, { 0.05, 0.6, 0.5, 0.8 },  Spring.FlowUI.elementCorner*0.4)
	end]]--	

	--Draw.Button(rectRoundVBO, nil, 0.4, 500,0,1524,1000, 24,24,32,60, 1,1,1,1, nil, { math.random(), math.random(), math.random(), 0.8 }, { math.random(), math.random(), math.random(), 0.8 },  Spring.FlowUI.elementCorner*0.4)
end

function widget:Shutdown()
	WG['flowui_instancevbo'] = nil
	WG['flowui_shader'] = nil
	WG['flowui_draw'] = nil

	if rectRoundShader then
		rectRoundShader:Finalize()
	end
end

elems = 0

function widget:DrawScreen()
	if atlasID == nil then 
		atlasID = WG['flowui_atlas'] 
		atlassedImages = WG['flowui_atlassedImages'] 
		Spring.Utilities.TableEcho({gl.GetAtlasTexture(atlasID, "unitpics/armcom.png")})
	end
	if elems < 100 then
		elems = elems+1
		local x = math.floor(math.random()*vsx) 
		local y = math.floor(math.random()*vsy)
		local s = math.floor(math.random()*35+70)
		local w = x+s*2
		local h = y+s
		local r = math.random()
		if r < 0.1 then
			--btninstance = Draw.Button(rectRoundVBO, nil, 0.4, x,y,w,h, 1,1,1,1, 1,1,1,1, nil, { math.random(), math.random(), math.random(), 0.8 }, { math.random(), math.random(), math.random(), 0.8 },  Spring.FlowUI.elementCorner*0.4)
		elseif r < 0.2 then
			btninstance = Draw.Button(rectRoundVBO, nil, 0.4, x,y,w,h, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, {0.2, 0.8, 0.2, 0.8 }, Spring.FlowUI.elementCorner * 0.5)
			--Draw.SelectHighlight(rectRoundVBO, nil, 0.5, x,y,w,h,1)
		elseif r < 0.3 then
			Draw.Selector(rectRoundVBO, nil, 0.5, x,y,w,h)
		elseif r < 0.4 then
			Draw.Slider(rectRoundVBO, nil, 0.5, x,y,w,h, 10, 1, 11)
		elseif r < 0.6 then
			Draw.SliderKnob(rectRoundVBO, nil, 0.5, x,y,s)

		elseif r < 0.7 then
			Draw.Toggle(rectRoundVBO, nil, 0.5, x,y,w,h, true)
			
		elseif r < 0.8 then
			--Draw.TexturedRectRound(rectRoundVBO, nil, 0.5, x,y,w,h, 10,1,1,1,1,nil,nil,nil,"icons/armpwt4.png")
			Draw.Element(
			rectRoundVBO, nil, 0.5, x,y,w,h, 
				1,1,1,1,
				1,1,1,1,
				nil,
				{ 0, 0, 0, 0.8 }, { 0.2, 0.8, 0.2, 0.8 },nil
			
			)
		elseif r < 0.9 then

			Draw.Unit(rectRoundVBO, nil, 0.5, x,y,w,y+2*s, 20, 
			1,1,1,1,
			1, nil, 0.8, -- zoom, bordersize, borderOpacity
			"unitpics/corcom.png", 
			"icons/bantha.png",
			"luaui/images/metal.png", --grouptexture
			500, 7)
	
		elseif r < 1.0 then 
			Draw.Scroller( rectRoundVBO, nil, 0.5, x,y,x+s/2,y+2*s, 1000, 20)
		end
	end
	local UiButton = Spring.FlowUI.Draw.Button
	UiButton(500, 500, 600, 550, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, { 0.2, 0.8, 0.2, 0.8 }, Spring.FlowUI.elementCorner * 0.5)
	if chobbyInterface then return end
	
	
	if rectRoundVBO.dirty then uploadAllElements(rectRoundVBO) end -- do updates!
	gl.Blending(GL.SRC_ALPHA, GL.ONE) -- bloomy
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- regular
	gl.Texture(0, "modules/flowui/images/backgroundtile.png")
	gl.Texture(1, atlasID)
	rectRoundShader:Activate()
	rectRoundVAO:DrawArrays(GL.POINTS)
	rectRoundShader:Deactivate()
	gl.Texture(1, false)
	gl.Texture(0, false)
end
