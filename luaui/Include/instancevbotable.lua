local GL_BUFFER = 0x82E0
local gldebugannotations = (Spring.GetConfigInt("gldebugannotations") == 1)
--Spring.Echo("gldebugannotations", gldebugannotations)
function makeInstanceVBOTable(layout, maxElements, myName, unitIDattribID)
	-- layout: this must be an array of tables with at least the following specified: {{id = 1, name = 'optional', size = 4}}
	-- maxElements: will be dynamic anyway, but defaults to 64
	-- myName: optional name, useful for debugging
	-- unitIDattribID: the attribute ID in the layout of the uvec4 of unitID bindings (e.g. 4 for  {id = 4, name = 'instData', type = GL.UNSIGNED_INT, size= 4} )
	-- returns: nil | instanceTable
	if maxElements == nil then maxElements = 64 end -- default size
	if myName == nil then myName = "InstanceVBOTable" end
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if newInstanceVBO == nil then Spring.Echo("makeInstanceVBOTable, cannot get VBO for", myName); return nil end
	newInstanceVBO:Define(
		maxElements,
		layout
	)
	


	local instanceStep = 0
	for i,attribute in pairs(layout) do
		instanceStep = instanceStep + attribute.size
	end
	local instanceData = {}
	for i = 1, instanceStep * maxElements do
		instanceData[i] = 0
	end
	local instanceTable = {
		instanceVBO 		= newInstanceVBO,
		instanceData 		= instanceData,
		instanceStep 		= instanceStep,
		usedElements 		= 0,
		maxElements 		= maxElements,
		myName 				= myName,
		instanceIDtoIndex 	= {}, -- this maps each instance ID to where it is in the buffer, 1 based
		indextoInstanceID 	= {}, -- this tells us what instanceID is located in any given pos
		layout 				= layout,
		dirty 				= false,
		numVertices 		= 0,
		primitiveType 		= GL.TRIANGLES,
		debugZombies 		= true,  -- this is new, and its for debugging non-existing stuff on unitdestroyed
		lastInstanceID		= 0,
	}

	if unitIDattribID ~= nil then
		instanceTable.indextoUnitID = {}
		instanceTable.unitIDattribID = unitIDattribID
		instanceTable.popUnitIDFailuresInGameFrame = {}
	end

	function instanceTable:clearInstanceTable()
		-- this wont resize it, but quickly sets it to empty
		self.usedElements = 0
		self.instanceIDtoIndex = {}
		self.indextoInstanceID = {}
		if self.indextoUnitID then self.indextoUnitID = {} end
	end

	function instanceTable:makeVAOandAttach(vertexVBO, instanceVBO, indexVBO) -- Attach a vertex buffer to an instance buffer, and optionally, an index buffer if one is supplied.
		-- There is a special case for this, when we are using a vertexVBO as a quasi-instanceVBO, e.g. when we are using the geometry shader to draw a vertex as each instance.
		--iT.vertexVBO = vertexVBO
		--iT.indexVBO = indexVBO
		local newVAO = nil
		newVAO = gl.GetVAO()
		if newVAO == nil then goodbye("Failed to create newVAO") end
		self.VAO = newVAO
		if vertexVBO == nil then -- the special case where are using 'vertices' as 'instances'
			newVAO:AttachVertexBuffer(instanceVBO)
		else
			newVAO:AttachVertexBuffer(vertexVBO)
			newVAO:AttachInstanceBuffer(instanceVBO)
			self.vertexVBO = vertexVBO
			self.instanceVBO = instanceVBO
		end
		if indexVBO then
			newVAO:AttachIndexBuffer(indexVBO)
			self.indexVBO = indexVBO
			function self:Draw()
				self.VAO:DrawElements(GL.TRIANGLES, nil, 0, self.usedElements, 0)
			end
		else
			function self:Draw()
				self.VAO:DrawArrays(GL.TRIANGLES, nil, 0, self.usedElements, 0)
			end
		end
		return newVAO
	end

	function instanceTable:clearInstanceTable()
		-- this wont resize it, but quickly sets it to empty
		self.usedElements = 0
		self.instanceIDtoIndex = {}
		self.indextoInstanceID = {}
		if self.indextoUnitID then self.indextoUnitID = {} end
	end

	function instanceTable:compact()
		self.destroyedElements = 0
		-- so this is for the edge case, where we have silently removed elements from instanceIDtoIndex
		-- where we have holes everywhere, so we have to 'compact' the table,
		-- by copying back contiguously while preserving element order
		local newInstanceIDtoIndex = {}
		local newIndexToInstanceID = {}
		local newInstanceData = {}
		local newUsedElements = 0
		for i = 1, self.usedElements do
			local instanceID = self.indextoInstanceID[i]
			local index = self.instanceIDtoIndex[self.indextoInstanceID[i]]
			if index then
				local instanceStep = self.instanceStep
				local instanceData = self.instanceData

				local dstpos = newUsedElements * instanceStep
				local srcpos = (i - 1) * instanceStep
				for j=1, instanceStep do
					newInstanceData[dstpos + j] = instanceData[srcpos +j]
				end
				newUsedElements = newUsedElements + 1
				newInstanceIDtoIndex[instanceID] = newUsedElements
				newIndexToInstanceID[newUsedElements] = instanceID
			else
			    --Spring.Echo("compacting index",i, 'instanceID', instanceID)
			end
		end
		--Spring.Echo("Post compacting", self.usedElements, newUsedElements)
		self.usedElements = newUsedElements
		self.instanceIDtoIndex = newInstanceIDtoIndex
		self.indextoInstanceID = newIndexToInstanceID
		self.instanceData = newInstanceData
		--iT.instanceVBO:Upload(iT.instanceData,nil,oldElementIndex-1,oldOffset +1,oldOffset + iTStep)
		if self.usedElements > 0 then
			self.instanceVBO:Upload(self.instanceData)
		end
	end


	function instanceTable:draw(primitiveType)
		if self.usedElements > 0 then
			if self.indexVBO then
				self.VAO:DrawElements(primitiveType or self.primitiveType, self.numVertices, 0, self.usedElements,0)
			else
				self.VAO:DrawArrays  (primitiveType or self.primitiveType, self.numVertices, 0, self.usedElements,0)
			end
		end
	end

	function instanceTable:getMemUsage()
		-- arrays are 16 bytes per element
		-- Hash tables are 40 bytes per element
		local totalMem = 0
		totalMem = totalMem + self.usedElements * self.instanceStep * 16 -- the actual instance data
		totalMem = totalMem + self.usedElements * 16 -- indextoinstanceid
		totalMem = totalMem + self.usedElements * 40 -- instanceIDtoIndex
		if self.indextoUnitID then totalMem = totalMem + self.usedElements * 16 end
		return totalMem
	end

	function instanceTable:Delete()
		-- Frees the instancevbo and vao for this instance table. Does not touch the vertex and index vbos.
		-- returns an estimate of how much ram was used
		if self.instanceVBO then self.instanceVBO:Delete() end
		if self.VAO then self.VAO:Delete() end
		local memusage = self:getMemUsage()
		self:clearInstanceTable()
		return memusage
	end


	newInstanceVBO:Upload(instanceData)

	-- I believe that the openGL spec doesnt guarantee that a buffer has an idea before data is uploaded to it, so we will fill it with zeros. 
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, newInstanceVBO:GetID(), myName)
	end
	

	--register self in WG if possible
	if WG then
		if WG.VBOTableRegistry == nil then
			--Spring.Echo("WG.VBORegistry == nil, creating registry on first load")
			WG.VBOTableRegistry = {}
		end
		if WG.VBOTableRegistry[instanceTable.myName] then
			local newname = instanceTable.myName .. tostring(math.random())
			--Spring.Echo(instanceTable.myName, 'already registered, renaming to', newname)
			instanceTable.myName = newname
		end
		--Spring.Echo("Registered ", instanceTable.myName)
		WG.VBOTableRegistry[instanceTable.myName] = instanceTable
	end

	return instanceTable
end

local function nextInstanceID(iT)
	iT.lastInstanceID = iT.lastInstanceID + 1
	return iT.lastInstanceID
end

function clearInstanceTable(iT)
	-- this wont resize it, but quickly sets it to empty
	iT.usedElements = 0
	iT.instanceIDtoIndex = {}
	iT.indextoInstanceID = {}
	if iT.indextoUnitID then iT.indextoUnitID = {} end
end

function makeVAOandAttach(vertexVBO, instanceVBO, indexVBO) -- Attach a vertex buffer to an instance buffer, and optionally, an index buffer if one is supplied.
	-- There is a special case for this, when we are using a vertexVBO as a quasi-instanceVBO, e.g. when we are using the geometry shader to draw a vertex as each instance.
	--iT.vertexVBO = vertexVBO
	--iT.indexVBO = indexVBO
	local newVAO = nil
	newVAO = gl.GetVAO()
	if newVAO == nil then goodbye("Failed to create newVAO") end
	if vertexVBO == nil then -- the special case where are using 'vertices' as 'instances'
		newVAO:AttachVertexBuffer(instanceVBO)
	else
		newVAO:AttachVertexBuffer(vertexVBO)
		newVAO:AttachInstanceBuffer(instanceVBO)
	end
	if indexVBO then
		newVAO:AttachIndexBuffer(indexVBO)
	end
	-- this allows us to set up our sane


	return newVAO
end


--------------- DEBUG HELPERS --------------------------
local function comparetables(t1, t2, name)
	for k,v in pairs(t1) do
		if t2[k] == nil then
			Spring.Echo("Key ",k,"with value",v,"existing in t1 does not exist in t2 in ", name)
		elseif t2[k] ~= v then
			Spring.Echo("Value ",v,"for",k,"existing in t1 does not match value for t2",t2[k]," in ", name)
		end
	end

	for k,v in pairs(t2) do
		if t1[k] == nil then
			Spring.Echo("Key ",k,"with value",v,"existing in t2 does not exist in t1 in ", name)
		elseif t1[k] ~= v then
			Spring.Echo("Value ",v,"for",k,"existing in t2 does not match value for t1",t1[k]," in ", name)
		end
	end
end

local function dbgt(t, name)
	name = name or ""
	local gf = Spring.GetGameFrame()
	local count = 0
	local res = ''
	for k,v in pairs(t) do
		if type(k) == 'number' and type(v) == 'number' then
			res = res .. tostring(k) .. ':' .. tostring(v) ..','
			count = count + 1
		end
	end
	Spring.Echo(tostring(gf).. " " ..name .. ' #' .. tostring(count) .. ' {'..res .. '}')
	return res
end

local function counttable(t)
	local count = 0
	if type(t) ~= type({}) then return 0 end
	for k, v in pairs(t) do count = count + 1 end
	return count
end

local function validateInstanceVBOTable(iT, calledfrom)
	-- check that instanceIDtoIndex and indextoInstanceID are valid and contigous:
	for i=1, iT.usedElements do
		if iT.indextoInstanceID[i] == nil then
			Spring.Echo("There is a hole in indextoInstanceID", iT.myName, "at", i,"out of",iT.usedElements, calledfrom)
			--Spring.Echo()
			if iT.indextoUnitID[i] == nil then
				Spring.Echo("It is also missing from indextoUnitID")
			else
				Spring.Echo("But it does exist in indextoUnitID with an unitID of ", iT.indextoUnitID[i])
				Spring.Echo("This is valid?", Spring.GetUnitPosition(iT.indextoUnitID[i]))
			end

		else
			local instanceID = iT.indextoInstanceID[i]
			if iT.instanceIDtoIndex[instanceID] == nil then
				Spring.Echo("There is a hole instanceIDtoIndex", iT.myName, "at", i," iT.instanceIDtoIndex[instanceID] == nil ")
			elseif iT.instanceIDtoIndex[instanceID] ~= i then
				Spring.Echo("There is a problem in indextoInstanceID", iT.myName, "at i =", i,"  iT.indextoInstanceID[instanceID] ~= i, it is instead: ", iT.indextoInstanceID[instanceID] )
			end
		end
	end
	local indextoInstanceIDsize = counttable(iT.indextoInstanceID)
	local instanceIDtoIndexsize = counttable(iT.instanceIDtoIndex)
	local indextoUnitID = counttable(iT.indextoUnitID)
	if (indextoInstanceIDsize ~= instanceIDtoIndexsize) or (instanceIDtoIndexsize ~= indextoUnitID) then
		Spring.Echo("Table size mismatch during validation of", iT.myName, indextoInstanceIDsize, instanceIDtoIndexsize, indextoUnitID)
	end

end

function locateInvalidUnits(iT)
	if iT.validinfo == nil then iT.validinfo = {} end
	local invalidcount = 0
	for i, unitID in ipairs(iT.indextoUnitID) do
		if iT.featureIDs then
			if Spring.ValidFeatureID(unitID) then
				local px, py, pz = Spring.GetFeaturePosition(unitID)
				local fdefname = FeatureDefs[Spring.GetFeatureDefID(unitID)].name
				iT.validinfo[unitID] = {px = px, py = py, pz = pz, fdefname = fdefname}
			else
				Spring.SendCommands({"pause 1"})
				Spring.Echo("INVALID feature, last seen at", unitID)
				local vi = iT.validinfo[unitID]
				local markertext = tostring(unitID) .. "," .. dbgt(vi)
				Spring.MarkerAddPoint(vi.px, vi.py, vi.pz, markertext )
				invalidcount = invalidcount + 1
			end
		else
			if Spring.ValidUnitID(unitID) then
				local px, py, pz = Spring.GetUnitPosition(unitID)
				local unitDefID = Spring.GetUnitDefID(unitID)
				local unitdefname = (unitDefID and UnitDefs[unitDefID].name) or "unknown:nil"
				iT.validinfo[unitID] = {px = px, py = py, pz = pz, unitdefname = unitdefname}
			else
				Spring.SendCommands({"pause 1"})
				Spring.Echo(iT.myName, " INVALID unitID",unitID,"#elements", iT.usedElements, "last seen at tablepos:", i)

				local vi = iT.validinfo[unitID]
				local markertext = tostring(unitID) .. "," .. dbgt(vi)
				Spring.MarkerAddPoint(vi.px, vi.py, vi.pz, markertext )
				invalidcount = invalidcount + 1
			end
		end
	end
	return invalidcount
end

------------------------------END DEBUG HELPERS ---------------------------

function resizeInstanceVBOTable(iT)
	-- iT: the InstanceVBOTable to double in size 'dynamically' resize the VBO, to double its size
	-- this is called automatically when the existing instanceVBO gets full
	-- Also performs a busload of sanity checking
	-- Spring.Echo("instanceVBOTable full, resizing to double size",iT.myName, iT.usedElements,iT.maxElements)
	iT.maxElements = iT.maxElements * 2
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	newInstanceVBO:Define(iT.maxElements, iT.layout)

	if iT.instanceVBO then iT.instanceVBO:Delete() end -- release if previous one existed
	iT.instanceVBO = newInstanceVBO
	-- ok this needs some sanitation right here, with reporting.
	if iT.indextoUnitID then
		-- we need to walk through both tables at the same time, and virtually pop all invalid unit/featureIDs on a resize, or else face dire consequences (crashes) later on
		-- the tables we need to keep updated are:
		local new_instanceData = {}
		local new_instanceData_count = 0
		local new_usedElements = 0
		local new_instanceIDtoIndex = {}
		local new_indextoInstanceID = {}
		local new_indextoUnitID = {}
		local invalidcount = 0
		local iTStep = iT.instanceStep

		for i, objectID in ipairs(iT.indextoUnitID) do
			local isValidID = false
			if iT.featureIDs then isValidID = Spring.ValidFeatureID(objectID)
			else isValidID = Spring.ValidUnitID(objectID) end
			if isValidID then
				local offset = new_usedElements * iTStep
				for j = 1, iTStep do
					new_instanceData_count = new_instanceData_count + 1
					new_instanceData[new_instanceData_count] = iT.instanceData[j + offset]
				end
				new_usedElements = new_usedElements + 1
				local currentInstanceID = iT.indextoInstanceID[i]
				new_indextoInstanceID[new_usedElements] = iT.indextoInstanceID[i]
				new_indextoUnitID[new_usedElements] =  iT.indextoUnitID[i]
				new_instanceIDtoIndex[currentInstanceID] = new_usedElements
				--Spring.Echo("Resize:",currentInstanceID, iT.indextoUnitID[i] )
				invalidcount = invalidcount + 1
			else
				Spring.Echo("Warning: Found invalid unit/featureID",objectID,"at",i,"while resizing",iT.myName)
			end
		end

		if invalidcount == 0 then
			comparetables( iT.instanceData, new_instanceData, "instanceData")
			comparetables( iT.instanceIDtoIndex, new_instanceIDtoIndex, "instanceIDtoIndex")
			comparetables( iT.indextoInstanceID, new_indextoInstanceID, "indextoInstanceID")
			comparetables( iT.indextoUnitID, new_indextoUnitID, "indextoUnitID")
		end

		iT.instanceData = new_instanceData
		iT.usedElements = new_usedElements
		iT.instanceIDtoIndex = new_instanceIDtoIndex
		iT.indextoInstanceID = new_indextoInstanceID
		iT.indextoUnitID = new_indextoUnitID
	end

	iT.instanceVBO:Upload(iT.instanceData,nil,0,1,iT.usedElements * iT.instanceStep)

	if gldebugannotations then
		gl.ObjectLabel(GL_BUFFER, iT.instanceVBO:GetID(), iT.myName)
	end

	if iT.VAO then -- reattach new if updated :D
		iT.VAO:Delete()
		iT.VAO = makeVAOandAttach(iT.vertexVBO,iT.instanceVBO, iT.indexVBO)
	end

	if iT.indextoUnitID then
		if iT.featureIDs then
			iT.instanceVBO:InstanceDataFromFeatureIDs(iT.indextoUnitID, iT.unitIDattribID)
		else
			iT.instanceVBO:InstanceDataFromUnitIDs(iT.indextoUnitID, iT.unitIDattribID)
		end
	end
	return iT.maxElements
end

--[[ from Ivand:
instVBO:Upload({
        100, 0, 0,
        -100, 0, 0,
        0, 0, 100,
        0, 0, -100,
    }, 7, 1, 4, 6)
Here is how you upload starting from 1st element and starting from 4th element in Lua array (-100) and finishing with 6th element (0), essentially it will upload (-100, 0, 0) into 7th attribute of 2nd instance.
]]--

function pushElementInstance(iT,thisInstance, instanceID, updateExisting, noUpload, unitID)
	-- iT: instanceTable created with makeInstanceTable
	-- thisInstance: is a lua array of values to add to table, MUST BE INSTANCESTEP SIZED LUA ARRAY
	-- instanceID: an optional key given to the item, so it can be easily removed/updated by reference, defaults to the index of the instance in the buffer (1 based)
	-- updateExisting: allow updating an existing element (same instanceID key)
	-- noUpload: prevent the VBO from being uploaded, if you feel like you are going to do a lot of ops and wish to manually upload when done instead
	-- unitID: if given, it will store then unitID corresponding to this instance, and will try to update the InstanceDataFromUnitIDs for this unit
	-- returns: the index of the instanceID in the table on success, else nil
	if #thisInstance ~= iT.instanceStep then
		Spring.Echo("Trying to upload an oddly sized instance into",iT.myName, #thisInstance, "instead of ",iT.instanceStep)
		Spring.Debug.TraceFullEcho(20,20,20, "pushElementInstance Failure:"..iT.myName )
	end
	local iTusedElements = iT.usedElements
	local iTStep    = iT.instanceStep
	local endOffset = iTusedElements * iTStep
	if instanceID == nil then instanceID = nextInstanceID(iT) end
	local thisInstanceIndex = iT.instanceIDtoIndex[instanceID]

	if (iTusedElements + 1 ) >= iT.maxElements then -- add 1 extra for safety (not the best idea, but we seem to be running over it by 1)
		resizeInstanceVBOTable(iT)
		iTusedElements = iT.usedElements -- because during validation of unitIDs during resizing, we can decrease the actual size of the table!
		thisInstanceIndex = iT.instanceIDtoIndex[instanceID]  -- this too, can change, TODO, also do this in VBOIDtable!
	end

	if thisInstanceIndex == nil then -- new, register it
		thisInstanceIndex = iTusedElements + 1
		iT.usedElements   = iTusedElements + 1
		iT.instanceIDtoIndex[instanceID] = thisInstanceIndex
		iT.indextoInstanceID[thisInstanceIndex] = instanceID
	else -- pre-existing ID, update or bail
		if updateExisting == nil then
			Spring.Echo("Tried to add existing element to an instanceTable",iT.myName, instanceID)
			return nil
		else
			endOffset = (thisInstanceIndex - 1) * iTStep
		end
	end
	local instanceData = iT.instanceData
	for i =1, iTStep  do -- copy data, but fast
		instanceData[endOffset + i] =  thisInstance[i]
	end

	if unitID ~= nil then
		local isvalidid
		if iT.featureIDs then isvalidid = Spring.ValidFeatureID(unitID)
		else isvalidid = Spring.ValidUnitID(unitID) end
		if isvalidid == false then
			Spring.Echo("Error: Attempted to push an invalid unit/featureID",unitID, "into", iT.myName)
			noUpload = true
			Spring.Debug.TraceFullEcho(20,20,20,"invalid unit/featureID in " ..iT.myName)
		end
		iT.indextoUnitID[thisInstanceIndex] = unitID
	end

	if noUpload ~= true then --upload or mark as dirty
		iT.instanceVBO:Upload(thisInstance, nil, thisInstanceIndex - 1)
		--Spring.Echo("pushElementInstance,unitID, iT.unitIDattribID, thisInstanceIndex",unitID, iT.unitIDattribID, thisInstanceIndex)
		if unitID ~= nil then
			if iT.featureIDs then
				iT.instanceVBO:InstanceDataFromFeatureIDs(unitID, iT.unitIDattribID, thisInstanceIndex-1)
			else
				iT.instanceVBO:InstanceDataFromUnitIDs(unitID, iT.unitIDattribID, thisInstanceIndex-1)
			end
		end
	else
		iT.dirty = true
	end

	if iT.debug then validateInstanceVBOTable(iT, 'push') end
	return instanceID
end

function popElementInstance(iT, instanceID, noUpload)
	-- iT: instanceTable created with makeInstanceTable
	-- instanceID: an optional key given to the item, so it can be easily removed by reference, defaults to the last element of the buffer, but this will screw up the instanceIDtoIndex table if used in mixed keys mode
	-- noUpload: prevent the VBO from being uploaded, if you feel like you are going to do a lot of ops and wish to manually upload when done instead
	-- returns nil on failure, the the index of the element on success
	if instanceID == nil then
		Spring.Echo("Tried to remove element with nil instanceID from instanceTable " .. iT.myName)
		return nil
	end

	if iT.instanceIDtoIndex[instanceID] == nil then -- if key is instanceID yet does not exist, then warn and bail
		Spring.Echo("Tried to remove element ",instanceID,'From instanceTable', iT.myName, 'but it does not exist in it')
		Spring.Debug.TraceFullEcho(10,10,3, iT.myName)
		return nil
	end
	if iT.usedElements == 0 then -- Dont remove the last element
		Spring.Echo("Tried to remove element ",instanceID,'From instanceTable', iT.myName, 'but it should be empty')
		return nil
	end

	--Fetch the position of the element we want to remove from the 'middle' of the table
	local oldElementIndex = iT.instanceIDtoIndex[instanceID]
	iT.instanceIDtoIndex[instanceID] = nil -- clean these out
	iT.indextoInstanceID[oldElementIndex] = nil

	-- get the index of the last element
	local lastElementIndex = iT.usedElements

	-- if this one was already at the end of the queue, do nothing but decrement usedElements and clear mappings
	if oldElementIndex == lastElementIndex then
		--Spring.Echo("Removed end element of instanceTable", iT.myName)
		iT.usedElements = iT.usedElements - 1
		-- if it had a related unitID stored, remove that:
		if iT.indextoUnitID then iT.indextoUnitID[oldElementIndex] = nil end

		if iT.debugZombies then
			if iT.zombies and iT.zombies[instanceID] then
				--Spring.Echo("Good, we are killing a stupid zombie at the end", instanceID, iT.numZombies)
				iT.zombies[instanceID] = nil
				iT.numZombies = iT.numZombies - 1
			end
		end

	else
		local lastElementInstanceID = iT.indextoInstanceID[lastElementIndex]
		if lastElementInstanceID == nil then --
			Spring.Echo("We somehow have a nil element at the back of the array, which is completely invalid, probably about to crash", iT.myName)
			dbgt(iT.instanceIDtoIndex, "instanceIDtoIndex")
			dbgt(iT.indextoInstanceID, "indextoInstanceID")
			dbgt(iT.indextoUnitID, "indextoUnitID")
		end
		local iTStep = iT.instanceStep
		local endOffset = (iT.usedElements - 1)*iTStep

		iT.instanceIDtoIndex[lastElementInstanceID] = oldElementIndex -- lastElementInstanceID was somehow nil here?
		iT.indextoInstanceID[oldElementIndex] = lastElementInstanceID
		iT.indextoInstanceID[lastElementIndex] = nil --- somehow this got forgotten? TODO for VBOIDtable

		local oldOffset = (oldElementIndex-1)*iTStep
		local instanceData = iT.instanceData
		for i = 1, iTStep do
			instanceData[oldOffset + i ] = instanceData[endOffset + i]
		end
		--size_t LuaVBOImpl::Upload(const sol::stack_table& luaTblData, const sol::optional<int> attribIdxOpt, const sol::optional<int> elemOffsetOpt, const sol::optional<int> luaStartIndexOpt, const sol::optional<int> luaFinishIndexOpt)
		--Spring.Echo("Removing instanceID",instanceID,"from iT at position", oldElementIndex, "shuffling back at", iT.usedElements,"endoffset=",endOffset,'oldOffset=',oldOffset)
		if noUpload ~= true then
			--Spring.Echo("Upload", oldElementIndex -1, oldOffset+1, oldOffset+iTStep)
			iT.instanceVBO:Upload(iT.instanceData,nil,oldElementIndex-1,oldOffset +1,oldOffset + iTStep)
		else
			iT.dirty = true
		end
		-- Do the unitID shuffle if needed:
		if iT.indextoUnitID then
			--Spring.Echo("popElementInstance,unitID, iT.unitIDattribID, thisInstanceIndex",unitID, iT.unitIDattribID, oldElementIndex)
			local popunitID = iT.indextoUnitID[lastElementIndex]
			if popunitID == nil then
				Spring.Echo("TODO: what the f is happening here?, how the f could we have popped a nil from the back of?", iT.myName) -- TODO TODO
			end

			if iT.debugZombies then
				local gf = Spring.GetGameFrame()
				--Spring.Echo("Popping", instanceID)
				if iT.lastpopgameframe == nil then
					iT.lastpopgameframe = gf
					iT.zombies = {}
					iT.numZombies = 0
				else
					if iT.lastpopgameframe ~= gf then -- New gameframe
						iT.lastpopgameframe = gf
						if iT.numZombies and iT.numZombies > 0 then -- WE HAVE ZOMBIES AAAAARGH
							local s = "Warning: We have " .. tostring(iT.numZombies) .. " zombie units left over in " .. iT.myName
							for zombie, gf in pairs(iT.zombies) do
								s = s .. " " .. tostring(zombie) ..'/'..tostring(gf)
								Spring.Echo("ZOMBIE instanceID", zombie, 'gf',gf)
								--Spring.SendCommands({"pause 1"})
								Spring.Debug.TraceFullEcho(nil,nil,nil, iT.myName)
							end
							Spring.Echo(s)
							iT.zombies = {}
							iT.numZombies = 0
						end
					else -- same gameframe
						if iT.zombies[instanceID] then
							--Spring.Echo("Good, we are killing a stupid zombie", gf, instanceID, iT.numZombies)
							iT.zombies[instanceID] = nil
							iT.numZombies = iT.numZombies - 1
						end
					end
				end
			end

			iT.indextoUnitID[oldElementIndex] = popunitID
			iT.indextoUnitID[lastElementIndex] = nil

			if (iT.featureIDs and Spring.ValidFeatureID(popunitID)) or Spring.ValidUnitID(popunitID) then
				if noUpload ~= true then
					if iT.featureIDs then
						iT.instanceVBO:InstanceDataFromFeatureIDs(popunitID, iT.unitIDattribID, oldElementIndex-1)
					else
						iT.instanceVBO:InstanceDataFromUnitIDs(popunitID, iT.unitIDattribID, oldElementIndex-1)
					end
				end
			else
				if iT.debugZombies then
					--Spring.Echo("Warning: Tried to pop back an invalid" .. ((iT.featureIDs and "featureID") or "unitID"), popunitID, "from", iT.myName, "while removing instance", instanceID, counttable(iT.instanceIDtoIndex), counttable(iT.indextoInstanceID), counttable(iT.indextoUnitID))
					--Spring.Debug.TraceFullEcho()
					local gf = Spring.GetGameFrame()
					if iT.lastpopgameframe == nil or iT.lastpopgameframe ~= gf then -- New gameframe
						iT.lastpopgameframe = gf
						iT.zombies = {}
						iT.numZombies = 0
					end
					if iT.zombies[lastElementInstanceID] == nil then
						iT.zombies[lastElementInstanceID] = gf
						iT.numZombies = iT.numZombies + 1
					end
				end
			end
		end
		iT.usedElements = iT.usedElements - 1
	end

	if iT.debug then validateInstanceVBOTable(iT,'pop') end
	return oldElementIndex
end

function getElementInstanceData(iT, instanceID, cacheTable)
	-- iT: instanceTable created with makeInstanceTable
	-- instanceID: an optional key given to the item, so it can be easily removed by reference, defaults to the index of the instance in the buffer (1 based)
	local instanceIndex = iT.instanceIDtoIndex[instanceID]
	if instanceIndex == nil then
		Spring.Echo("Tried to getElementInstanceData from",iT.myName,instanceID, "but it does not exist")
		return nil
	end
	local iData = cacheTable or {}
	local iTStep = iT.instanceStep
	instanceIndex = (instanceIndex-1) * iTStep
	local instanceData = iT.instanceData
	for i = 1, iTStep do
		iData[i] = instanceData[instanceIndex + i]
	end
	return iData
end

function uploadAllElements(iT)
	-- upload all USED elements
	if iT.usedElements == 0 then return end

	iT.instanceVBO:Upload(iT.instanceData,nil,0, 1, iT.usedElements * iT.instanceStep)
	iT.dirty = false
	if iT.indextoUnitID then
		if iT.featureIDs then
			iT.instanceVBO:InstanceDataFromFeatureIDs(iT.indextoUnitID, iT.unitIDattribID)
		else
			iT.instanceVBO:InstanceDataFromUnitIDs(iT.indextoUnitID, iT.unitIDattribID)
		end
	end
end

function uploadElementRange(iT, startElementIndex, endElementIndex)
	iT.instanceVBO:Upload(iT.instanceData, -- The lua mirrored VBO data
		nil, -- the attribute index, nil for all attributes
		startElementIndex, -- vboOffset optional, , what ELEMENT offset of the VBO to start uploading into, 0 based
		startElementIndex * iT.instanceStep + 1, --  luaStartIndex, default 1, what element of the lua array to start uploading from. 1 is the 1st element of a lua table.
		endElementIndex * iT.instanceStep --] luaEndIndex, default #{array}, what element of the lua array to upload up to, inclusively
	)
	if iT.indextoUnitID then
		--we need to reslice the table
		local unitIDRange = {}
		local indextoUnitID = iT.indextoUnitID
		for i = startElementIndex, endElementIndex do
			unitIDRange[#unitIDRange + 1] = indextoUnitID[i]
		end
		if iT.featureIDs then
			iT.instanceVBO:InstanceDataFromFeatureIDs(unitIDRange, iT.unitIDattribID, startElementIndex - 1)
		else
			iT.instanceVBO:InstanceDataFromUnitIDs(unitIDRange, iT.unitIDattribID, startElementIndex - 1)
		end
	end
end

-- This function allows for order-preserving compacting of a list of instances based on these funcs.
-- It is designed for Decals GL4, where draw order matters a lot!
-- remove takes priority over keep
function compactInstanceVBO(iT, removelist, keeplist)
	local usedElements = iT.usedElements
	if usedElements == 0 then return 0 end
	local instanceStep = iT.instanceStep
	local instanceData = iT.instanceData
	local indextoInstanceID = iT.indextoInstanceID
	local newindextoInstanceID = {}
	local newinstanceIDtoIndex = {}
	local newUsedElements = 0
	local numremoved = 0
	local removemode = (removelist ~= nil) and (keeplist == nil)
	for index, instanceID in ipairs(indextoInstanceID) do
		-- If its in keeplist,
		if (removemode and (removelist[instanceID]== nil) ) or ((removemode == false) and keeplist[instanceID]) then
			local instanceOffset = (index-1) * instanceStep
			local newInstanceOffset = newUsedElements * instanceStep
			for i = 1, instanceStep do
				instanceData[newInstanceOffset + i] = instanceData[instanceOffset + i]
			end
			newUsedElements = newUsedElements + 1
			newindextoInstanceID[newUsedElements] = instanceID
			newinstanceIDtoIndex[instanceID] = newUsedElements
		else
			numremoved = numremoved + 1
		end
	end
	if numremoved > 0 then
		iT.dirty = true -- we set the flag to notify that CPU and GPU contents dont match!
		iT.usedElements = newUsedElements
		iT.instanceIDtoIndex = newinstanceIDtoIndex
		iT.indextoInstanceID = newindextoInstanceID
	end
	return numremoved
end

function drawInstanceVBO(iT)
	if iT.usedElements > 0 then
		if iT.indexVBO then
			iT.VAO:DrawElements(iT.primitiveType, iT.numVertices, 0, iT.usedElements,0)
		else
			iT.VAO:DrawArrays(iT.primitiveType, iT.numVertices, 0, iT.usedElements,0)
		end
	end
end

function countInvalidUnitIDs(iT)
	local invalids = {}
	for i, objectID in ipairs(iT.indextoUnitID) do
		local isValidID = false
		if iT.featureIDs then isValidID = Spring.ValidFeatureID(objectID)
		else isValidID = Spring.ValidUnitID(objectID) end
		if isValidID then

		else
			invalids[#invalids + 1] = objectID
		end
	end
	if #invalids > 0 then
		Spring.Echo(#invalids, "invalid IDs found in ", iT.myName)
	end
	return invalids
end


--------- HELPERS FOR PRIMITIVES ------------------

function makeCircleVBO(circleSegments, radius, startCenter, name)
	-- Makes circle of radius in xy space
	-- can be used in both GL.LINES and GL.TRIANGLE_FAN mode
	-- Startcenter places a vertex in the center, this is nice for triangle fans,
	-- but when drawing lines with this vbo, start at an offset of 1
	-- Fun note: its NOT faster to draw stenciled circles with this. 
	if not radius then radius = 1 end
	circleSegments  = circleSegments -1 -- for po2 buffers
	local circleVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if circleVBO == nil then return nil end

	local VBOLayout = {
		{id = 0, name = "position", size = 4},
	}

	local VBOData = {}
	if startCenter then
		VBOData[#VBOData+1] = 0 -- X
		VBOData[#VBOData+1] = 0 -- Y
		VBOData[#VBOData+1] = 0 -- circumference [0-1]
		VBOData[#VBOData+1] = radius
	end

	for i = 0, circleSegments  do -- this is +1
		VBOData[#VBOData+1] = math.sin(math.pi*2* i / circleSegments) * radius -- X
		VBOData[#VBOData+1] = math.cos(math.pi*2* i / circleSegments) * radius-- Y
		VBOData[#VBOData+1] = i / circleSegments -- circumference [0-1]
		VBOData[#VBOData+1] = radius
	end

	circleVBO:Define(
		circleSegments + 1 + (startCenter and 1 or 0) , -- +1 for center point if startCenter is true
		VBOLayout
	)
	circleVBO:Upload(VBOData)
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, circleVBO:GetID(), name or "CircleVBO")
	end
	return circleVBO, #VBOData/4
end

function makePlaneVBO(xsize, ysize, xresolution, yresolution, name) -- makes a plane from [-xsize to xsize] with xresolution subdivisions
	if not xsize then xsize = 1 end
	if not ysize then ysize = xsize end
	if not xresolution then xresolution = 1 end
	if not yresolution then yresolution = xresolution end
	xresolution = math.floor(xresolution)
	yresolution = math.floor(yresolution)
	local planeVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	if planeVBO == nil then return nil end

	local VBOLayout = {
		{id = 0, name = "xyworld_xyfract", size = 2},
	}

	local VBOData = {}

	for x = 0, xresolution  do -- this is +1
		for y = 0, yresolution do
			VBOData[#VBOData+1] = xsize * ((x / xresolution) -0.5 ) *2
			VBOData[#VBOData+1] = ysize * ((y / yresolution) -0.5 ) * 2
		end
	end

	planeVBO:Define(
		(xresolution + 1) * (yresolution + 1) ,
		VBOLayout
	)
	planeVBO:Upload(VBOData)

	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, planeVBO:GetID(), name or "PlaneVBO")
	end

	--Spring.Echo("PlaneVBOData up:",#VBOData, "Down", #planeVBO:Download())
	return planeVBO, #VBOData/2
end

function makePlaneIndexVBO(xresolution, yresolution, cutcircle, name)
	xresolution = math.floor(xresolution)
	if not yresolution then yresolution = xresolution end
	local planeIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	if planeIndexVBO == nil then return nil end

	local function xyinrad(lx, ly)
		local px = (lx / xresolution) * 2 - 1
		local py = (ly / yresolution) * 2 - 1
		return (px*px + py*py) <= 1
	end

	local IndexVBOData = {}
	local qindex = 0
	local colsize = yresolution + 1
	for x = 0, xresolution-1  do -- this is +1
		for y = 0, yresolution-1 do
			--this is only 20% optimization
			if cutcircle == nil or (xyinrad(x,y) or xyinrad(x + 1,y) or xyinrad(x,y + 1 )) then
				-- top left one
				IndexVBOData[#IndexVBOData + 1] = qindex
				IndexVBOData[#IndexVBOData + 1] = qindex +1
				IndexVBOData[#IndexVBOData + 1] = qindex + colsize
			end

			if cutcircle == nil or (xyinrad(x+1,y+1) or xyinrad(x + 1,y) or xyinrad(x,y + 1 )) then
				-- bottom right one?
				IndexVBOData[#IndexVBOData + 1] = qindex +1
				IndexVBOData[#IndexVBOData + 1] = qindex + colsize + 1
				IndexVBOData[#IndexVBOData + 1] = qindex + colsize
			end
			qindex = qindex + 1

		end
		qindex = qindex + 1
	end
	planeIndexVBO:Define(
		#	IndexVBOData
	)
	planeIndexVBO:Upload(IndexVBOData)
	
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, planeIndexVBO:GetID(), name or "planeIndexVBO")
	end
	--Spring.Echo("PlaneIndexVBO up:",#IndexVBOData, "Down", #planeIndexVBO:Download())
	return planeIndexVBO, IndexVBOData
end

function makePointVBO(numPoints, randomFactor, name)
	-- makes points with xyzw
	-- can be used in both GL.LINES and GL.TRIANGLE_FAN mode
	numPoints = numPoints or 1
	randomFactor = randomFactor or 0
	local pointVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if pointVBO == nil then return nil end

	local VBOLayout = {
		{id = 0, name = "position_w", size = 4},
	}

	local VBOData = {}

	for i = 1, numPoints  do --
		VBOData[#VBOData+1] = randomFactor * math.random()-- X
		VBOData[#VBOData+1] = randomFactor * math.random()-- Y
		VBOData[#VBOData+1] = randomFactor * math.random()---Z
		VBOData[#VBOData+1] = i/numPoints -- index for lolz?
	end

	pointVBO:Define(
		numPoints,
		VBOLayout
	)
	pointVBO:Upload(VBOData)
	
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, pointVBO:GetID(), name or "pointVBO")
	end
	return pointVBO, numPoints
end

function makeRectVBO(minX,minY, maxX, maxY, minU, minV, maxU, maxV, name)
	if minX == nil then
		minX, minY, maxX, maxY, minU, minV, maxU, maxV  = 0,0,1,1,0,0,1,1
	end
	-- makes points with xyzw
	-- can be used in both GL.LINES and GL.TRIANGLE_FAN mode
	local rectVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	if rectVBO == nil then return nil end

	local VBOLayout = {
		{id = 0, name = "position_xy_uv", size = 4},
	}

	local VBOData = {
		--bl
		minX,minY, minU, minV, --bl
		minX,maxY, minU, maxV, --tr
		maxX,maxY, maxU, maxV, --tr
		maxX,maxY, maxU, maxV, --tr
		maxX,minY, maxU, minV, --br
		minX,minY, minU, minV, --bl
	}

	rectVBO:Define(
		6,
		VBOLayout
	)
	rectVBO:Upload(VBOData)
	
	if gldebugannotations then
		gl.ObjectLabel(GL_BUFFER, rectVBO:GetID(), name or "rectVBO")
	end
	return rectVBO, 6
end

function makeRectIndexVBO(name)
	local rectIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	if rectIndexVBO == nil then return nil end

	rectIndexVBO:Define(
		6
	)
	rectIndexVBO:Upload({0,1,2,3,4,5})
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, rectIndexVBO:GetID(), name or "rectIndexVBO")
	end
	return rectIndexVBO,6
end



function makeConeVBO(numSegments, height, radius, name)
	-- make a cone that points up, (y = height), with radius specified
	-- returns the VBO object, and the number of elements in it (usually ==  numvertices)
	-- needs GL.TRIANGLES
	if not height then height = 1 end
	if not radius then radius = 1 end
	local coneVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if coneVBO == nil then return nil end

	local VBOData = {}

	for i = 1, numSegments do
		-- center vertex
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = (i - 1) / numSegments

		--- first cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = -1* math.cos(math.pi*2* (i - 1) / numSegments) * radius-- Y
		VBOData[#VBOData+1] = (i - 1) / numSegments

		--- second cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius-- X
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = -1* math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 0) / numSegments

		-- top vertex
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = height
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = (i - 1) / numSegments

		--- first cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius -- X
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 0) / numSegments

		--- second cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 1) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 1) / numSegments
	end


	coneVBO:Define(#VBOData/4,	{{id = 0, name = "localpos_progress", size = 4}})
	coneVBO:Upload(VBOData)

	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, coneVBO:GetID(), name or "coneVBO")
	end

	return coneVBO, #VBOData/4
end



function makeCylinderVBO(numSegments, height, radius, hastop, hasbottom, name)
	-- make a cylinder that points up, (y = height), with radius specified
	-- returns the VBO object, and the number of elements in it (usually ==  numvertices)
	-- needs GL.TRIANGLES
	if not height then height = 1 end
	if not radius then radius = 1 end
	local cylinderVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if cylinderVBO == nil then return nil end

	local VBOData = {}

	for i = 1, numSegments do
		if hasbottom then
			-- center vertex
			VBOData[#VBOData+1] = 0
			VBOData[#VBOData+1] = -1* height
			VBOData[#VBOData+1] = 0
			VBOData[#VBOData+1] = (i - 1) / numSegments

			--- first cone flat
			VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
			VBOData[#VBOData+1] = -1* height
			VBOData[#VBOData+1] = -1* math.cos(math.pi*2* (i - 1) / numSegments) * radius-- Y
			VBOData[#VBOData+1] = (i - 1) / numSegments

			--- second cone flat
			VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius-- X
			VBOData[#VBOData+1] = -1* height
			VBOData[#VBOData+1] = -1* math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
			VBOData[#VBOData+1] =(i - 0) / numSegments
		end


		--- first cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius -- X
		VBOData[#VBOData+1] = height
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 0) / numSegments

		--- second cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
		VBOData[#VBOData+1] = height
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 1) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 1) / numSegments



		--- first cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius -- X
		VBOData[#VBOData+1] = -1 * height
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 0) / numSegments

		--- second cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
		VBOData[#VBOData+1] = height
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 1) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 1) / numSegments


		--- first cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius -- X
		VBOData[#VBOData+1] = -1 * height
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 0) / numSegments


		--- second cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
		VBOData[#VBOData+1] = -1 * height
		VBOData[#VBOData+1] = -1*math.cos(math.pi*2* (i - 1) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 1) / numSegments



		if hastop then
			-- center vertex
			VBOData[#VBOData+1] = 0
			VBOData[#VBOData+1] = height
			VBOData[#VBOData+1] = 0
			VBOData[#VBOData+1] = (i - 1) / numSegments

			--- first cone flat
			VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
			VBOData[#VBOData+1] = height
			VBOData[#VBOData+1] = -1* math.cos(math.pi*2* (i - 1) / numSegments) * radius-- Y
			VBOData[#VBOData+1] = (i - 1) / numSegments

			--- second cone flat
			VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius-- X
			VBOData[#VBOData+1] = height
			VBOData[#VBOData+1] = -1* math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
			VBOData[#VBOData+1] =(i - 0) / numSegments
		end
	end


	cylinderVBO:Define(#VBOData/4,	{{id = 0, name = "localpos_progress", size = 4}})
	cylinderVBO:Upload(VBOData)
	
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, cylinderVBO:GetID(), name or "cylinderVBO")
	end

	return cylinderVBO, #VBOData/4
end



function makeBoxVBO(minX, minY, minZ, maxX, maxY, maxZ, name) -- make a box
	-- needs GL.TRIANGLES
	local boxVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if boxVBO == nil then return nil end

	local VBOData = {
		minX,minY,minZ,0
		,minX,minY,maxZ,0
		,minX,maxY,maxZ,0
		,maxX,maxY,minZ,0
		,minX,minY,minZ,0
		,minX,maxY,minZ,0
		,maxX,minY,maxZ,0
		,minX,minY,minZ,0
		,maxX,minY,minZ,0
		,maxX,maxY,minZ,0
		,maxX,minY,minZ,0
		,minX,minY,minZ,0
		,minX,minY,minZ,0
		,minX,maxY,maxZ,0
		,minX,maxY,minZ,0
		,maxX,minY,maxZ,0
		,minX,minY,maxZ,0
		,minX,minY,minZ,0
		,minX,maxY,maxZ,0
		,minX,minY,maxZ,0
		,maxX,minY,maxZ,0
		,maxX,maxY,maxZ,0
		,maxX,minY,minZ,0
		,maxX,maxY,minZ,0
		,maxX,minY,minZ,0
		,maxX,maxY,maxZ,0
		,maxX,minY,maxZ,0
		,maxX,maxY,maxZ,0
		,maxX,maxY,minZ,0
		,minX,maxY,minZ,0
		,maxX,maxY,maxZ,0
		,minX,maxY,minZ,0
		,minX,maxY,maxZ,0
		,maxX,maxY,maxZ,0
		,minX,maxY,maxZ,0
		,maxX,minY,maxZ,0
	}
	boxVBO:Define(#VBOData/4,	{{id = 0, name = "localpos_progress", size = 4}})
	boxVBO:Upload(VBOData)
	
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, boxVBO:GetID(), name or "boxVBO")
	end

	return boxVBO, #VBOData/4
end



---Generate a sphere vertex VBO and the corresponding indexVBO
---The sphere is oriented in the Z direction
---Layout:
---{id = 0, name = "position", size = 4}, -- cake slices along Z, w is sector angle.
---{id = 1, name = "normals", size = 3}, -- normal vector
---{id = 2, name = "uvs", size = 2}, -- UV vector, where x goes around the belly and y goes along Z
---@param sectorCount number is the number of orange slices around the belly in XY
---@param stackCount number how many horizontal slices along Z, usually less than sectorcount
---@param radius number how many elmos in radius, default 1
function makeSphereVBO(sectorCount, stackCount, radius, name) -- http://www.songho.ca/opengl/gl_sphere.html


	local sphereVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if sphereVBO == nil then return nil end
	local vertVBOLayout = {
		{id = 0, name = "position", size = 4},
		{id = 1, name = "normals", size = 3},
		{id = 2, name = "uvs", size = 2},
	}

	local VBOData = {}
	radius = radius or 1
	local x, y, z, xy; --  vertex position
	local nx, ny, nz
	local lengthInv = 1.0 / radius;    -- vertex normal
	local s, t;                                     -- vertex texCoord

	local sectorStep = 2 * math.pi / sectorCount;
	local stackStep = math.pi / stackCount;
	local sectorAngle, stackAngle;

	for i = 0, stackCount do

		stackAngle = math.pi / 2 - i * stackStep;        -- starting from pi/2 to -pi/2
		xy = radius * math.cos(stackAngle);             -- r * cos(u)
		z = radius * math.sin(stackAngle);              -- r * sin(u)

		-- add (sectorCount+1) vertices per stack
		-- the first and last vertices have same position and normal, but different tex coords
		for j = 0, sectorCount do -- for (int j = 0; j <= sectorCount; ++j)

			sectorAngle = j * sectorStep;           -- starting from 0 to 2pi

			-- vertex position (x, y, z)
			x = xy * math.cos(sectorAngle);             -- r * cos(u) * cos(v)
			y = xy * math.sin(sectorAngle);             -- r * cos(u) * sin(v)
			VBOData[#VBOData + 1] = x;
			VBOData[#VBOData + 1] = y;
			VBOData[#VBOData + 1] = z;
			VBOData[#VBOData + 1] = sectorAngle;
			--Spring.Echo(x,y,z)
			-- normalized vertex normal (nx, ny, nz)
			nx = x * lengthInv;
			ny = y * lengthInv;
			nz = z * lengthInv;


			VBOData[#VBOData + 1] = nx;
			VBOData[#VBOData + 1] = ny;
			VBOData[#VBOData + 1] = nz;

			-- vertex tex coord (s, t) range between [0, 1]
			s = j / sectorCount;
			t = i / stackCount;

			VBOData[#VBOData + 1] = s;
			VBOData[#VBOData + 1] = t;
		end
	end
	sphereVBO:Define(#VBOData/9, vertVBOLayout)
	sphereVBO:Upload(VBOData)
	
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, sphereVBO:GetID(), name or "sphereVBO")
	end

	local numVerts = #VBOData/9

	local sphereIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	VBOData = {}

	-- generate CCW index list of sphere triangles
	-- k1--k1+1
	-- |  / |
	-- | /  |
	-- k2--k2+1
	local k1, k2
	for i = 0, stackCount-1 do -- for(int i = 0; i < stackCount; ++i)

		k1 = i * (sectorCount + 1)     -- beginning of current stack
		k2 = k1 + sectorCount + 1      -- beginning of next stack

		for j = 0, sectorCount-1   do --for(int j = 0; j < sectorCount; ++j, ++k1, ++k2)
			--	Spring.Echo('indices', k1, k2)
			-- 2 triangles per sector excluding first and last stacks
			-- k1 => k2 => k1+1
			if i ~= 0 then

				VBOData[#VBOData + 1] = k1
				VBOData[#VBOData + 1] = k2
				VBOData[#VBOData + 1] = k1 + 1
			end

			-- k1+1 => k2 => k2+1
			if i ~= (stackCount-1)	 then

				VBOData[#VBOData + 1] = k1 + 1
				VBOData[#VBOData + 1] = k2
				VBOData[#VBOData + 1] = k2 + 1

			end

			k1 = k1 + 1
			k2 = k2 + 1
		end
	end


	sphereIndexVBO:Define(#VBOData)
	sphereIndexVBO:Upload(VBOData)
		
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, sphereIndexVBO:GetID(), name or "sphereIndexVBO")
	end

	return sphereVBO, numVerts, sphereIndexVBO, #VBOData
end


function MakeTexRectVAO(minX,minY, maxX, maxY, minU, minV, maxU, maxV, name)
	-- Draw with myGL4TexRectVAO:DrawArrays(GL.TRIANGLES)
	minX,minY,maxX,maxY,minU,minV,maxU,maxV  = minX or -1,minY or -1,maxX or 1, maxY or 1, minU or 0, minV or 0, maxU or 1, maxV or 1

	local myGL4TexRectVAO
	local rectVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	if rectVBO == nil then return nil end

	--rectVBO:Define(	6,	{{id = 0, name = "position_xy_uv", size = 8}})
	local z = 0.5
	local w = 1
	rectVBO:Define(	6,	{{id = 0, name = "pos", size = 4}})
	rectVBO:Upload({
			
		minX,minY, minU, minV, --bl
		maxX,maxY, maxU, maxV, --tr
		minX,maxY, minU, maxV, --tl
		maxX,maxY, maxU, maxV, --tr
		minX,minY, minU, minV, --bl
		maxX,minY, maxU, minV, --br
			})
	
	
	if gldebugannotations then 
		gl.ObjectLabel(GL_BUFFER, rectVBO:GetID(), name or "rectVBO")
	end
			
	myGL4TexRectVAO = gl.GetVAO()
	if myGL4TexRectVAO == nil then return nil end
	myGL4TexRectVAO:AttachVertexBuffer(rectVBO)
	return myGL4TexRectVAO
end