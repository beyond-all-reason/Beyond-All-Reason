function widget:GetInfo()
	return {
		name      = "Forest GL4",
		desc      = "fucking trees",
		author    = "Beherith",
		date      = "2021.07.14",
		license   = "CC BY-NC",
		layer     = 0,
		enabled   = false
	}
end
 
------- GL4 NOTES -----
-- 10k trees:
--  - 60 fps without index buffer


local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local treeShader = nil

local treeInstanceVBO = nil


local SHADERRESOLUTION = 24 -- THIS SHOULD MATCH RADARMIPLEVEL!

local vsSrc = [[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec3 vertexPos;
layout (location = 1) in vec3 vertexNormal;
layout (location = 2) in vec3 stangent;
layout (location = 3) in vec3 ttangent;
layout (location = 4) in vec2 texcoords0;
layout (location = 5) in vec2 texcoords1;
layout (location = 6) in float pieceindex;
layout (location = 7) in vec4 worldpos_rot; //x, y, z, rot
layout (location = 8) in vec4 scale; //x, y, z, global
layout (location = 9) in vec4 color; //rgba
layout (location = 10) in vec4 uvoffsets; //rgba

uniform vec4 radarcenter_range;  // x y z range
uniform float resolution;  // how many steps are done

uniform sampler2D heightmapTex;

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 texcoords;
	vec4 blendedcolor;
	mat3 TBN;
	
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

vec3 windsweep(vec3 oldpos, vec3 treecenter){
	vec3 randos = vec3(10, 20.9, 11.7) * timeInfo.x * 0.02 + (oldpos*0.1);
	randos = randos + treecenter;
	float heightfactor = oldpos.y*0.01;
	float sidefactor = abs(oldpos.x + oldpos.z) * 0.02;
	
	randos = sin(randos*0.1);
	
	vec3 displace = sidefactor * randos.xzy;
	displace.xz += heightfactor * randos.xz;
	
	vec3 newpos = oldpos + displace;
	return newpos;
}

void main() {
	
	vec3 scaledModelPos = (vertexPos * scale.w);// * scale.xyz; // TODO: also scale the TBN?
	
	mat3 rotY = rotation3dY(worldpos_rot.w);
	
	vec3 rotatedModelPos = rotY * scaledModelPos;
	
	rotatedModelPos = windsweep(rotatedModelPos, worldpos_rot.xyz);
	
	vec3 pointWorldPos = rotatedModelPos + worldpos_rot.xyz; 
	
	vec3 T = normalize(vec3(rotY * stangent));
	vec3 B = normalize(vec3(rotY * ttangent));
	vec3 N = normalize(vec3(rotY * vertexNormal));
	
	TBN = mat3(T, B, N);
	
	vec3 sunPos = normalize(vec3(1.0, 2.0, -1.0));
	
	gl_Position = cameraViewProj * vec4(pointWorldPos.xyz, 1.0);
	texcoords.xy = texcoords0;
	texcoords.zw = texcoords1;
	blendedcolor = (color -1.0) * 0.2 + 1.0;
	
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

uniform vec4 radarcenter_range;  // x y z range
uniform float resolution;  // how many steps are done

uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D texnormal;

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__
in DataVS {
	vec4 worldPos; // pos and radius
	vec4 texcoords;
	vec4 blendedcolor;
	mat3 TBN;
};

out vec4 fragColor;

#line 20200
void main() {
	fragColor.a = 1.0;
	vec4 tex1s = texture(tex1,texcoords.xy);
	vec4 tex2s = texture(tex2,texcoords.xy);
	vec4 texns = texture(texnormal,texcoords.xy);
	//texns = vec4(0.5,0.5,1.0,0.0);
	texns.rgb = normalize(texns.rgb);
	vec3 normal = texns.rgb * 2.0 - 1.0;
	normal = normalize(TBN * normal.xyz);
	
	
	vec3 sunPos = normalize(vec3(1.0, 2.0, -1.0));// mat3(shadowView) * vec3(0,0,1) no bueno
	
	fragColor.rgb = (normal + 1.0) * 0.5 ;
	
	
	float diffuse = clamp(dot(normalize(normal), sunPos), 0.00, 1.0);
	
	vec3 treebasecolor = tex1s.rgb * blendedcolor.rgb;
	
	vec3 ambienttreecolor = treebasecolor * sunAmbientModel.rgb;
	
	vec3 diffusetreecolor = treebasecolor * sunDiffuseModel.rgb * diffuse;
	

	fragColor.rgb =  1.5*ambienttreecolor + 2.0* diffusetreecolor;	
	
	//fragColor.rgb = vec3(diffuse);
	
	//fragColor.rgb = normal.rgb * (blendedcolor.rgb + 0.5);
	fragColor.a = tex2s.a;
	if (tex2s.a<0.5) discard;
}
]]

local function goodbye(reason)
  Spring.Echo("treeShader GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end
local function pushrandotrees(count)
	for i = 1, count do
		local x = math.random()*Game.mapSizeX
		local z = math.random()*Game.mapSizeZ
		local y= Spring.GetGroundHeight(x,z)
		pushElementInstance(treeInstanceVBO, {
			x, y,z,math.random()*6.14,
			math.random() + 0.5, math.random() + 0.5, math.random() + 0.5, math.random() + 0.5,
			math.random(), math.random(), math.random(), math.random(), 
			0.0, 0.0, 0.0, 0.0,
		})
	end

end
local function initgl4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	treeShader =  LuaShader(
		{
		  vertex = vsSrc:gsub("//__DEFINES__", "#define SHADERRESOLUTION "..tostring(SHADERRESOLUTION+0.0001)),
		  fragment = fsSrc:gsub("//__DEFINES__", "#define USE_STIPPLE ".. tostring(usestipple) ),
		  --geometry = gsSrc, no geom shader for now
		  uniformInt = {
			tex1 = 0,
			tex2 = 1,
			texnormal = 2,
			},
		  uniformFloat = {
			radarcenter_range = {2000,100,2000,2000},
			resolution = {32},
		  },
		},
		"treeShader GL4"
	  )
	shaderCompiled = treeShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile treeShader  GL4 ") end

	tree = VFS.Include("luaui/images/luagrass/fir_tree_small_1()tree_fir_tall_5.obj.lua")
	--tree = VFS.Include("luaui/images/luagrass/cube_sphere.obj.lua")

	local treeVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	treeVBO:Define(tree.numVerts,tree.VBOLayout) -- TODO
	treeVBO:Upload(tree.VBOData)

	local treeIndexVBO =  gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	local defres = treeIndexVBO:Define(tree.numIndices)
	local upres = treeIndexVBO:Upload(tree.indexArray)

	--Spring.Echo(treeIndexVBO, defres, upres)
	--Spring.Echo(treeIndexVBO:DumpDefinition())
	--Spring.Utilities.TableEcho(treeIndexVBO:Download())
	
	treeInstanceVBO = makeInstanceVBOTable({
		{id = 7, name = 'worldpos_rot', size = 4},
		{id = 8, name = 'scale', size = 4},
		{id = 9, name = 'colormod', size = 4},
		{id = 10, name = 'uvoffsets', size = 4},
		}, 
		256, "treeInstanceVBO")
		
	treeInstanceVBO.numVertices = tree.numVerts
	treeInstanceVBO.vertexVBO = treeVBO
	treeInstanceVBO.VAO = gl.GetVAO()
	treeInstanceVBO.VAO:AttachIndexBuffer(treeIndexVBO)
	treeInstanceVBO.VAO:AttachVertexBuffer(treeVBO)
	treeInstanceVBO.VAO:AttachInstanceBuffer(treeInstanceVBO.instanceVBO)
	
	treeInstanceVBO.primitiveType = GL.TRIANGLES
	
	pushElementInstance(treeInstanceVBO, {
		370,150,680,math.random()*6.14,
		1.0, 1.0, 1.0, 1.0,
		math.random(), math.random(), math.random(), math.random(), 
		0.0, 0.0, 0.0, 0.0,
	})
	math.randomseed(1)
	pushrandotrees(1000)
	
end

-- Functions shortcuts

-- Globals
local chobbyInterface

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:Initialize()
	initgl4()
end

function widget:Shutdown()
end
local mousepos = {0,0,0}
function widget:Update()
	local mx, my, lp, mp, rp, offscreen = Spring.GetMouseState ( )
	local _ , coords = Spring.TraceScreenRay(mx,my,true)
	if coords then 
		mousepos = {coords[1],coords[2],coords[3]}
	end

end


local function dodraw(shadowpass)
    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    gl.Culling(GL.BACK) -- needs better front and back instead of using this
	
	gl.Texture(0, "luaui/images/luagrass/tree_fir_tall_5_1.dds")
	gl.Texture(1, "luaui/images/luagrass/tree_fir_tall_5_2.dds")
	gl.Texture(2, "luaui/images/luagrass/tree_fir_tall_5_normal.dds")
	treeShader:Activate()
	--[[treeShader:SetUniform("radarcenter_range", 
		mousepos[1],
		mousepos[2] + 64,
		mousepos[3],
		2100
		)]]--
	
	--drawInstanceVBO(treeInstanceVBO)
	treeInstanceVBO.VAO:DrawArrays(GL.TRIANGLES, treeInstanceVBO.numVertices, 0, treeInstanceVBO.usedElements, 0)
	--treeInstanceVBO.VAO:DrawElements(GL.TRIANGLES, 100, 0, treeInstanceVBO.usedElements, 0)
	
	treeShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	
    gl.DepthTest(GL.ALWAYS)
    gl.DepthMask(false)
    gl.Culling(GL.BACK)
end

--[[

    iT.VAO:DrawArrays(iT.primitiveType, iT.numVertices, 0, iT.usedElements,0)

]]--


function widget:DrawWorldShadow()
	--Spring.Echo("Drwing shadows")
	--dodraw()
end



function widget:DrawWorld()
    if chobbyInterface then return end
    --if spIsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then return end
	dodraw()

end

