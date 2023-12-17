---VAO

---
---@return nil
function vao:Delete() end

---Parameters
---@param vbo VBO
---@return nil
function vao:AttachVertexBuffer(vbo) end

---Parameters
---@param vbo VBO
---@return nil
function vao:AttachInstanceBuffer(vbo) end

---Parameters
---@param vbo VBO
---@return nil
function vao:AttachIndexBuffer(vbo) end

---Parameters
---@param glEnum number
---@param numVertices number (optional)
---@param vertexCount number (optional)
---@param vertexFirst number (optional)
---@param instanceCount number (optional)
---@param instanceFirst number (optional)
---@return nil
function vao:DrawArrays(glEnum[, numVertices[, vertexCount[, vertexFirst[, instanceCount[, instanceFirst]]]]]) end

---Parameters
---@param glEnum number
---@param drawCount number (optional)
---@param baseIndex number (optional)
---@param instanceCount number (optional)
---@param baseVertex number (optional)
---@param baseInstance number (optional)
---@return nil
function vao:DrawElements(glEnum[, drawCount[, baseIndex[, instanceCount[, baseVertex[, baseInstance]]]]]) end

---Parameters
---@param unitIDs number|{number,...}
---@return number submittedCount
function vao:AddUnitsToSubmission(unitIDs) end

---Parameters
---@param featureIDs number|{number,...}
---@return number submittedCount
function vao:AddFeaturesToSubmission(featureIDs) end

---Parameters
---@param unitDefIDs number|{number,...}
---@return number submittedCount
function vao:AddUnitDefsToSubmission(unitDefIDs) end

---Parameters
---@param featureDefIDs number|{number,...}
---@return number submittedCount
function vao:AddFeatureDefsToSubmission(featureDefIDs) end

---Parameters
---@param index number
---@return nil
function vao:RemoveFromSubmission(index) end

---@return nil
function vao:Submit() end

