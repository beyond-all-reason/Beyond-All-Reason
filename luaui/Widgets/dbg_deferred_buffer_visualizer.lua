local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	  = "Deferred Buffer visualizer",
		desc	  = "Swap buffers with /luaui prevbuffer|nextbuffer, show alpha in red with /luaui ",
		author	= "Beherith",
		date	  = "2016-03-30",
		license   = "GNU GPL, v2 or later",
		layer	 = 9999999,
		enabled   = false,
	}
end

local myshader = nil
local myshaderDebgDrawLoc = nil
local myshaderTexture0Loc = nil
local dbgDraw = 0
local depthCopyTex = nil

local deferredbuffers = ({
	"$map_gbuffer_normtex",
	"$map_gbuffer_difftex",
	"$map_gbuffer_spectex",
	"$map_gbuffer_emittex",
	"$map_gbuffer_misctex",
	"$map_gbuffer_zvaltex",

	"$model_gbuffer_normtex",
	"$model_gbuffer_difftex" ,
	"$model_gbuffer_spectex" ,
	"$model_gbuffer_emittex" ,
	"$model_gbuffer_misctex" ,
	"$model_gbuffer_zvaltex",
	"depthcopy",
})
deferredbuffer_info= ({
	["$map_gbuffer_normtex"] ="contains the smoothed normals buffer of the map in view in world space coordinates (note that to get true normal vectors from it, you must multiply the vector by 2 and subtract 1)",
	["$map_gbuffer_difftex"] 	= "contains the diffuse texture buffer of the map in view New in version 95",
	["$map_gbuffer_spectex"] 	= "contains the specular textures of the map in view New in version 95",
	["$map_gbuffer_emittex"] 	= "for emissive materials (bloom would be the canonical use) New in version 95",
	["$map_gbuffer_misctex"] 	= "for arbitrary shader data New in version 95",
	["$map_gbuffer_zvaltex"] 	= "contains the depth values (z-buffer) of the map in view. New in version 95",
	["$model_gbuffer_normtex"] 	= "contains the smoothed normals buffer of the models in view in world space coordinates (note that to get true normal vectors from it, you must multiply the vector by 2 and subtract 1) New in version 95",
	["$model_gbuffer_difftex"] 	= "contains the diffuse texture buffer of the models in view New in version 95",
	["$model_gbuffer_spectex"] 	= "contains the specular textures of the models in view New in version 95",
	["$model_gbuffer_emittex"] 	= "for emissive materials (bloom would be the canonical use) New in version 95",
	["$model_gbuffer_misctex"] 	= "for arbitrary shader data New in version 95",
	["$model_gbuffer_zvaltex"]	= "contains the depth values (z-buffer) of the models in view. ",
	["depthcopy"]	= "A copy of the current depth buffer. ",
})

local currentbuffer = 13 -- starts with model_gbuffer_normtex

local function RemoveMe(msg)
	Spring.Echo(msg)
	widgetHandler:RemoveWidget()
end

local function MakeShader()
	if (gl.DeleteShader) then
		if myshader ~= nil then gl.DeleteShader(myshader or 0) end
	end

	local uniformInts = {}
	for i, texname in ipairs(deferredbuffers) do 
		uniformInts[string.gsub(texname, "%$", "")] = i-1
	end
	
	myshader = gl.CreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform sampler2D map_gbuffer_normtex;
			uniform sampler2D map_gbuffer_difftex;
			uniform sampler2D map_gbuffer_spectex;
			uniform sampler2D map_gbuffer_emittex;
			uniform sampler2D map_gbuffer_misctex;
			uniform sampler2D map_gbuffer_zvaltex;
			uniform sampler2D model_gbuffer_normtex;
			uniform sampler2D model_gbuffer_difftex;
			uniform sampler2D model_gbuffer_spectex;
			uniform sampler2D model_gbuffer_emittex;
			uniform sampler2D model_gbuffer_misctex;
			uniform sampler2D model_gbuffer_zvaltex;
			uniform sampler2D depthcopy;
			uniform int debugDraw;
		
			#define lind(value) (fract(0.2* (1.0/(1.0 - value))))
			
			
			void main(void) {
				vec2 uvs = gl_TexCoord[0].st;
				//vec4 a = texture2D(texture0, gl_TexCoord[0].st);
				vec4 o = vec4(0.0);
				if (uvs.x > 0.875){ 
					// fourth column normals, diffuse
					if (uvs.y > 0.75){
						o = texture2D(map_gbuffer_normtex, uvs);
						o.a = 1.0;
					}else if (uvs.y > 0.5){
						o = texture2D(model_gbuffer_normtex, uvs);
						o.a = 1.0;
					}else if (uvs.y > 0.25){
						o = texture2D(map_gbuffer_difftex, uvs);
						o.a = 1.0;
					}else{
						o = texture2D(model_gbuffer_difftex, uvs);
						o.a = 1.0;
					}
				}else if (uvs.x > 0.75){
					// third column spec, emit
					if (uvs.y > 0.75){
						o = texture2D(map_gbuffer_spectex, uvs);
						o.a = 1.0;
					}else if (uvs.y > 0.5){
						o = texture2D(map_gbuffer_emittex, uvs);
						o.a = 1.0;
					}else if (uvs.y > 0.25){
						o = texture2D(model_gbuffer_spectex, uvs);
						o.a = 1.0;
					}else{
						o = texture2D(model_gbuffer_emittex, uvs);
						o.a = 1.0;
					}
				
				}else if (uvs.x > 0.625){
					// second column depthcopy, misc
					if (uvs.y > 0.75){
						o = texture2D(depthcopy, uvs).rrrr;
						o.a = 1.0;
					}else if (uvs.y > 0.5){
						o = texture2D(depthcopy, uvs).rrrr;
						o = lind(o);
						o.a = 1.0;
					}else if (uvs.y > 0.25){
						o = texture2D(map_gbuffer_misctex, uvs);
						o.a = 1.0;
					}else{
						o = texture2D(model_gbuffer_misctex, uvs);
						o.a = 1.0;
					}
				
				}else{
					// first column map depth, model depth
					if (uvs.y > 0.75){
						o = texture2D(map_gbuffer_zvaltex, uvs).rrrr;
						o.a = 1.0;
					}else if (uvs.y > 0.5){
						o = texture2D(model_gbuffer_zvaltex, uvs).rrrr;
						o.a = 1.0;
					}else if (uvs.y > 0.25){
						o = texture2D(map_gbuffer_zvaltex, uvs).rrrr;
						o = lind(o);
						o.a = 1.0;
					}else{
						o = texture2D(model_gbuffer_zvaltex, uvs).rrrr;
						o = lind(o);
						o.a = 1.0;
					}
				
				}
			
				gl_FragColor = o;
			}
		]],
		--while this vertex shader seems to do nothing, it actually does the very important world space to screen space mapping for gl.TexRect!
		vertex = [[

			void main(void)
			{
				gl_TexCoord[0] = gl_MultiTexCoord0;
				gl_Position	= gl_Vertex;
			}
		]],
		uniformInt = uniformInts,
	})

	if (myshader == nil) then
		RemoveMe("[deferred buffer visualizer] myshader compilation failed"); print(gl.GetShaderLog()); return
	end

	myshaderDebgDrawLoc = gl.GetUniformLocation(myshader, "debugDraw")
	--myshaderTexture0Loc = gl.GetUniformLocation(myshader, "texture0")

end


function widget:Initialize()
	if (gl.CreateShader == nil) then
		RemoveMe("[deferred buffer visualizer] removing widget, no shader support")
		return
	end
	hasdeferredrendering = (Spring.GetConfigString("AllowDeferredModelRendering")=='1') and (Spring.GetConfigString("AllowDeferredMapRendering")=='1')
	if hasdeferredrendering == false then
		RemoveMe("[deferred buffer visualizer] removing widget, AllowDeferred Model and Map Rendering is required")
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local GL_DEPTH_COMPONENT24 = 0x81A6
	
	local GL_DEPTH_COMPONENT   = 0x1902
	local GL_DEPTH_COMPONENT32 = 0x81A7
	depthCopyTex = 	 gl.CreateTexture(vsx,vsy, {
		target = GL_TEXTURE_2D,
		format = GL_DEPTH_COMPONENT,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
	})
	if depthCopyTex == nil then Spring.Echo("Failed to allocate the depth texture", vsx,vsy) end 
	MakeShader()
end

function widget:Shutdown()
	RemoveChatActions()
	if (gl.DeleteShader) then
		if myshader ~= nil then gl.DeleteShader(myshader or 0) end
	end
end

function widget:DrawWorld()
	local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	
	gl.CopyToTexture(depthCopyTex, 0, 0, vpx, vpy, vsx, vsy) -- the original screen image

end

function widget:DrawScreenPost()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- https://www.andersriggelsen.dk/glblendfunc.php
	gl.UseShader(myshader)
	for i=1, 12 do
		gl.Texture(i-1, deferredbuffers[i])
	end
	gl.Texture(12, depthCopyTex)
	
	
	gl.TexRect(0, -1, 1, 1, 0.5, 0, 1, 1)
	for i=0, 12 do
		gl.Texture(i, false)
	end
	gl.UseShader(0)
	gl.Blending("reset")
end

