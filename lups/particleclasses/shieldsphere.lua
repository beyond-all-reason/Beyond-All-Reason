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

			float Perlin3D( vec3 P ) {
				//  https://github.com/BrianSharpe/Wombat/blob/master/Perlin3D.glsl

				// establish our grid cell and unit position
				vec3 Pi = floor(P);
				vec3 Pf = P - Pi;
				vec3 Pf_min1 = Pf - 1.0;

				// clamp the domain
				Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
				vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

				// calculate the hash
				vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
				Pt *= Pt;
				Pt = Pt.xzxz * Pt.yyww;
				const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
				const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
				vec3 lowz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi.zzz * ZINC ) );
				vec3 highz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi_inc1.zzz * ZINC ) );
				vec4 hashx0 = fract( Pt * lowz_mod.xxxx );
				vec4 hashx1 = fract( Pt * highz_mod.xxxx );
				vec4 hashy0 = fract( Pt * lowz_mod.yyyy );
				vec4 hashy1 = fract( Pt * highz_mod.yyyy );
				vec4 hashz0 = fract( Pt * lowz_mod.zzzz );
				vec4 hashz1 = fract( Pt * highz_mod.zzzz );

				// calculate the gradients
				vec4 grad_x0 = hashx0 - 0.49999;
				vec4 grad_y0 = hashy0 - 0.49999;
				vec4 grad_z0 = hashz0 - 0.49999;
				vec4 grad_x1 = hashx1 - 0.49999;
				vec4 grad_y1 = hashy1 - 0.49999;
				vec4 grad_z1 = hashz1 - 0.49999;
				vec4 grad_results_0 = inversesqrt( grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x0 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y0 + Pf.zzzz * grad_z0 );
				vec4 grad_results_1 = inversesqrt( grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x1 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1 );

				// Classic Perlin Interpolation
				vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
				vec4 res0 = mix( grad_results_0, grad_results_1, blend.z );
				vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
				float final = dot( res0, blend2.zxzx * blend2.wwyy );
				return ( final * 1.1547005383792515290182975610039 );  // scale things to a strict -1.0->1.0 range  *= 1.0/sqrt(0.75)
			}

			#define SNORM2NORM(value) (value * 0.5 + 0.5)

			void main(void)
			{
				//float waveFront = mod(-gameFrame * 0.005, 1.0);
				//float band = SNORM2NORM(cos((modelPos.y - waveFront) * PI * 8.0));

				const float resolution = 3.5;
				const float sharpness = 10.0;
				const float outerMult = 4.0;
				const float timePace = 0.015;

				vec3 pos = -modelPos.xzy;
				float noiseVal = 0.0;

				for (int i = 0; i < 4; ++i) {
					noiseVal += abs(Perlin3D( float(i+1) * pos * resolution + gameFrame * timePace )) / float(i+2);
					pos = pos.yzx;
				}

				noiseVal = 1.0 - noiseVal;
				noiseVal = pow(noiseVal, sharpness);

				noiseVal *= outerMult;
				noiseVal = clamp(noiseVal, 0.0, 1.0);
				//noiseVal *= band;

				gl_FragColor = mix(color1, color2, opac);
				gl_FragColor = pow(gl_FragColor, vec4(1.3 - noiseVal));
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