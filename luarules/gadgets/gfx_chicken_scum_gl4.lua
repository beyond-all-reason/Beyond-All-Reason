function gadget:GetInfo()
	return {
		name = "Chicken Scum GL4",
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
	local scumSpawnerIDs = {}
	
	
	local scums = {} -- {posx = 123, posz = 123, radius = 123, spawnframe = 0, growthrate = 1.0} -- in elmos per sec
	local scumIndex = 0
	local numscums = 0
	local scumBins = {} -- a table keyed with (posx / 1024) + 1024 + (posz/1024), values are tables of scumindexes that can overlap that bin
	local scumRemoveQueue = {} -- maps gameframes to list of scums that will be removed
	
	local sqrt = math.sqrt
	local floor = math.floor
	local max = math.max
	local min = math.min
	local spGetGroundHeight = Spring.GetGroundHeight 
	local spGetGameFrame = Spring.GetGameFrame
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local initialized = false
	local boundary = 128 -- how many elmos closer to the center of the scum than the actual edge of the scum the unit must be to be considered on the scum
	
	local function GetScumCurrentRadius(scum, gf)
		gf = gf or spGetGameFrame()
		if scum.growthrate > 0 then 
			return max(0, min(scum.radius, (gf - scum.spawnframe) * scum.growthrate))
		else
			return min(scum.radius, max(0,scum.radius - (gf - scum.spawnframe) *(-1.0 * scum.growthrate)) )
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
		scumSpawnerIDs[UnitDefNames['roost'].id] = {radius = 384, growthrate = 0.5}
		scumSpawnerIDs[UnitDefNames['chickend2'].id] = {radius = 384, growthrate = 0.5}
		scumSpawnerIDs[UnitDefNames['chickend1'].id] = {radius = 384, growthrate = 0.5}
		
		for x= 0, math.ceil(mapSizeX/1024) do 
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
				--Spring.Echo("testing ScumID", scumID, sqrdistance, scumradius, currentscumradius)
				if currentscumradius  - sqrt(sqrdistance) > boundary then 
					return scumID
				end
			end
		end
		return nil
	end

	GG.IsPosInChickenScum = IsPosInScum --(x,y,z)
	
	
	local function UpdateBins(scumID, removeScum)
		local scumTable = scums[scumID]
		if scumTable == nil then 
			Spring.Echo("Tried to update a scumID",scumID,"that no longer exists because it probably shrank to death, remove = ", removeScum)
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
		
		return scumID
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if scumSpawnerIDs[unitDefID] then 
			local px, py, pz = Spring.GetUnitPosition(unitID)
			local gf = Spring.GetGameFrame()
			
			local scumID = AddOrUpdateScum(px, py, pz, scumSpawnerIDs[unitDefID].radius, scumSpawnerIDs[unitDefID].growthrate, unitID)
			local scum = scums[scumID]
			SendToUnsynced("ScumCreated",scum.posx, scum.posz, scum.radius, scum.growthrate, gf, scumID)
			--Spring.Echo("Scum Created Synced")
		end
	end
	

	function gadget:UnitDestroyed(unitID, unitDefID)
		if scumSpawnerIDs[unitDefID] and scums[unitID] then 
			AddOrUpdateScum(nil,nil,nil,nil, -10 * math.abs(scums[unitID].growthrate), unitID)
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
				UpdateBins(instanceID, true)
			end
			scumRemoveQueue[n] = nil
		end
	end
else 


	local texcolorheight = "LuaUI/images/alien_guts_colorheight.dds"
	local texnormalspec =  "LuaUI/images/alien_guts_normalspec.dds"
	local texdistortion =  "LuaUI/images/lavadistortion.png"
	local resolution = 32

	local scumVBO = nil
	local scumShader = nil
	local luaShaderDir = "LuaUI/gadgets/Include/"
	local debugmode = false

	local glTexture = gl.Texture
	local glCulling = gl.Culling
	local glDepthTest = gl.DepthTest
	local GL_BACK = GL.BACK
	local GL_LEQUAL = GL.LEQUAL
	local glStencilFunc         = gl.StencilFunc
	local glStencilOp           = gl.StencilOp
	local glStencilTest         = gl.StencilTest
	local glStencilMask         = gl.StencilMask
	local glDepthTest           = gl.DepthTest
	local glClear               = gl.Clear
	local GL_ALWAYS             = GL.ALWAYS
	local GL_NOTEQUAL           = GL.NOTEQUAL
	local GL_KEEP               = 0x1E00 --GL.KEEP
	local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
	local GL_REPLACE            = GL.REPLACE
	local GL_POINTS				= GL.POINTS

	local shaderConfig = {
		SPECULAREXPONENT = 64.0,  -- the specular exponent of the lava plane
		SPECULARSTRENGTH = 1.0, -- The peak brightness of specular highlights
		
		LOSDARKNESS = 0.5, -- how much to darken the out-of-los areas of the lava plane
		SHADOWSTRENGTH = 0.4, -- how much light a shadowed fragment can recieve
		CREEPTEXREZ = 0.003,
		JIGGLEAMPLITUDE = 0.2,
	}

	---- GL4 Backend Stuff----

	local luaShaderDir = "LuaUI/widgets/Include/"
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
	layout (location = 2) in vec4 lifeparams; // lifestart, growthrate, unused, unused;

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
		vec2 uvhm = heighmapUVatWorldPos(mapPos.xz);
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
		vec4 texdistort2 = texture(distortion, v_worldUV.xz * CREEPTEXREZ * 2.0 + vec2(sin(time * 0.0002))) * 0.5 + 0.5;
		
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
		
		// do hermitian interpolation on 0.1 of this shit
		
		
		// darken outside

		fragColor.a = 1.0 - radialScum*3;
		fragColor.rgb *= ((fragColor.a  -0.3)*2.0) ;
		
		

	}
	]]

	local function goodbye(reason)
	  Spring.Echo("Scum GL4 gadget exiting with reason: "..reason)
	  gadgetHandler:RemoveGadget()
	end

	local function initGL4(shaderConfig, DPATname)
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

	local scumIndex = 0
	local scumRemoveQueue = {} -- maps gameframes to list of scums that will be removed
	local scums = {} -- table of {posx = 123, posz = 123, radius = 123, spawnframe = 0, growthrate = -1.0} -- in elmos per sec
	local numscums = 0
	local scumBins = {} -- a table keyed with (posx / 1024) + 1024 + (posz/1024), values are tables of scumindexes that can overlap that bin

	local sqrt = math.sqrt
	local floor = math.floor
	local max = math.max
	local min = math.min
	local spGetGroundHeight = Spring.GetGroundHeight 
	local spGetGameFrame = Spring.GetGameFrame
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
		gf = gf or Spring.GetGameFrame()
		if scum.growthrate > 0 then 
			return max(0, min(scum.radius, (gf - scum.spawnframe) * scum.growthrate))
		else
			return min(scum.radius, max(0,scum.radius - (gf - scum.spawnframe) *(-1.0 * scum.growthrate)) )
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
			Spring.Echo("Tried to update a scumID",scumID,"that no longer exists because it probably shrank to death, remove = ", removeScum)
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
		pushElementInstance(
			scumVBO, -- push into this Instance VBO Table
				{scum.posx, scum.posy, scum.posz, scum.radius ,  -- 
				scum.spawnframe,  scum.growthrate, 0, 0, -- alphastart_alphadecay_heatstart_heatdecay
				},
			scumID, -- this is the key inside the VBO Table, should be unique per unit
			true, -- update existing element
			false) -- noupload, dont use unless you know what you are doing and want to batch push/pop
			
		if scum.growthrate < 0 then 
			if debugmode then Spring.Echo("Removal of scum ID", scumID,"Scheduled for ",  deathtime - gf , "from now" ) end 
			if scumRemoveQueue[deathtime] == nil then 
				scumRemoveQueue[deathtime] = {}
			end
			scumRemoveQueue[deathtime][scumID] = true
		end
		
		return scumID
	end

	local usestencil = false

	function gadget:DrawWorldPreUnit()
		if debugmode then 
			local mx, my, mb = Spring.GetMouseState()
			local _, coords = Spring.TraceScreenRay(mx, my, true)
			local posx  = Game.mapSizeX * math.random() * 1
			local posz  = Game.mapSizeZ * math.random() * 1
			local posy  = Spring.GetGroundHeight(posx, posz)
			if coords and (IsPosInScum(coords[1], coords[2],coords[3])) then 
				Spring.Echo("Inscum", numscums, IsPosInScum(coords[1], coords[2],coords[3])) 
			end
		end
		if scumVBO.usedElements > 0 then
			local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
			--Spring.Echo(scumVBO.usedElements)
			--glCulling(GL_BACK)
			glCulling(false)
			glDepthTest(GL_LEQUAL)
			--glDepthTest(false)
			--gl.DepthMask(true)
			glTexture(0, '$heightmap')
			glTexture(1, '$normals')
			glTexture(2, "$info")-- Texture file
			glTexture(3, "$shadow")-- Texture file
			glTexture(4, texcolorheight)
			glTexture(5, texnormalspec)
			glTexture(6, texdistortion)-- Texture file
			scumShader:Activate()
			
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

	local function RemoveScum(instanceID)
		if debugmode then Spring.Echo("Removing scum", instanceID) end
		if scums[instanceID] then 
			numscums = numscums - 1
		end
		UpdateBins(instanceID, true)
		if scumVBO.instanceIDtoIndex[instanceID] then
			popElementInstance(scumVBO, instanceID)
		end
	end

	local function AddRandomScum()
		local posx  = Game.mapSizeX * math.random() * 0.8
		local posz  = Game.mapSizeZ * math.random() * 0.8
		local posy  = Spring.GetGroundHeight(posx, posz)
		local radius = math.random() * 256 + 128
		local lifetime = math.random() * 1025
		local deathtime = lifetime * 2
		local growthrate = math.random() * 0.5 -- in elmos per frame
		AddOrUpdateScum(
				posx,
				posy,
				posz,
				radius,
				growthrate
				)
	end

	function gadget:GameFrame(n)
		if scumRemoveQueue[n] then 
			for scumID, _ in pairs(scumRemoveQueue[n]) do 
				RemoveScum(scumID)
			end
			scumRemoveQueue[n] = nil
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

	function gadget:Initialize()
		--shaderConfig.MAXVERTICES = 4
		initGL4(shaderConfig, "scum")
		
		gadgetHandler:AddSyncAction("ScumCreated", HandleScumCreated)
		gadgetHandler:AddSyncAction("ScumRemoved", HandleScumRemoved)
		
	end

	function gadget:ShutDown()
		gadgetHandler:RemoveSyncAction("ScumCreated")
		gadgetHandler:RemoveSyncAction("ScumRemoved")
	end
end
