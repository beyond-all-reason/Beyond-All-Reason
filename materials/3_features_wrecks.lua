-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SunChanged(curShader)
	gl.Uniform(gl.GetUniformLocation(curShader, "shadowDensity"), gl.GetSun("shadowDensity" ,"unit"))

	gl.Uniform(gl.GetUniformLocation(curShader, "sunAmbient"), gl.GetSun("ambient" ,"unit"))
	gl.Uniform(gl.GetUniformLocation(curShader, "sunDiffuse"), gl.GetSun("diffuse" ,"unit"))
	gl.Uniform(gl.GetUniformLocation(curShader, "sunSpecular"), gl.GetSun("specular" ,"unit"))
	--gl.Uniform(gl.GetUniformLocation(curShader, "sunSpecularExp"), gl.GetSun("specularExponent" ,"unit"))
end


local default_lua = VFS.Include("materials/Shaders/default.lua")

local materials = {
	feature_wreck = {
		shader    = default_lua,
		deferred  = default_lua,
		shaderDefinitions = {
			"#define use_normalmapping",
			"#define deferred_mode 0",
			--"#define use_vertex_ao",
			"#define SPECULARMULT 6.0",
		},
		deferredDefinitions = {
			--"#define use_normalmapping", --actively disable normalmapping, it can be pricey, and is only shown for deferred lights...
			"#define deferred_mode 1",
			--"#define use_vertex_ao",
			"#define SPECULARMULT 6.0",
		},
		force     = false, --// always use the shader even when normalmapping is disabled
		usecamera = false,
		culling   = GL.BACK,
		texunits  = {
			[0] = '%%FEATUREDEFID:0',
			[1] = '%%FEATUREDEFID:1',
			[2] = '$shadow',
			[3] = '$specular',
			[4] = '$reflection',
			[5] = '%NORMALTEX',
		},
		--DrawFeature = DrawFeature,
		SunChanged = SunChanged,
		feature = true, --// This is used to define that this is a feature shader
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- affected featuredefs

local function FindNormalmap(tex1, tex2)
	local normaltex = nil
	-- Spring.Echo("searching for normals for",tex1)
	--// check if there is a corresponding _normals.dds file
	unittexttures = 'unittextures/'
	if (VFS.FileExists(unittexttures .. tex1)) and (VFS.FileExists(unittexttures .. tex2)) then
		normaltex = unittexttures .. tex1:gsub("%.","_normals.")
		-- Spring.Echo(normaltex)
		if (VFS.FileExists(normaltex)) then
			return normaltex
		end
		normaltex = unittexttures .. tex1:gsub("%.","_normal.")
		-- Spring.Echo(normaltex)
		if (VFS.FileExists(normaltex)) then
			return normaltex
		end
	end
	return nil
end



local featureMaterials = {}

for id, featureDef in pairs(FeatureDefs) do
	local isTree=false
	for _,stub in ipairs({"ad0_", "btree", "art"}) do
		if featureDef.name:find(stub) == 1 then
			isTree=true
			-- Spring.Echo(featureDef.name, 'is a tree')
		end
	end
	Spring.PreloadFeatureDefModel(id)
	-- how to check if its a wreck or a heap?

	if (not isTree) and featureDef.model.textures and featureDef.model.textures.tex1 and ((featureDef.modelpath and featureDef.modelpath:find("%.3ds")) or (featureDef.model ~= nil and featureDef.model.path ~= nil and featureDef.model.path:find("%.3ds") == nil)) then --its likely a proper feature
		if  featureDef.name:find("_dead") then
			if featureDef.name == "cormaw_dead" or featureDef.name == "armclaw_dead" then
				--ignore these two edge cases.
			elseif featureDef.name == "freefusion_free_fusion_dead" then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = "unittextures/mission_command_tower_wreck_1_normal.dds"}
			elseif featureDef.model.textures.tex1:find("Arm_wreck") then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = "unittextures/Arm_wreck_color_normal.dds"}
				--Spring.Echo('Featuredef info for', featureDef.name, to_string(featureDef.model))
			elseif featureDef.model.textures.tex1:find("Core_color_wreck") then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = "unittextures/Core_color_wreck_normal.dds"}
			else
				--Spring.Echo("3_feature_wrecks: featureDef.name has _dead but doesnt have the correct tex1 defined!",featureDef.name, featureDef.model.textures.tex1,featureDef.model.textures.tex2)
			end
		elseif featureDef.model.textures.tex1 and featureDef.model.textures.tex2 then
			if FindNormalmap(featureDef.model.textures.tex1,featureDef.model.textures.tex2) then
				featureMaterials[featureDef.name] = {"feature_wreck", NORMALTEX = FindNormalmap(featureDef.model.textures.tex1,featureDef.model.textures.tex2)}
			end
		end
	end
end

function to_string(data, indent)
	local str = ""

	if(indent == nil) then
		indent = 0
	end

	-- Check the type
	if(type(data) == "string") then
		str = str .. ("    "):rep(indent) .. data .. "\n"
	elseif(type(data) == "number") then
		str = str .. ("    "):rep(indent) .. data .. "\n"
	elseif(type(data) == "boolean") then
		if(data == true) then
			str = str .. "true"
		else
			str = str .. "false"
		end
	elseif(type(data) == "table") then
		local i, v
		for i, v in pairs(data) do
			-- Check for a table in a table
			if(type(v) == "table") then
				str = str .. ("    "):rep(indent) .. i .. ":\n"
				str = str .. to_string(v, indent + 2)
			else
				str = str .. ("    "):rep(indent) .. i .. ": " .. to_string(v, 0)
			end
		end
	elseif (data ==nil) then
		str=str..'nil'
	else
		--print_debug(1, "Error: unknown data type: %s", type(data))
		str=str.. "Error: unknown data type:" .. type(data)
		Spring.Echo('X data type')
	end

	return str
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
