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
	technique		= 1,

	colormap1		= { {0, 0, 0, 0} },
	colormap2		= { {0, 0, 0, 0} },

	repeatEffect	= false,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glMultiTexCoord = gl.MultiTexCoord
local glCallList = gl.CallList
local LuaShader = gl.LuaShader

local gameFrame = 0
local timeOffset = 0

function ShieldSphereParticle:BeginDraw()
	gl.DepthMask(false)
	shieldShader:Activate()
	gl.Culling(false)
	gameFrame = Spring.GetGameFrame()
	timeOffset = Spring.GetFrameTimeOffset()
end

function ShieldSphereParticle:EndDraw()
	gl.DepthMask(false)
	shieldShader:Deactivate()

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
	if self.lightID and self.stunned or Spring.IsUnitIcon(self.unit) then
		if Script.LuaUI("GadgetRemoveLight") then
			Script.LuaUI.GadgetRemoveLight(self.lightID)
		end
		self.lightID = nil
		return
	end
	local color = self.color1
	glMultiTexCoord(1, color[1], color[2], color[3], color[4] or 1)
	color = self.color2
	glMultiTexCoord(2, color[1], color[2], color[3], color[4] or 1)
	local pos = self.pos
	glMultiTexCoord(3, pos[1], pos[2], pos[3], self.technique or 0)
	glMultiTexCoord(4, self.margin, self.size, gameFrame + timeOffset, self.unit / 65535.0)

	glCallList(sphereList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereParticle:Initialize()
	shieldShader = LuaShader({
		vertex = [[
			#version 150 compatibility

			#define pos gl_MultiTexCoord3.xyz
			#define margin gl_MultiTexCoord4.x
			#define size vec4(gl_MultiTexCoord4.yyy, 1.0)

			out float opac;
			out float gameFrame;
			out vec4 color1;
			out vec4 color2;
			out vec4 modelPos;
			out float unitID;
			flat out int technique;

			void main()
			{
				gameFrame = gl_MultiTexCoord4.z;
				unitID = gl_MultiTexCoord4.w;
				modelPos = gl_Vertex;

				technique = int(floor(gl_MultiTexCoord3.w));

				gl_Position = gl_ModelViewProjectionMatrix * (modelPos * size + vec4(pos, 0.0));
				vec3 normal = gl_NormalMatrix * gl_Normal;
				vec3 vertex = vec3(gl_ModelViewMatrix * gl_Vertex);
				float angle = dot(normal,vertex)*inversesqrt( dot(normal,normal)*dot(vertex,vertex) ); //dot(norm(n),norm(v))
				opac = pow( abs( angle ) , margin);

				color1 = gl_MultiTexCoord1;
				color2 = gl_MultiTexCoord2;
			}
		]],
		fragment = [[
			#version 150 compatibility

			in float opac;
			in float gameFrame;
			in vec4 color1;
			in vec4 color2;
			in vec4 modelPos;
			in float unitID;
			flat in int technique;


			const float PI = acos(0.0) * 2.0;

			float hash13(vec3 p3) {
				const float HASHSCALE1 = 44.38975;
				p3  = fract(p3 * HASHSCALE1);
				p3 += dot(p3, p3.yzx + 19.19);
				return fract((p3.x + p3.y) * p3.z);
			}

			float noise12(vec2 p){
				vec2 ij = floor(p);
				vec2 xy = fract(p);
				xy = 3.0 * xy * xy - 2.0 * xy * xy * xy;
				//xy = 0.5 * (1.0 - cos(PI * xy));
				float a = hash13(vec3(ij + vec2(0.0, 0.0), unitID));
				float b = hash13(vec3(ij + vec2(1.0, 0.0), unitID));
				float c = hash13(vec3(ij + vec2(0.0, 1.0), unitID));
				float d = hash13(vec3(ij + vec2(1.0, 1.0), unitID));
				float x1 = mix(a, b, xy.x);
				float x2 = mix(c, d, xy.x);
				return mix(x1, x2, xy.y);
			}

			float noise13( vec3 P ) {
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

			float Fbm12(vec2 P) {
				const int octaves = 2;
				const float lacunarity = 1.5;
				const float gain = 0.49;

				float sum = 0.0;
				float amp = 1.0;
				vec2 pp = P;

				int i;

				for(i = 0; i < octaves; ++i)
				{
					amp *= gain;
					sum += amp * noise12(pp);
					pp *= lacunarity;
				}
				return sum;
			}

			float Fbm31Magic(vec3 p) {
				 float v = 0.0;
				 v += noise13(p * 1.0) * 2.200;
				 v -= noise13(p * 4.0) * 3.125;
				 return v;
			}

			float Fbm31Electro(vec3 p) {
				 float v = 0.0;
				 v += noise13(p * 0.9) * 0.99;
				 v += noise13(p * 3.99) * 0.49;
				 v += noise13(p * 8.01) * 0.249;
				 v += noise13(p * 15.05) * 0.124;
				 return v;
			}

			#define SNORM2NORM(value) (value * 0.5 + 0.5)
			#define NORM2SNORM(value) (value * 2.0 - 1.0)

			#define time (gameFrame * 0.03333333)

			vec3 LightningOrb(vec2 vUv, vec3 color) {
				vec2 uv = NORM2SNORM(vUv);

				const float strength = 0.01;
				const float dx = 0.1;

				float t = 0.0;

				for (int k = -4; k < 14; ++k) {
					vec2 thisUV = uv;
					thisUV.x -= dx * float(k);
					thisUV.y += float(k);
					t += abs(strength / ((thisUV.x + Fbm12( thisUV + time ))));
				}

				return color * t;
			}

			vec3 MagicOrb(vec3 noiseVec, vec3 color) {
				float t = 0.0;

				for( int i = 1; i < 2; ++i ) {
					t = abs(2.0 / ((noiseVec.y + Fbm31Magic( noiseVec + 0.5 * time / float(i)) ) * 75.0));
					t += 1.3 * float(i);
				}
				return color * t;
			}

			vec3 ElectroOrb(vec3 noiseVec, vec3 color) {
				float t = 0.0;

				for( int i = 0; i < 5; ++i ) {
					noiseVec = noiseVec.zyx;
					t = abs(2.0 / (Fbm31Electro(noiseVec + vec3(0.0, time / float(i + 1), 0.0)) * 120.0));
					t += 0.2 * float(i + 1);
				}

				return color * t;
			}

			vec2 RadialCoords(vec3 a_coords)
			{
				vec3 a_coords_n = normalize(a_coords);
				float lon = atan(a_coords_n.z, a_coords_n.x);
				float lat = acos(a_coords_n.y);
				vec2 sphereCoords = vec2(lon, lat) / PI;
				return vec2(sphereCoords.x * 0.5 + 0.5, 1.0 - sphereCoords.y);
			}

			vec3 RotAroundY(vec3 p)
			{
				float ra = -time * 1.5;
				mat4 tr = mat4(cos(ra), 0.0, sin(ra), 0.0,
							   0.0, 1.0, 0.0, 0.0,
							   -sin(ra), 0.0, cos(ra), 0.0,
							   0.0, 0.0, 0.0, 1.0);

				return (tr * vec4(p, 1.0)).xyz;
			}

			void main(void)
			{
				gl_FragColor = mix(color1, color2, opac);

				if (technique == 1) { // LightningOrb
					vec3 noiseVec = modelPos.xyz;
					noiseVec = RotAroundY(noiseVec);
					vec2 vUv = (RadialCoords(noiseVec));
					vec3 col = LightningOrb(vUv, gl_FragColor.rgb);
					gl_FragColor.rgb = max(gl_FragColor.rgb, col * col);
				}
				else if (technique == 2) { // MagicOrb
					vec3 noiseVec = modelPos.xyz;
					noiseVec = RotAroundY(noiseVec);
					vec3 col = MagicOrb(noiseVec, gl_FragColor.rgb);
					gl_FragColor.rgb = max(gl_FragColor.rgb, col * col);
				}
				else if (technique == 3) { // ElectroOrb
					vec3 noiseVec = modelPos.xyz;
					noiseVec = RotAroundY(noiseVec);
					vec3 col = ElectroOrb(noiseVec, gl_FragColor.rgb);
					gl_FragColor.rgb = max(gl_FragColor.rgb, col * col);
				}

				gl_FragColor.a = length(gl_FragColor.rgb);
			}

		]],
	}, "ShieldSphereParticleShader")

	if (shieldShader == nil) then
		print(PRIO_MAJOR,"LUPS->Shield: critical shader error: "..gl.GetShaderLog())
		return false
	end
	shieldShader:Initialize()

	sphereList = gl.CreateList(DrawSphere, 0, 0, 0, 1, 30, false)
end

function ShieldSphereParticle:Finalize()
	if shieldShader then
		shieldShader:Finalize()
	end
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

	if not self.stunned and self.light and not Spring.IsUnitIcon(self.unit) then
		if Script.LuaUI("GadgetCreateLight") then
			if not self.unitPos then
				self.unitPos = {}
				self.unitPos[1], self.unitPos[2], self.unitPos[3] = Spring.GetUnitPosition(self.unit)
			end
			if not self.lightID then
        
        local color = {GetColor(self.colormap2,self.life) }
        color[4]=color[4]*self.light
				self.lightID = Script.LuaUI.GadgetCreateLight('shieldsphere',self.unitPos[1]+self.pos[1], self.unitPos[2]+self.pos[2], self.unitPos[3]+self.pos[1], self.size*6, color)
			else
				--Script.LuaUI.GadgetEditLight(self.lightID, {orgMult=color[4],param={r=color[1],g=color[2],b=color[3]}})
        -- I saw ZERO reason to edit the light while it is running, as we dont use any of the color map shit, and editing a light is a MASSIVE performance hog
        
			end
		else
			self.lightID = nil
		end
	end
  if (self.life<1) then
    -- first off, BAR doesnt change the size of the sphere, nor the color of it in any significant way, so there is no point in ever calling this, but ill leave it here for others to learn from it.
		self.life		 = self.life + 31
		self.size		 = self.size + n*self.sizeGrowth
		self.color1 = {GetColor(self.colormap1,self.life)}
		self.color2 = {GetColor(self.colormap2,self.life)}
    --Spring.Echo(Spring.GetGameFrame(),n, self.life, self.life_incr)
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
	-- apply teamcoloring for default
	local r,g,b = Spring.GetTeamColor(Spring.GetUnitTeam(Options.unit))
	ShieldSphereParticle.Default.colormap1 = {{(r*0.45)+0.3, (g*0.45)+0.3, (b*0.45)+0.3, 0.6}}
	ShieldSphereParticle.Default.colormap2 = {{r*0.5, g*0.5, b*0.5, 0.66} }

	local newObject = table.merge(ShieldSphereParticle.Default, Options)
	setmetatable(newObject,ShieldSphereParticle)	-- make handle lookup
	newObject:CreateParticle()
	return newObject
end

function ShieldSphereParticle:Destroy()
	if self.lightID and Script.LuaUI("GadgetRemoveLight") then
		Script.LuaUI.GadgetRemoveLight(self.lightID)
		self.lightID = nil
	end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereParticle
