local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Raptor Scum GL4",
		desc = "Draws scum with global overlap texturing",
		author = "Beherith",
		date = "2022.04.20",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = true,
	}
end

-- TODO:
	-- maybe even use parallax
	-- add a moving distortion texture
	-- also write to deferred buffers maybe?
	-- fix stencil testing


if gadgetHandler:IsSyncedCode() then
	local scavengerAITeamID = 999
	local raptorsAITeamID = 999

	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local luaAI = Spring.GetTeamLuaAI(teams[i])
		if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
			scavengerAITeamID = i - 1
			break
		end
	end
	for i = 1, #teams do
		local luaAI = Spring.GetTeamLuaAI(teams[i])
		if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'RaptorsAI' then
			raptorsAITeamID = i - 1
			break
		end
	end

	local scumSpawnerIDs = {}

	local scums = {} -- {posx = 123, posz = 123, radius = 123, spawnframe = 0, growthrate = 1.0} -- in elmos per sec
	local numscums = 0
	local scumBins = {} -- a table keyed with (posx / 1024) + 1024 + (posz/1024), values are tables of scumindexes that can overlap that bin
	local scumRemoveQueue = {} -- maps gameframes to list of scums that will be removed
	local debugmode = false

	local sqrt = math.sqrt
	local floor = math.floor
	local max = math.max
	local min = math.min
	local clamp = math.clamp
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetGameFrame = Spring.GetGameFrame
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local initialized = false
	local boundary = 128 -- how many elmos closer to the center of the scum than the actual edge of the scum the unit must be to be considered on the scum

	local function GetScumCurrentRadius(scum, gf)
		gf = gf or spGetGameFrame()
		if scum.growthrate > 0 then
			return clamp((gf - scum.spawnframe) * scum.growthrate, 0, scum.radius)
		else
			return clamp(scum.radius - (gf - scum.spawnframe) *(-1.0 * scum.growthrate), 0, scum.radius)
		end
	end

	local function GetMapSquareKey(posx, posz)
		if posx < 0 or posz < 0 or posx > mapSizeX or posz > mapSizeZ then return nil end
		return (floor(posx*0.0009765625) * 1024 + floor(posz* 0.0009765625))
	end

	for x= 0, math.ceil(mapSizeX/1024) do
		for z = 0, math.ceil(mapSizeZ/1024) do
			scumBins[x*1024+z] = {}
		end
	end

	function gadget:Initialize()
		local scumGenerators = {
			raptor_hive = {radius = 800, growthrate = 0.8},
			raptor_turret_basic_t3_v1 = {radius = 600, growthrate = 0.4},
			raptor_turret_basic_t2_v1 = {radius = 400, growthrate = 0.2},
			raptor_turret_basic_t4_v1 = {radius = 800, growthrate = 0.8},
			raptor_turret_antiair_t3_v1 = {radius = 600, growthrate = 0.4},
			raptor_turret_antiair_t2_v1 = {radius = 400, growthrate = 0.2},
			raptor_turret_antiair_t4_v1 = {radius = 800, growthrate = 0.8},
			raptor_turret_acid_t3_v1 = {radius = 600, growthrate = 0.4},
			raptor_turret_acid_t2_v1 = {radius = 400, growthrate = 0.2},
			raptor_turret_acid_t4_v1 = {radius = 800, growthrate = 0.8},
			raptor_turret_emp_t3_v1 = {radius = 600, growthrate = 0.4},
			raptor_turret_emp_t2_v1 = {radius = 400, growthrate = 0.2},
			raptor_turret_emp_t4_v1 = {radius = 800, growthrate = 0.8},
			raptor_turret_antinuke_t3_v1 = {radius = 600, growthrate = 0.4},
			raptor_turret_antinuke_t2_v1 = {radius = 400, growthrate = 0.2},
			raptor_turret_meteor_t4_v1 = {radius = 800, growthrate = 0.8},

			scavbeacon_t1_scav = {radius = 740, growthrate = 0.74},
			scavbeacon_t2_scav = {radius = 880, growthrate = 0.88},
			scavbeacon_t3_scav = {radius = 1000, growthrate = 1},
			scavbeacon_t4_scav = {radius = 1360, growthrate = 1.36},
		}
		for unitDefName, scumParams in pairs(scumGenerators) do
			if UnitDefNames[unitDefName] then
				scumSpawnerIDs[UnitDefNames[unitDefName].id] = scumParams
			end
		end
		local scumSpawnerExclusions = {
			lootdroppod_gold_scav = true,
			lootdroppod_printer_scav = true,
			meteor_scav = true,
			mission_command_tower_scav = true,
			nuketest_scav = true,
			nuketestcor_scav = true,
			nuketestorg_scav = true,
			scavempspawner_scav = true,
			scavengerdroppod_scav = true,
			scavengerdroppodfriendly_scav = true,
			scavtacnukespawner_scav = true
		}
		for unitDefID, unitDef in pairs(UnitDefs) do
			if unitDef.customParams.isscavenger and not scumSpawnerExclusions[unitDef.name] and not unitDef.canMove and not string.find(unitDef.name, "lootbox") and not scumSpawnerIDs[unitDefID] and not unitDef.customParams.objectify and not unitDef.canCloak then
				scumSpawnerIDs[unitDefID] = {radius = 600, growthrate = 1.2}
			end
		end

		for x = 0, math.ceil(mapSizeX/1024) do
			for z = 0, math.ceil(mapSizeZ/1024) do
				scumBins[x*1024+z] = {}
			end
		end
	end


	-- This checks wether the unit is under any scum
	local function IsPosInScum(unitx,unity, unitz)
		-- out of bounds check, no scum outside of map bounds
		if unitx < 0 or unitz < 0 or unitx > mapSizeX or unitz > mapSizeZ then return nil end
		-- underwater scum doesnt count for hovers, ships
		unity = unity or 1
		if unity > -1 and spGetGroundHeight(unitx, unitz) < 0 then return nil end

		-- Empty bins also return
		local scumBinID = GetMapSquareKey(unitx, unitz)
		if scumBinID == nil or scumBins[scumBinID] == nil then return nil end
		local gf = spGetGameFrame()

		for scumID, scum in pairs(scumBins[scumBinID]) do
			local dx = (unitx - scum.posx)
			local dz = (unitz - scum.posz)
			local sqrdistance = (dx*dx + dz*dz)
			local scumradius = scum.radius
			if sqrdistance < (scumradius * scumradius) then
				local currentscumradius = GetScumCurrentRadius(scum, gf)
				--Spring.Echo("testing ScumID", scumID, sqrt(sqrdistance), scumradius, currentscumradius)
				if currentscumradius  - sqrt(sqrdistance) > boundary then
					return scumID
				end
			end
		end
		return nil
	end

	GG.IsPosInRaptorScum = IsPosInScum --(x,y,z)

	local function GetRandomScumID(startID)
		if numscums < 1 then return end
		local scumID = startID or next(scums) -- so we can start iterating from anywhere
		if not scumID then return end -- return nil on no scums
		local randomindex = math.random(1, numscums)
		for i = 1, randomindex do
			scumID = next(scums)
		end
		return scumID
	end

	GG.GetRandomScumID =  GetRandomScumID -- Returns nil or scumID

	local function GetRandomPositionInScum()
		local scumID = GetRandomScumID()
		if not scumID then return end
		local px, pz

		local scum   = scums[scumID]
		local radius = GetScumCurrentRadius(scum)
		local attempts = 0
		repeat
			attempts = attempts + 1
			local r = radius * math.sqrt(math.random())
			local theta = math.random() * 2 * math.pi
			local x = scum.posx + r * math.cos(theta)
			local z = scum.posz + r * math.sin(theta)
			if x > 128 and x < Game.mapSizeX - 128 and z > 128 and z < Game.mapSizeZ - 128 and r > 32 then
				px,pz = x,z
			end
		until (px and pz) and (attempts < 10)
		return px,pz
	end

	GG.GetRandomPositionInScum = GetRandomPositionInScum -- Returns nil or (X, Z)

	local function UpdateBins(scumID, removeScum)
		local scumTable = scums[scumID]
		if scumTable == nil then
			--Spring.Echo("Tried to update a scumID",scumID,"that no longer exists because it probably shrank to death, remove = ", removeScum)
			return nil
		end

		local posx = scumTable.posx
		local posz = scumTable.posz
		local radius = scumTable.radius

		if removeScum then
			scumTable = nil
			scums[scumID] = nil
		end

		local step = radius / 3
		for dx = -radius, radius, step do
			for dz = -radius, radius, step do
				local binID = GetMapSquareKey(posx + dx, posz + dz)
				if binID then
					scumBins[binID][scumID] = scumTable
					--Spring.Echo("scum added to bin! scumID:", scumID, "binID:", binID)
				end
			end
		end
	end

	local function AddOrUpdateScum(posx, posy, posz, radius, growthrate, scumID)
		if debugmode then Spring.Echo("AddOrUpdateScum",posx, posy, posz, radius, growthrate, scumID) end
		-- if scumID is supplied, we are updateing an existing scum instance!

		local gf = spGetGameFrame()
		local deathtime
		local scum
		-- thus we need to make a new scum, and register it in our scumBins
		if scums[scumID] == nil then
			posy = posy or Spring.GetGroundHeight(posx, posz)
			scum = {posx = posx, posz = posz, radius = radius, spawnframe = gf, growthrate = growthrate, scumID = scumID}
			scums[scumID] = scum
			UpdateBins(scumID)
			numscums = numscums + 1
		else-- a scumID is supplied, meaning we just update an existing instance
			scum = scums[scumID]
			-- well then, seems we have to do this after all, when we update a scum, we need to check how long its been alive
			-- this is the nastiest garbage ive ever done
			local currentradius = GetScumCurrentRadius(scum, gf)

			-- always remove from removal queue on update
			for _, removescums in pairs(scumRemoveQueue) do
				removescums[scumID] = nil
			end

			if growthrate > 0 then
				scum.spawnframe = gf - ( currentradius/growthrate)
				-- remove it from the death queue, no matter where it is, cause its 'growing'
			else
				scum.spawnframe = gf - ((scum.radius - currentradius)/ (-1 * growthrate) )
				deathtime = math.floor( gf + (currentradius/(-1 * growthrate)))
			end
			scum.growthrate = growthrate

			if debugmode then Spring.Echo("Updated scum", scumID, "it was", currentradius,"/", scum.radius, "sized, growing at", growthrate) end
		end
		--Spring.Echo(scumID, growthrate, radius, gf)

		if scum.growthrate < 0 then
			if debugmode then Spring.Echo("Removal of scum ID", scumID,"Scheduled for ",  deathtime - gf , "from now" ) end
			if scumRemoveQueue[deathtime] == nil then
				scumRemoveQueue[deathtime] = {}
			end
			scumRemoveQueue[deathtime][scumID] = true
		end

		return scumID
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if scumSpawnerIDs[unitDefID] and (debugmode or (unitTeam == scavengerAITeamID or unitTeam == raptorsAITeamID)) then
			local px, py, pz = Spring.GetUnitPosition(unitID)
			local gf = Spring.GetGameFrame()

			local scumID = AddOrUpdateScum(px, py, pz, scumSpawnerIDs[unitDefID].radius, scumSpawnerIDs[unitDefID].growthrate, unitID)
			local scum = scums[scumID]
			SendToUnsynced("ScumCreated",scum.posx, scum.posz, scum.radius, scum.growthrate, gf, scumID)
			--Spring.Echo("Scum Created Synced")
		end
	end


	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if scumSpawnerIDs[unitDefID] and scums[unitID] then
			AddOrUpdateScum(nil,nil,nil,nil, -10*math.abs(scums[unitID].growthrate), unitID)
			SendToUnsynced("ScumRemoved", unitID)
		end
	end

	function gadget:GameFrame(n)
		if not initialized then
			for i, unitID in ipairs(Spring.GetAllUnits()) do
				gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
			end
			initialized = true
		end
		if scumRemoveQueue[n] then
			for scumID, _ in pairs(scumRemoveQueue[n]) do
				if scums[scumID] then
					numscums = numscums - 1
				end
				UpdateBins(scumID, true)
			end
			scumRemoveQueue[n] = nil
		end
	end



elseif not Spring.Utilities.Gametype.IsScavengers() then	-- UNSYNCED



	local textureresolution = "low" -- low or high
	local textures = {
		low = {
			texcolorheight = "LuaUI/images/raptor_scum/alien_guts_colorheight.dds",
			texnormalspec =  "LuaUI/images/raptor_scum/alien_guts_normalspec.dds",
			texdistortion =  "LuaUI/images/lavadistortion.dds"
			},
		high = {
			texcolorheight = "LuaUI/images/raptor_scum/alien_guts_colorheight.dds",
			texnormalspec =  "LuaUI/images/raptor_scum/alien_guts_normalspec_u8888.dds",
			texdistortion =  "LuaUI/images/lavadistortion.png"
			},
		}


	local resolution = 32
	local gameFrame = -1

	local scumVBO = nil
	local scumShader = nil
	local debugmode = false
	local headless = false
	local drawScum = true
	local optimizeoverlaps = true

	local glTexture = gl.Texture
	local glCulling = gl.Culling
	local GL_LEQUAL = GL.LEQUAL
	local glStencilFunc         = gl.StencilFunc
	local glStencilOp           = gl.StencilOp
	local glStencilMask         = gl.StencilMask
	local glDepthTest           = gl.DepthTest
	local glClear               = gl.Clear
	local GL_ALWAYS             = GL.ALWAYS
	local GL_NOTEQUAL           = GL.NOTEQUAL
	local GL_KEEP               = 0x1E00 --GL.KEEP
	local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
	local GL_REPLACE            = GL.REPLACE

	local shaderConfig = {
		SPECULAREXPONENT = 64.0,  -- the specular exponent of the lava plane
		SPECULARSTRENGTH = 1.0, -- The peak brightness of specular highlights

		LOSDARKNESS = 0.5, -- how much to darken the out-of-los areas of the lava plane
		SHADOWSTRENGTH = 0.4, -- how much light a shadowed fragment can recieve
		CREEPTEXREZ = 0.003,
		JIGGLEAMPLITUDE = 0.2,
		VOIDWATER = (gl.GetMapRendering("voidWater") and 1 or 0),
	}

	local nightFactor = {1,1,1,1}

	---- GL4 Backend Stuff----

	local luaShaderDir = "LuaUI/Include/"
	local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
	VFS.Include(luaShaderDir.."instancevbotable.lua")

	local vsSrc =  [[
	#version 420
	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shader_storage_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require

	#line 5000

	layout (location = 0) in vec4 xyworld_xyfract; // l w rot and maxalpha
	layout (location = 1) in vec4 worldposradius; // xyz and radius
	layout (location = 2) in vec4 lifeparams; // lifestart, growthrate, OVERLAPPED, unused;

	//__ENGINEUNIFORMBUFFERDEFS__
	//__DEFINES__

	#line 10000

	//uniform float fadeDistance;
	uniform sampler2D heightmapTex;
	uniform sampler2D mapnormalsTex;

	out DataVS {
		vec4 v_worldPosRad;
		vec4 v_localxz;
		vec4 v_worldUV;
		vec4 v_lifeparams;
		vec4 v_mapnormals;
		float v_trueradius;
	};

	float rand(vec2 co){ // a pretty crappy random function
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}

	#line 11000
	void main()
	{
		v_worldPosRad = worldposradius;
		v_lifeparams = lifeparams;
		v_localxz = xyworld_xyfract;
		// Transform the [-1, 1] rect into world space
		vec4 mapPos = vec4(worldposradius.xyz, 1.0);
		mapPos.xz += xyworld_xyfract.xy *  worldposradius.w;

		// Sample the heightmap to get reasonable world depth
		vec2 uvhm = heightmapUVatWorldPos(mapPos.xz);
		mapPos.y = textureLod(heightmapTex, uvhm, 0.0).x + 3.0;

		// sample the map normals and pass it on for later use:
		v_mapnormals = textureLod(mapnormalsTex, uvhm, 0.0);

		v_worldUV =  mapPos.xyzw;

		float time = timeInfo.x + timeInfo.w;

		v_worldUV.x += JIGGLEAMPLITUDE * sin(time * 0.1 + 100*rand(v_worldUV.xy));
		v_worldUV.z += JIGGLEAMPLITUDE * sin(time * 0.1 + 100*rand(v_worldUV.zy));

		if (lifeparams.y > 0.0) {
			v_trueradius = clamp (lifeparams.y * (time - lifeparams.x), 0.0,  v_worldPosRad.w);
		}
		else{
			v_trueradius = clamp (v_worldPosRad.w + lifeparams.y * (time - lifeparams.x), 0.0, v_worldPosRad.w) ;
		}
		//mapPos.y += fract( 10 * (time - lifeparams.x) * 0.001) * 100;

		gl_Position = cameraViewProj * mapPos;
		if (lifeparams.z > 0.5){
			// Place overlapped circles outside of NDC space
			gl_Position = vec4(2.0,2.0,2.0,1.0);
		}
	}
	]]

	local fsSrc =
	[[
	#version 330
	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require
	//__ENGINEUNIFORMBUFFERDEFS__
	//__DEFINES__

	#line 30000
	uniform float iconDistance;
	uniform vec4 nightFactor;
	in DataVS {
		vec4 v_worldPosRad;
		vec4 v_localxz;
		vec4 v_worldUV;
		vec4 v_lifeparams;
		vec4 v_mapnormals;
		float v_trueradius;
	};

	uniform sampler2D heightmapTex;
	uniform sampler2D mapnormalsTex;
	uniform sampler2D infoTex;
	uniform sampler2DShadow shadowTex;
	uniform sampler2D colorheight;
	uniform sampler2D normalspec;
	uniform sampler2D distortion;

	out vec4 fragColor;

	vec4 shadowMapUVAtWorldPos(vec3 worldPos){
			vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
			shadowVertexPos.xy += vec2(0.5);
			return shadowVertexPos;
			//return clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
	}

	// RNM func from: https://blog.selfshadow.com/publications/blending-in-detail/
	vec3 ReOrientNormal(vec3 basenormal, vec3 detailnormal){
		vec3 t = basenormal.xyz * vec3( 2,  2, 2) + vec3(-1, -1,  0);
		vec3 u = detailnormal.xyz* vec3(-2, -2, 2) + vec3( 1,  1, -1);
		vec3 r = t*dot(t, u) - u*t.z;
		return normalize(r);
	}


	#line 31000
	void main(void)
	{
		if (any(lessThan(vec4(v_worldUV.xz, mapSize.xy - v_worldUV.xz) , vec4(0.0) ))) discard; // Discard out-of-map fragments
		#if (VOIDWATER == 1)
			if (v_worldUV.y < 0) discard;
		#endif

		float time = timeInfo.x+timeInfo.w;

		float internalradius = length (v_localxz.xy) ; //dot(v_localxz.xy, v_localxz.xy);
		float radialgrowth = v_trueradius/v_worldPosRad.w;
		// discard outside of current radius
		if (internalradius> radialgrowth) discard; // bail before any texture fetches
		vec4 texdistort = texture(distortion, v_worldUV.xz * CREEPTEXREZ * 1.0);
		float radialScum = smoothstep(radialgrowth - 0.15, radialgrowth, internalradius + 0.1 * texdistort.x );
		if (radialScum > 0.7) discard;

		vec4 texcolorheight= texture(colorheight, v_worldUV.xz * CREEPTEXREZ, -0.5);
		vec4 texnormalspec = texture(normalspec, v_worldUV.xz* CREEPTEXREZ, - 0.5);
		//vec4 texdistort2 = texture(distortion, v_worldUV.xz * CREEPTEXREZ * 2.0 + vec2(sin(time * 0.0002))) * 0.5 + 0.5;

		vec3 fragNormal = (texnormalspec.xzy * 2.0 -1.0);

		vec4 camPos = cameraViewInv[3];
		vec3 worldtocam = camPos.xyz - v_worldUV.xyz;

		float shadow = clamp(textureProj(shadowTex, shadowMapUVAtWorldPos(v_worldUV.xyz)), SHADOWSTRENGTH, 1.0);

		vec2 losUV = clamp(v_worldUV.xz, vec2(0.0), mapSize.xy ) / mapSize.zw;
		float loslevel = dot(vec3(0.33), texture(infoTex, losUV).rgb) ; // lostex is PO2
		loslevel = clamp(loslevel * 4.0 - 1.0, LOSDARKNESS, 1.0);

		// this is the actually correct way of blending according to
		// Whiteout blending https://blog.selfshadow.com/publications/blending-in-detail/
		fragNormal.xz += v_mapnormals.ra;
		vec3 normal = normalize(fragNormal.xyz);//  + texdistort2.xzy);
		//normal = vec3(0.0, 1.0, 0.0);

		// calculate direct lighting
		float lightamount = clamp(dot(sunDir.xyz, normal), 0.3, 1.0) * max(SHADOWSTRENGTH, shadow);

		// Specular Color
		vec3 reflvect = reflect(normalize(-1.0 * sunDir.xyz), normal);
		float specular = clamp(pow(clamp(dot(normalize(worldtocam), normalize(reflvect)), 0.0, 1.0), SPECULAREXPONENT), 0.0, SPECULARSTRENGTH);// * shadow;
		//float specular = clamp(dot(normalize(worldtocam), normalize(reflvect)), 0.0, 1.0);// * shadow;
		fragColor.rgb += fragColor.rgb * specular;

		vec3 outcolor = texcolorheight.rgb;

		outcolor = outcolor * (  loslevel * (lightamount ) * 0.5) + outcolor * specular * shadow;
		fragColor.rgba = vec4(outcolor, 1.0 );


		// darken outside

		fragColor.a = 1.0 - radialScum*3;
		fragColor.rgb *= ((fragColor.a  -0.3)*2.0) ;

		// emulate linear fog
		// vec4 fogParams; //fog {start, end, 0.0, scale}
		float fogFactor = 1.0;
		float fogDist = length(worldtocam.xyz);
		fogFactor = (fogParams.y - fogDist) * fogParams.w;
		fogFactor = clamp(fogFactor, 0.0, 1.0);
		fragColor.rgb = mix( fogColor.rgb, fragColor.rgb,fogFactor);

		fragColor.rgb *= nightFactor.rgb;
	}
	]]

	local function goodbye(reason)
	  Spring.Echo("Scum GL4 gadget exiting with reason: "..reason)
	  gadgetHandler:RemoveGadget()
	end

	local function initGL4(shaderConfig, DPATname)
		if gl.CreateShader == nil then
			headless = true
			return
		end

		local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
		vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		scumShader =  LuaShader(
			{
			  vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
			  fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
			  uniformInt = {
				heightmapTex = 0,
				mapnormalsTex = 1,
				infoTex = 2,
				shadowTex = 3,
				colorheight = 4,
				normalspec = 5,
				distortion = 6,
				},
			uniformFloat = {
				nightFactor = {1,1,1,1},
				--fadeDistance = 3000,
			  },
			},
			DPATname .. "Shader"
		  )
		local shaderCompiled = scumShader:Initialize()
		if not shaderCompiled then
			goodbye("Failed to compile ".. DPATname .." GL4 ")
			return
		end

		scumVBO = makeInstanceVBOTable(
			{
				{id = 1, name = 'worldposradius', size = 4}, -- xpos, ypos, zpos, radius
				{id = 2, name = 'lifeparams', size = 4}, -- lifestart, lifeend, growthrate, unused
			},
			64, -- maxelements
			DPATname .. "VBO" -- name
		)
		if scumVBO == nil then
			goodbye("Failed to create scumVBO")
			return
		end

		local planeVBO, numVertices = makePlaneVBO(1,1,resolution,resolution)
		local planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution,resolution, true)

		scumVBO.vertexVBO = planeVBO
		scumVBO.indexVBO = planeIndexVBO

		scumVBO.VAO = makeVAOandAttach(
			scumVBO.vertexVBO,
			scumVBO.instanceVBO,
			scumVBO.indexVBO)

	end

	local scumRemoveQueue = {} -- maps gameframes to list of scums that will be removed
	local scums = {} -- table of {posx = 123, posz = 123, radius = 123, spawnframe = 0, growthrate = -1.0} -- in elmos per sec
	local numscums = 0
	local scumBins = {} -- a table keyed with (posx / 1024) + 1024 + (posz/1024), values are tables of scumindexes that can overlap that bin

	local sqrt = math.sqrt
	local floor = math.floor
	local clamp = math.clamp
	local spGetGroundHeight = Spring.GetGroundHeight
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local boundary = 32 -- how many elmos closer to the center of the scum than the actual edge of the scum the unit must be to be considered on the scum

	local function GetMapSquareKey(posx, posz)
		if posx < 0 or posz < 0 or posx > mapSizeX or posz > mapSizeZ then return nil end
		return (floor(posx*0.0009765625) * 1024 + floor(posz* 0.0009765625))
	end

	for x= 0, math.ceil(mapSizeX/1024) do
		for z = 0, math.ceil(mapSizeZ/1024) do
			scumBins[x*1024+z] = {}
		end
	end

	local function GetScumCurrentRadius(scum, gf)
		gf = gf or gameFrame
		if scum.growthrate > 0 then
			return clamp((gf - scum.spawnframe) * scum.growthrate, 0, scum.radius)
		else
			return clamp(scum.radius - (gf - scum.spawnframe) *(-1.0 * scum.growthrate), 0, scum.radius)
		end
	end

	-- This checks wether the unit is under any scum
	local function IsPosInScum(unitx,unity, unitz)
		-- out of bounds check, no scum outside of map bounds
		if unitx < 0 or unitz < 0 or unitx > mapSizeX or unitz > mapSizeZ then return nil end
		-- underwater scum doesnt count for hovers, ships
		unity = unity or 1
		if unity > -1 and spGetGroundHeight(unitx, unitz) < 0 then return nil end

		-- Empty bins also return
		local scumBinID = GetMapSquareKey(unitx, unitz)
		if scumBinID == nil or scumBins[scumBinID] == nil then return nil end
		local gf = gameFrame

		for scumID, scum in pairs(scumBins[scumBinID]) do
			local dx = (unitx - scum.posx)
			local dz = (unitz - scum.posz)
			local sqrdistance = (dx*dx + dz*dz)
			local scumradius = scum.radius -- edges are not fully covered, so they shouldn't count,
			if scumradius < 1 then scumradius = 1 end
			if sqrdistance < (scumradius * scumradius) then
				local currentscumradius = GetScumCurrentRadius(scum, gf)
				--Spring.Echo("testing ScumID", scumID, sqrdistance, scumradius, currentscumradius)
				if currentscumradius  - sqrt(sqrdistance) > boundary then
					return scumID
				end
			end
		end
		return nil
	end

	local function UpdateBins(scumID, removeScum)
		local scumTable = scums[scumID]
		if scumTable == nil then
			--Spring.Echo("Tried to update a scumID",scumID,"that no longer exists because it probably shrank to death, remove = ", removeScum)
			return nil
		end

		local posx = scumTable.posx
		local posz = scumTable.posz
		local radius = scumTable.radius

		if removeScum then
			scumTable = nil
			scums[scumID] = nil
		end

		local binID = GetMapSquareKey(posx, posz)
		if binID then scumBins[binID][scumID] = scumTable end
		binID = GetMapSquareKey(posx + radius, posz + radius)
		if binID then scumBins[binID][scumID] = scumTable end
		binID = GetMapSquareKey(posx - radius, posz + radius)
		if binID then scumBins[binID][scumID] = scumTable end
		binID = GetMapSquareKey(posx + radius, posz - radius)
		if binID then scumBins[binID][scumID] = scumTable end
		binID = GetMapSquareKey(posx - radius, posz - radius)
		if binID then scumBins[binID][scumID] = scumTable end
	end

	-- growthrate is in elmos per frame, negative for shrinking scums
	local function AddOrUpdateScum(posx, posy, posz, radius, growthrate, scumID)
		if debugmode then Spring.Echo("AddOrUpdateScum",posx, posy, posz, radius, growthrate, scumID) end
		-- if scumID is supplied, we are updateing an existing scum instance!

		local gf = Spring.GetGameFrame()
		local deathtime
		local scum
		-- thus we need to make a new scum, and register it in our scumBins
		if scumID == nil or scums[scumID] == nil then
			posy = posy or Spring.GetGroundHeight(posx, posz)
			scum = {posx = posx, posz = posz, radius = radius, spawnframe = gf, growthrate = growthrate, scumID = scumID, atmaxsize = false }
			scums[scumID] = scum
			UpdateBins(scumID)
			numscums = numscums + 1
		else-- a scumID is supplied, meaning we just update an existing instance
			scum = scums[scumID]
			-- well then, seems we have to do this after all, when we update a scum, we need to check how long its been alive
			-- this is the nastiest garbage ive ever done
			local currentradius = GetScumCurrentRadius(scum, gf)

			-- always remove from removal queue on update
			for _, removescums in pairs(scumRemoveQueue) do
				removescums[scumID] = nil
			end

			if growthrate > 0 then
				scum.spawnframe = gf - ( currentradius/growthrate)
				-- remove it from the death queue, no matter where it is, cause its 'growing'
			else
				scum.spawnframe = gf - ((scum.radius - currentradius)/ (-1 * growthrate) )
				deathtime = math.floor( gf + (currentradius/(-1 * growthrate)))
			end
			scum.growthrate = growthrate

			if debugmode then Spring.Echo("Updated scum", scumID, "it was", currentradius,"/", scum.radius, "sized, growing at", growthrate) end
		end

		--Spring.Echo(scumID, growthrate, radius, gf)
		if not headless then
			pushElementInstance(
				scumVBO, -- push into this Instance VBO Table
					{scum.posx, scum.posy, scum.posz, scum.radius ,  --
					scum.spawnframe,  scum.growthrate, 0, 0, -- alphastart_alphadecay_heatstart_heatdecay
					},
				scumID, -- this is the key inside the VBO Table, should be unique per unit
				true, -- update existing element
				false) -- noupload, dont use unless you know what you are doing and want to batch push/pop
		end
		if scum.growthrate < 0 then
			if debugmode then Spring.Echo("Removal of scum ID", scumID,"Scheduled for ",  deathtime - gf , "from now" ) end
			if scumRemoveQueue[deathtime] == nil then
				scumRemoveQueue[deathtime] = {}
			end
			scumRemoveQueue[deathtime][scumID] = true
		end

		return scumID
	end

	local lastoverlapframe = 0
	local function UpdateScumOverlaps()
		local overlapped = {} -- keys are scumID, value is that its either overlapped or not.
		local scumRadii = {} -- keys are scumID, value is current radius

		for scumID, scum in pairs(scums) do
			overlapped[scumID] = false
			scumRadii[scumID] = GetScumCurrentRadius(scum)
		end
		local comparisons = 0
		local diag = math.diag

		for binID, scumBin in pairs(scumBins) do
			for bigScumID, bigScum in pairs(scumBin) do -- for each of the scums in the bin
				local bigRadius = scumRadii[bigScumID]

				if not overlapped[bigScumID] and bigRadius > 512 then
					for smallScumID, smallScum in pairs(scumBin) do
						if not overlapped[smallScumID] and scumRadii[smallScumID] < bigRadius then
							comparisons = comparisons + 1
							if diag(bigScum.posx - smallScum.posx, bigScum.posz - smallScum.posz)  < (bigRadius - scumRadii[smallScumID] - 128) then
								overlapped[smallScumID] = true
							end
						end
					end
				end
			end
		end

		local overlapcount = 0
		for scumID, overlaps in pairs(overlapped) do
			if overlaps then overlapcount = overlapcount + 1 end
		end
		if debugmode then
			Spring.Echo(string.format("Of %d scums, %d overlaps found in %d comparisons", numscums, overlapcount, comparisons))
		end

		-- update the VBO
		for i = 0, scumVBO.usedElements -1 do
			local scumID = scumVBO.indextoInstanceID[i + 1]
			scumVBO.instanceData[(i * scumVBO.instanceStep) + 7] = (overlapped[scumID] and optimizeoverlaps) and 1 or 0
		end
		uploadAllElements(scumVBO)
		return overlapcount, comparisons
	end


	local usestencil = false

	function gadget:DrawWorldPreUnit()

		if headless then return end
		if debugmode then
			local mx, my, mb = Spring.GetMouseState()
			local _, coords = Spring.TraceScreenRay(mx, my, true)
			if coords and (IsPosInScum(coords[1], coords[2],coords[3])) then
				Spring.Echo("Inscum", numscums, IsPosInScum(coords[1], coords[2],coords[3]))
			end
		end

		if drawScum and scumVBO.usedElements > 0 then
			if optimizeoverlaps and gameFrame%63 == 0 and lastoverlapframe ~= gameFrame then
				lastoverlapframe = gameFrame
				UpdateScumOverlaps()
			end

			--Spring.Echo(scumVBO.usedElements)
			--glCulling(GL.BACK)
			glCulling(false)
			glDepthTest(GL_LEQUAL)
			--glDepthTest(false)
			--gl.DepthMask(true)
			glTexture(0, '$heightmap')
			glTexture(1, '$normals')
			glTexture(2, "$info")-- Texture file
			glTexture(3, "$shadow")-- Texture file
			glTexture(4, textures[textureresolution].texcolorheight)
			glTexture(5, textures[textureresolution].texnormalspec)
			glTexture(6, textures[textureresolution].texdistortion)-- Texture file
			scumShader:Activate()
			scumShader:SetUniform("nightFactor", nightFactor[1], nightFactor[2], nightFactor[3], nightFactor[4])

			if usestencil then
				gl.StencilTest(true) --https://learnopengl.com/Advanced-OpenGL/Stencil-testing
				gl.DepthTest(true)
				glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon		this to the shader
				glClear(GL_STENCIL_BUFFER_BIT) -- set stencil buffer to 0

				glStencilFunc(GL_NOTEQUAL, 1, 1) -- use NOTEQUAL instead of ALWAYS to ensure that overlapping transparent fragments dont get written multiple times
				glStencilMask(1)
			end

			--scumShader:SetUniform("fadeDistance",disticon * 1000)
			scumVBO.VAO:DrawElements(GL.TRIANGLES,nil,0,scumVBO.usedElements, 0)
			scumShader:Deactivate()
			if usestencil then
				glStencilMask(1)
				glStencilFunc(GL_ALWAYS, 1, 1)
				gl.StencilTest(false)
				glClear(GL_STENCIL_BUFFER_BIT) -- set stencil buffer to 0
				glStencilMask(0)
			end
			for i = 0, 6 do glTexture(i, false) end
			glCulling(false)
			--glDepthTest(false)
		end
	end

	local lastSunChanged = -1
	function gadget:SunChanged() -- Note that map_nightmode.lua gadget has to change sun twice in a single draw frame to update all
		local df = Spring.GetDrawFrame()
		if df == lastSunChanged then return end
		lastSunChanged = df
		if GG['NightFactor'] then
			local altitudefactor = 1.0 --+ (1.0 - WG['NightFactor'].altitude) * 0.5
			nightFactor[1] = GG['NightFactor'].red
			nightFactor[2] = GG['NightFactor'].green
			nightFactor[3] = GG['NightFactor'].blue
			nightFactor[4] = GG['NightFactor'].shadow
		end
	end

	local function RemoveScum(instanceID)
		if debugmode then Spring.Echo("Removing scum", instanceID) end
		if scums[instanceID] then
			numscums = numscums - 1
		end
		UpdateBins(instanceID, true)
		if scumVBO.instanceIDtoIndex[instanceID] and (not headless) then
			popElementInstance(scumVBO, instanceID)
		end
	end

	local function AddRandomScum()
		local posx  = Game.mapSizeX * math.random() * 0.8
		local posz  = Game.mapSizeZ * math.random() * 0.8
		local posy  = Spring.GetGroundHeight(posx, posz)
		local radius = math.random() * 256 + 128
		local growthrate = math.random() * 0.5 -- in elmos per frame
		local scumID = math.random()
		AddOrUpdateScum(posx, posy, posz, radius, growthrate, scumID)
	end

	local scumModulo = 1
	function gadget:GameFrame(n)
		gameFrame = n
		if scumRemoveQueue[n] then
			for scumID, _ in pairs(scumRemoveQueue[n]) do
				RemoveScum(scumID)
			end
			scumRemoveQueue[n] = nil
		end

		if n % 39 == 1 and Script.LuaUI("GadgetRemoveGrass") then
			scumModulo = (scumModulo + 1) % 4
			for scumID, scum in pairs(scums) do
				if ((scumID % 4) == scumModulo) and scum.growthrate > 0 and (not scum.atmaxsize) then
					local currentRadius = GetScumCurrentRadius(scum, n)
					if currentRadius < scum.radius then
						Script.LuaUI.GadgetRemoveGrass(scum.posx, scum.posz, currentRadius * 0.87)
					else
						if debugmode then Spring.Echo("Scum ID", scumID, "reached max size", currentRadius, '>=', scum.radius) end
						scum.atmaxsize = true
					end

				end
			end
		end

		if debugmode then
			-- randomly add a new scum instance
			if n % 2 == 0 then
				if numscums < 300 then
					AddRandomScum()
				else
					for scumID, scumData in pairs(scums) do
						if math.random() < 1.0 / numscums then
							AddOrUpdateScum(nil,nil,nil,nil, math.random() * 1 -0.5, scumID)
							break
						end
					end
				end
			end
		end
	end

	local function HandleScumCreated(cmd, posx, posz, radius, growthrate, gf, scumID)
		--Spring.Echo("Scum Created Unsynced", cmd, posx, posz, radius, growthrate, gf, scumID)
		AddOrUpdateScum(posx, nil, posz, radius, growthrate, scumID)
	end

	local function HandleScumRemoved(cmd, scumID )
		AddOrUpdateScum(nil,nil,nil,nil, -10 * math.abs( scums[scumID].growthrate), scumID)
	end

	local function ScumTextures()
		textureresolution = ((textureresolution == 'low') and 'high') or 'low'
		Spring.Echo("Scum textureresolution set to ", textureresolution)
	end

	local function ScumStats()
		for x= 0, math.ceil(mapSizeX/1024) do
			for z = 0, math.ceil(mapSizeZ/1024) do
				local scumBin = scumBins[GetMapSquareKey(x*1024, z * 1024)]
				local scumCount = 0
				for _ in pairs(scumBin) do scumCount = scumCount + 1 end
				Spring.Echo(string.format("%d scums are in bin %d x %d", scumCount, x, z))
			end
		end
		Spring.Echo(string.format("Total amount of scums on map is %d", numscums))
		local overlapcount, comparisons = UpdateScumOverlaps()
		Spring.Echo("overlapcount", overlapcount, "comparisons=", comparisons)
	end

	local function ScumReloadShader()
		Spring.Echo("ScumReloadShader not implemented")
	end

	local function ScumDrawToggle()
		drawScum = not drawScum
		Spring.Echo("Scum drawing toggled to", drawScum)
	end
	local function ScumOptimizeOverlap()
		optimizeoverlaps = not optimizeoverlaps
		Spring.Echo("Scum optimizeoverlaps toggled to", optimizeoverlaps)
		UpdateScumOverlaps()
	end


	function gadget:Initialize()
		initGL4(shaderConfig, "scum")

		gadgetHandler:AddSyncAction("ScumCreated", HandleScumCreated)
		gadgetHandler:AddSyncAction("ScumRemoved", HandleScumRemoved)

		gadgetHandler:AddChatAction("scumtextures", ScumTextures, "Toggle between texture resolutions")
		gadgetHandler:AddChatAction("scumreloadshader"   , ScumReloadShader, "Reload the Scum Shader")
		gadgetHandler:AddChatAction("scumstats"   	, ScumStats, "Print statistics about scum" )
		gadgetHandler:AddChatAction("scumdraw"   	, ScumDrawToggle, "Toggles drawing the scom" )
		gadgetHandler:AddChatAction("scumoptimizeoverlap"   	, ScumOptimizeOverlap, "Toggles drawing the scom" )
	end

	function gadget:ShutDown()
		gadgetHandler:RemoveSyncAction("ScumCreated")
		gadgetHandler:RemoveSyncAction("ScumRemoved")

		gadgetHandler:RemoveChatAction("scumhighrestextures", ScumTextures)
		gadgetHandler:RemoveChatAction("scumreloadshader"   , ScumReloadShader  )
		gadgetHandler:RemoveChatAction("scumstats"   	, ScumStats )
		gadgetHandler:RemoveChatAction("scumdraw"   	, ScumDrawToggle )
		gadgetHandler:RemoveChatAction("scumoptimizeoverlap"   	, ScumOptimizeOverlap )
	end
end
