---@meta

--- Engine vertex array object (`gl.GetVAO`).

---@class VAO
---@field Delete fun(self: VAO)
---@field AttachVertexBuffer fun(self: VAO, vbo: VBO)
---@field AttachInstanceBuffer fun(self: VAO, vbo: VBO)
---@field AttachIndexBuffer fun(self: VAO, vbo: VBO)
---@field DrawArrays fun(self: VAO, glEnum: number, vertexCount: number?, vertexFirst: number?, instanceCount: number?, instanceFirst: number?)
---@field DrawElements fun(self: VAO, ...: any)
---@field ClearSubmission fun(self: VAO)
---@field AddUnitsToSubmission fun(self: VAO, ...: any)
---@field AddUnitDefsToSubmission fun(self: VAO, ...: any)
---@field AddFeaturesToSubmission fun(self: VAO, ...: any)
---@field AddFeatureDefsToSubmission fun(self: VAO, ...: any)
---@field BindBufferRange fun(self: VAO, ...: any)
---@field [string] any
