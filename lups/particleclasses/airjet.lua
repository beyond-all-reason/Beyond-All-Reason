-- $Id: AirJet.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local AirJet = {}
AirJet.__index = AirJet

local jetShader,jitShader
local tex --//screencopy
local timerUniform, timer2Uniform

local lastTexture1,lastTexture2

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function AirJet.GetInfo()
  return {
    name      = "AirJet",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 4, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    distortion= true,
    ms        = -1,
    intel     = -1,
  }
end


AirJet.Default = {
  --// visibility check
  los            = true,
  airLos         = true,
  radar          = false,
  
  layer = 4,
  life  = math.huge,
  repeatEffect  = true,

  emitVector    = {0,0,-1},
  pos           = {0,0,0}, --// not used
  width         = 4,
  length        = 50,
  color         = {0, 0, 0.5},
  distortion    = 0.02,
  jitterWidthScale  = 3,
  jitterLengthScale = 3,
  animSpeed     = 1,

  texture1      = "bitmaps/GPL/Lups/perlin_noise.jpg", --// noise texture
  texture2      = ":c:bitmaps/GPL/Lups/jet.bmp",       --// shape
  texture3      = ":c:bitmaps/GPL/Lups/jet.bmp",       --// jitter shape
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitLosState     = Spring.GetUnitLosState
local spIsSphereInView      = Spring.IsSphereInView
local spGetUnitRadius       = Spring.GetUnitRadius

local IsPosInLos    = Spring.IsPosInLos
local IsPosInAirLos = Spring.IsPosInAirLos
local IsPosInRadar  = Spring.IsPosInRadar

local spGetGameSeconds = Spring.GetGameSeconds
local glUseShader = gl.UseShader
local glUniform   = gl.Uniform
local glBlending  = gl.Blending
local glTexture   = gl.Texture
local glCallList  = gl.CallList
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local GL_ONE                 = GL.ONE

function AirJet:BeginDraw()
  glUseShader(jetShader)
    glUniform(timerUniform, spGetGameSeconds())
  glBlending(GL_ONE,GL_ONE)
end

function AirJet:EndDraw()
  glUseShader(0)
  glTexture(1,false)
  glTexture(2,false)
  glBlending(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA)
  lastTexture1,lastTexture2 = "",""
end

function AirJet:Draw()
  if not Spring.IsUnitIcon(self.unit) then
    self.isicon = false
    if (lastTexture1~=self.texture1) then
      glTexture(1,self.texture1)
      lastTexture1=self.texture1
    end
    if (lastTexture2~=self.texture2) then
      glTexture(2,self.texture2)
      lastTexture2=self.texture2
    end

    glCallList(self.dList)
  else
    self.isicon = true
  end
end



function AirJet:BeginDrawDistortion()
  glUseShader(jitShader)
    glUniform(timer2Uniform, spGetGameSeconds())
end

function AirJet:EndDrawDistortion()
  glUseShader(0)
  glTexture(1,false)
  glTexture(2,false)
  lastTexture1,lastTexture2 = "",""
end

function AirJet:DrawDistortion()
  if not self.isicon then
    if (lastTexture1~=self.texture1) then
      glTexture(1,self.texture1)
      lastTexture1=self.texture1
    end
    if (lastTexture2~=self.texture3) then
      glTexture(2,self.texture3)
      lastTexture2=self.texture3
    end

    glCallList(self.dList)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local time = 0
function AirJet:Update(n)
  time = time + n
  if time > 1.5 then
    time = 0
    if Spring.GetUnitMoveTypeData(self.unit) and Spring.GetUnitMoveTypeData(self.unit).aircraftState == "crashing" then
      self.repeatEffect = false
      self.dieGameFrame = Spring.GetGameFrame() + 1
    end
  end

  if self.light then
    if not WG['lighteffects'] or not WG['lighteffects'].enableThrusters then
      self.lightID = nil
    else
      if not self.visible or self.isicon then  -- temporarily disabled for testing purposesif self.lightID then
        if self.lightID then
          WG['lighteffects'].removeLight(self.lightID, 3)
          self.lightID = nil
        end
      else
        local unitPos = {Spring.GetUnitPosition(self.unit)}
        local pitch, yaw = Spring.GetUnitRotation(self.unit)
        local lightOffset = Spring.GetUnitPieceInfo(self.unit, self.piecenum).offset

        -- still just only Y thus inacurate
        local lightOffsetRotYx = lightOffset[1]*math.cos(3.1415+math.rad( 90+(((yaw+1.571)/6.2)*360) ))- lightOffset[3]*math.sin(3.1415+math.rad(90+ (((yaw+1.571)/6.2)*360) ))
        local lightOffsetRotYz = lightOffset[1]*math.sin(3.1415+math.rad( 90+(((yaw+1.571)/6.2)*360) ))+ lightOffset[3]*math.cos(3.1415+math.rad(90+ (((yaw+1.571)/6.2)*360) ))
		
        local offsetX = lightOffsetRotYx
        local offsetY = lightOffset[2] --+ 7  -- add some height to make the light shine a bit more on top (for debugging)
        local offsetZ = lightOffsetRotYz

        local radius = 0.8 * ((self.width*self.length) * (0.8+(math.random()/10)))  -- add a bit of flickering

        if not self.lightID then
          if not self.color[4] then
            self.color[4] = self.light * 0.6
          end
          self.lightID = WG['lighteffects'].createLight('thruster',unitPos[1]+offsetX, unitPos[2]+offsetY, unitPos[3]+offsetZ, radius, self.color)
        else
          if not WG['lighteffects'].editLight(self.lightID, {px=unitPos[1]+offsetX, py=unitPos[2]+offsetY, pz=unitPos[3]+offsetZ, param={radius=radius}}) then
            self.lightID = nil
          end
        end
      end
    end
  end
end

-- used if repeatEffect=true;
function AirJet:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function AirJet.Initialize()

  jetShader = gl.CreateShader({
    vertex = [[
      uniform float timer;

      varying float distortion;
      varying vec4 texCoords;

      const vec4 centerPos = vec4(0.0,0.0,0.0,1.0);

      #define WIDTH  gl_Vertex.x
      #define LENGTH gl_Vertex.y
      #define TEXCOORD gl_Vertex.zw
      // gl_MultiTexCoord0.xy := jitter width/length scale (i.e jitter quad length = gl_vertex.x * gl_MultiTexCoord0.x)
      // gl_MultiTexCoord0.z  := (quad_width) / (quad_length) (used to normalize the texcoord dimensions)
      #define DISTORTION_STRENGTH gl_MultiTexCoord0.w
      #define EMITDIR gl_MultiTexCoord1
      #define COLOR gl_MultiTexCoord2.rgb
      #define ANIMATION_SPEED gl_MultiTexCoord2.w

      void main()
      {
        texCoords.st = TEXCOORD;
        texCoords.pq = TEXCOORD;
        texCoords.q += timer * ANIMATION_SPEED;

        gl_Position = gl_ModelViewMatrix * centerPos ;
        vec3 dir3   = vec3(gl_ModelViewMatrix * EMITDIR) - gl_Position.xyz;
        vec3 v = normalize( dir3 );
        vec3 w = normalize( -vec3(gl_Position) );
        vec3 u = normalize( cross(w,v) );
        gl_Position.xyz += WIDTH*v + LENGTH*u;
        gl_Position      = gl_ProjectionMatrix * gl_Position;

        gl_FrontColor.rgb = COLOR;

        distortion = DISTORTION_STRENGTH;
      }
    ]],
    fragment = [[
      uniform sampler2D noiseMap;
      uniform sampler2D mask;

      varying float distortion;
      varying vec4 texCoords;

      void main(void)
      {
          vec2 displacement = texCoords.pq;

          vec2 txCoord = texCoords.st;
          txCoord.s += (texture2D(noiseMap, displacement * distortion * 20.0).y - 0.5) * 40.0 * distortion;
          txCoord.t +=  texture2D(noiseMap, displacement).x * (1.0-texCoords.t)        * 15.0 * distortion;
          float opac = texture2D(mask,txCoord.st).r;

          gl_FragColor.rgb  = opac * gl_Color.rgb; //color
          gl_FragColor.rgb += pow(opac, 5.0 );     //white flame
          gl_FragColor.a    = opac*1.5;
      }

    ]],
    uniformInt = {
      noiseMap = 1,
      mask = 2,
    },
    uniform = {
      timer = 0,
    }
  })

  if (jetShader == nil) then
    print(PRIO_MAJOR,"LUPS->airjet: (color-)shader error: "..gl.GetShaderLog())
    return false
  end

  jitShader = gl.CreateShader({
    vertex = [[
      uniform float timer;

      varying float distortion;
      varying vec4 texCoords;

      const vec4 centerPos = vec4(0.0,0.0,0.0,1.0);

      #define WIDTH  gl_Vertex.x
      #define LENGTH gl_Vertex.y
      #define TEXCOORD gl_Vertex.zw
      // gl_MultiTexCoord0.xy := jitter width/length scale (i.e jitter quad length = gl_vertex.x * gl_MultiTexCoord0.x)
      // gl_MultiTexCoord0.z  := (quad_width) / (quad_length) (used to normalize the texcoord dimensions)
      #define DISTORTION_STRENGTH gl_MultiTexCoord0.w
      #define EMITDIR gl_MultiTexCoord1
      #define COLOR gl_MultiTexCoord2.rgb
      #define ANIMATION_SPEED gl_MultiTexCoord2.w

      void main()
      {
        texCoords.st  = TEXCOORD;
        texCoords.pq  = TEXCOORD*0.8;
        texCoords.p  *= gl_MultiTexCoord0.z;
        texCoords.pq += 0.2*timer*ANIMATION_SPEED;

        gl_Position = gl_ModelViewMatrix * centerPos;
        vec3 dir3   = vec3(gl_ModelViewMatrix * EMITDIR) - gl_Position.xyz;
        vec3 v = normalize( dir3 );
        vec3 w = normalize( -vec3(gl_Position) );
        vec3 u = normalize( cross(w,v) );
        float length = LENGTH * gl_MultiTexCoord0.x;
        float width  = WIDTH * gl_MultiTexCoord0.y;
        gl_Position.xyz += width*v + length*u;
        gl_Position      = gl_ProjectionMatrix * gl_Position;

        distortion = DISTORTION_STRENGTH;
      }
    ]],
    fragment = [[
      uniform sampler2D noiseMap;
      uniform sampler2D mask;

      varying float distortion;
      varying vec4 texCoords;

      void main(void)
      {
          float opac    = texture2D(mask,texCoords.st).r;
          vec2 noiseVec = (texture2D(noiseMap, texCoords.pq).st - 0.5) * distortion * opac;
          gl_FragColor  = vec4(noiseVec.xy,0.0,gl_FragCoord.z);
      }

    ]],
    uniformInt = {
      noiseMap = 1,
      mask = 2,
    },
    uniform = {
      timer = 0,
    }
  })


  if (jitShader == nil) then
    print(PRIO_MAJOR,"LUPS->airjet: (jitter-)shader error: "..gl.GetShaderLog())
    return false
  end

  timerUniform  = gl.GetUniformLocation(jetShader, 'timer')
  timer2Uniform = gl.GetUniformLocation(jitShader, 'timer')
end

function AirJet:Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(jetShader)
    gl.DeleteShader(jitShader)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glMultiTexCoord = gl.MultiTexCoord
local glVertex        = gl.Vertex
local glCreateList    = gl.CreateList
local glDeleteList    = gl.DeleteList
local glBeginEnd      = gl.BeginEnd
local GL_QUADS        = GL.QUADS

local function BeginEndDrawList(self)
  local color = self.color
  local ev    = self.emitVector 
  glMultiTexCoord(0,self.jitterWidthScale,self.jitterLengthScale,self.width/self.length,self.distortion)
  glMultiTexCoord(1,ev[1],ev[2],ev[3],1)
  glMultiTexCoord(2,color[1],color[2],color[3],self.animSpeed)

  --// xy = width/length ; zw = texcoord
  local w = self.width
  local l = self.length
  glVertex(-l,-w, 1,0)
  glVertex(0, -w, 1,1)
  glVertex(0,  w, 0,1)
  glVertex(-l, w, 0,0)
end


function AirJet:CreateParticle()
  self.dList = glCreateList(glBeginEnd,GL_QUADS,
                            BeginEndDrawList,self)

  --// used for visibility check
  self.radius = self.length*self.jitterLengthScale

  self.dieGameFrame  = thisGameFrame + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local MergeTable   = MergeTable
local setmetatable = setmetatable

function AirJet.Create(Options)
  local newObject = MergeTable(Options, AirJet.Default)
  setmetatable(newObject,AirJet)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function AirJet:Destroy()
  if self.lightID and WG['lighteffects'] and WG['lighteffects'].removeLight then
    WG['lighteffects'].removeLight(self.lightID)
  end
  --gl.DeleteTexture(self.texture1)
  --gl.DeleteTexture(self.texture2)
  glDeleteList(self.dList)
end

function AirJet:Visible()
  local radius = self.length
  local posX,posY,posZ = self.pos[1],self.pos[2],self.pos[3]
  local losState
  if (self.unit and not self.worldspace) then
    losState = GetUnitLosState(self.unit)
    local ux,uy,uz = spGetUnitViewPosition(self.unit)
	if ux then
      posX,posY,posZ = posX+ux,posY+uy,posZ+uz
      radius = radius + (spGetUnitRadius(self.unit) or 30)
	end
  end
  if (losState==nil) then
    if (self.radar) then
      losState = IsPosInRadar(posX,posY,posZ)
    end
    if ((not losState) and self.airLos) then
      losState = IsPosInAirLos(posX,posY,posZ)
    end
    if ((not losState) and self.los) then
      losState = IsPosInLos(posX,posY,posZ)
    end
  end
  --self.visible = true
  return (losState)and(spIsSphereInView(posX,posY,posZ,radius))
end
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return AirJet