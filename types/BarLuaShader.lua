---@meta

---@class BarLuaShader
---@field Activate fun(self)
---@field Deactivate fun(self)
---@field SetUniform fun(self, name: string, ...: number|boolean)
---@field SetUniformInt fun(self, name: string, ...: integer)
---@field Initialize fun(self): boolean
---@field Finalize fun(self)
---@field [string] any
