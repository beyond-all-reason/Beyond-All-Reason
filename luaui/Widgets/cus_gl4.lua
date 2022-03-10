function widget:GetInfo()
	return {
		name	= "CUS GL4",
		author	= "ivand",
		layer	= 0,
		enabled	= true,
	}
end



-- Beheriths notes

-- Bins / separate VAO and IBO :
	-- Flags (drawpass):
		-- forward opaque + reflections
		-- deferred opaque, all units
	-- Shaders / shaderconfig:
		-- Features
		-- Trees
		-- Regular Units
		-- Tanks
		-- Chickens
		-- Scavengers
	-- Textures:
		-- arm/cor 
		-- 10x chickensets
		-- 5x featuresets
		-- scavengers?
	-- Objects (the VAO)
		-- 8x 8x 16x -> 8192 different VAOs? damn thats horrible
	-- Note that Units and Features cant share a VAO!
	
	-- Can we assume that all BAR units wont have transparency? 
		-- if yes then we can say that forward and deferred can share! 
	-- https://stackoverflow.com/questions/8923174/opengl-vao-best-practices 
	
	
	
-- TODO:
	-- Under construction shader via uniform
	-- normalmapping
	-- chickens
	-- tanktracks
	-- Reflection camera
	-- refraction camera
	-- texture LOD bias of -0.5, maybe adaptive for others 
	-- still extremely perf heavy
	-- separate VAO and IBO for each 'bin' for less heavy updates 
	-- Do alpha units also get drawn into deferred pass? Seems like no, because only flag == 1 is draw into that
	-- todo: dynamically size IBOS instead of using the max of 8192!
	-- TODO: new engine callins needed:
		-- get the number of drawflaggable units (this is kind of gettable already from the API anyway) 
		-- get the number of changed drawFlags
		-- if the number of changed drawflags > log(numdrawflags) then do a full rebuild instead of push-popping
		-- e.g if there are 100 units of a bin in view, then a change of ~ 8 units will trigger a full rebuild?
			-- cant know ahead of time how many per-bin changes this will trigger though
			
	-- TODO: write an engine callin that, instead of the full list of unitdrawflags, only returns the list of units whos drawflags have changed!
		-- reset this 'hashmap' when reading it
		-- also a problem is handling units that died, what 'drawflag' should they get? 
			-- probably 0 
	-- TODO: handle fast rebuilds of the IBO's when large-magnitude changes happen
	-- TODO: faster bitops maybe?
	
	-- TODO: GetTextures() is not the best implementation at the moment
	
	-- NOTE: in general, a function call is about 10x faster than a table lookup.... 
	
	-- TODO: fully blank normal map for non-normal mapped units (or else risk having to write a shader for that bin, which wont even get used
	
	-- GetTextures :
		-- should return array table instead of hash table
			-- fill in unused stuff with 'false' for contiguous array table
			-- index -1 
			-- oddly enough, accessing array tables instead of hash tables is only 25% faster, so the overhead of -1 might not even result in any perf gains
			
		-- Should also get the normalmaps for each unit!
		-- PBR textures:
			-- uniform sampler2D brdfLUT;			//9
			-- uniform sampler2D envLUT;			//10
			-- uniform sampler2D rgbNoise;			//11
			-- uniform samplerCube reflectTex; 		// 7
			
			-- uniform sampler2D losMapTex;	//8 for features out of los maybe?
			
		-- We also need the skybox cubemap for PBR (samplerCube reflectTex)
		-- We also need wrecktex for damaged units!
	-- Create a default 'wrecktex' for features too? 
	
	

-- DONE:
	-- unit uniforms

--inputs

local debugmode = false

local alphaMult = 0.35
local alphaThresholdOpaque = 0.5
local alphaThresholdAlpha  = 0.1
local overrideDrawFlags = {
	[0]  = true , --SO_OPAQUE_FLAG = 1, deferred hack
	[1]  = true , --SO_OPAQUE_FLAG = 1,
	[2]  = true , --SO_ALPHAF_FLAG = 2,
	[4]  = true , --SO_REFLEC_FLAG = 4,
	[8]  = true , --SO_REFRAC_FLAG = 8,
	[16] = true , --SO_SHADOW_FLAG = 16,
}


--implementation
local overrideDrawFlag = 0
for f, e in pairs(overrideDrawFlags) do
	overrideDrawFlag = overrideDrawFlag + f * (e and 1 or 0)
end

local drawBinKeys = {1, 1 + 4, 1 + 8, 2, 2 + 4, 2 + 8, 16} --deferred is handled ad-hoc
local overrideDrawFlagsCombined = {
	[0    ] = overrideDrawFlags[0],
	[1    ] = overrideDrawFlags[1],
	[1 + 4] = overrideDrawFlags[1] and overrideDrawFlags[4],
	[1 + 8] = overrideDrawFlags[1] and overrideDrawFlags[8],
	[2    ] = overrideDrawFlags[2],
	[2 + 4] = overrideDrawFlags[2] and overrideDrawFlags[4],
	[2 + 8] = overrideDrawFlags[2] and overrideDrawFlags[8],
	[16   ] = overrideDrawFlags[16],
}

local overriddenUnits = {}
local processedUnits = {}

-- This is the main table of all the unit drawbins:
-- It is organized like so:
-- unitDrawBins[drawFlag][shaderID][textureKey] = {
	-- textures = {
	   -- 0 = %586:1 -- in this example, its just texture 1 
	-- },
	-- objects = {
	   -- 31357 = true
	   -- 20174 = true
	   -- 29714 = true
	   -- 3024 = true
	   -- 24268 = true
	   -- 5584 = true
	   -- 5374 = true
	   -- 26687 = true
	-- },
	-- VAO = vao,
	-- IBO = ibo,			
	-- objectsArray = {}, -- {index: objectID} 
	-- objectsIndex = {}, -- {objectID : index} (this is needed for efficient removal of items, as RemoveFromSubmission takes an index as arg)
	-- numobjects = 0,  -- a 'pointer to the end' 
-- }
local unitDrawBins = {
	[0    ] = {},	-- deferred opaque
	[1    ] = {},	-- forward  opaque
	[1 + 4] = {},	-- forward  opaque + reflection
	[1 + 8] = {},	-- forward  opaque + refraction
	[2    ] = {},	-- alpha
	[2 + 4] = {},	-- alpha + reflection
	[2 + 8] = {},	-- alpha + refraction
	[16   ] = {},	-- shadow
}


local idToDefId = {}

local processedCounter = 0

local shaders = {}

local vao = nil

local vbo = nil
local ebo = nil
local ibo = nil


local MAX_DRAWN_UNITS = 8192
local objectTypeAttribID = 6

-- setting this to 1 enables the incrementally updated VBOs
-- 0 updates it every frame
-- 2 completely disables draw, so one can measure overhead sans draw
local drawIncrementalMode = 1 -- 
-----------------

local function Bit(p)
	return 2 ^ (p - 1)  -- 1-based indexing
end

-- Typical call:  if hasbit(x, bit(3)) then ...
local function HasBit(x, p)
	return x % (p + p) >= p
end

local math_bit_and = math.bit_and
local function HasAllBits(x, p)
	return math_bit_and(x, p) == p
end

local function SetBit(x, p)
	return HasBit(x, p) and x or x + p
end

local function ClearBit(x, p)
	return HasBit(x, p) and x - p or x
end

-----------------

local function GetShader(drawPass, unitDef)
	return shaders[drawPass]
end


local function SetFixedStatePre(drawPass, shaderID)
	if HasBit(drawPass, 4) then
		gl.ClipDistance(2, true)
	elseif HasBit(drawPass, 8) then
		gl.ClipDistance(2, true)
	end
end

local function SetFixedStatePost(drawPass, shaderID)
	if HasBit(drawPass, 4) then
		gl.ClipDistance(2, false)
	elseif HasBit(drawPass, 8) then
		gl.ClipDistance(2, false)
	end
end

--[[
drawMode:
		case  1: // water reflection
		case  2: // water refraction
		default: // player, (-1) static model, (0) normal rendering
]]--
local function SetShaderUniforms(drawPass, shaderID)
	if drawPass <= 2 then
		gl.UniformInt(gl.GetUniformLocation(shaderID, "drawMode"), 0)
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane2"), 0.0, 0.0, 0.0, 1.0)
	elseif drawPass == 16 then
		--gl.Uniform(gl.GetUniformLocation(shaderID, "alphaCtrl"), alphaThresholdOpaque, 1.0, 0.0, 0.0)
		-- set properly by default
	end

	if HasBit(drawPass, 1) then
		gl.Uniform(gl.GetUniformLocation(shaderID, "alphaCtrl"), alphaThresholdOpaque, 1.0, 0.0, 0.0)
		gl.Uniform(gl.GetUniformLocation(shaderID, "colorMult"), 1.0, 1.0, 1.0, 1.0)
	elseif HasBit(drawPass, 2) then
		gl.Uniform(gl.GetUniformLocation(shaderID, "alphaCtrl"), alphaThresholdAlpha , 1.0, 0.0, 0.0)
		gl.Uniform(gl.GetUniformLocation(shaderID, "colorMult"), 1.0, 1.0, 1.0, alphaMult)
	elseif HasBit(drawPass, 4) then
		gl.UniformInt(gl.GetUniformLocation(shaderID, "drawMode"), 1)
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane2"), 0.0, 1.0, 0.0, 0.0)
	elseif HasBit(drawPass, 8) then
		gl.UniformInt(gl.GetUniformLocation(shaderID, "drawMode"), 2)
		gl.Uniform(gl.GetUniformLocation(shaderID, "clipPlane2"), 0.0, -1.0, 0.0, 0.0)
	end
end

local gettexturescalls = 0

-- Order of textures in shader:
	-- uniform sampler2D texture1;			//0
	-- uniform sampler2D texture2;			//1
	-- uniform sampler2D normalTex;		//2

	-- uniform sampler2D texture1w;		//3
	-- uniform sampler2D texture2w;		//4
	-- uniform sampler2D normalTexw;		//5

	-- uniform sampler2DShadow shadowTex;	//6
	-- uniform samplerCube reflectTex;		//7
	
	-- uniform sampler2D losMapTex;	//8
	
	-- uniform sampler2D brdfLUT;			//9
	-- uniform sampler2D envLUT;			//10
	-- uniform sampler2D rgbNoise;			//11

local function GetTextures(drawPass, unitDef)
	gettexturescalls = (gettexturescalls + 1 ) % (2^20)
	if drawPass == 16 then
		return {
			[0] = string.format("%%%s:%i", unitDef, 1), --tex2 only
		}
	else
		return {
			[0] = string.format("%%%s:%i", unitDef, 0),
			[1] = string.format("%%%s:%i", unitDef, 1),
			[2] = "$shadow",
			[3] = "$reflection",
		}
	end
end

local MAX_TEX_ID = 131072 --should be enough
--- Hashes a table of textures to a unique integer
-- @param textures a table of {bindposition:texture}
-- @return a unique hash for binning
local function GetTexturesKey(textures)
	local cs = 0
	for bindPosition, tex in pairs(textures) do
		local texInfo = gl.TextureInfo(tex)
		
		local texInfoid = 0
		if texInfo and texInfo.id then texInfoid = texInfo.id end 
		cs = cs + (texInfoid or 0) + bindPosition * MAX_TEX_ID
	end

	return cs
end

-----------------

local asssigncalls = 0

--- Assigns a unit to a material bin
-- This function gets called from AddUnit every time a unit enters drawrange (or gets its flags changed)
-- @param unitID The unitID of the unit
-- @param unitDefID Which unitdef it belongs to 
-- @param flag which drawflags it has
-- @param shader which shader should be assigned to it
-- @param textures A table of {bindPosition:texturename} for this unit
-- @param texKey A unique key hashed from the textures names, bindpositions
local function AsssignUnitToBin(unitID, unitDefID, flag, shader, textures, texKey)
	asssigncalls = (asssigncalls + 1 ) % (2^20)
	shader = shader or GetShader(flag, unitDefID)
	textures = textures or GetTextures(flag, unitDefID)
	texKey = texKey or GetTexturesKey(textures)
	
	local unitDrawBinsFlag = unitDrawBins[flag]
	if unitDrawBinsFlag[shader] == nil then
		unitDrawBinsFlag[shader] = {}
	end
	local unitDrawBinsFlagShader = unitDrawBinsFlag[shader]

	if unitDrawBinsFlagShader[texKey] == nil then
		local mybinVAO = gl.GetVAO()
		local mybinIBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
		
		if (mybinIBO == nil) or (mybinVAO == nil) then 
			Spring.Echo("Failed to allocate IBO or VAO for CUS GL4", mybinIBO, mybinVAO)
			Spring.Debug.TraceFullEcho()
			widgetHandler:RemoveWidget()
		end
		
		mybinIBO:Define(MAX_DRAWN_UNITS, {
			{id = 6, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		})
		
		mybinVAO:AttachVertexBuffer(vbo)
		mybinVAO:AttachIndexBuffer(ebo)
		mybinVAO:AttachInstanceBuffer(mybinIBO)
	
		unitDrawBinsFlagShader[texKey] = {
			textures = textures, -- hashmap of textures for this unit
			IBO = mybinIBO, -- my own IBO, for incrementing
			VAO = mybinVAO, -- my own VBO, for incremental updating
			objectsArray = {}, -- {index: objectID} 
			objectsIndex = {}, -- {objectID : index} (this is needed for efficient removal of items, as RemoveFromSubmission takes an index as arg)
			numobjects = 0,  -- a 'pointer to the end' 
		}
	end
	
	local unitDrawBinsFlagShaderTexKey = unitDrawBinsFlagShader[texKey]
	
	if unitDrawBinsFlagShaderTexKey.objectsIndex[unitID] then 
		Spring.Echo("Trying to add a unit to a bin that is already in it!")
	end
	
	
	local numobjects = unitDrawBinsFlagShaderTexKey.numobjects
	unitDrawBinsFlagShaderTexKey.IBO:InstanceDataFromUnitIDs(unitID, objectTypeAttribID, numobjects)
	unitDrawBinsFlagShaderTexKey.VAO:AddUnitsToSubmission   (unitID)
	
	numobjects = numobjects + 1 
	unitDrawBinsFlagShaderTexKey.numobjects = numobjects
	unitDrawBinsFlagShaderTexKey.objectsArray[numobjects] = unitID
	unitDrawBinsFlagShaderTexKey.objectsIndex[unitID    ] = numobjects
	
	if debugmode and flag == 0 then 
		Spring.Echo("AsssignUnitToBin", unitID, unitDefID, texKey,shader,flag, numobjects)
		local objids = "objectsArray "
		for k,v in pairs(unitDrawBinsFlagShaderTexKey.objectsArray) do 
			objids = objids .. tostring(k) .. ":" ..tostring(v) .. " " 
		end
		Spring.Echo(objids) 
	end
end


local function AddUnit(unitID, drawFlag)
	if (drawFlag >= 128) then --icon
		return
	end
	if (drawFlag >=  32) then --far tex
		return
	end

	local unitDefID = Spring.GetUnitDefID(unitID)
	idToDefId[unitID] = unitDefID

	--Spring.Echo(unitID, UnitDefs[unitDefID].name)

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]

		if HasAllBits(drawFlag, flag) then
			if overrideDrawFlagsCombined[flag] then
				AsssignUnitToBin(unitID, unitDefID, flag)
				if flag == 1 then
					AsssignUnitToBin(unitID, unitDefID, 0) --deferred hack
				end
			end
		end
	end

	Spring.SetUnitEngineDrawMask(unitID, 255 - overrideDrawFlag) -- ~overrideDrawFlag & 255
	overriddenUnits[unitID] = drawFlag
	--overriddenUnits[unitID] = overrideDrawFlag
end

local function RemoveUnitFromBin(unitID, unitDefID, texKey, shader, flag)
	shader = shader or GetShader(flag, unitDefID)
	textures = textures or GetTextures(flag, unitDefID)
	texKey = texKey or GetTexturesKey(textures)
	if unitDrawBins[flag][shader] then
		if unitDrawBins[flag][shader][texKey] then
			
			-- do the pop magic
			local unitDrawBinsFlagShaderTexKey = unitDrawBins[flag][shader][texKey]
			local objectIndex = unitDrawBinsFlagShaderTexKey.objectsIndex[unitID]
			
			--if flag == 0 then Spring.Echo("RemoveUnitFromBin", unitID, unitDefID, texKey,shader,flag,objectIndex) end
			if objectIndex == nil then 
				--Spring.Echo("Remove failed")
				return 
				end
			local numobjects = unitDrawBinsFlagShaderTexKey.numobjects
			
			unitDrawBinsFlagShaderTexKey.VAO:RemoveFromSubmission(objectIndex - 1) -- do we become out of order?
			if objectIndex == numobjects then -- last element
				unitDrawBinsFlagShaderTexKey.objectsIndex[unitID    ] = nil
				unitDrawBinsFlagShaderTexKey.objectsArray[numobjects] = nil
				unitDrawBinsFlagShaderTexKey.numobjects = numobjects -1 
			else
				local unitIDatEnd = unitDrawBinsFlagShaderTexKey.objectsArray[numobjects]
				if debugmode and flag == 0 then Spring.Echo("Moving", unitIDatEnd, "from", numobjects, " to", objectIndex, "while removing", unitID) end
				unitDrawBinsFlagShaderTexKey.objectsIndex[unitID     ] = nil -- pop back
				unitDrawBinsFlagShaderTexKey.objectsIndex[unitIDatEnd] = objectIndex -- bring the last unitID to to this one
				if Spring.ValidUnitID(unitIDatEnd) == true and Spring.GetUnitIsDead(unitIDatEnd) ~= true then
					unitDrawBinsFlagShaderTexKey.IBO:InstanceDataFromUnitIDs(unitIDatEnd, objectTypeAttribID, objectIndex - 1)
				else
					Spring.Echo("Tried to remove invalid unitID", unitID)
				end
				unitDrawBinsFlagShaderTexKey.objectsArray[numobjects ] = nil -- pop back
				unitDrawBinsFlagShaderTexKey.objectsArray[objectIndex] = unitIDatEnd -- Bring the last unitID here 
				unitDrawBinsFlagShaderTexKey.numobjects = numobjects -1 
			end
		end
	end
end

local function UpdateUnit(unitID, drawFlag)
	if (drawFlag >= 128) then --icon
		return
	end
	if (drawFlag >=  32) then --far tex
		return
	end

	local unitDefID = idToDefId[unitID]

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]

		local hasFlagOld = HasAllBits(overriddenUnits[unitID], flag)
		local hasFlagNew = HasAllBits(               drawFlag, flag)

		if hasFlagOld ~= hasFlagNew and overrideDrawFlagsCombined[flag] then
			local shader = GetShader(flag, unitDefID)
			local textures = GetTextures(flag, unitDefID)
			local texKey  = GetTexturesKey(textures)

			if hasFlagOld then --had this flag, but no longer have
				RemoveUnitFromBin(unitID, unitDefID, texKey, shader, flag)
				if flag == 1 then
					RemoveUnitFromBin(unitID, unitDefID, texKey, nil, 0)
				end
			end
			if hasFlagNew then -- didn't have this flag, but now has
				AsssignUnitToBin(unitID, unitDefID, flag, shader, textures, texKey)
				if flag == 1 then
					AsssignUnitToBin(unitID, unitDefID, 0, nil, textures, texKey) --deferred
				end
			end
		end
	end

	overriddenUnits[unitID] = drawFlag
end

local function RemoveUnit(unitID)
	--remove the object from every bin and table

	local unitDefID = idToDefId[unitID]

	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]

		if overrideDrawFlagsCombined[flag] then
			local shader = GetShader(flag, unitDefID)
			local textures = GetTextures(flag, unitDefID)
			local texKey  = GetTexturesKey(textures)
			RemoveUnitFromBin(unitID, unitDefID, texKey, shader, flag)
			if flag == 1 then
				RemoveUnitFromBin(unitID, unitDefID, texKey, nil, 0)
			end
		end
	end

	idToDefId[unitID] = nil
	overriddenUnits[unitID] = nil
	processedUnits[unitID] = nil

	Spring.SetUnitEngineDrawMask(unitID, 255)
	--Spring.Debug.TableEcho(unitDrawBins)
end

local function ProcessUnits(units, drawFlags)
	processedCounter = (processedCounter + 1) % (2 ^ 16)

	for i = 1, #units do
		local unitID = units[i]
		local drawFlag = drawFlags[i]

		if overriddenUnits[unitID] == nil then --object was not seen
			AddUnit(unitID, drawFlag)
		elseif overriddenUnits[unitID] ~= drawFlag then --flags have changed
			UpdateUnit(unitID, drawFlag)
		end
		processedUnits[unitID] = processedCounter
	end

	for unitID, _ in pairs(overriddenUnits) do
		if processedUnits[unitID] ~= processedCounter then --object was not updated thus was removed
			RemoveUnit(unitID)
		end
	end
end

local unitIDscache = {}


local function ExecuteDrawPass(drawPass)
	--defersubmissionupdate = (defersubmissionupdate + 1) % 10;
	local batches = 0
	local units = 0
	for shaderId, data in pairs(unitDrawBins[drawPass]) do
		for _, texAndObj in pairs(data) do
		
			if drawIncrementalMode == 1 then 
				if texAndObj.numobjects > 0  then 
					batches = batches + 1
					units = units + texAndObj.numobjects
					local mybinVAO = texAndObj.VAO
					for bindPosition, tex in pairs(texAndObj.textures) do
						gl.Texture(bindPosition, tex)
					end
					
					SetFixedStatePre(drawPass, shaderId)
					
					gl.UseShader(shaderId)
					SetShaderUniforms(drawPass, shaderId)
					
					mybinVAO:Submit()
					gl.UseShader(0)

					SetFixedStatePost(drawPass, shaderId)

					for bindPosition, tex in pairs(texAndObj.textures) do
						gl.Texture(bindPosition, false)
					end
				end
					
			elseif drawIncrementalMode == 0 then 
				batches = batches + 1
				
				for bindPosition, tex in pairs(texAndObj.textures) do
					gl.Texture(bindPosition, tex)
				end
				
				SetFixedStatePre(drawPass, shaderId)
				
				for unitID, _ in pairs(texAndObj.objectsIndex) do
					unitIDscache[#unitIDscache + 1] = unitID
					units = units + 1 
				end
				
				ibo:InstanceDataFromUnitIDs(unitIDscache, 6) --id = 6, name = "instData"
				vao:ClearSubmission()
				vao:AddUnitsToSubmission(unitIDscache)
				
				for i=1, #unitIDscache do
					unitIDscache[i] = nil
				end
				
				gl.UseShader(shaderId)
				SetShaderUniforms(drawPass, shaderId)
				
				vao:Submit()
				gl.UseShader(0)

				SetFixedStatePost(drawPass, shaderId)
				

				for bindPosition, tex in pairs(texAndObj.textures) do
					gl.Texture(bindPosition, false)
				end
			end
		end
	end
	return batches, units
end

function widget:Initialize()
	local fwdShader = gl.CreateShader({
		vertex   = VFS.LoadFile("luaui/Widgets/Shaders/ModelShaderGL4.vert.glsl"),
		fragment = VFS.LoadFile("luaui/Widgets/Shaders/ModelShaderGL4.frag.glsl"),
		definitions = table.concat({
			"#version 430 core",
			"#define USE_SHADOWS 1",
			"#define DEFERRED_MODE 0",
		}, "\n") .. "\n",
	})
	Spring.Echo(gl.GetShaderLog())
	if fwdShader == nil then
		widgetHandler:RemoveWidget()
	end

	local dfrShader = gl.CreateShader({
		vertex   = VFS.LoadFile("luaui/Widgets/Shaders/ModelShaderGL4.vert.glsl"),
		fragment = VFS.LoadFile("luaui/Widgets/Shaders/ModelShaderGL4.frag.glsl"),
		definitions = table.concat({
			"#version 430 core",
			"#define USE_SHADOWS 1",
			"#define DEFERRED_MODE 1",
			"#define GBUFFER_NORMTEX_IDX 0",
			"#define GBUFFER_DIFFTEX_IDX 1",
			"#define GBUFFER_SPECTEX_IDX 2",
			"#define GBUFFER_EMITTEX_IDX 3",
			"#define GBUFFER_MISCTEX_IDX 4",
			"#define GBUFFER_ZVALTEX_IDX 5",
		}, "\n") .. "\n",
	})

	Spring.Echo(gl.GetShaderLog())
	if dfrShader == nil then
		widgetHandler:RemoveWidget()
	end


	local shdShader = gl.CreateShader({
		vertex   = VFS.LoadFile("luaui/Widgets/Shaders/ModelShaderShadowGL4.vert.glsl"),
		fragment = VFS.LoadFile("luaui/Widgets/Shaders/ModelShaderShadowGL4.frag.glsl"),
		definitions = table.concat({
			"#version 430 core",
		}, "\n") .. "\n",
	})

	Spring.Echo(gl.GetShaderLog())
	if shdShader == nil then
		widgetHandler:RemoveWidget()
	end


	for k = 1, #drawBinKeys do
		local flag = drawBinKeys[k]
		shaders[flag] = fwdShader
	end
	shaders[0 ] = dfrShader
	shaders[16] = shdShader

	vao = gl.GetVAO()
	if vao == nil then
		widgetHandler:RemoveWidget()
	end

	vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	ebo = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	ibo = gl.GetVBO(GL.ARRAY_BUFFER, true)

	if ((vbo == nil) or (ebo == nil) or (ibo == nil)) then
		widgetHandler:RemoveWidget()
	end

	ibo:Define(MAX_DRAWN_UNITS, {
		{id = 6, name = "instData", type = GL.UNSIGNED_INT, size = 4},
	})

	vbo:ModelsVBO()
	ebo:ModelsVBO()

	vao:AttachVertexBuffer(vbo)
	vao:AttachIndexBuffer(ebo)
	vao:AttachInstanceBuffer(ibo)

	widget:Update()
end

function widget:Shutdown()
	--Spring.Debug.TableEcho(unitDrawBins)

	for unitID, _ in pairs(overriddenUnits) do
		RemoveUnit(unitID)
	end

	vbo = nil
	ebo = nil
	ibo = nil

	vao = nil
	unitDrawBins = nil
	
	gl.DeleteShader(shaders[0]) -- deferred
	gl.DeleteShader(shaders[1]) -- forward
	gl.DeleteShader(shaders[16]) -- shadow
end

local updateframe = 0
function widget:Update()
	
	updateframe = (updateframe + 1) % 1
	
	if updateframe == 0 then 
		-- this call has a massive mem load, at 1k units at 225 fps, its 7mb/sec, e.g. for each unit each frame, its 32 bytes alloc/dealloc
		-- which isnt all that bad, but still far from optimal
		-- it is, however, not that bad CPU wise
		local units, drawFlags = Spring.GetRenderUnits(overrideDrawFlag, true) 
		--units, drawFlags = Spring.GetRenderUnits(overrideDrawFlag, true)
		--Spring.Echo("#units", #units, overrideDrawFlag)
		ProcessUnits(units, drawFlags)
		--Spring.Debug.TableEcho(unitDrawBins)
	end
	
end

function widget:GameFrame(n)
	
	if (n%60) == 0 then 
		Spring.Echo(Spring.GetGameFrame(), "processedCounter", processedCounter, asssigncalls,gettexturescalls)
	end
end

function widget:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	local drawPass = 1 --opaque

	if deferredPass then
		drawPass = 0
	end

	if drawReflection then
		drawPass = 1 + 4
	end

	if drawRefraction then
		drawPass = 1 + 8
	end

	local batches, units = ExecuteDrawPass(drawPass)
	--Spring.Echo("drawPass", drawPass, "batches", batches, "units", units)
end

function widget:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	local drawPass = 2 --alpha

	if drawReflection then
		drawPass = 2 + 4
	end

	if drawRefraction then
		drawPass = 2 + 8
	end

	local batches, units = ExecuteDrawPass(drawPass)
	--Spring.Echo("drawPass", drawPass, "batches", batches, "units", units)
	
end

function widget:DrawShadowUnitsLua()
	ExecuteDrawPass(16)
end