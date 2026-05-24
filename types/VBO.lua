---@meta

--- Engine GL buffer object (`gl.GetVBO`). Declared in `types/` so LuaLS resolves methods
--- when `types/` is ordered before generated stubs.

---@class VBO
---@field Define fun(self: VBO, size: number, attribs?: number|table)
---@field Upload fun(self: VBO, vboData: number[], attributeIndex: integer?, elemOffset: integer?, luaStartIndex: integer?, luaFinishIndex: integer?): any
---@field Delete fun(self: VBO)
---@field BindBufferRange fun(self: VBO, ...: any)
---@field ModelsVBO fun(self: VBO): (nil|number)
---@field InstanceDataFromUnitIDs fun(self: VBO, ...: any)
---@field InstanceDataFromUnitDefIDs fun(self: VBO, ...: any)
---@field InstanceDataFromFeatureIDs fun(self: VBO, ...: any)
---@field InstanceDataFromFeatureDefIDs fun(self: VBO, ...: any)
---@field [string] any
