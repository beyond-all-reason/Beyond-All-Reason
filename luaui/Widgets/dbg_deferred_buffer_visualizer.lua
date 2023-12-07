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
myshaderDebgDrawLoc = nil
myshaderTexture0Loc = nil
local dbgDraw = 0
local depthCopyTex = nil

deferredbuffers = ({
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

currentbuffer = 13 -- starts with model_gbuffer_normtex

local function RemoveMe(msg)
	Spring.Echo(msg)
	widgetHandler:RemoveWidget()
end

local function MakeShader()
	if (gl.DeleteShader) then
		if myshader ~= nil then gl.DeleteShader(myshader or 0) end
	end

	myshader = gl.CreateShader({
		fragment = [[
			uniform sampler2D texture0;
			uniform int debugDraw;
			void main(void) {
				vec4 a = texture2D(texture0, gl_TexCoord[0].st);
				if (debugDraw == 0) {
					gl_FragColor = a;
				} else {
					if (debugDraw==1){
						a.r= a.a;
						a.a = 1.0;
						gl_FragColor = a;
						gl_FragColor = vec4(fract(a.rbg), 1.0);
					}else{
						a.rgb = fract(100*(pow(a.rgb, vec3(8.0))));
						a.a = 1.0;
						gl_FragColor = a;
					}
				}
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
		uniformInt = { texture0 = 0, debugDraw = 0}
	})

	if (myshader == nil) then
		RemoveMe("[deferred buffer visualizer] myshader compilation failed"); print(gl.GetShaderLog()); return
	end

	myshaderDebgDrawLoc = gl.GetUniformLocation(myshader, "debugDraw")
	myshaderTexture0Loc = gl.GetUniformLocation(myshader, "texture0")

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
	AddChatActions()
	MakeShader()
end

function widget:Shutdown()
	RemoveChatActions()
	if (gl.DeleteShader) then
		if brightShader ~= nil then gl.DeleteShader(myshader or 0) end
	end
end

function widget:DrawWorld()
	if deferredbuffers[currentbuffer] == 'depthcopy' then
		local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
		gl.CopyToTexture(depthCopyTex, 0, 0, vpx, vpy, vsx, vsy) -- the original screen image
	end
	gl.Blending(GL.ONE, GL.ZERO)
	gl.UseShader(myshader)
	gl.UniformInt(myshaderTexture0Loc, 0)
	
	if deferredbuffers[currentbuffer] == 'depthcopy' then
		gl.Texture(0, depthCopyTex)
		gl.UniformInt(myshaderDebgDrawLoc, 2)
	else
		gl.Texture(0, deferredbuffers[currentbuffer])
	gl.UniformInt(myshaderDebgDrawLoc, dbgDraw)
	end
	gl.TexRect(0, -1, 1, 1, 0.5, 0, 1, 1)
	gl.Texture(0, false)
	gl.UseShader(0)
	gl.Blending("reset")
end

function AddChatActions()
	local function EchoVars()
		Spring.Echo("[deferred buffer visualizer] buff=".. tostring(currentbuffer) .. " alphaasred=" ..tostring(dbgDraw) .. " info:".. deferredbuffers[currentbuffer] .. ":" .. deferredbuffer_info[deferredbuffers[currentbuffer]])
	end

	local function nextbuffer() currentbuffer = math.min(currentbuffer+1, #deferredbuffers) ; EchoVars() end
	local function prevbuffer() currentbuffer = math.max(currentbuffer-1, 1) ; EchoVars() end
	local function DebugToggle()
		if dbgDraw == 1 then
			dbgDraw = 0
		else
			dbgDraw = 1
		end
		EchoVars()
	end
	local function DebugOff() dbgDraw = 0; EchoVars() end

	widgetHandler:AddAction("nextbuffer", nextbuffer, nil, 't')
	widgetHandler:AddAction("prevbuffer", prevbuffer, nil, 't')
	widgetHandler:AddAction("alphabuffer", DebugToggle, nil, 't')
end

function RemoveChatActions()
	widgetHandler:RemoveAction("nextbuffer", nextbuffer, nil, 't')
	widgetHandler:RemoveAction("prevbuffer", prevbuffer, nil, 't')
	widgetHandler:RemoveAction("alphabuffer", DebugToggle, nil, 't')
end
