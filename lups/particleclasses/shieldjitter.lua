-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local ShieldJitter = {}
ShieldJitter.__index = ShieldJitter

local warpShader
local timerUniform, strengthUniform
local sphereList
local checkStunned = true

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldJitter.GetInfo()
  return {
    name      = "ShieldJitter",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 16, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    distortion= true,
    rtt       = false,
    ctt       = true,
    intel     = 0,
  }
end

ShieldJitter.Default = {
  layer = 16,

  pos        = {0,0,0}, --// start pos
  life       = math.huge,

  size       = 600,
  --precision  = 26, --// bias the used polies for a sphere

  strength   = 0.005,
  strengthMin= nil,
  texture    = 'bitmaps/GPL/Lups/grass5.png',
  --texture    = 'bitmaps/GPL/Lups/perlin_noise.jpg',

  repeatEffect = false,
  dieGameFrame = math.huge
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldJitter:BeginDrawDistortion()
  gl.UseShader(warpShader)
  local drawTime = (Spring.GetGameFrame() + Spring.GetFrameTimeOffset()) * 0.003333333
  gl.Uniform(timerUniform,  drawTime)

  gl.Culling(GL.FRONT) --FIXME: check if camera is in the sphere
end

function ShieldJitter:EndDrawDistortion()
  gl.UseShader(0)
  gl.Texture(0,false)

  gl.Culling(false)
end

function ShieldJitter:DrawDistortion()
	if checkStunned then
		self.stunned = Spring.GetUnitIsStunned(self.unit)
	end
	if self.stunned then
		return
	end

	local pos  = self.pos
	local size = self.size

	gl.Uniform(strengthUniform, self.strength, self.strengthMin)

	gl.Texture(0, self.texture)
	gl.PushMatrix()
	gl.Translate(pos[1], pos[2], pos[3])
	gl.Scale(size, size, size)
	gl.CallList(sphereList)
	gl.PopMatrix()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldJitter.Initialize()
	ShieldJitter.Default.strengthMin = ShieldJitter.Default.strengthMin or ShieldJitter.Default.strength

	warpShader = gl.CreateShader({
		vertex = [[
			#version 150 compatibility
			uniform float timer;
			uniform vec2 strength;

			varying float scale;
			varying vec2 texCoord;

			void main()
			{
				vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
				texCoord       = gl_MultiTexCoord0.st + timer;

				vec3 normal  = normalize(gl_NormalMatrix * gl_Normal);
				vec3 nvertex = normalize(viewPos.xyz);

				float normCamDist = smoothstep(50.0, 5000.0, length(viewPos.xyz));
				float strengthCamDist = mix(strength.y, strength.x, normCamDist);

				scale = strengthCamDist * abs(dot( normal, nvertex ));

				gl_Position = gl_ProjectionMatrix * viewPos;
			}
		]],
		fragment = [[
			#version 150 compatibility
			uniform sampler2D noiseMap;

			varying float scale;
			varying vec2 texCoord;

			void main(void)
			{
			  vec2 noiseVec;
			  noiseVec = texture2D(noiseMap, texCoord).yz - 0.5;
			  noiseVec *= scale;

			  gl_FragColor = vec4(noiseVec,0.0,gl_FragCoord.z);
			}
		]],
		uniformInt = {
			noiseMap = 0,
		},
		uniformFloat = {
			timer = 0,
			strength = {ShieldJitter.Default.strength, ShieldJitter.Default.strengthMin},
		}
	})

	if (warpShader == nil) then
		print(PRIO_MAJOR,"LUPS->ShieldJitter: shader error: "..gl.GetShaderLog())
		return false
	end

	timerUniform    = gl.GetUniformLocation(warpShader, 'timer')
	strengthUniform = gl.GetUniformLocation(warpShader, 'strength')

	sphereList = gl.CreateList(DrawSphere,0,0,0,1,22)
end

function ShieldJitter.Finalize()
	gl.DeleteShader(warpShader)
	gl.DeleteList(sphereList)
	gl.DeleteTexture(tex)
end

function ShieldJitter.ViewResize(viewSizeX, viewSizeY)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local time = 0
function ShieldJitter:Update(dt)
  time = time + dt
  if time > 45 then
    checkStunned = true
    time = 0
  else
    checkStunned = false
  end
end

-- used if repeatEffect=true;
function ShieldJitter:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function ShieldJitter:CreateParticle()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldJitter.Create(Options)
  local newObject = table.merge(ShieldJitter.Default, Options)
  setmetatable(newObject,ShieldJitter)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function ShieldJitter:Destroy()
  gl.DeleteTexture(self.texture)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldJitter