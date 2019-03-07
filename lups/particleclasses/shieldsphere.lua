-- $Id: ShieldSphere.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local ShieldSphereParticle = {}
ShieldSphereParticle.__index = ShieldSphereParticle

local sphereList
local shieldShader
local checkStunned = true

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereParticle.GetInfo()
	return {
		name			= "ShieldSphere",
		backup		= "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
		desc			= "",

		layer		 = -23, --// extreme simply z-ordering :x

		--// gfx requirement
		fbo			 = false,
		shader		= true,
		rtt			 = false,
		ctt			 = false,
	}
end

ShieldSphereParticle.Default = {
	pos				= {0,0,0}, -- start pos
	layer			= -23,

	life			 = 0,

	size			 = 0,
	sizeGrowth = 0,

	margin		 = 1,

	colormap1	= { {0, 0, 0, 0} },
	colormap2	= { {0, 0, 0, 0} },

	repeatEffect = false,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glMultiTexCoord = gl.MultiTexCoord
local glCallList = gl.CallList

local gameFrame = 0

function ShieldSphereParticle:BeginDraw()
	gl.DepthMask(false)
	gl.UseShader(shieldShader)
	gl.Culling(GL.FRONT)
	gameFrame = Spring.GetGameFrame()
end

function ShieldSphereParticle:EndDraw()
	gl.DepthMask(false)
	gl.UseShader(0)

	gl.Culling(GL.BACK)
	gl.Culling(false)

	glMultiTexCoord(1, 1,1,1,1)
	glMultiTexCoord(2, 1,1,1,1)
	glMultiTexCoord(3, 1,1,1,1)
	glMultiTexCoord(4, 1,1,1,1)
end

function ShieldSphereParticle:Draw()
	if checkStunned then
		self.stunned = Spring.GetUnitIsStunned(self.unit)
	end
	if self.stunned or Spring.IsUnitIcon(self.unit) then
		if self.lightID and WG['lighteffects'] then
			WG['lighteffects'].removeLight(self.lightID)
			self.lightID = nil
		end
		return
	end
	local color = self.color1
	glMultiTexCoord(1, color[1],color[2],color[3],color[4] or 1)
	color = self.color2
	glMultiTexCoord(2, color[1],color[2],color[3],color[4] or 1)
	local pos = self.pos
	glMultiTexCoord(3, pos[1],pos[2],pos[3], 0)
	glMultiTexCoord(4, self.margin, self.size, gameFrame, 1)

	glCallList(sphereList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereParticle:Initialize()
	shieldShader = gl.CreateShader({
		vertex = [[
			#define pos gl_MultiTexCoord3
			#define margin gl_MultiTexCoord4.x
			#define size vec4(gl_MultiTexCoord4.yyy,1.0)

			varying float opac;
			varying float gameFrame;
			varying vec4 color1;
			varying vec4 color2;
			varying vec4 modelPos;

			void main()
			{
				gameFrame = gl_MultiTexCoord4.z;
				modelPos = gl_Vertex;
				gl_Position = gl_ModelViewProjectionMatrix * (modelPos * size + pos);
				vec3 normal = gl_NormalMatrix * gl_Normal;
				vec3 vertex = vec3(gl_ModelViewMatrix * gl_Vertex);
				float angle = dot(normal,vertex)*inversesqrt( dot(normal,normal)*dot(vertex,vertex) ); //dot(norm(n),norm(v))
				opac = pow( abs( angle ) , margin);

				color1 = gl_MultiTexCoord1;
				color2 = gl_MultiTexCoord2;
			}
		]],
		fragment = [[
			varying float opac;
			varying float gameFrame;
			varying vec4 color1;
			varying vec4 color2;
			varying vec4 modelPos;

			const float pi = acos(0.0) * 2.0;
			const float phi = (1.0 + sqrt(5.0))/2.0;

			float SphFib1(vec3 v, float n) {	 // based on iq's version of Keinert et al's Spherical Fibonnacci Mapping code
				vec4 b;
				vec3 q;
				vec2 ff, c;
				float fk,	a, z, ni;

				ni = 1.0 / n;
				fk = pow (phi, max (2., floor (log (n * pi * sqrt (5.) * (1. - v.z * v.z)) / log (phi + 1.)))) / sqrt (5.);
				ff = vec2 (floor (fk + 0.5), floor (fk * phi + 0.5));
				b = 2. * vec4 (ff * ni, pi * (fract ((ff + 1.) * phi) - (phi - 1.)));
				c = floor ((mat2 (b.y, - b.x, b.w, - b.z) / (b.y * b.z - b.x * b.w)) * vec2 (atan (v.y, v.x), v.z - (1. - ni)));
				float ddMin = 4.1;
				for (int s = 0; s < 4; s ++) {
					a = dot (ff, vec2 (s - 2 * (s / 2), s / 2) + c);
					z = 1. - (2. * a + 1.) * ni;
					q = vec3 (sin (2. * pi * fract (phi * a) + vec2 (0.5 * pi, 0.)) * sqrt (1. - z * z), z) - v;
					ddMin = min (ddMin, dot (q, q));
				}
				return sqrt (ddMin);
			}

			#define SNORM2NORM(value) (value * 0.5 + 0.5)

			void main(void)
			{
				float waveFront = mod(-gameFrame * 0.005, 1.0);
				float band = SNORM2NORM(cos((modelPos.y - waveFront) * pi * 4.0));
				float fibRaw = SphFib1(-modelPos.xzy, 384.0 + 128.0 * sin(gameFrame * 0.0025) );
				float fib = pow(smoothstep(0.1, 0.0, fibRaw * band), 3.0);

				gl_FragColor = mix(color1, color2, opac);
				gl_FragColor = pow(gl_FragColor, vec4(1.4 - fib));
			}

		]],
		uniform = {
			margin = 1,
		}
	})

	if (shieldShader == nil) then
		print(PRIO_MAJOR,"LUPS->Shield: critical shader error: "..gl.GetShaderLog())
		return false
	end

	sphereList = gl.CreateList(DrawSphere,0,0,0,1,30,false)
end

function ShieldSphereParticle:Finalize()
	gl.DeleteShader(shieldShader)
	gl.DeleteList(sphereList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereParticle:CreateParticle()
	-- needed for repeat mode
	self.csize	= self.size
	self.clife	= self.life

	self.size			= self.csize or self.size
	self.life_incr = 1/self.life
	self.life			= 0
	self.color1		 = self.colormap1[1]
	self.color2		 = self.colormap2[1]

	self.firstGameFrame = Spring.GetGameFrame()
	self.dieGameFrame	 = self.firstGameFrame + self.clife

end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local time = 0
function ShieldSphereParticle:Update(n)
	time = time + n
	if time > 40 then
		checkStunned = true
		time = 0
	else
		checkStunned = false
	end

	if not self.stunned and self.light then
		if WG['lighteffects'] and WG['lighteffects'].createLight then
			if not self.unitPos then
				self.unitPos = {}
				self.unitPos[1], self.unitPos[2], self.unitPos[3] = Spring.GetUnitPosition(self.unit)
			end
			local color = {GetColor(self.colormap2,self.life) }
			color[4]=color[4]*self.light
			if not self.lightID then
				self.lightID = WG['lighteffects'].createLight('shieldsphere',self.unitPos[1]+self.pos[1], self.unitPos[2]+self.pos[2], self.unitPos[3]+self.pos[1], self.size*6, color)
			else
				WG['lighteffects'].editLight(self.lightID, {orgMult=color[4],param={r=color[1],g=color[2],b=color[3]}})
			end
		else
			self.lightID = nil
		end
	end

	if (self.life<1) then
		self.life		 = self.life + n*self.life_incr
		self.size		 = self.size + n*self.sizeGrowth
		self.color1 = {GetColor(self.colormap1,self.life)}
		self.color2 = {GetColor(self.colormap2,self.life)}
	end
end

-- used if repeatEffect=true;
function ShieldSphereParticle:ReInitialize()
	self.size		 = self.csize
	self.life		 = 0
	self.color1	 = self.colormap1[1]
	self.color2	 = self.colormap2[1]

	self.dieGameFrame = self.dieGameFrame + self.clife
end

function ShieldSphereParticle.Create(Options)
	local newObject = MergeTable(Options, ShieldSphereParticle.Default)
	setmetatable(newObject,ShieldSphereParticle)	-- make handle lookup
	newObject:CreateParticle()
	return newObject
end

function ShieldSphereParticle:Destroy()
	if self.lightID and WG['lighteffects'] and WG['lighteffects'].removeLight then
		WG['lighteffects'].removeLight(self.lightID)
	end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereParticle