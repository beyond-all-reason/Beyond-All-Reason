-- Feature Defs Builder
-- Registry of feature definitions, the FeatureDefs counterpart to UnitDefsBuilder.
-- Two views over the same defs:
--   GetFeatureDefsByID()   numeric defID -> def   (the engine-runtime shape)
--   GetFeatureDefsByName() string name   -> def

---@class FeatureDefsBuilder
---@field _byID table<number, table>
---@field _byName table<string, table>
---@field _names table<string, { id: number }>
local FDB = {}
FDB.__index = FDB

---@return FeatureDefsBuilder
function FDB.new()
	return setmetatable({
		_byID = {},
		_byName = {},
		_names = {},
	}, FDB)
end

---@param self FeatureDefsBuilder
---@param defID number
---@param def table
---@return FeatureDefsBuilder
function FDB:WithFeatureDef(defID, def)
	self._byID[defID] = def
	if def.name then
		self._byName[def.name] = def
		self._names[def.name] = { id = defID }
	end
	return self
end

---Register several definitions at once, keyed by defID, which reads closer to the
---FeatureDefs table the engine exposes.
---@param self FeatureDefsBuilder
---@param defsByID table<number, table>
---@return FeatureDefsBuilder
function FDB:WithFeatureDefs(defsByID)
	for defID, def in pairs(defsByID or {}) do
		self:WithFeatureDef(defID, def)
	end
	return self
end

---@return table<number, table>
function FDB:GetFeatureDefsByID()
	return self._byID
end

---@return table<string, table>
function FDB:GetFeatureDefsByName()
	return self._byName
end

---@return table<string, { id: number }>
function FDB:GetFeatureDefNames()
	return self._names
end

return FDB
