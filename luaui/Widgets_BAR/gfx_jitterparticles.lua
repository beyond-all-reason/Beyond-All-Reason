function widget:GetInfo()
	return {
		name = "Jitterparticles",
		desc = "Heat/distortion effect", -- extracted from lups
		author = "jK, Floris",
		date = "August 2020",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local texture = 'bitmaps/GPL/Lups/mynoise.png'
local defaults = {
	emitVector = { 0, 1, 0 },
	pos = { 0, 0, 0 }, --// start pos
	partpos = "0,0,0", --// particle relative start pos (can contain lua code!)
	layer = 0,

	--// visibility check
	los = true,
	airLos = true,
	radar = false,

	life = 0,
	lifeSpread = 0,
	delaySpread = 0,

	emitVector = { 0, 1, 0 },
	emitRot = 0,
	emitRotSpread = 0,

	force = { 0, 0, 0 }, --// global effect force
	forceExp = 1,

	speed = 0,
	speedSpread = 0,
	speedExp = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow

	size = 0,
	sizeSpread = 0,
	sizeGrowth = 0,
	sizeExp = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow;  <0 : invert x-axis (start large become smaller)

	strength = 1, --// distortion strength
	scale = 1, --// scales the distortion texture
	animSpeed = 1, --// speed of the distortion
	heat = 0, --// brighten distorted regions by "length(distortionVec)*heat"

	repeatEffect = false, --can be a number,too
}

--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------

local particles = {}
local time
local billShader
local nullVector = { 0, 0, 0 }
local currentGameFrame = Spring.GetGameFrame()

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------

local abs = math.abs
local sqrt = math.sqrt
local rand = math.random
local twopi = 2 * math.pi
local cos = math.cos
local sin = math.sin
local min = math.min
local floor = math.floor
local degreeToPI = math.pi / 180
local type = type

local spGetPositionLosState = Spring.GetPositionLosState
local spIsSphereInView = Spring.IsSphereInView

local IsPosInLos = Spring.IsPosInLos
local IsPosInAirLos = Spring.IsPosInAirLos
local IsPosInRadar = Spring.IsPosInRadar

local glTexture = gl.Texture
local glBlending = gl.Blending
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glRotate = gl.Rotate
local glColor = gl.Color
local glUseShader = gl.UseShader
local glDepthTest = gl.DepthTest
local glAlphaTest = gl.AlphaTest

local GL_GREATER = GL.GREATER
local GL_QUADS = GL.QUADS
local GL_ONE = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local glBeginEnd = gl.BeginEnd
local glMultiTexCoord = gl.MultiTexCoord
local glVertex = gl.Vertex

--------------------------------------------------------------------------------
-- Vector functions
--------------------------------------------------------------------------------

local Vector = {}
Vector.mt = {}

function Vector.new(t)
	local v = {}
	setmetatable(v, Vector.mt)
	for i, w in pairs(t) do
		v[i] = w
	end
	return v
end

function Vector.mt.__add(a, b)
	if type(a) ~= "table" or
		type(b) ~= "table"
	then
		error("attempt to `add' a vector with a non-table value", 2)
	end

	local v = {}
	local n = math.min(#a or 0, #b or 0)
	for i = 1, n do
		v[i] = a[i] + b[i]
	end
	return v
end

function Vector.mt.__sub(a, b)
	if type(a) ~= "table" or
		type(b) ~= "table"
	then
		error("attempt to `sub' a vector with a non-table value", 2)
	end

	local v = {}
	local n = math.min(#a or 0, #b or 0)
	for i = 1, n do
		v[i] = a[i] - b[i]
	end
	return v
end

function Vector.mt.__mul(a, b)
	if ((type(a) ~= "table") and (type(b) ~= "number")) or
		((type(b) ~= "table") and (type(a) ~= "number"))
	then
		error("attempt to `mult' a vector with something else than a number", 2)
	end

	local u, w
	if (type(a) == "table") then
		u, w = a, b
	else
		u, w = b, a
	end

	local v = {}
	for i = 1, #u do
		v[i] = w * u[i]
	end
	return v
end

function Vadd(a, b)
	local v = {}
	local n = min(#a or 0, #b or 0)
	for i = 1, n do
		v[i] = a[i] + b[i]
	end
	return v
end

function Vsub(a, b)
	local v = {}
	local n = min(#a or 0, #b or 0)
	for i = 1, n do
		v[i] = a[i] - b[i]
	end
	return v
end

function Vmul(a, b)
	local u, w
	if (type(a) == "table") then
		u, w = a, b
	else
		u, w = b, a
	end

	local v = {}
	for i = 1, #u do
		v[i] = w * u[i]
	end
	return v
end

function Vcross(a, b)
	return { a[2] * b[3] - a[3] * b[2],
			 a[3] * b[1] - a[1] * b[3],
			 a[1] * b[2] - a[2] * b[1] }
end

function Vlength(a)
	return sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
end

function CopyVector(write, read, n)
	for i = 1, n do
		write[i] = read[i]
	end
end

function CreateEmitMatrix3x3(x, y, z)
	local xz = x * z
	local xy = x * y
	local yz = y * z

	return {
		x * x, xy - z, xz + y,
		xy + z, y * y, yz - x,
		xz - y, yz + x, z * z
	}
end

function MultMatrix3x3(m, x, y, z)
	return m[1] * x + m[2] * y + m[3] * z,
	m[4] * x + m[5] * y + m[6] * z,
	m[7] * x + m[8] * y + m[9] * z
end

--------------------------------------------------------------------------------
-- Mathenv Functions
--------------------------------------------------------------------------------

local MathG = { math = math, rand = math.random, random = math.random, sin = math.sin, cos = math.cos, pi = math.pi,
				deg = math.deg, loadstring = loadstring, assert = assert, echo = Spring.Echo };

--local cachedParsedFunctions = {}

local function Split(str, delim, maxNb)
	--// Eliminate bad cases...
	if str:find(delim) == nil then
		return { str }
	end
	if maxNb == nil or maxNb < 1 then
		maxNb = 0    -- No limit
	end
	local result = {}
	local pat = "(.-)" .. delim .. "()"
	local nb = 0
	local lastPos
	for part, pos in str:gmatch(pat) do
		nb = nb + 1
		result[nb] = part
		lastPos = pos
		if nb == maxNb then
			break
		end
	end
	--// Handle the last field
	if nb ~= maxNb then
		result[nb + 1] = str:sub(lastPos)
	end
	return result
end

local loadstring = loadstring
local char = string.char
local type = type

function ParseParamString(strfunc)
	--if (cachedParsedFunctions[strfunc]) then
	--  return cachedParsedFunctions[strfunc]
	--end

	local luaCode = "return function() "
	local vec_defs, math_defs = {}, {}

	local params = Split(strfunc or "", "|") --//split math vector components and defintion of additional params (radius etc.)

	if (type(params) == "table") then
		vec_defs = Split(params[1], ",")
		if (params[2]) then
			math_defs = Split(params[2], ",")
		end
	else
		vec_defs = params
	end

	--// set user variables (i.e. radius of the effect)
	for i = 1, #math_defs do
		luaCode = luaCode .. math_defs[i] .. ";"
	end

	--// set return values
	for i = 1, #vec_defs do
		luaCode = luaCode .. "local __" .. char(64 + i) .. "=" .. vec_defs[i] .. ";"
	end

	--// and now insert the return code of those to returned values
	luaCode = luaCode .. "return "
	for i = 1, #vec_defs do
		luaCode = luaCode .. " __" .. char(64 + i) .. ","
	end
	luaCode = luaCode .. "nil end"

	local status, luaFunc = pcall(loadstring(luaCode))

	if (not status) then
		print(PRIO_MAJOR, 'LUPS: Failed to parse custom param code: ' .. luaFunc);
		return function()
			return 1, 2, 3, 4
		end
	end ;

	--cachedParsedFunctions[strfunc] = luaFunc

	return luaFunc
end

local setmetatable = setmetatable
local setfenv = setfenv
local pcall = pcall
local meta = { __index = {} }

function ProcessParamCode(func, locals)
	--// set up safe enviroment
	meta.__index = locals
	setmetatable(MathG, meta);

	setfenv(func, MathG);

	--// run generated code
	local success, r1, r2, r3, r4 = pcall(func);
	setmetatable(MathG, nil);

	if (success) then
		return r1, r2, r3, r4;
	else
		print(PRIO_MAJOR, 'LUPS: Failed to run custom param code: ' .. r1);
		return nil;
	end
end

--------------------------------------------------------------------------------
-- Functions
--------------------------------------------------------------------------------

function tableMerge(t1, t2)
	for k, v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end

local function DrawParticleForDList(life, delay, x, y, z, dx, dy, dz, sizeStart, sizeEnd)
	local animDirX = floor((rand() - 0.5) * 2)
	local animDirY = floor((rand() - 0.5) * 2)

	glMultiTexCoord(0, x, y, z, life / 200)
	glMultiTexCoord(1, dx, dy, dz, delay / 200)
	glMultiTexCoord(2, sizeStart, sizeEnd, animDirX, animDirY)

	glVertex(0, 0)
	glVertex(1, 0)
	glVertex(1, 1)
	glVertex(0, 1)
end

function InitializeParticle(particleID)
	-- calc base of the emitvector system
	local up = particles[particleID].emitVector
	local right = Vcross(up, { up[2], up[3], -up[1] })
	local forward = Vcross(up, right)

	local partposCode
	if (particles[particleID].partpos ~= "0,0,0") then
		partposCode = ParseParamString(particles[particleID].partpos)
	end

	particles[particleID].force = Vmul(particles[particleID].force, particles[particleID].life + particles[particleID].lifeSpread)

	local ev = particles[particleID].emitVector
	local emitMatrix = CreateEmitMatrix3x3(ev[1], ev[2], ev[3])

	--// global data
	glMultiTexCoord(3, particles[particleID].speedExp, particles[particleID].sizeExp)
	glMultiTexCoord(4, particles[particleID].force[1], particles[particleID].force[2], particles[particleID].force[3], particles[particleID].forceExp)
	glMultiTexCoord(6, particles[particleID].strength * 0.01, particles[particleID].scale, particles[particleID].heat / particles[particleID].strength)

	particles[particleID].maxSpawnRadius = 0

	local life, delay, x, y, z, dx, dy, dz, sizeStart, sizeEnd = CreateParticleAttributes(particleID, up, right, forward, partposCode)
	dx, dy, dz = MultMatrix3x3(emitMatrix, dx, dy, dz)
	DrawParticleForDList(life, delay,
		x, y, z, -- relative start pos
		dx, dy, dz, -- speed vector
		sizeStart, sizeEnd)
	local spawnDist = x * x + y * y + z * z
	if (spawnDist > particles[particleID].maxSpawnRadius) then
		particles[particleID].maxSpawnRadius = spawnDist
	end

	particles[particleID].maxSpawnRadius = sqrt(particles[particleID].maxSpawnRadius)

	glMultiTexCoord(2, 0, 0, 0, 1)
	glMultiTexCoord(3, 0, 0, 0, 1)
	glMultiTexCoord(4, 0, 0, 0, 1)
	glMultiTexCoord(5, 0, 0, 0, 1)
	glMultiTexCoord(6, 0, 0, 0, 1)
end

function CreateDList(particleID)
	glPushMatrix()
	glTranslate(particles[particleID].pos[1], particles[particleID].pos[2], particles[particleID].pos[3])
	glBeginEnd(GL_QUADS, InitializeParticle, particleID)
	glPopMatrix()
end

local function CreateParticle(options)
	local particleID = #particles + 1
	options = tableMerge(defaults, options)
	options.id = particleID
	particles[particleID] = options
	particles[particleID].dlist = glCreateList(CreateDList, particleID)
	particles[particleID].frame = 0
	particles[particleID].firstGameFrame = currentGameFrame
	particles[particleID].dieGameFrame = particles[particleID].firstGameFrame + particles[particleID].life + particles[particleID].lifeSpread + particles[particleID].delaySpread
	particles[particleID].radius = particles[particleID].size + particles[particleID].sizeSpread + particles[particleID].maxSpawnRadius + 100
	particles[particleID].maxSpeed = particles[particleID].speed + abs(particles[particleID].speedSpread)
	particles[particleID].forceStrength = Vlength(particles[particleID].force)
	particles[particleID].sphereGrowth = particles[particleID].forceStrength + particles[particleID].sizeGrowth + particles[particleID].maxSpeed
	return particleID
end

function CreateParticleAttributes(particleID, up, right, forward, partpos)
	local self = particles[particleID]
	local life, delay, pos, speed, sizeStart, sizeEnd, rotStart, rotEnd

	local az = rand() * twopi
	local ay = (self.emitRot + rand() * self.emitRotSpread) * degreeToPI

	local a, b, c = cos(ay), cos(az) * sin(ay), sin(az) * sin(ay)

	speed = {
		up[1] * a - right[1] * b + forward[1] * c,
		up[2] * a - right[2] * b + forward[2] * c,
		up[3] * a - right[3] * b + forward[3] * c }

	life = self.life + rand() * self.lifeSpread
	speed = Vmul(speed, (self.speed + rand() * self.speedSpread) * life)
	delay = rand() * self.delaySpread

	sizeStart = self.size + rand() * self.sizeSpread
	sizeEnd = sizeStart + self.sizeGrowth * life

	if partpos then
		local part = { speed = speed, velocity = Vlength(speed), life = life, delay = delay, i = n }
		pos = { ProcessParamCode(partpos, part) }
	else
		pos = nullVector
	end

	return life, delay, pos[1], pos[2], pos[3], speed[1], speed[2], speed[3], sizeStart, sizeEnd
end

function RemoveParticle(particleID)
	if particles[particleID] then
		gl.DeleteList(particles[particleID].dlist)
		particles[particleID] = nil
	end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function widget:Initialize()
	billShader = gl.CreateShader({
		vertex = [[
	  #version 150 compatibility
      // global attributes
      #define frame         gl_MultiTexCoord5.x
      #define time          gl_MultiTexCoord5.y
      #define forceExp      gl_MultiTexCoord4.w
      #define force        (gl_MultiTexCoord4.xyz)
      #define distStrength  gl_MultiTexCoord6.x
      #define distScale     gl_MultiTexCoord6.y
      #define distHeat      gl_MultiTexCoord6.z
      #define animDir      (gl_MultiTexCoord2.zw)

      // particle attributes
      #define posV        (gl_MultiTexCoord0.xyz)
      #define dirV        (gl_MultiTexCoord1.xyz)
      #define maxLife      gl_MultiTexCoord0.w
      #define delay        gl_MultiTexCoord1.w

      #define sizeStart       gl_MultiTexCoord2.x
      #define sizeEnd         gl_MultiTexCoord2.y
      // equation is: 1-(1-life)^exp
      #define attributesExp  (gl_MultiTexCoord3.xy)

      const float halfpi = 0.159;


      varying float strength;
      varying float heat;
      varying vec4  texCoords;

      void main()
      {
         float lframe = frame - delay;
         float life   = lframe / maxLife; // 0.0 .. 1.0 range!

         if (life<=0.0 || life>1.0) {
           // move dead particles offscreen, this way we don't dump the fragment shader with it
           gl_Position = vec4(-2000.0,-2000.0,-2000.0,-2000.0);
         }else{
           // calc particle attributes
           vec2 attrib = vec2(1.0) - pow(vec2(1.0 - life), abs(attributesExp));
         //if (attributesExp.x<0.0) attrib.x = 1.0 - attrib.x; // speed (no need for backward movement)
           if (attributesExp.y<0.0) attrib.y = 1.0 - attrib.y; // size
           attrib.y   = sizeStart + attrib.y * sizeEnd;

           // calc vertex position
           vec3 forceV     = (1.0 - pow(1.0 - life, abs(forceExp))) * force;
           vec4 pos4       = vec4(posV + attrib.x * dirV + forceV, 1.0);
           gl_Position     = gl_ModelViewMatrix * pos4;

           // offset vertex from center of the polygon
           gl_Position.xy += (gl_Vertex.xy - 0.5) * attrib.y;

           // final position
           gl_Position     = gl_ProjectionMatrix * gl_Position;

           // calc some stuff used by the fragment shader
           texCoords.st  = (gl_Vertex.st + animDir * time) * distScale;
           strength      = (1.0 - life) * distStrength;
           heat          = distHeat;
           texCoords.pq  = (gl_Vertex.xy - 0.5) * 2.0;
         }
       }
    ]],
		fragment = [[
	  #version 150 compatibility
      uniform sampler2D noiseMap;

      varying float strength;
      varying float heat;
      varying vec4  texCoords;

      void main()
      {
         vec2 noiseVec;
         vec4 noise = texture2D(noiseMap, texCoords.st);
         noiseVec = (noise.xy - 0.50) * strength;

         noiseVec *= smoothstep(1.0, 0.0, dot(texCoords.pq,texCoords.pq) ); // smooth dot (FIXME: use a mask texture instead?)

         gl_FragColor = vec4(noiseVec,length(noiseVec)*heat,gl_FragCoord.z);
      }
    ]],
		uniformInt = {
			noiseMap = 0,
		},
	})

	WG['jitter'] = {}
	WG['jitter'].AddParticle = function(options)
		return CreateParticle(options)
	end
	WG['jitter'].RemoveParticle = function(particleID)
		RemoveParticle(particleID)
	end
end

function widget:Shutdown()
	for i, _ in pairs(particles) do
		RemoveParticle(i)
	end
	gl.DeleteShader(billShader)
	WG['jitter'] = nil
end

function widget:GameFrame(gf)
	currentGameFrame = gf
end

function widget:Update(dt)
	for id, options in pairs(particles) do
		particles[id].frame = particles[id].frame + 1
	end
end

function widget:DrawWorld()
	glDepthTest(true)

	--glAlphaTest(GL_GREATER, 0)

	glUseShader(billShader)
	glTexture(0, texture)
	time = currentGameFrame * 0.01
	for particleID, options in pairs(particles) do
		-- visible?
		if currentGameFrame >= options.dieGameFrame then
			RemoveParticle(particleID)
			--Spring.Echo('removed particle', particleID, gf, options.dieGameFrame)
		elseif spIsSphereInView(options.pos[1], options.pos[2], options.pos[3], options.radius) then
			glMultiTexCoord(5, options.frame / 200, time * options.animSpeed)
			glCallList(options.dlist)
		end
	end
	--glAlphaTest(false)

	glTexture(0, false)
	glUseShader(0)

	glDepthTest(false)
end
