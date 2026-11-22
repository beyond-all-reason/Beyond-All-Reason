local EFFECTS_DIR = "luarules/mission_api/effects/"
local EFFECT_FILES_PATTERN = "*.lua"

local function loadEffectDefinitions()
	local effects = {}
	local effectTypes = {}
	for _, filePath in ipairs(VFS.DirList(EFFECTS_DIR, EFFECT_FILES_PATTERN)) do
		---@type { type:string, Create:(fun(area, strength):any), Remove:fun(id) }
		local effectDefinition = VFS.Include(filePath)
		local effectType = effectDefinition.type
		if not (effectType and effectDefinition.Create and effectDefinition.Remove) then
			Spring.Log(
				"effects_loader.lua",
				LOG.ERROR,
				"[Mission API] Effect needs a type, Create, and Remove: " .. filePath
			)
		else
			if effects[effectType] then
				Spring.Log(
					"effects_loader.lua",
					LOG.WARNING,
					"[Mission API] Effect type '" .. effectType .. "' is defined twice, second in: " .. filePath
				)
			end
			effects[effectType] = effectDefinition
			effectTypes[effectType] = effectType
		end
	end

	return {
		Effects = effects,
		Types = effectTypes,
	}
end

return {
	LoadEffectDefinitions = loadEffectDefinitions,
}
