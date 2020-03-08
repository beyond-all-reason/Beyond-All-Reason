-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  author:  jK
--
--  Copyright (C) 2008,2009,2010.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "CustomUnitShaders",
		desc      = "allows to override the engine unit and feature shaders",
		author    = "jK, gajop, ivand",
		date      = "2008,2009,2010,2016, 2019",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Synced
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then
	return
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Unsynced
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gl.CreateShader) then
	Spring.Log("CUS", LOG.WARNING, "Shaders not supported, disabling")
	return false
end

-----------------------------------------------------------------
-- File path Constants
-----------------------------------------------------------------

local MATERIALS_DIR = "Materials/"
local LUASHADER_DIR = "LuaRules/Gadgets/Include/"
local DEFAULT_VERSION = "#version 150 compatibility"

-----------------------------------------------------------------
-- Includes and classes loading
-----------------------------------------------------------------

VFS.Include("LuaRules/Utilities/UnitRendering.lua", nil, VFS.MOD .. VFS.BASE)
local LuaShader = VFS.Include(LUASHADER_DIR .. "LuaShader.lua")

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------

--these two have no callin to detect change of state
local advShading
local shadows

local bug3734wa = false

local sunChanged = false
local optionsChanged = true --just in case

local registeredOptions = {}

local idToDefID = {}

--- Main data structures:
-- rendering.drawList[objectID] = matSrc
-- rendering.materialInfos[objectDefID] = {matName, name = param, name1 = param1}
-- rendering.bufMaterials[objectDefID] = rendering.spGetMaterial("opaque") / luaMat
-- rendering.bufShadowMaterials[objectDefID] = rendering.spGetMaterial("shadow") / luaMat
-- rendering.materialDefs[matName] = matSrc
-- rendering.loadedTextures[texname] = true
---

local unitRendering = {
	drawList            = {},
	materialInfos       = {},
	bufMaterials        = {},
	bufShadowMaterials  = {},
	materialDefs        = {},
	loadedTextures      = {},

	spGetAllObjects      = Spring.GetAllUnits,
	spGetObjectPieceList = Spring.GetUnitPieceList,

	spGetMaterial        = Spring.UnitRendering.GetMaterial,
	spSetMaterial        = Spring.UnitRendering.SetMaterial,
	spActivateMaterial   = Spring.UnitRendering.ActivateMaterial,
	spDeactivateMaterial = Spring.UnitRendering.DeactivateMaterial,
	spSetObjectLuaDraw   = Spring.UnitRendering.SetUnitLuaDraw,
	spSetLODCount        = Spring.UnitRendering.SetLODCount,
	spSetPieceList       = Spring.UnitRendering.SetPieceList,

	DrawObject           = "DrawUnit", --avoid, will kill CPU-side of performance!
	ObjectCreated        = "UnitCreated",
	ObjectDestroyed      = "UnitDestroyed",
}

local featureRendering = {
	drawList            = {},
	materialInfos       = {},
	bufMaterials        = {},
	bufShadowMaterials  = {},
	materialDefs        = {},
	loadedTextures      = {},

	spGetAllObjects      = Spring.GetAllFeatures,
	spGetObjectPieceList = Spring.GetFeaturePieceList,

	spGetMaterial        = Spring.FeatureRendering.GetMaterial,
	spSetMaterial        = Spring.FeatureRendering.SetMaterial,
	spActivateMaterial   = Spring.FeatureRendering.ActivateMaterial,
	spDeactivateMaterial = Spring.FeatureRendering.DeactivateMaterial,
	spSetObjectLuaDraw   = Spring.FeatureRendering.SetFeatureLuaDraw,
	spSetLODCount        = Spring.FeatureRendering.SetLODCount,
	spSetPieceList       = Spring.FeatureRendering.SetPieceList,

	DrawObject           = "DrawFeature", --avoid, will kill CPU-side of performance!
	ObjectCreated        = "FeatureCreated",
	ObjectDestroyed      = "FeatureDestroyed",
}

local allRendering = {
	unitRendering,
	featureRendering,
}

-----------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------



local function _CompileShader(shader, definitions, plugIns, addName)
	definitions = definitions or {}

	local hasVersion = false
	if definitions[1] then -- #version must be 1st statement
		hasVersion = string.find(definitions[1], "#version") == 1
	end

	if not hasVersion then
		table.insert(definitions, 1, DEFAULT_VERSION)
	end

	shader.definitions = table.concat(definitions, "\n") .. "\n"

	--// insert small pieces of code named `plugins`
	--// this way we can use a basic shader and add some simple vertex animations etc.
	do
		local function InsertPlugin(str)
			return (plugIns and plugIns[str]) or ""
		end

		if shader.vertex then
			shader.vertex   = shader.vertex:gsub("%%%%([%a_]+)%%%%", InsertPlugin)
		end
		if shader.fragment then
			shader.fragment = shader.fragment:gsub("%%%%([%a_]+)%%%%", InsertPlugin)
		end
		if shader.geometry then
			shader.geometry = shader.geometry:gsub("%%%%([%a_]+)%%%%", InsertPlugin)
		end
	end

	local luaShader = LuaShader(shader, "Custom Unit Shaders. " .. addName)
	local compilationResult = luaShader:Initialize()

	return (compilationResult and luaShader) or nil
end


local engineUniforms = {
	"viewMatrix",
	"viewMatrixInv",
	"projectionMatrix",
	"projectionMatrixInv",
	"viewProjectionMatrix",
	"viewProjectionMatrixInv",
	"shadowMatrix",
	"shadowParams",
	"cameraPos",
	"cameraDir",
	"sunDir",
	"rndVec",
	"simFrame",
	"drawFrame", --visFrame
}

local function _FillUniformLocs(luaShader)
	local uniformLocTbl = {}
	for _, uniformName in ipairs(engineUniforms) do
		local uniformNameLoc = string.lower(uniformName).."loc"
		uniformLocTbl[uniformNameLoc] = luaShader:GetUniformLocation(uniformName)
	end
	return uniformLocTbl
end

local function _CompileMaterialShaders(rendering)
	for matName, matSrc in pairs(rendering.materialDefs) do
		if matSrc.shaderSource then
			local luaShader = _CompileShader(
				matSrc.shaderSource,
				matSrc.shaderDefinitions,
				matSrc.shaderPlugins,
				string.format("MatName: \"%s\"(%s)", matName, "Standard")
			)

			if luaShader then
				if matSrc.standardShader then
					if matSrc.standardShaderObj then
						matSrc.standardShaderObj:Finalize()
					else
						gl.DeleteShader(matSrc.standardShader)
					end
				end
				matSrc.standardShaderObj = luaShader
				matSrc.standardShader = luaShader:GetHandle()
				luaShader:SetUnknownUniformIgnore(true)
				luaShader:ActivateWith( function()
					matSrc.standardUniforms = _FillUniformLocs(luaShader)
				end)
				luaShader:SetActiveStateIgnore(true)

				if matSrc.Initialize then
					matSrc.Initialize(matName, matSrc)
				end
			end
		end

		if (matSrc.deferredSource) then
			local luaShader = _CompileShader(
				matSrc.deferredSource,
				matSrc.deferredDefinitions,
				matSrc.shaderPlugins,
				string.format("MatName: \"%s\"(%s)", matName, "Deferred")
			)

			if luaShader then
				if matSrc.deferredShader then
					if matSrc.deferredShaderObj then
						matSrc.deferredShaderObj:Finalize()
					else
						gl.DeleteShader(matSrc.deferredShader)
					end
				end
				matSrc.deferredShaderObj = luaShader
				matSrc.deferredShader = luaShader:GetHandle()
				luaShader:SetUnknownUniformIgnore(true)
				luaShader:ActivateWith( function()
					matSrc.deferredUniforms = _FillUniformLocs(luaShader)
				end)
				luaShader:SetActiveStateIgnore(true)

				if matSrc.Initialize then
					matSrc.Initialize(matName, matSrc)
				end
			end
		end

		if (matSrc.shadowSource) then
			local luaShader = _CompileShader(
				matSrc.shadowSource,
				matSrc.shadowDefinitions,
				matSrc.shaderPlugins,
				string.format("MatName: \"%s\"(%s)", matName, "Shadow")
			)
			if luaShader then
				if matSrc.shadowShader then
					if matSrc.shadowShaderObj then
						matSrc.shadowShaderObj:Finalize()
					else
						gl.DeleteShader(matSrc.shadowShader)
					end
				end
				matSrc.shadowShaderObj = luaShader
				matSrc.shadowShader = luaShader:GetHandle()
				luaShader:SetUnknownUniformIgnore(true)
				luaShader:ActivateWith( function()
					matSrc.shadowUniforms = _FillUniformLocs(luaShader)
				end)
				luaShader:SetActiveStateIgnore(true)

				if matSrc.Initialize then
					matSrc.Initialize(matName, matSrc)
				end
			end
		end

	end
end

local function _ProcessOptions(optName, _, optValues, playerID)
	if (playerID ~= Spring.GetMyPlayerID()) then
		return
	end

	if type(optValues) ~= "table" then
		optValues = {optValues}
	end

	--Spring.Utilities.TableEcho({optName, optValues, playerID}, "_ProcessOptions")

	for _, rendering in ipairs(allRendering) do
		for matName, matTable in pairs(rendering.materialDefs) do
			if matTable.ProcessOptions then
				local optCh = matTable.ProcessOptions(matTable, optName, optValues)
				optionsChanged = optionsChanged or optCh
			end
		end
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local validTexturePrefixes = {
	["%"] = true,
	["#"] = true,
	["!"] = true,
	["$"] = true
}
local function GetObjectMaterial(rendering, objectDefID)
	local mat = rendering.bufMaterials[objectDefID]
	if mat then
		return mat
	end


	local matInfo = rendering.materialInfos[objectDefID]
	local mat = rendering.materialDefs[matInfo[1]]

	if type(objectDefID) == "number" then
		-- Non-number objectDefIDs are default material overrides. They will have
		-- their textures defined in the unit materials files.
		matInfo.UNITDEFID = objectDefID
		matInfo.FEATUREDEFID = -objectDefID
	end

	--// find unitdef tex keyword and replace it
	--// (a shader can be just for multiple unitdefs, so we support this keywords)
	local texUnits = {}
	for texid, tex in pairs(mat.texUnits or {}) do
		local tex_ = tex
		for varname, value in pairs(matInfo) do
			tex_ = tex_:gsub("%%"..tostring(varname), value)
		end
		texUnits[texid] = {tex = tex_, enable = false}
	end

	--// materials don't load those textures themselves

	local texdl = gl.CreateList(function() --this stupidity is required, because GetObjectMaterial() is called outside of GL enabled callins
		for _, tex in pairs(texUnits) do
			if not rendering.loadedTextures[tex.tex] then
				local prefix = tex.tex:sub(1, 1)
				if not validTexturePrefixes[prefix] then
					gl.Texture(tex.tex)
					rendering.loadedTextures[tex.tex] = true
				end
			end
		end
	end)
	gl.DeleteList(texdl)


	local luaMat = rendering.spGetMaterial("opaque", {
		standardshader = mat.standardShader,
		deferredshader = mat.deferredShader,

		standarduniforms = mat.standardUniforms,
		deferreduniforms = mat.deferredUniforms,

		usecamera   = mat.usecamera,
		culling     = mat.culling,
		texunits    = texUnits,
		prelist     = mat.predl,
		postlist    = mat.postdl,
	})

	rendering.bufMaterials[objectDefID] = luaMat
	return luaMat
end

local function GetObjectShadowMaterial(rendering, objectDefID)
	local mat = rendering.bufShadowMaterials[objectDefID]
	if mat then
		return mat
	end


	local matInfo = rendering.materialInfos[objectDefID]
	local mat = rendering.materialDefs[matInfo[1]]

	if type(objectDefID) == "number" then
		-- Non-number objectDefIDs are default material overrides. They will have
		-- their textures defined in the unit materials files.
		matInfo.UNITDEFID = objectDefID
		matInfo.FEATUREDEFID = -objectDefID
	end

	--// find unitdef tex keyword and replace it
	--// (a shader can be just for multiple unitdefs, so we support this keywords)
	local texUnits = {}
	for texid, tex in pairs(mat.texUnits or {}) do
		local tex_ = tex
		for varname, value in pairs(matInfo) do
			tex_ = tex_:gsub("%%"..tostring(varname), value)
		end
		texUnits[texid] = {tex = tex_, enable = false}
	end

	--// materials don't load those textures themselves

	local texdl = gl.CreateList(function() --this stupidity is required, because GetObjectMaterial() is called outside of GL enabled callins
		for _, tex in pairs(texUnits) do
			if not rendering.loadedTextures[tex.tex] then
				local prefix = tex.tex:sub(1, 1)
				if validTexturePrefixes[prefix] then
					gl.Texture(tex.tex)
					rendering.loadedTextures[tex.tex] = true
				end
			end
		end
	end)
	gl.DeleteList(texdl)

	--No deferred statements are required
	local luaShadowMat = rendering.spGetMaterial("shadow", {
		standardshader = mat.shadowShader,

		standarduniforms = mat.shadowUniforms,

		usecamera   = true,
		culling     = mat.shadowCulling,
		texunits    = texUnits,
	})

	rendering.bufShadowMaterials[objectDefID] = luaShadowMat
	return luaShadowMat
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function _ResetUnit(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	gadget:RenderUnitDestroyed(unitID, unitDefID)
	if not select(3, Spring.GetUnitIsStunned(unitID)) then --// inbuild?
		gadget:UnitFinished(unitID, unitDefID)
	end
end

local function _ResetFeature(featureID)
	gadget:FeatureDestroyed(featureID)
	gadget:FeatureCreated(featureID)
end

local function _LoadMaterialConfigFiles(path)
	local unitMaterialDefs = {}
	local featureMaterialDefs = {}

	GG.CUS.unitMaterialDefs = unitMaterialDefs
	GG.CUS.featureMaterialDefs = featureMaterialDefs

	local files = VFS.DirList(path)
	table.sort(files)

	for i = 1, #files do
		local matNames, matObjects = VFS.Include(files[i])
		for k, v in pairs(matNames) do
		-- Spring.Echo(files[i],'is a feature?',v.feature)
			local rendering
			if v.feature then
				rendering = featureRendering
			else
				rendering = unitRendering
			end
			if not rendering.materialDefs[k] then
				rendering.materialDefs[k] = v
			end
		end
		for k, v in pairs(matObjects) do
			--// we check if the material is defined as a unit or as feature material (one namespace for both!!)
			local materialDefs
			if featureRendering.materialDefs[v[1]] then
				materialDefs = featureMaterialDefs
			else
				materialDefs = unitMaterialDefs
			end
			if not materialDefs[k] then
				materialDefs[k] = v
			end
		end
	end
	
	return unitMaterialDefs, featureMaterialDefs
end

local function _ProcessMaterials(rendering, materialDefsSrc)
	local engineShaderTypes = {"3do", "s3o", "ass"}

	for _, matSrc in pairs(rendering.materialDefs) do

		if matSrc.shader ~= nil and engineShaderTypes[matSrc.shader] == nil then
			matSrc.shaderSource = matSrc.shader
			matSrc.shader = nil
		end

		if matSrc.deferred ~= nil and engineShaderTypes[matSrc.deferred] == nil then
			matSrc.deferredSource = matSrc.deferred
			matSrc.deferred = nil
		end

		if matSrc.shadow ~= nil and engineShaderTypes[matSrc.shadow] == nil then
			matSrc.shadowSource = matSrc.shadow
			matSrc.shadow = nil
		end
	end

	_CompileMaterialShaders(rendering)

	for objectDefID, materialInfo in pairs(materialDefsSrc) do --note not rendering.materialDefs
		if (type(materialInfo) ~= "table") then
			materialInfo = {materialInfo}
		end
		rendering.materialInfos[objectDefID] = materialInfo
	end
end


local function BindMaterials()
	local units = Spring.GetAllUnits()
	for _, unitID in pairs(units) do
		_ResetUnit(unitID)
	end

	local features = Spring.GetAllFeatures()
	for _, featureID in pairs(features) do
		_ResetFeature(featureID)
	end

end

local function ToggleAdvShading()
	unitRendering.drawList = {}
	featureRendering.drawList = {}

	BindMaterials()
end

local function GetShaderOverride(objectID, objectDefID)
	if Spring.ValidUnitID(objectID) then
		return Spring.GetUnitRulesParam(objectID, "comm_texture")
	end
	return false
end

local function ObjectFinished(rendering, objectID, objectDefID)
	if not advShading then
		return
	end

	objectDefID = GetShaderOverride(objectID, objectDefID) or objectDefID
	local objectMat = rendering.materialInfos[objectDefID]
	if objectMat then
		local mat = rendering.materialDefs[objectMat[1]]

		if mat.standardShader then
			rendering.spActivateMaterial(objectID, 3)

			rendering.spSetMaterial(objectID, 3, "opaque", GetObjectMaterial(rendering, objectDefID))
			if mat.shadowShader and (not bug3734wa) then
				rendering.spSetMaterial(objectID, 3, "shadow", GetObjectShadowMaterial(rendering, objectDefID))
			end

			for pieceID in ipairs(rendering.spGetObjectPieceList(objectID) or {}) do
				rendering.spSetPieceList(objectID, 3, pieceID)
			end

			local DrawObject = mat[rendering.DrawObject]
			local ObjectCreated = mat[rendering.ObjectCreated]

			if DrawObject then
				rendering.spSetObjectLuaDraw(objectID, true)
				rendering.drawList[objectID] = mat
			end

			if ObjectCreated then
				ObjectCreated(objectID, mat, 3)
			end
		end
	end
end


local function _CleanupEverything(rendering)
	for objectID, mat in pairs(rendering.drawList) do
		local DrawObject = mat[rendering.DrawObject]
		if DrawObject then
			rendering.spSetObjectLuaDraw(objectID, false)
		end
	end

	for _, mat in pairs(rendering.materialDefs) do
		if mat.Finalize then
			mat.Finalize(matName, matSrc)
		end
		for _, shaderObject in pairs({mat.standardShaderObj, mat.deferredShaderObj, mat.shadowShaderObj}) do
			if shaderObject then
				shaderObject:Finalize()
			end
		end
	end

	for tex, _ in pairs(rendering.loadedTextures) do
		gl.DeleteTexture(tex)
	end

	for _, oid in ipairs(rendering.spGetAllObjects()) do
		rendering.spSetLODCount(oid, 0)
	end

	for optName, _ in pairs(registeredOptions) do
		gadgetHandler:RemoveChatAction(optName)
	end

	rendering.drawList            = {}
	rendering.materialInfos       = {}
	rendering.bufMaterials        = {}
	rendering.bufShadowMaterials  = {}
	rendering.materialDefs        = {}
	rendering.loadedTextures      = {}

	gadgetHandler:RemoveChatAction("cusreload")
	gadgetHandler:RemoveChatAction("reloadcus")
end

local function ObjectDestroyed(rendering, objectID, objectDefID)
	local mat = rendering.drawList[objectID]
	if mat then
		local _ObjectDestroyed = mat[rendering.ObjectDestroyed]
		if _ObjectDestroyed then
			_ObjectDestroyed(objectID)
		end
		rendering.drawList[objectID] = nil
	end
	rendering.spDeactivateMaterial(objectID, 3)
end

local function DrawObject(rendering, objectID, objectDefID, drawMode)
	local mat = rendering.drawList[objectID]
	if not mat then
		return
	end

	local _DrawObject = mat[rendering.DrawObject]
	if _DrawObject then
		local luaShaderObj = ((drawMode == 1) and mat.standardShaderObj) or ((drawMode == 5) and mat.deferredShaderObj)
		return _DrawObject(objectID, objectDefID, mat, drawMode, luaShaderObj)
	end
end


-----------------------------------------------------------------
-- Gadget Functions
-----------------------------------------------------------------

function gadget:SunChanged()
	sunChanged = true
end

function gadget:DrawGenesis()
	for _, rendering in ipairs(allRendering) do
		for _, mat in pairs(rendering.materialDefs) do
			local SunChangedFunc = (sunChanged and mat.SunChanged) or nil
			local DrawGenesisFunc = mat.DrawGenesis
			local ApplyOptionsFunc = mat.ApplyOptions

			if SunChangedFunc or DrawGenesisFunc or (optionsChanged and ApplyOptionsFunc) then
				for key, shaderObject in pairs({mat.standardShaderObj, mat.deferredShaderObj, mat.shadowShaderObj}) do
					if shaderObject then
						shaderObject:ActivateWith( function ()

							if optionsChanged and ApplyOptionsFunc then
								ApplyOptionsFunc(shaderObject, mat, key)
							end

							if SunChangedFunc then
								SunChangedFunc(shaderObject, mat)
							end

							if DrawGenesisFunc then
								DrawGenesisFunc(shaderObject, mat)
							end

						end)
					end
				end
			end
		end
	end

	if sunChanged then
		sunChanged = false
	end

	if optionsChanged then
		optionsChanged = false
	end
end

-----------------------------------------------------------------
-----------------------------------------------------------------

-- To be called once per CHECK_FREQ
local function GameFrameSlow(gf)
	for _, rendering in ipairs(allRendering) do
		for _, mat in pairs(rendering.materialDefs) do
			local gameFrameSlowFunc = mat.GameFrameSlow
			if gameFrameSlowFunc then
				if mat.standardShaderObj then
					gameFrameSlowFunc(gf, mat, false)
				end
				if mat.deferredShaderObj then
					gameFrameSlowFunc(gf, mat, true)
				end
			end
		end
	end
end

local CHECK_FREQ = 30
function gadget:GameFrame(gf)
	local gfMod = gf % CHECK_FREQ
	if gfMod == 0 then
		local advShadingNow = Spring.HaveAdvShading()
		local shadowsNow = Spring.HaveShadows()

		if (advShading ~= advShadingNow) then
			advShading = advShadingNow
			ToggleAdvShading()
		end

		if (shadows ~= shadowsNow) then
			shadows = shadowsNow
			_ProcessOptions("shadowmapping", nil, shadows, Spring.GetMyPlayerID())
		end
	elseif gfMod == 15 then --TODO change 15 to something less busy
		GameFrameSlow(gf)
	end
end

-----------------------------------------------------------------
-----------------------------------------------------------------

function gadget:UnitFinished(unitID, unitDefID)
	idToDefID[unitID] = unitDefID
	ObjectFinished(unitRendering, unitID, unitDefID)
end

function gadget:FeatureCreated(featureID)
	idToDefID[-featureID] = Spring.GetFeatureDefID(featureID)
	ObjectFinished(featureRendering, featureID, idToDefID[-featureID])
end

function gadget:RenderUnitDestroyed(unitID, unitDefID)
	ObjectDestroyed(unitRendering, unitID, unitDefID)
	idToDefID[unitID] = nil  --not really required
end

function gadget:FeatureDestroyed(featureID)
	ObjectDestroyed(featureRendering, featureID, idToDefID[-featureID])
	idToDefID[-featureID] = nil --not really required
end

-----------------------------------------------------------------
-----------------------------------------------------------------

---------------------------
-- Draw{Unit, Feature}(id, drawMode)

-- With enum drawMode {
-- notDrawing = 0,
-- normalDraw = 1,
-- shadowDraw = 2,
-- reflectionDraw = 3,
-- refractionDraw = 4,
-- gameDeferredDraw = 5,
-- };
-----------------

function gadget:DrawUnit(unitID, drawMode)
	return DrawObject(unitRendering, unitID, idToDefID[unitID], drawMode)
end


function gadget:DrawFeature(featureID, drawMode)
	return DrawObject(featureRendering, featureID, idToDefID[-featureID], drawMode)
end

-----------------------------------------------------------------
-----------------------------------------------------------------

gadget.UnitReverseBuilt = gadget.RenderUnitDestroyed
gadget.UnitCloaked   = gadget.RenderUnitDestroyed
gadget.UnitDecloaked = gadget.UnitFinished


-- NOTE: No feature equivalent (features can't change team)
function gadget:UnitGiven(unitID, ...)
	_ResetUnit(unitID)
end

-----------------------------------------------------------------
-----------------------------------------------------------------

local function ReloadCUS(optName, _, _, playerID)
	if (playerID ~= Spring.GetMyPlayerID()) then
		return
	end
	gadget:Shutdown()
	gadget:Initialize()
end

-----------------------------------------------------------------
-----------------------------------------------------------------

function gadget:Initialize()
	--// GG assignment
	GG.CUS = {}

	--// load the materials config files
	local unitMaterialDefs, featureMaterialDefs = _LoadMaterialConfigFiles(MATERIALS_DIR)
	--// process the materials (compile shaders, load textures, ...)
	_ProcessMaterials(unitRendering,    unitMaterialDefs)
	_ProcessMaterials(featureRendering, featureMaterialDefs)

	advShading = Spring.HaveAdvShading()

	shadows = Spring.HaveShadows()

	bug3734wa = Spring.GetConfigInt("bug3734wa", 0) > 0

	local normalmapping = Spring.GetConfigInt("NormalMapping", 1) > 0
	local treewind = Spring.GetConfigInt("TreeWind", 1) > 0

	local commonOptions = {
		shadowmapping     = shadows,
		normalmapping     = normalmapping,
		treewind          = treewind,
		--metal_highlight   = false,
	}

	for _, rendering in ipairs(allRendering) do
		for matName, matTable in pairs(rendering.materialDefs) do
			
			if matTable.GetAllOptions then
				local allOptions = matTable.GetAllOptions()
				for opt, _ in pairs(allOptions) do
					if not registeredOptions[opt] then
						registeredOptions[opt] = true
						gadgetHandler:AddChatAction(opt, _ProcessOptions)
					end
				end

				for optName, optValue in pairs(commonOptions) do
					_ProcessOptions(optName, nil, optValue, Spring.GetMyPlayerID())
				end
			end
		end
	end

	BindMaterials()
	gadgetHandler:AddChatAction("cusreload", ReloadCUS)
	gadgetHandler:AddChatAction("reloadcus", ReloadCUS)
end

function gadget:Shutdown()
	for _, rendering in ipairs(allRendering) do
		_CleanupEverything(rendering)
	end

	--// GG de-assignment
	GG.CUS = nil
end
