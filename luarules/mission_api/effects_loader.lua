local EFFECTS_DIR = "luarules/mission_api/effects/"
local EFFECT_FILES_PATTERN = "*.lua"

local parameterTypes = GG["MissionAPI"].Modules.ParameterTypes

local function loadEffectDefinitions()
	local effects = {}
	local effectTypes = {}
	for _, filePath in ipairs(VFS.DirList(EFFECTS_DIR, EFFECT_FILES_PATTERN)) do
		---@type { type:string, Create:fun(area, strength):any, Remove:fun(id) }
		local effectDefinition = VFS.Include(filePath)
		local effectType = effectDefinition.type
		if effects[effectType] then
			Spring.Log(
				"effects_loader.lua",
				LOG.ERROR,
				"[Mission API] Effect type '" .. effectType .. "' is defined twice, second in: " .. filePath
			)
		end
		effects[effectType] = effectDefinition
		effectTypes[effectType] = true
	end

	-- Populates the type enum for validation and the mission editor.
	parameterTypes.Enums[parameterTypes.Types.EffectID] = effectTypes

	return {
		Effects = effects,
	}
end

return {
	LoadEffectDefinitions = loadEffectDefinitions,
}
