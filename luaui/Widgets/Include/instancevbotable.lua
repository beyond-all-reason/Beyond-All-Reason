function makeInstanceVBOTable(layout, maxElements, myName)
	-- layout: this must be an array of tables with at least the following specified: {{id = 1, name = 'optional', size = 4}}
	-- maxElements: will be dynamic anyway, but defaults to 64
	-- myName: optional name, useful for debugging
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
		instanceVBO = newInstanceVBO,
		instanceData = instanceData,
		instanceStep = instanceStep,
		usedElements = 0,
		maxElements = maxElements,
		myName = myName,
		instanceIDtoIndex = {}, -- this maps each instance ID to where it is in the buffer, 1 based
		indextoInstanceID = {}, -- this tells us what instanceID is located in any given pos
		layout = layout,
		dirty = false,
		numVertices = 0,
	}
	newInstanceVBO:Upload(instanceData)
	return instanceTable
end

function clearInstanceTable(iT) 
	-- this wont resize it, but quickly sets it to empty
	iT.usedElements = 0
	iT.instanceIDtoIndex = {}
end

function makeVAOandAttach(vertexVBO, instanceVBO) -- return a VAO
	local newVAO = nil 
	newVAO = gl.GetVAO()
	if newVAO == nil then goodbye("Failed to create newVAO") end
	newVAO:AttachVertexBuffer(vertexVBO)
	newVAO:AttachInstanceBuffer(instanceVBO)
	return newVAO
end

function resizeInstanceVBOTable(iT)
	-- iT: the InstanceVBOTable to double in size 'dynamically' resize the VBO, to double its size
	iT.maxElements = iT.maxElements * 2
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	newInstanceVBO:Define(iT.maxElements, iT.layout)
	for i = (iT.maxElements/2)*iT.instanceStep, (iT.maxElements)*iT.instanceStep do
		iT.instanceData[i] = 0
	end
	iT.instanceVBO = nil
	iT.instanceVBO = newInstanceVBO
	iT.instanceVBO:Upload(iT.instanceData)
	if iT.VAO and iT.vertexVBO then -- reattach new if updated :D
		iT.VAO = makeVAOandAttach(iT.vertexVBO,iT.instanceVBO)
	end
	Spring.Echo("instanceVBOTable full, resizing to double size",iT.myName, iT.usedElements,iT.maxElements)
	--return nil
end

function pushElementInstance(iT,thisInstance, instanceID, updateExisting, noUpload) 
	-- iT: instanceTable created with makeInstanceTable
	-- thisInstance: is a lua array of values to add to table, MUST BE INSTANCESTEP SIZED LUA ARRAY
	-- instanceID: an optional key given to the item, so it can be easily removed/updated by reference, defaults to the index of the instance in the buffer (1 based)
	-- updateExisting: allow updating an existing element (same instanceID key)
	-- noUpload: prevent the VBO from being uploaded, if you feel like you are going to do a lot of ops and wish to manually upload when done instead
	-- returns: the index of the instanceID in the table on success, else nil
	local iTusedElements = iT.usedElements
	local iTStep    = iT.instanceStep 
	local endOffset = iTusedElements*iTStep
	if instanceID == nil then instanceID = iTusedElements + 1 end
	local thisInstanceIndex = iT.instanceIDtoIndex[instanceID] 

	if iTusedElements >= iT.maxElements then
		resizeInstanceVBOTable(iT)
	end
	
	if thisInstanceIndex == nil then -- new, register it
		thisInstanceIndex = iTusedElements + 1
		iT.usedElements   = iTusedElements + 1 --THE WHOLE THING IS PROBABLY OFF BY 1 !!!
		iT.instanceIDtoIndex[instanceID] = thisInstanceIndex
		iT.indextoInstanceID[thisInstanceIndex] = instanceID
	else -- pre-existing ID, update or bail
		if updateExisting == nil then
			Spring.Echo("Tried to add existing element to an instanceTable",iT.myName, instanceID)
			return nil
		else
			endOffset = (thisInstanceIndex - 1)*iTStep
		end
	end
	
	for i =1, iTStep  do -- copy data, but fast
		iT.instanceData[endOffset + i] =  thisInstance[i]
	end
	
	if noUpload ~= true then --upload or mark as dirty
		iT.instanceVBO:Upload(thisInstance,nil,(thisInstanceIndex -1))
	else
		iT.dirty = true
	end
	
	return thisInstanceIndex
end

function popElementInstance(iT, instanceID, noUpload) 
	-- iT: instanceTable created with makeInstanceTable
	-- instanceID: an optional key given to the item, so it can be easily removed by reference, defaults to the last element of the buffer, but this will screw up the instanceIDtoIndex table if used in mixed keys mode
	-- noUpload: prevent the VBO from being uploaded, if you feel like you are going to do a lot of ops and wish to manually upload when done instead
	-- returns nil on failure, the the index of the element on success
	if instanceID == nil then instanceID = iT.usedElements  end
	
	if iT.instanceIDtoIndex[instanceID] == nil then -- sanity
		Spring.Echo("Tried to remove element ",instanceID,'From instanceTable', iT.myName, 'but it does not exist in it')
		return nil 
	end
	if iT.usedElements == 0 then -- sanity
		Spring.Echo("Tried to remove element ",instanceID,'From instanceTable', iT.myName, 'but it should be empty')
		return nil 
	end
	-- BUG BUG, while the data itself is being shuffled back, the instanceIDtoIndex is not being updated, as we dont know the last element being added?
	local oldElementIndex = iT.instanceIDtoIndex[instanceID]
	iT.instanceIDtoIndex[instanceID] = nil -- clean these out
	iT.indextoInstanceID[oldElementIndex] = nil 
	
	-- get the data of the last ones:
	local lastElementIndex = iT.usedElements
	
		-- if this one was already at the end of the queue, do nothing but decrement usedElements and clear mappings 
	if oldElementIndex == lastElementIndex then -- EARLY OPT DEVILRY BAD!
		--Spring.Echo("Removed end element of instanceTable", iT.myName)
		iT.usedElements = iT.usedElements - 1
	else
		local lastElementInstanceID = iT.indextoInstanceID[lastElementIndex]
		local iTStep = iT.instanceStep
		local endOffset = (iT.usedElements - 1)*iTStep 
		
		iT.instanceIDtoIndex[lastElementInstanceID] = oldElementIndex
		iT.indextoInstanceID[oldElementIndex] = lastElementInstanceID
		
		--oldElementIndex = (oldElementIndex)*iTStep
		local oldOffset = (oldElementIndex-1)*iTStep 
		for i= 1, iTStep do 
			local data =  iT.instanceData[endOffset + i]
			iT.instanceData[oldOffset + i ] = data
		end
		--size_t LuaVBOImpl::Upload(const sol::stack_table& luaTblData, const sol::optional<int> attribIdxOpt, const sol::optional<int> elemOffsetOpt, const sol::optional<int> luaStartIndexOpt, const sol::optional<int> luaFinishIndexOpt)
		--Spring.Echo("Removing instanceID",instanceID,"from iT at position", oldElementIndex, "shuffling back at", iT.usedElements,"endoffset=",endOffset,'oldOffset=',oldOffset)
		if noUpload ~= true then
			--Spring.Echo("Upload", oldElementIndex -1, oldOffset+1, oldOffset+iTStep)
			iT.instanceVBO:Upload(iT.instanceData,nil,oldElementIndex-1,oldOffset +1,oldOffset + iTStep)
		else
			iT.dirty = true
		end
		iT.usedElements = iT.usedElements - 1
	end
end

function getElementInstanceData(iT, instanceID)
	-- iT: instanceTable created with makeInstanceTable
	-- instanceID: an optional key given to the item, so it can be easily removed by reference, defaults to the index of the instance in the buffer (1 based)
	local instanceIndex = iT.instanceIDtoIndex[instanceID] 
	if instanceIndex == nil then return nil end
	local iData = {}
	local iTStep = iT.instanceStep
	instanceIndex = (instanceIndex-1) * iTStep
	for i = 1, iTStep do
		iData[i] = iT.instanceData[instanceIndex + i]
	end
	return iData
end

function uploadAllElements(iT)
  -- upload all USED elements
  iT.instanceVBO:Upload(iT.instanceData,nil,0, 1, iT.usedElements * iT.instanceStep)
end


--------- HELPERS FOR PRIMITIVES ------------------

function makeCircleVBO(circleSegments, radius)
	-- Makes unit circle in xy space
	if not radius then radius = 1 end
	circleSegments  = circleSegments -1 -- for po2 buffers
	local circleVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if circleVBO == nil then goodbye("Failed to create circleVBO") end
	
	local VBOLayout = {
	 {id = 0, name = "position", size = 4},
	}
	
	local VBOData = {}
	
	for i = 0, circleSegments  do -- this is +1
		VBOData[#VBOData+1] = math.sin(math.pi*2* i / circleSegments) * radius -- X
		VBOData[#VBOData+1] = math.cos(math.pi*2* i / circleSegments) * radius-- Y
		VBOData[#VBOData+1] = i / circleSegments -- circumference [0-1]
		VBOData[#VBOData+1] = radius
	end	
	
	circleVBO:Define(
		circleSegments + 1,
		VBOLayout
	)
	circleVBO:Upload(VBOData)
	return circleVBO, #VBOData/4
end


function makeConeVBO(numSegments, height, radius) 
	-- make a cone that points up, (y = height), with radius specified
	-- returns the VBO object, and the number of elements in it (usually ==  numvertices)
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
		VBOData[#VBOData+1] = math.cos(math.pi*2* (i - 1) / numSegments) * radius-- Y
		VBOData[#VBOData+1] =(i - 1) / numSegments
		
		--- second cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius-- X
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 0) / numSegments
		
		-- top vertex
		VBOData[#VBOData+1] = 0 
		VBOData[#VBOData+1] = height
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = (i - 1) / numSegments
		
		--- first cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 1) / numSegments) * radius -- X
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = math.cos(math.pi*2* (i - 1) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 1) / numSegments
		
		--- second cone flat
		VBOData[#VBOData+1] = math.sin(math.pi*2* (i - 0) / numSegments) * radius -- X
		VBOData[#VBOData+1] = 0
		VBOData[#VBOData+1] = math.cos(math.pi*2* (i - 0) / numSegments) * radius -- Y
		VBOData[#VBOData+1] =(i - 0) / numSegments
	end
	
	
	coneVBO:Define(#VBOData/4,	{{id = 0, name = "localpos_progress", size = 4}})
	coneVBO:Upload(VBOData)
	return coneVBO, #VBOData/4
end


function makeBoxVBO(minX, minY, minZ, maxX, maxY, maxZ) -- make a box

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
	return boxVBO, #VBOData/4
end
