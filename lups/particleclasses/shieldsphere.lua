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
		name		= "ShieldSphere",
		backup		= "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
		desc		= "",

		layer		= -23, --// extreme simply z-ordering :x

		--// gfx requirement
		fbo			= false,
		shader		= true,
		rtt			= false,
		ctt			= false,
	}
end

ShieldSphereParticle.Default = {
	pos				= {0,0,0}, -- start pos
	layer			= -23,

	life			= 0,

	size			= 0,
	sizeGrowth		= 0,

	margin			= 1,

	colormap1		= { {0, 0, 0, 0} },
	colormap2		= { {0, 0, 0, 0} },

	repeatEffect	= false,
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

	glMultiTexCoord(1, 1, 1, 1, 1)
	glMultiTexCoord(2, 1, 1, 1, 1)
	glMultiTexCoord(3, 1, 1, 1, 1)
	glMultiTexCoord(4, 1, 1, 1, 1)
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
	glMultiTexCoord(1, color[1], color[2], color[3], color[4] or 1)
	color = self.color2
	glMultiTexCoord(2, color[1], color[2], color[3], color[4] or 1)
	local pos = self.pos
	glMultiTexCoord(3, pos[1], pos[2], pos[3], 0)
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

			const float PI = acos(0.0) * 2.0;

			float rand(vec2 c){
				return fract(sin(dot(c.xy, vec2(12.9898, 78.233))) * 43758.5453);
			}

			float noise(vec2 p){
				vec2 ij = floor(p);
				vec2 xy = fract(p);
				xy = 3.0 * xy * xy - 2.0 * xy * xy * xy;
				//xy = 0.5 * (1.0 - cos(PI * xy));
				float a = rand((ij + vec2(0.0, 0.0)));
				float b = rand((ij + vec2(1.0, 0.0)));
				float c = rand((ij + vec2(0.0, 1.0)));
				float d = rand((ij + vec2(1.0, 1.0)));
				float x1 = mix(a, b, xy.x);
				float x2 = mix(c, d, xy.x);
				return mix(x1, x2, xy.y);
			}

			float fbm(vec2 P)
			{
				const int octaves = 3;
				const float lacunarity = 2.1;
				const float gain = 0.49;

				float sum = 0.0;
				float amp = 1.0;
				vec2 pp = P;

				int i;

				for(i = 0; i < octaves; i+=1)
				{
					amp *= gain;
					sum += amp * noise(pp);
					pp *= lacunarity;
				}
				return sum;
			}

			#define SNORM2NORM(value) (value * 0.5 + 0.5)
			#define NORM2SNORM(value) (value * 2.0 - 1.0)

			#define time (gameFrame * 0.03333333)

			vec3 LightningOrb(vec2 vUv) {
				vec2 uv = NORM2SNORM(vUv);

				vec3 finalColor = vec3( 0.0 );
				const float inverseStrength = 65.0;
				const float colorIntensity = 0.1;

				for( int i=1; i < 4; ++i )
				{
					float hh = float(i) * colorIntensity;

					float t = 0.0;

					t += abs(1.0 / ((uv.x + 0.3 + fbm( uv + time/float(i))) * inverseStrength));
					t += abs(1.0 / ((uv.x - 0.1 + fbm( uv + time/float(i))) * inverseStrength));
					t += abs(1.0 / ((uv.x - 0.4 + fbm( uv + time/float(i))) * inverseStrength));
					t += abs(1.0 / ((uv.x - 0.8 + fbm( uv + time/float(i))) * inverseStrength));
					t += abs(1.0 / ((uv.x - 1.2 + fbm( uv + time/float(i))) * inverseStrength));

					finalColor +=  t * vec3( hh + 0.1, 0.3, 1.0 );
				}
				return finalColor;
			}

			vec2 RadialCoords(vec3 a_coords)
			{
				vec3 a_coords_n = normalize(a_coords);
				float lon = atan(a_coords_n.z, a_coords_n.x);
				float lat = acos(a_coords_n.y);
				vec2 sphereCoords = vec2(lon, lat) / PI;
				return vec2(sphereCoords.x * 0.5 + 0.5, 1.0 - sphereCoords.y);
			}

			void main(void)
			{
				gl_FragColor = mix(color1, color2, opac);

				vec2 vUv = (RadialCoords(modelPos.xyz));
				vec3 orbColor = LightningOrb(vUv);

				gl_FragColor.rgb = max(gl_FragColor.rgb, orbColor * orbColor);
				gl_FragColor.a = length(gl_FragColor.rgb);
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

	sphereList = gl.CreateList(DrawSphere, 0, 0, 0, 1, 30, false)
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