---@meta

--- Instance VBO table from `gl.InstanceVBOTable` / `InstanceVBOTable.makeInstanceVBOTable`.
--- Single merged definition (see `modules/graphics/instancevbotable.lua` implementation).

---@class InstanceVBOTable
---@field instanceVBO VBO|any
---@field instanceData number[]
---@field instanceStep integer
---@field usedElements integer
---@field maxElements integer
---@field myName string
---@field instanceIDtoIndex table<any, integer>
---@field indextoInstanceID table<integer, any>
---@field indextoUnitID table<integer, integer>?
---@field unitIDattribID integer?
---@field layout table
---@field dirty boolean
---@field numVertices integer
---@field primitiveType integer
---@field VAO VAO?
---@field vertexVBO VBO|any?
---@field indexVBO VBO|any?
---@field clearInstanceTable fun(self: InstanceVBOTable)
---@field makeVAOandAttach fun(self: InstanceVBOTable, vertexVBO: any?, instanceVBO: any?, indexVBO: any?): any
---@field Draw fun(self: InstanceVBOTable)
---@field draw fun(self: InstanceVBOTable, primitiveType: integer?)
---@field compact fun(self: InstanceVBOTable)
---@field Delete fun(self: InstanceVBOTable)
---@field debug boolean?
---@field [string] any

--- The shared instance-buffer helpers, reached as `gl.InstanceVBOTable`. The
--- implementation lives in `modules/graphics/instancevbotable.lua`;
--- `luaui/Include/instancevbotable.lua` is a deprecated shim that re-exports it.
---
--- Note the vocabulary: an `InstanceVBOTable` is a *wrapper* around a `VBO`, not a
--- VBO itself. `pushElementInstance` and friends all take the wrapper.
---@class InstanceVBOTableModule
local InstanceVBOTableModule = {}

--- Allocates an instance buffer. Returns `nil` when the VBO cannot be created.
---@param layout table[] Attribute descriptors, e.g. `{{id = 1, name = 'pos', size = 4}}`.
---@param maxElements integer? Grows dynamically anyway. Defaults to `64`.
---@param myName string? Name used in log messages. Defaults to `"InstanceVBOTable"`.
---@param unitIDattribID integer? Attribute id of the uvec4 holding unitID bindings.
---@return InstanceVBOTable? instanceTable
function InstanceVBOTableModule.makeInstanceVBOTable(layout, maxElements, myName, unitIDattribID) end

--- Adds or updates one instance.
---@param iT InstanceVBOTable
---@param thisInstance number[] Exactly `iT.instanceStep` values.
---@param instanceID string|number|nil Key for later reference; `nil` auto-generates one.
---@param updateExisting boolean? Allow overwriting an element with the same key.
---@param noUpload boolean? Skip the upload, to batch several operations.
---@param unitID integer? Bind the instance to a unit, so the buffer tracks it.
---@return string|number|nil instanceID The key it was filed under; `nil` on failure.
function InstanceVBOTableModule.pushElementInstance(iT, thisInstance, instanceID, updateExisting, noUpload, unitID) end

--- Removes one instance, swapping the last element into its place.
---@param iT InstanceVBOTable
---@param instanceID string|number
---@param noUpload boolean?
---@return integer? index The buffer index it occupied; `nil` when not found.
function InstanceVBOTableModule.popElementInstance(iT, instanceID, noUpload) end

--- Reads one instance back out of the buffer.
---@param iT InstanceVBOTable
---@param instanceID string|number
---@param cacheTable number[]? Reused output table, to avoid an allocation.
---@return number[]? instanceData
function InstanceVBOTableModule.getElementInstanceData(iT, instanceID, cacheTable) end

--- Empties the table without resizing its buffer.
---@param iT InstanceVBOTable
function InstanceVBOTableModule.clearInstanceTable(iT) end

--- Uploads every used element.
---@param iT InstanceVBOTable
function InstanceVBOTableModule.uploadAllElements(iT) end

---@param iT InstanceVBOTable
---@param startElementIndex integer
---@param endElementIndex integer
function InstanceVBOTableModule.uploadElementRange(iT, startElementIndex, endElementIndex) end

---@param iT InstanceVBOTable
function InstanceVBOTableModule.drawInstanceVBO(iT) end

--- Attaches a vertex buffer to an instance buffer, and an index buffer if given.
---@param vertexVBO InstanceVBOTable|VBO|nil
---@param instanceVBO InstanceVBOTable|VBO|nil
---@param indexVBO InstanceVBOTable|VBO|nil
---@return VAO|InstanceVBOTable|nil vao
function InstanceVBOTableModule.makeVAOandAttach(vertexVBO, instanceVBO, indexVBO) end

---@param iT InstanceVBOTable
---@param removelist table<string|number, true>? Instance keys to drop.
---@param keeplist table<string|number, true>? Instance keys to keep, dropping the rest.
function InstanceVBOTableModule.compactInstanceVBO(iT, removelist, keeplist) end

--- Reports instances bound to units that no longer exist.
---@param iT InstanceVBOTable
function InstanceVBOTableModule.locateInvalidUnits(iT) end

--- The geometry helpers below each build a standalone vertex buffer, for use as the
--- vertex side of `makeVAOandAttach`. `name` is only used in log messages.
---@param circleSegments integer
---@param radius number
---@param startCenter boolean? Emit a centre vertex first, for a triangle fan.
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makeCircleVBO(circleSegments, radius, startCenter, name) end

---@param xsize number Spans `-xsize` to `xsize`.
---@param ysize number
---@param xresolution integer? Subdivisions.
---@param yresolution integer?
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makePlaneVBO(xsize, ysize, xresolution, yresolution, name) end

---@param xresolution integer
---@param yresolution integer
---@param cutcircle boolean? Drop the triangles outside the inscribed circle.
---@param name string?
---@return InstanceVBOTable? indexVBO
function InstanceVBOTableModule.makePlaneIndexVBO(xresolution, yresolution, cutcircle, name) end

---@param numPoints integer
---@param randomFactor number?
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makePointVBO(numPoints, randomFactor, name) end

---@param minX number?
---@param minY number?
---@param maxX number?
---@param maxY number?
---@param minU number?
---@param minV number?
---@param maxU number?
---@param maxV number?
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makeRectVBO(minX, minY, maxX, maxY, minU, minV, maxU, maxV, name) end

---@param name string?
---@return InstanceVBOTable? indexVBO
function InstanceVBOTableModule.makeRectIndexVBO(name) end

---@param numSegments integer
---@param height number
---@param radius number
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makeConeVBO(numSegments, height, radius, name) end

---@param numSegments integer
---@param height number
---@param radius number
---@param hastop boolean?
---@param hasbottom boolean?
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makeCylinderVBO(numSegments, height, radius, hastop, hasbottom, name) end

---@param minX number
---@param minY number
---@param minZ number
---@param maxX number
---@param maxY number
---@param maxZ number
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makeBoxVBO(minX, minY, minZ, maxX, maxY, maxZ, name) end

---@param sectorCount integer
---@param stackCount integer
---@param radius number
---@param name string?
---@return InstanceVBOTable? vertexVBO
function InstanceVBOTableModule.makeSphereVBO(sectorCount, stackCount, radius, name) end

--- A screen-space textured rectangle, already wrapped in a VAO.
---@param minX number?
---@param minY number?
---@param maxX number?
---@param maxY number?
---@param minU number?
---@param minV number?
---@param maxU number?
---@param maxV number?
---@param name string?
---@return InstanceVBOTable? rectVAO
function InstanceVBOTableModule.MakeTexRectVAO(minX, minY, maxX, maxY, minU, minV, maxU, maxV, name) end

--- `gl` is declared as a plain global by the engine library, so the helpers are
--- attached to it here rather than through a class declaration.
---@type InstanceVBOTableModule
gl.InstanceVBOTable = InstanceVBOTableModule
