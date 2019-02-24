-- $Id$
--------------------------------------------------------------------------------

local materials = {
	normalMappedS3O = {
		shaderDefinitions = {
			"#define use_normalmapping",
			"#define deferred_mode 0",
			"#define use_vertex_ao",
			"#define flashlights",
			"#define SPECULARMULT 8.0",
		},
		deferredDefinitions = {
			"#define use_normalmapping",
			"#define deferred_mode 1",
			"#define flashlights",
			"#define use_vertex_ao",
			"#define SPECULARMULT 8.0",
		},

		shader    = include("ModelMaterials/Shaders/default.lua"),
		deferred  = include("ModelMaterials/Shaders/default.lua"),
		usecamera = false,
		culling   = GL.BACK,
		predl  = nil,
		postdl = nil,
		texunits  = {
			[0] = '%%UNITDEFID:0',
			[1] = '%%UNITDEFID:1',
			[2] = '$shadow',
			[3] = '$specular',
			[4] = '$reflection',
			[5] = '%NORMALTEX',
		},
		-- uniforms = {
		-- }
		--DrawUnit = DrawUnit,
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local unitMaterials = {}

for i=1,#UnitDefs do
	local udef = UnitDefs[i]

	if ((udef.customParams.arm_tank == nil ) and udef.customParams.normaltex and VFS.FileExists(udef.customParams.normaltex)) then
		unitMaterials[udef.name] = {"normalMappedS3O", NORMALTEX = udef.customParams.normaltex}
		--Spring.Echo('normalmapped',udef.name)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
