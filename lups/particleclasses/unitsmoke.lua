-- $Id: UnitSmoke.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local UnitSmoke = {}
UnitSmoke.__index = UnitSmoke

local UnitSmokeShader
local widthLoc, timeLoc, headingLoc
local trailDirsUniform = {}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitSmoke.GetInfo()
  return {
    name      = "UnitSmoke",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 1, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

UnitSmoke.Default = {
  layer = 1,

  life     = math.huge,
  pos      = {0,0,0},
  size     = 20,
  width    = 5,
  quads    = 10, --//max 16

  repeatEffect = false,
  dieGameFrame = math.huge
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glUniform   = gl.Uniform
local glUseShader = gl.UseShader

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitSmoke:BeginDraw()
  glUseShader(UnitSmokeShader)
  glUniform(timeLoc, thisGameFrame * 0.01 )
  gl.Texture(1,"bitmaps/GPL/Lups/mynoise.png")
  gl.Texture(0,":c:bitmaps/GPL/Lups/smoketrail.png")
  --gl.Texture(0,":c:bitmaps/GPL/Lups/flametrail.png")
  --gl.Texture(0,":c:bitmaps/GPL/Lups/firetrail.png")
  --gl.Texture(false)
  --gl.Blending(GL.SRC_ALPHA,GL.ONE)

  local modelview = {gl.GetMatrixData("camera")}
  gl.MatrixMode(GL.TEXTURE)
  gl.PushMatrix()
  gl.LoadMatrix(modelview) --//FIXME: gl.MultMatrix("camera")
  gl.MatrixMode(GL.MODELVIEW)
  gl.PushMatrix()
  gl.LoadIdentity()

  --gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
end

function UnitSmoke:EndDraw()
  glUseShader(0)
  --gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.Texture(0,false)
  gl.Texture(1,false)

  gl.MatrixMode(GL.TEXTURE)
  gl.PopMatrix()
  gl.MatrixMode(GL.MODELVIEW)
  gl.PopMatrix()

  gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
end


function UnitSmoke:Draw()
  local pos = self.pos
  glUniform(widthLoc, self.width )
  glUniform(headingLoc, Spring.GetUnitHeading(self.unit)/32000 );

  local quads = self.quads-1 --// "-1" cause glsl is 0-indexed and lua 1-indexed

  for i=1,quads+1 do
    local dir = self.trailDirs[i]
    glUniform( trailDirsUniform[i] , dir[1], dir[2] + self.size*(i-1)/quads , dir[3] )
  end

  gl.PushMatrix()
    gl.Translate(pos[1],pos[2],pos[3])
    gl.BeginEnd(GL.QUADS,function()
      for i=0,quads-1 do
        --local tex_t      = 1 - self.trailTexCoords[i]   / self.totalLength
        --local tex_t_next = 1 - self.trailTexCoords[i+1] / self.totalLength

        local tex_t      = 1 - i/quads
        local tex_t_next = 1 - (i+1)/quads

        gl.TexCoord(-1,tex_t_next,0,i+1)
        gl.Vertex(0,0,0)
        gl.TexCoord(1,tex_t_next,1,i+1)
        gl.Vertex(0,0,0)
        gl.TexCoord(1,tex_t,1,i)
        gl.Vertex(0,0,0)
        gl.TexCoord(-1,tex_t,0,i)
        gl.Vertex(0,0,0)
      end
    end)
  gl.PopMatrix()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitSmoke.Initialize()
  UnitSmokeShader = gl.CreateShader({
    vertex = [[
      uniform float width;
      uniform float time;
      uniform float heading;

      uniform vec3 traildirs[16];

      void main()
      {
         vec3 updir,right;

         gl_Position = (gl_ModelViewMatrix * gl_Vertex);

         updir = traildirs[int(gl_MultiTexCoord0.w)];
         gl_Position.xyz += updir;

         //gl_TexCoord[0].pq = updir.xy*vec2(0.1) + vec2(heading, -time*3.0); 

         gl_Position = gl_TextureMatrix[0] * gl_Position;

         updir = ( gl_TextureMatrix[0] * vec4(updir,0.0) ).xyz - gl_Position.xyz;
         right = normalize( cross(updir,gl_Position.xyz) );

         //gl_Position.x += gl_MultiTexCoord0.x * size * 0.35;
         gl_Position.xyz += right * gl_MultiTexCoord0.x * width;

         gl_Position    = gl_ProjectionMatrix * gl_Position;

         //gl_FrontColor = vec4(1.0,1.0,1.0,1.0);
         gl_TexCoord[0].st = gl_MultiTexCoord0.pt;
         //gl_TexCoord[0].st = gl_Position.xy;
         gl_TexCoord[0].pq = gl_TexCoord[0].st + vec2(heading, time*3.0); 
      }
    ]],
    fragment = [[
      uniform sampler2D SmokeTex;
      uniform sampler2D noiseMap;

      void main()
      {
         vec4 noise = texture2D(noiseMap, gl_TexCoord[0].pq*0.8); //vec4(0.0);

         gl_FragColor = texture2D(SmokeTex, gl_TexCoord[0].st + vec2( (noise.r-0.5) ,0.0) );
         //gl_FragColor.a *= (gl_FragColor.r+gl_FragColor.g+gl_FragColor.b)*0.333;
         gl_FragColor.a *= 0.9;
      }
    ]],
    uniformInt={
      SmokeTex = 0,
      noiseMap = 1,
    },
  })

  if (UnitSmokeShader == nil) then
    print(PRIO_MAJOR,"LUPS->UnitSmoke: critical shader error: "..gl.GetShaderLog())
    return false
  end

  widthLoc = gl.GetUniformLocation(UnitSmokeShader, 'width')
  timeLoc  = gl.GetUniformLocation(UnitSmokeShader, 'time')
  headingLoc = gl.GetUniformLocation(UnitSmokeShader, 'heading')

  for i=1,16 do
    trailDirsUniform[i] = gl.GetUniformLocation(UnitSmokeShader,"traildirs["..(i-1).."]")
  end
end

function UnitSmoke.Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(UnitSmokeShader)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitSmoke:Update()
  local vel = {Spring.GetUnitVelocity(self.unit)}
  vel = Vmul( -1 , vel )

  local x,y,z = Spring.GetWind()
  local wind  = Vmul( 0.125 , {z,y,-x} )

  self.trailDirs[2] = Vadd( Vadd(vel,wind), {0,2,0})

  for i=self.quads,3,-1 do
    self.trailDirs[i] = Vadd( self.trailDirs[i-1], Vadd(vel,wind) )
  end

--[[
  local tlength = 0
  for i=1,16 do
    tlength = tlength + Vlength( self.trailDirs[i] )
    self.trailTexCoords[i] = tlength
  end
  self.totalLength = tlength
--]]
end

-- used if repeatEffect=true;
function UnitSmoke:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function UnitSmoke:CreateParticle()
--[[
  self.trailTexCoords = { [0] = 0 }
  self.totalLength = 0
--]]

  if (self.quads>16) then self.quads=16
  elseif (self.quads<5) then self.quads=5 end

  self.trailDirs = {}
  for i=1,self.quads do
    self.trailDirs[i] = {0,0.05,0}
  end

  self.startGameFrame = thisGameFrame
  self.dieGameFrame   = self.startGameFrame + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local MergeTable   = MergeTable
local setmetatable = setmetatable

function UnitSmoke.Create(Options)
  local newObject = MergeTable(Options, UnitSmoke.Default)
  setmetatable(newObject,UnitSmoke)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function UnitSmoke:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return UnitSmoke