---VBO

---
---@return nil
function vbo:Delete() end

---Parameters
---@param size number
---@param attribs number|{{number,number,number,number,number},...}
---@return nil
function vbo:Define(size, attribs) end

---terrainVertexVBO:Define(numPoints, { {id = 0, name = "pos", size = 2}, })
---@return number elementsCount
function vbo:GetBufferSize() end

---@return number bufferSizeInBytes
function vbo:GetBufferSize() end

---@return number size
function vbo:GetBufferSize() end

---Parameters
---@param vboData {number,...}
---@param attributeIndex number (default): `-1`
---@param elemOffset number (default): `0`
---@param luaStartIndex number (default): `0`
---@param luaFinishIndex number (optional)
---@return {number, ...} indexData
function vbo:Upload(vboData[, attributeIndex=-1[, elemOffset=0[, luaStartIndex=0[, luaFinishIndex]]]]) end

---@return number elemOffset
function vbo:Upload(vboData[, attributeIndex=-1[, elemOffset=0[, luaStartIndex=0[, luaFinishIndex]]]]) end

---@return number|{number,number,number,number} attrID
function vbo:Upload(vboData[, attributeIndex=-1[, elemOffset=0[, luaStartIndex=0[, luaFinishIndex]]]]) end

---vbo:Upload(posArray, 0, 1)
-- 0 is offset into vbo (on GPU) in this case no offset
-- 1 is lua index index into the Lua table, in this case it's same as default
-- Upload will upload from luaOffset to end of lua array
---rectInstanceVBO:Upload({1},0)
---Parameters
---@param attributeIndex number (default): `-1`
---@param elementOffset number (default): `0`
---@param elementCount number (optional)
---@param forceGPURead boolean (default): `false`
---@return {{number,...},...} vboData
function vbo:Download([attributeIndex=-1[, elementOffset=0[, elementCount[, forceGPURead=false]]]]) end

---@return nil|number buffer size in bytes
function vbo:ModelsVBO() end

---Parameters
---@param unitDefIDs number|{number,...}
---@param attrID number
---@param teamIdOpt number (optional)
---@param elementOffset number (optional)
---@return {number,number,number,number} instanceData
function vbo:InstanceDataFromUnitDefIDs(unitDefIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return number elementOffset
function vbo:InstanceDataFromUnitDefIDs(unitDefIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return attrID
function vbo:InstanceDataFromUnitDefIDs(unitDefIDs, attrID[, teamIdOpt[, elementOffset]]) end

---Data Layout


---Parameters
---@param featureDefIDs number|{number,...}
---@param attrID number
---@param teamIdOpt number (optional)
---@param elementOffset number (optional)
---@return {number,number,number,number} instanceData
function vbo:InstanceDataFromFeatureDefIDs(featureDefIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return number elementOffset
function vbo:InstanceDataFromFeatureDefIDs(featureDefIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return attrID
function vbo:InstanceDataFromFeatureDefIDs(featureDefIDs, attrID[, teamIdOpt[, elementOffset]]) end

---Data Layout


---Parameters
---@param unitIDs number|{number,...}
---@param attrID number
---@param teamIdOpt number (optional)
---@param elementOffset number (optional)
---@return {number,number,number,number} instanceData
function vbo:InstanceDataFromUnitIDs(unitIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return number elementOffset
function vbo:InstanceDataFromUnitIDs(unitIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return attrID
function vbo:InstanceDataFromUnitIDs(unitIDs, attrID[, teamIdOpt[, elementOffset]]) end

---Data Layout


---Parameters
---@param featureIDs number|{number,...}
---@param attrID number
---@param teamIdOpt number (optional)
---@param elementOffset number (optional)
---@return {number,number,number,number} instanceData
function vbo:InstanceDataFromFeatureIDs(featureIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return number elementOffset
function vbo:InstanceDataFromFeatureIDs(featureIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return attrID
function vbo:InstanceDataFromFeatureIDs(featureIDs, attrID[, teamIdOpt[, elementOffset]]) end

---Parameters
---@param projectileIDs number|{number,...}
---@param attrID number
---@param teamIdOpt number (optional)
---@param elementOffset number (optional)
---@return {number, ...} matDataVec 4x4 matrix
function vbo:MatrixDataFromProjectileIDs(projectileIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return number elemOffset
function vbo:MatrixDataFromProjectileIDs(projectileIDs, attrID[, teamIdOpt[, elementOffset]]) end

---@return number|{number,number,number,number} attrID
function vbo:MatrixDataFromProjectileIDs(projectileIDs, attrID[, teamIdOpt[, elementOffset]]) end

---Parameters
---@param index number
---@param elementOffset number (optional)
---@param elementCount number (optional)
---@param target number (optional)
---@return number bindingIndex when successful, -1 otherwise
function vbo:BindBufferRange(index[, elementOffset[, elementCount[, target]]]) end

---Parameters
---@param index number
---@param elementOffset number (optional)
---@param elementCount number (optional)
---@param target number (optional)
---@return number bindingIndex when successful, -1 otherwise
function vbo:UnbindBufferRange(index[, elementOffset[, elementCount[, target]]]) end

---@return nil
function vbo:DumpDefinition() end

