-- $Id: RingParticles.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local RingParticles = {}
RingParticles.__index = RingParticles

local billShader = 0
local uPartSize  = 0

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------


function RingParticles.GetInfo()
  return {
    name      = "RingParticles",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 0, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = true,
    atiseries = 1,
  }
end

RingParticles.Default = {
  lists = {},

  emitVector = {0,0,0}, -- todo
  pos        = {0,0,0}, -- start pos
  layer      = 0,

  grav       = 0,
  airdrag    = 1,
  speed      = 0,
  speedSpread= 0,
  life       = 0,
  lifeSpread = 0,
  rotSpeed   = 0,
  rotSpread  = 0,
  rotairdrag = 1,
  emitRot    = 90,
  emitRotSpread = 0,
  size       = 0,
  sizeSpread = 0,
  sizeGrowth = 0,
  colormap   = { {0, 0, 0, 0} },
  srcBlend   = GL.ONE,
  dstBlend   = GL.ONE_MINUS_SRC_ALPHA,
  texture    = '',
  count      = 0,
  repeatEffect = false,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function RingParticles:InitializePartList(partList)
  partList.speed    = partList.cspeed or self.speed
  partList.vspeed   = self.grav
  partList.rotate   = self.rotSpeed
  partList.rotspeed = self.rotSpeed
  partList.size     = partList.csize or self.size
  partList.radius   = 0
  partList.altitude = 0
  partList.life     = 0
  local r,g,b,a     = GetColor(self.colormap,partList.life)
  partList.color    = {r,g,b,a}
  partList.start_pos= self.pos

  -- spread values
  if (self.speedSpread>0) then partList.speed   = partList.speed    + math.random(self.speedSpread*100)/100 end
  if (self.sizeSpread>0)  then partList.size    = partList.size     + math.random(self.sizeSpread*100)/100 end
  if (self.rotSpread>0)   then partList.rotspeed= partList.rotspeed + math.random(self.rotSpread*100)/100 end
  local rand = 0
  if (self.lifeSpread>0) then rand = math.random(self.lifeSpread) end
  partList.life_incr = 1/(self.life+rand)
end

function RingParticles:UpdatePartList(partList,n)
  partList.speed    = partList.speed  * (self.airdrag^n)
  --partList.vspeed   = (partList.vspeed + self.grav) * self.airdrag
  --partList.rotate   = (partList.rotate + partList.rotspeed) * self.rotairdrag

  local gravBoost,rotBoost = 0,0
  for i=1,n do 
    gravBoost = gravBoost + self.grav*(self.airdrag^i);
    rotBoost  = rotBoost + partList.rotspeed*(self.rotairdrag^i);
  end
  partList.vspeed   = (partList.vspeed * (self.airdrag^n)) + gravBoost
  partList.rotate   = (partList.rotate * (self.rotairdrag^n)) + rotBoost

  partList.radius   = partList.radius   + n*partList.speed
  partList.altitude = partList.altitude + n*partList.vspeed
  partList.size     = partList.size     + n*self.sizeGrowth
  partList.life     = partList.life     + n*partList.life_incr
  local r,g,b,a     = GetColor(self.colormap,partList.life)
  partList.color    = {r,g,b,a}
end

function DrawParticle(size,beta)
  local one = 1+(size or 0)
  gl.BeginEnd(GL.QUADS, function()
    gl.MultiTexCoord(0,0,0)
    gl.MultiTexCoord(1,0,beta, -one,-one)
    gl.Vertex(0,0)

    gl.MultiTexCoord(0,1,0)
    gl.MultiTexCoord(1,0,beta, one,-one)
    gl.Vertex(0,0)

    gl.MultiTexCoord(0,1,1)
    gl.MultiTexCoord(1,0,beta, one,one)
    gl.Vertex(0,0)

    gl.MultiTexCoord(0,0,1)
    gl.MultiTexCoord(1,0,beta, -one,one)
    gl.Vertex(0,0)
  end)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function RingParticles:BeginDraw()
  gl.UseShader(billShader)
end

function RingParticles:EndDraw()
  gl.Texture(false)
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.UseShader(0)
end

function RingParticles:BeginShadow()
  gl.DepthMask(true)
  gl.UseShader(shadowShader)
  local xmid, ymid, p17, p18 = gl.GetShadowMapParams()
  gl.Uniform(gl.GetUniformLocation(shadowShader, 'xmid'), xmid)
  gl.Uniform(gl.GetUniformLocation(shadowShader, 'ymid'), ymid)
  gl.Uniform(gl.GetUniformLocation(shadowShader, 'p17'),  p17)
  gl.Uniform(gl.GetUniformLocation(shadowShader, 'p18'),  p18)
end

function RingParticles:EndShadow()
  gl.Texture(false)
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.UseShader(0)
  gl.DepthMask(false)
end

function RingParticles:Draw()
  --if self.genmipmap then
  --  gl.GenerateMipmap(self.texture)
  --  self.genmipmap = false
  --end

  gl.Texture(self.texture)  
  gl.Blending(self.srcBlend,self.dstBlend)

  gl.PushMatrix()
  gl.Translate(self.pos[1],self.pos[2],self.pos[3])
  gl.Rotate(self.emitRot,self.emitVector[1],self.emitVector[2],self.emitVector[3])

  for _,partList in ipairs(self.lists) do
    if (partList.life < 1)and
      Spring.IsSphereInView(partList.start_pos[1],partList.start_pos[2],partList.start_pos[3],partList.radius+partList.size)
    then
      gl.Uniform(uPartSize, partList.size)

      gl.Color(partList.color)

      gl.PushMatrix()
        gl.Translate(0,partList.altitude,0)
        gl.Rotate(partList.rotate,0,1,0)
        gl.Scale(partList.radius,1,partList.radius)
        gl.CallList(partList.dlist)
      gl.PopMatrix()
    end
  end

  gl.PopMatrix()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function RingParticles:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      uniform float size;

      varying vec2 texCoord;

	void main()
	{
            gl_Position     = gl_ModelViewMatrix * gl_Vertex;
            gl_Position.xy += gl_MultiTexCoord1.zw * size;
            gl_Position     = gl_ProjectionMatrix  * gl_Position;

            texCoord  = gl_MultiTexCoord0.st;
            gl_FrontColor   = gl_Color;
	}
    ]],
    fragment = [[
      uniform sampler2D tex0;

      varying vec2 texCoord;

      void main(void)
      {
        gl_FragColor    = texture2D(tex0, texCoord)*gl_Color;
        //gl_FragDepth    = gl_FragCoord.z - (gl_FragColor.a/500);
      }
    ]],
    uniformInt = {
      tex0 = 0,
    },
    uniform = {
      size  = 10,
    },
  })

  if (billShader==nil) then
    print(PRIO_MAJOR,"LUPS: RingParticles: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end

  -- get uniform pointers
  uPartSize  = gl.GetUniformLocation(billShader, 'size')
end

function RingParticles:Finalize()
  gl.DeleteShader(billShader)
end
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function RingParticles:Update(n)
  for _,partList in ipairs(self.lists) do
    if (partList.life<1) then
      self:UpdatePartList(partList,n)
    end
  end
end

-- used if repeatEffect=true;
function RingParticles:ReInitialize()
  for _,partList in ipairs(self.lists) do
    self:InitializePartList(partList)
  end
  self.dieGameFrame = self.dieGameFrame + self.life + self.lifeSpread
end

function RingParticles:CreateParticle()
  local listsCount = self.lifeSpread/5
  for i=0,listsCount do
    local newPartList = {}

    self:InitializePartList(newPartList)

    --needed for repeat mode
    newPartList.csize  = newPartList.size
    newPartList.cspeed = newPartList.speed

    newPartList.dlist = gl.CreateList(function(count)
      for y = 0, count do
        --gl.Rotate(360/count,0,1,0)
        local beta = math.random(360)
        gl.Rotate(beta,0,1,0)
        gl.Translate(0,0,1)
        DrawParticle(math.random(self.sizeSpread*100)/100,beta)
        gl.Translate(0,0,-1)
      end
    end, self.count/listsCount)

    table.insert(self.lists,newPartList)
  end

  self.firstGameFrame = Spring.GetGameFrame()
  self.dieGameFrame   = self.firstGameFrame + self.life + self.lifeSpread
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function RingParticles.Create(Options)
  local newObject = MergeTable(Options, RingParticles.Default)
  setmetatable(newObject,RingParticles)  -- make handle lookup
  return newObject
end

function RingParticles:Destroy()
  for _,partList in ipairs(self.lists) do
    gl.DeleteList(partList.dlist)
  end
  gl.DeleteTexture(self.texture)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return RingParticles