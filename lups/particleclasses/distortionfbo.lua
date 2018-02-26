-- $Id: distortionFBO.lua 4396 2009-04-15 21:42:33Z jk $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--//FIXME: GL_TEXTURE_RECTANGLE support (LuaFBO doesn't support it yet?)

local PostDistortion = {}
local pd = PostDistortion 
PostDistortion.__index = PostDistortion

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--//shader+FBO/MRT
local fbo
local depthTex, screenCopyTex, jitterTex
local jitterShader
local screenSizeLoc

--//DisplayLists
local enterIdentity,postDrawAndLeaveIdentity

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--// some GL const

local GL_TEXTURE_RECTANGLE = 0x84F5

local GL_RGBA16F_ARB = 0x881A
local GL_RGBA32F_ARB = 0x8814

local GL_RGBA12 = 0x805A
local GL_RGBA16 = 0x805B

local GL_DEPTH_BITS        = 0x0D56
local GL_DEPTH_COMPONENT   = 0x1902
local GL_DEPTH_COMPONENT16 = 0x81A5
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_DEPTH_COMPONENT32 = 0x81A7

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
local GL_COLOR_ATTACHMENT2_EXT = 0x8CE2
local GL_COLOR_ATTACHMENT3_EXT = 0x8CE3

local NON_POWER_OF_TWO = gl.HasExtension("GL_ARB_texture_non_power_of_two")
local TEXRECT          = gl.HasExtension("GL_ARB_texture_rectangle")
local FLOAT_TEXTURES   = gl.HasExtension("GL_ARB_texture_float")

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--// SYSTEM CONFIG
PostDistortion.texRectangle     = false
PostDistortion.jitterformat     = GL_RGBA16F_ARB
PostDistortion.depthformat      = GL_DEPTH_COMPONENT
PostDistortion.copyDepthBuffer  = true

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

PostDistortion.layer = 1
PostDistortion.dieGameFrame = math.huge
PostDistortion.repeatEffect = true

function PostDistortion.GetInfo()
  return {
    name      = "PostDistortion",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 1, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    rtt       = true,
    ctt       = true,
    ms        = -1,
  }
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function PostDistortion.ViewResize()
  gl.DeleteTexture(depthTex)
  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(screenCopyTex)
    gl.DeleteTextureFBO(jitterTex)
  end

  local target = (pd.texRectangle and GL_TEXTURE_RECTANGLE)

  depthTex = gl.CreateTexture(vsx,vsy, {
    target = target,
    format = PostDistortion.depthformat,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
    wrap_s   = GL.CLAMP_TO_EDGE,
    wrap_t   = GL.CLAMP_TO_EDGE,
  })

  screenCopyTex = gl.CreateTexture(vsx,vsy, {
    target = target,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s   = GL.CLAMP_TO_EDGE,
    wrap_t   = GL.CLAMP_TO_EDGE,
  })

  jitterTex = gl.CreateTexture(vsx,vsy, {
    target = target,
    format = PostDistortion.jitterformat,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
    wrap_s   = GL.CLAMP_TO_EDGE,
    wrap_t   = GL.CLAMP_TO_EDGE,
  })

  fbo.depth  = depthTex
  fbo.color0 = jitterTex
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local GL_COLOR_BUFFER_BIT = GL.COLOR_BUFFER_BIT
local GL_DEPTH_BUFFER_BIT = GL.DEPTH_BUFFER_BIT
local GL_DEPTH_COLOR_BUFFER_BIT = math.bit_or(GL_DEPTH_BUFFER_BIT,GL_COLOR_BUFFER_BIT)
local glActiveFBO     = gl.ActiveFBO
local glCopyToTexture = gl.CopyToTexture
local glCallList      = gl.CallList
local glTexture       = gl.Texture


function PostDistortion:BeginDraw()
  if depthTex then
    glActiveFBO(fbo, gl.Clear, GL_COLOR_BUFFER_BIT, 0,0,0,0) --//clear jitterTex

    --// copy depthbuffer to a seperated depth texture, so we can use it in the MRT
    if (pd.copyDepthBuffer) then
      glCopyToTexture(depthTex, 0, 0, vpx, vpy, vsx, vsy)
    end

    --// update screen copy
    glCopyToTexture(screenCopyTex, 0, 0, vpx, vpy, vsx, vsy)
  end
end

function PostDistortion:EndDraw()
  glCallList(enterIdentity);
  if (pd.texRectangle) then glUniform(screenSizeLoc,vsx,vsy) end
  glTexture(0,jitterTex);
  glTexture(1,screenCopyTex); 
  glCallList(postDrawAndLeaveIdentity);
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function PostDistortion.Initialize()
  ------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------
  -- HARDWARE CHECK
  --

  if (LupsConfig.distortions==false) then
    return false
  end

  if (not (LupsConfig.distortions==true)) then
    if (not NON_POWER_OF_TWO)and(not TEXRECT) then
      print(PRIO_LESS,"LUPS->Distortion: your hardware is missing non_power_of_two texture support.")
      return false
    end

    if (not FLOAT_TEXTURES) then
      print(PRIO_LESS,"LUPS->Distortion: your hardware is missing floating point texture support.")
      return false
    end
  end

  ------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------

  if (type(LupsConfig.distortioncopydepthbuffer)=="boolean") then
    pd.copyDepthBuffer = LupsConfig.distortioncopydepthbuffer
  end

  ------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------
  -- CREATE SHADER
  --

  local defines = ""
  if (pd.copyDepthBuffer) then defines = defines .. "#define depthtexture\n" end

  jitterShader = gl.CreateShader({
    fragment = defines .. [[
      #ifdef texrect
        #extension GL_ARB_texture_rectangle : enable

        #define sampler2D sampler2DRect
        #define texture2D texture2DRect
        uniform vec2 ScreenSize;
      #endif

        uniform sampler2D infoTex;
        uniform sampler2D screenTex;

      #ifdef depthtexture
        uniform sampler2D depthTex;
      #endif

        void main(void)
        {

      #ifdef texrect
          vec2 texcoord  = gl_FragCoord.xy;
      #else
          vec2 texcoord  = gl_TexCoord[0].st;
      #endif

          vec4 offset  = texture2D(infoTex, texcoord );
          if (offset.a>0.001) {

      #ifdef texrect
            vec2 texcoord2 = gl_FragCoord.xy+offset.st*ScreenSize;
      #else
            vec2 texcoord2 = gl_TexCoord[0].st+offset.st;
      #endif

            gl_FragColor = texture2D(screenTex, texcoord2 );
            gl_FragColor.rgb += offset.b;

      #ifdef depthtexture
           gl_FragDepth = texture2D(depthTex, texcoord ).z;
      #endif

          }else{
            discard;
          }
        }
    ]],
    uniformInt = {
      infoTex   = 0,
      screenTex = 1,
      depthTex  = 2,
      ScreenSize = {vsx,vsy},
    },
  })

  if (jitterShader==nil) then
    print(PRIO_MAJOR,"LUPS->Distortion: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end

  if (pd.texRectangle) then
    screenSizeLoc = gl.GetUniformLocation(jitterShader,"ScreenSize")
  end

  ------------------------------------------------------------------------------------------
  ------------------------------------------------------------------------------------------
  -- FBO + some OpenGL stuff
  --

  enterIdentity = gl.CreateList(function()
    gl.DepthTest(false);
    gl.UseShader(jitterShader);
    gl.Blending(GL.ONE,GL.ZERO);

    gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity();
    gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity();
  end)

  postDrawAndLeaveIdentity = gl.CreateList(function()
    gl.TexRect(-1,1,1,-1);
    gl.Texture(0,false);
    gl.Texture(1,false);
    gl.Texture(2,false);

    gl.MatrixMode(GL.PROJECTION); gl.PopMatrix();
    gl.MatrixMode(GL.MODELVIEW);  gl.PopMatrix();

    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
    gl.UseShader(0);
    gl.DepthTest(true);
  end)

  fbo = gl.CreateFBO()
  fbo.drawbuffers = GL_COLOR_ATTACHMENT0_EXT
  pd.fbo = fbo
end

function PostDistortion.Finalize()
  gl.DeleteTexture(depthTex or 0)
  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(screenCopyTex or 0)
    gl.DeleteTextureFBO(jitterTex or 0)
  end
  if (gl.DeleteFBO) then
    gl.DeleteFBO(fbo or 0)
  end
  if (gl.DeleteShader) then
    gl.DeleteShader(jitterShader or 0)
  end

  gl.DeleteList(enterIdentity or 0) 
  gl.DeleteList(postDrawAndLeaveIdentity or 0)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function PostDistortion.Create()
  local newObject = {}
  setmetatable(newObject,PostDistortion)
  return newObject
end

function PostDistortion:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return PostDistortion