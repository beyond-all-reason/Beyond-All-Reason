function widget:GetInfo()
	return {
		name	= "CUS GL4",
		author	= "ivand",
		layer	= 0,
		enabled	= true,
	}
end

--inputs
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

local function GetTextures(drawPass, unitDef)
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
local function GetTexturesKey(textures)
	local cs = 0
	for bp, tex in pairs(textures) do
		local texInfo = gl.TextureInfo(tex) or {}
		cs = cs + (texInfo.id or 0) + bp * MAX_TEX_ID
	end

	return cs
end

-----------------

local function AsssignUnitToBin(unitID, unitDefID, flag, shader, textures, texKey)
	shader = shader or GetShader(flag, unitDefID)
	textures = textures or GetTextures(flag, unitDefID)
	texKey = texKey or GetTexturesKey(textures)

	local unitDrawBinsFlag = unitDrawBins[flag]
	if unitDrawBinsFlag[shader] == nil then
		unitDrawBinsFlag[shader] = {}
	end
	local unitDrawBinsFlagShader = unitDrawBinsFlag[shader]

	if unitDrawBinsFlagShader[texKey] == nil then
		unitDrawBinsFlagShader[texKey] = {
			textures = textures
		}
	end
	local unitDrawBinsFlagShaderTexKey = unitDrawBinsFlagShader[texKey]

	if unitDrawBinsFlagShaderTexKey.objects == nil then
		unitDrawBinsFlagShaderTexKey.objects = {}
	end
	local unitDrawBinsFlagShaderTexKeyObjs = unitDrawBinsFlagShaderTexKey.objects

	unitDrawBinsFlagShaderTexKeyObjs[unitID] = true
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
			if unitDrawBins[flag][shader][texKey].objects then
				unitDrawBins[flag][shader][texKey].objects[unitID] = nil
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

local unitIDs = {}
local function ExecuteDrawPass(drawPass)
	for shaderId, data in pairs(unitDrawBins[drawPass]) do
		for _, texAndObj in pairs(data) do
			for bp, tex in pairs(texAndObj.textures) do
				gl.Texture(bp, tex)
			end

			unitIDs = {}
			for unitID, _ in pairs(texAndObj.objects) do
				unitIDs[#unitIDs + 1] = unitID
			end

			SetFixedStatePre(drawPass, shaderId)

			ibo:InstanceDataFromUnitIDs(unitIDs, 6) --id = 6, name = "instData"
			vao:ClearSubmission()
			vao:AddUnitsToSubmission(unitIDs)

			gl.UseShader(shaderId)
			SetShaderUniforms(drawPass, shaderId)
			vao:Submit()
			gl.UseShader(0)

			SetFixedStatePost(drawPass, shaderId)


			for bp, tex in pairs(texAndObj.textures) do
				gl.Texture(bp, false)
			end
		end
	end
end

local MAX_DRAWN_UNITS = 8192
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
	Spring.Debug.TableEcho(unitDrawBins)

	for unitID, _ in pairs(overriddenUnits) do
		RemoveUnit(unitID)
	end

	vbo = nil
	ebo = nil
	ibo = nil

	vao = nil

	gl.DeleteShader(shaders[0])
	gl.DeleteShader(shaders[1])
end

function widget:Update()
	local units, drawFlags = Spring.GetRenderUnits(overrideDrawFlag, true)
	--Spring.Echo("#units", #units, overrideDrawFlag)
	ProcessUnits(units, drawFlags)
	--Spring.Debug.TableEcho(unitDrawBins)
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

	--Spring.Echo("drawPass", drawPass)
	ExecuteDrawPass(drawPass)
end

function widget:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	local drawPass = 2 --alpha

	if drawReflection then
		drawPass = 2 + 4
	end

	if drawRefraction then
		drawPass = 2 + 8
	end

	--Spring.Echo("drawPass", drawPass)
	ExecuteDrawPass(drawPass)
end

function widget:DrawShadowUnitsLua()
	ExecuteDrawPass(16)
end