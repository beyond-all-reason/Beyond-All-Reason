function gadget:GetInfo()
  return {
    name      = "Map Lava Gadget 2.4",
    desc      = "lava",
    author    = "knorke, Beherith, The_Yak, Anarchid, Kloot, Gajop, ivand, Damgam",
    date      = "Feb 2011, Nov 2013, 2022!",
    license   = "GNU GPL, v2 or later",
    layer     = -3,
    enabled   = true
  }
end
-----------------


if (gadgetHandler:IsSyncedCode()) then

tideRhym = {}
tideIndex = 1
tideContinueFrame = 0
lavaLevel = 0
lavaGrow = 0
--_G.Game.mapSizeX = Game.mapSizeX
--_G.Game.mapSizeY = Game.mapSizeY
gameframe = 0

function gadget:Initialize()
	_G.frame = 0
	--This should be in config file
	VFS.Include("luarules/configs/lavaConfig.lua")
	if lavaMap == false then
		gadgetHandler:RemoveGadget(self)
	end
	_G.lavaLevel = lavaLevel
	_G.lavaGrow = lavaGrow
end


function addTideRhym (targetLevel, speed, remainTime)
	local newTide = {}
	newTide.targetLevel = targetLevel
	newTide.speed = speed
	newTide.remainTime = remainTime
	table.insert (tideRhym, newTide)
end


function updateLava ()
	if (lavaGrow < 0 and lavaLevel < tideRhym[tideIndex].targetLevel) 
		or (lavaGrow > 0 and lavaLevel > tideRhym[tideIndex].targetLevel) then
		tideContinueFrame = gameframe + tideRhym[tideIndex].remainTime*30
		lavaGrow = 0
		--Spring.Echo ("Next LAVA LEVEL change in " .. (tideContinueFrame-gameframe)/30 .. " seconds")
	end

	if (gameframe == tideContinueFrame) then
		tideIndex = tideIndex + 1
		if (tideIndex > table.getn (tideRhym)) then
			tideIndex = 1
		end
		--Spring.Echo ("tideIndex=" .. tideIndex .. " target=" ..tideRhym[tideIndex].targetLevel )
		if  (lavaLevel < tideRhym[tideIndex].targetLevel) then
			lavaGrow = tideRhym[tideIndex].speed
		else
			lavaGrow = -tideRhym[tideIndex].speed
		end
	end
	_G.lavaGrow = lavaGrow
end

local function clamp(low, x, high)
	return math.min(math.max(x, low), high)
end

function gadget:GameFrame (f)
	gameframe = f
	_G.lavaLevel = lavaLevel+math.sin(f/30)*0.5
	--_G.lavaLevel = lavaLevel + clamp(-0.95, math.sin(f / 30), 0.95) * 0.5 --clamp to avoid jittering when sin(x) is around +-1
	_G.frame = f

	if (f%10==0) then
		lavaDeathCheck()
	end

	updateLava ()
	lavaLevel = lavaLevel+lavaGrow

	local x = math.random(1,Game.mapX*512)
	local z = math.random(1,Game.mapY*512)
	local y = Spring.GetGroundHeight(x,z)
	if y  < lavaLevel then
		--This should be in config file to customize effects on lava plane
		if (f%5==0) then
			Spring.SpawnCEG("lavasplash", x, lavaLevel+5, z)
			local r = math.random(0,15)
			if r == 0 then
				Spring.PlaySoundFile("lavabubbles", math.random(50,100)/100, x, y, z, 'sfx')
			elseif r == 5 then
				Spring.PlaySoundFile("lavarumble", math.random(50,100)/100, x, y, z, 'sfx')
			elseif r == 10 then
				Spring.PlaySoundFile("lavarumble2", math.random(50,100)/100, x, y, z, 'sfx')
			end
		end
	end
	if lavaGrow and lavaGrow > 0 then
		Spring.Echo("LavaIsRising")
	elseif lavaGrow and lavaGrow < 0 then
		Spring.Echo("LavaIsDropping")
	end
end

function lavaDeathCheck ()
	local all_units = Spring.GetAllUnits()
	for i in pairs(all_units) do
		x,y,z = Spring.GetUnitBasePosition(all_units[i])
		if (y ~= nil) then
			if (y and y < lavaLevel) then
				--This should be in config file to change damage + effects/cegs
				-- local health, maxhealth = Spring.GetUnitHealth(all_units[i])
				-- Spring.AddUnitDamage (all_units[i], health - maxhealth*0.033, 0, Spring.GetGaiaTeamID(), 1) 
				Spring.AddUnitDamage (all_units[i], lavaDamage, 0, Spring.GetGaiaTeamID(), 1) 
				--Spring.DestroyUnit (all_units[i], true, false, Spring.GetGaiaTeamID())
				Spring.SpawnCEG("lavadamage", x, y+5, z)
			end
		end
	end
	local all_features = Spring.GetAllFeatures()
	for i in pairs(all_features) do
		x,y,z = Spring.GetFeaturePosition(all_features[i])
		if (y ~= nil) then
			if (y and y < lavaLevel) then
				local reclaimLeft = select(5, Spring.GetFeatureResources (all_features[i]))
				if reclaimLeft <= 0 then
					Spring.DestroyFeature(all_features[i])
					Spring.SpawnCEG("lavadamage", x, y+5, z)
				else
					local newReclaimLeft = reclaimLeft - 0.033
					Spring.SetFeatureReclaim (all_features[i], newReclaimLeft)
					Spring.SpawnCEG("lavadamage", x, y+5, z)
				end
			end
		end
	end
end

local DAMAGE_EXTSOURCE_WATER = -500

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID)
    if (weaponDefID ~= DAMAGE_EXTSOURCE_WATER) then
           -- not water damage, do not modify
           return damage, 1.0
    end

    local unitDef = UnitDefs[unitDefID]
    local moveDef = unitDef.moveDef

    if (moveDef == nil or moveDef.family ~= "hover") then
          -- not a hovercraft, do not modify
          return damage, 1.0
    end

    return 0.0, 1.0
end


else --- UNSYCNED:
--This should be in config file to change used image
local lavaTex = ":la:LuaRules/images/lavacolor3.png"
local heightTex = "$heightmap"

local shader
local timeLoc

function gadget:Initialize()
	VFS.Include("luarules/configs/lavaConfig.lua")
	if lavaMap == false then
		gadgetHandler:RemoveGadget(self)
	end
	Spring.SetDrawWater(true)
	Spring.SetDrawGround(true)
	--This should be in config file to change if you want forced void water/ground)
	Spring.SetMapRenderingParams({voidWater = false, voidGround = false})

	if (gl.CreateShader == nil) then
		Spring.Echo("Shaders not found, reverting to non-GLSL lava gadget")
	else
		shader = gl.CreateShader({

			uniform = {
				mapsizex = Game.mapSizeX,
				mapsizez = Game.mapSizeZ,
				--Not sure, but this might be needed in config file
				minHeight = 0,--Spring.GetGroundExtremes(),
			},
			uniformInt = {
				lavacolor = 0,
				height = 1,
			},

			vertex = [[
				// Application to vertex shader
				varying vec3 normal;
				varying float lavaHeight;

				uniform float mapsizex;
				uniform float mapsizez;

				varying vec2 hmuv;
				varying vec4 viewSpacePos;

				void main()
				{
					gl_TexCoord[0] = gl_MultiTexCoord0;
					normal  = gl_NormalMatrix * gl_Normal;

					lavaHeight = gl_Vertex.y;
					hmuv = vec2(gl_Vertex.x / mapsizex, gl_Vertex.z / mapsizez);

					viewSpacePos = gl_ModelViewMatrix * gl_Vertex;
					gl_Position = gl_ProjectionMatrix * viewSpacePos;
				}

			]],

			fragment = [[
				#define M_PI 3.1415926535897932384626433832795
				varying vec3 normal;
				varying float lavaHeight;

				uniform float time;
				uniform float mapsizex;
				uniform float mapsizez;
				uniform sampler2D lavacolor;
				uniform sampler2D height;

				uniform float minHeight;

				varying vec2 hmuv;
				varying vec4 viewSpacePos;


				////////////////////////////////////////////////////////////////////////////////

				#define FANCY_LAVA

				//#define CRASH_SHADER

				#ifdef CRASH_SHADER
					blabla1 + blabla2;
				#endif

				vec4 bilinearTexture2D(sampler2D tex, vec2 res, vec2 uv)
				{
					vec2 st = uv * res - 0.5;

					vec2 iuv = floor( st );
					vec2 fuv = fract( st );

					vec4 a = texture( tex, (iuv+vec2(0.5,0.5))/res );
					vec4 b = texture( tex, (iuv+vec2(1.5,0.5))/res );
					vec4 c = texture( tex, (iuv+vec2(0.5,1.5))/res );
					vec4 d = texture( tex, (iuv+vec2(1.5,1.5))/res );

					return mix(
							mix( a, b, fuv.x),
							mix( c, d, fuv.x), fuv.y
							);
				}

				#if defined(FANCY_LAVA)
					#define time2 time * 0.005

					#if 1
						#define HASHSCALE1 .1031
						float hash12(vec2 p)
						{
							vec3 p3  = fract(vec3(p.xyx) * HASHSCALE1);
							p3 += dot(p3, p3.yzx + 19.19);
							return fract((p3.x + p3.y) * p3.z);
						}
						#define rand(p) hash12(p)
					#else
						//this one is apparently terrible. See: https://www.shadertoy.com/view/4djSRW
						float rand(vec2 co)
						{
							float a = 12.9898;
							float b = 78.233;
							float c = 43758.5453;
							float dt = dot(co.xy ,vec2(a,b));
							float sn = mod(dt, M_PI);
							return fract(sin(sn) * c);
						}
					#endif

					float noise(in vec2 n)
					{
						const vec2 d = vec2(0.0, 1.0);
						vec2 b = floor(n);
						vec2 f = 0.5 * (1.0 - cos(M_PI * fract(n)));
						return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
					}

					mat2 makem2(in float theta){float c = cos(theta);float s = sin(theta);return mat2(c,-s,s,c);}

					vec2 gradn(vec2 p)
					{
						float ep = 0.1;
						float gradx = noise(vec2(p.x+ep,p.y))-noise(vec2(p.x-ep,p.y));
						float grady = noise(vec2(p.x,p.y+ep))-noise(vec2(p.x,p.y-ep));
						return vec2(gradx,grady);
					}

					#define MAX_OCTAVES 15
					#define MIN_OCTAVES 7

					float flow(in vec2 p, int octaves)
					{
						float z= 1.5;
						float rz = 0.;
						vec2 bp = p;
						for (int i = 0; i < MAX_OCTAVES; ++i) {
							if (i < octaves) {
								//primary flow speed
								p += time2 * -0.02;

								//secondary flow speed (speed of the perceived flow)
								bp += time2 * 0.01;

								//displacement field (try changing time multiplier)
								vec2 gr = gradn(1 * i * p * 0.75 + time2 * 0.05);

								//rotation of the displacement field
								gr *= makem2(time2 * 1.0 - (0.05 * p.x + 0.03 * p.y) * 25.0);

								//displace the system
								p += gr*.3;

								//add noise octave
								rz += (sin(noise(p)*5.0)*0.5+0.5)/z;

								//blend factor (blending displaced system with base system)
								//you could call this advection factor (.5 being low, .95 being high)
								p = mix(bp, p, 0.77);

								//intensity scaling
								z *= 1.7;

								//octave scaling
								p *= 2.4;
								bp *= 1.2;
							}
						}
						return rz;
					}
				#endif

				////////////////////////////////////////////////////////////////////////////////////

				const vec3 SHORE_COLOR = vec3(1.8, 0.99, 0.02);

				void main()
				{
					#if defined(FANCY_LAVA)
						const vec3 FANCYLAVA_COLOR = vec3(0.4, 0.2, 0.02);

						const vec2 UV_MULT = vec2(20.0);
						vec2 p = gl_TexCoord[0].st * vec2(UV_MULT);

						vec3 worldVertex = vec3(hmuv.s * mapsizex, lavaHeight, hmuv.t * mapsizez);
						//float cameraDist = gl_FragCoord.z / gl_FragCoord.w; //magically returns distance from the camera origin to this pixel
						float cameraDist = length(viewSpacePos);
						//float cameraDist = abs(viewSpacePos.z);

						const vec2 CAM_MINMAX = vec2(200.0, 6600.0);

						// LOG scaling doesn't work as well as expected. TODO, figure something out, because linear scaling overdraw things.
						//float logMul = (MAX_OCTAVES - MIN_OCTAVES) / log(CAM_MINMAX.y - CAM_MINMAX.x + 1.0);
						//int octaves = int(MAX_OCTAVES - floor(logMul * log( clamp(cameraDist, CAM_MINMAX.x, CAM_MINMAX.y) - CAM_MINMAX.x + 1.0 )));

						// Use linear scaling instead
						int octaves = int(MAX_OCTAVES - floor((MAX_OCTAVES - MIN_OCTAVES) * clamp(cameraDist, CAM_MINMAX.x, CAM_MINMAX.y) / CAM_MINMAX.y));

						float rz = flow(p, octaves);
						vec3 col = FANCYLAVA_COLOR / rz;
						vec4 vlavacolor = vec4(col, 1.0);
						const float CONSTRAST_POW = 1.8;
					#else
						const vec2 UV_MULT = vec2(16.0);
						vec2 p = gl_TexCoord[0].st * vec2(UV_MULT);

						vec2 distortion;
						distortion.x = p.s + sin(p.s * 20 + time / 50) / 350;
						distortion.y = p.t + sin(p.t * 20 + time / 73) / 400;
						vec4 vlavacolor = texture2D(lavacolor, distortion) + 0.1;

						vec2 distortion2;
						distortion2 = (distortion + M_PI * 12) * M_PI / 9;
						vec4 vlavacolor2 = texture2D(lavacolor, distortion2) * 2 + 0.1;
						vlavacolor *= vlavacolor2;
						const float CONSTRAST_POW = 1.6;
					#endif

					vlavacolor.rgb = pow(vlavacolor.rgb, vec3(CONSTRAST_POW)); //change contrast

					const vec2 SMOOTHSTEPS = vec2(-0.0015, 0.002);
					vec2 inmap = smoothstep(SMOOTHSTEPS.x, SMOOTHSTEPS.y, hmuv) * (1.0 - smoothstep(1.0 - SMOOTHSTEPS.y, 1.0 - SMOOTHSTEPS.x, hmuv));

					float groundHeight = bilinearTexture2D(height, vec2(mapsizex / 8.0, mapsizez / 8.0), hmuv).r;
					float factor = smoothstep(0.0, 1.0, (groundHeight - minHeight) / (lavaHeight - minHeight)) * min(inmap.x, inmap.y);

					const float FACTOR_POW = 16.0;
					const float FACTOR_AMP = 0.99;

					gl_FragColor = mix(vlavacolor, vec4(SHORE_COLOR.rgb, 0.9), pow(FACTOR_AMP * factor, FACTOR_POW));
					//gl_FragColor = vec4(0.0);
				}
			]],
		})
		if (shader == nil) then
			Spring.Echo(gl.GetShaderLog())
			Spring.Echo("LAVA shader compilation failed, falling back to GL Lava. See infolog for details")
		else
			timeLoc = gl.GetUniformLocation(shader, "time")
			Spring.Echo('Lava shader compiled successfully! Yay!')
		end
	end
end

function gadget:DrawWorldPreUnit()
    if (SYNCED.lavaLevel) then
		DrawGroundHuggingSquare(-2*Game.mapX*512, -2*Game.mapY*512,  3*Game.mapX*512, 3*Game.mapY*512, SYNCED.lavaLevel) --***map.width bla
		--DrawGroundHuggingSquare(-0*Game.mapX*512, -0*Game.mapY*512,  1*Game.mapX*512, 1*Game.mapY*512, SYNCED.lavaLevel) --***map.width bla
	end
end

function DrawGroundHuggingSquare(x1, z1, x2, z2, HoverHeight)
	if (shader==nil) then
		--Spring.Echo('no shader, fallback renderer working...')
		gl.PushAttrib(gl.ALL_ATTRIB_BITS)
		gl.DepthTest(true)
		gl.DepthMask(true)
		gl.Texture(":la:LuaRules/images/lavacolor3.png")-- Texture file
		gl.BeginEnd(GL.QUADS, DrawGroundHuggingSquareVertices,  x1, z1, x2, z2, 5,  HoverHeight)
		gl.Texture(false)
		gl.DepthMask(false)
		gl.DepthTest(false)
	else
		gl.PushAttrib(gl.ALL_ATTRIB_BITS)
		us=gl.UseShader(shader)

		local f=Spring.GetGameFrame()

		gl.Uniform(timeLoc, f)

		gl.Texture(0, lavaTex)-- Texture file
		gl.Texture(1, heightTex)-- Texture file

		gl.DepthTest(true)
		gl.DepthMask(true)

		gl.BeginEnd(GL.QUADS, DrawGroundHuggingSquareVertices, x1, z1, x2, z2, 1, HoverHeight)

		gl.DepthTest(false)
		gl.DepthMask(false)

		gl.UseShader(0)
	end
	gl.PopAttrib()
end


function DrawGroundHuggingSquareVertices(x1, z1, x2, z2, tiles, HoverHeight)
	local y = HoverHeight

	local xstep = (x2 - x1) / tiles
	local zstep = (z2 - z1) / tiles

	for x = x1, x2 - 1, xstep do
		for z = z1, z2 - 1, zstep do
		gl.TexCoord(tiles * x / (x2 - 1), tiles * z / (z2 - 1))
		gl.Vertex(x, y, z)

		gl.TexCoord(tiles * x / (x2 - 1), tiles * (z + zstep) / (z2 - 1))
		gl.Vertex(x, y, z + zstep)

		gl.TexCoord(tiles * (x + xstep) / (x2 - 1), tiles * (z + zstep) / (z2 - 1))
		gl.Vertex(x + xstep, y, z + zstep)

		gl.TexCoord(tiles * (x + xstep) / (x2 - 1), tiles * z / (z2 - 1))
		gl.Vertex(x + xstep, y, z)
		end
	end
end

end--ende unsync
