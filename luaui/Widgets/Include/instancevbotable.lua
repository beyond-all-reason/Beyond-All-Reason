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
	}
	
	if unitIDattribID ~= nil then
		instanceTable.indextoUnitID = {}
		instanceTable.unitIDattribID = unitIDattribID
		
	end
	
	newInstanceVBO:Upload(instanceData)
	return instanceTable
end

function clearInstanceTable(iT) 
	-- this wont resize it, but quickly sets it to empty
	iT.usedElements = 0
	iT.instanceIDtoIndex = {}
	iT.indextoInstanceID = {}
	if iT.indextoUnitID then iT.indextoUnitID = {} end
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
	for i = (iT.maxElements/2) * iT.instanceStep + 1, (iT.maxElements) * iT.instanceStep do
		iT.instanceData[i] = 0
	end
	iT.instanceVBO = nil
	iT.instanceVBO = newInstanceVBO
	iT.instanceVBO:Upload(iT.instanceData)
	if iT.VAO and iT.vertexVBO then -- reattach new if updated :D
		iT.VAO = makeVAOandAttach(iT.vertexVBO,iT.instanceVBO)
	end
	Spring.Echo("instanceVBOTable full, resizing to double size",iT.myName, iT.usedElements,iT.maxElements)
	
	if iT.indextoUnitID then
		for index, unitID in ipairs(iT.indextoUnitID) do
			iT.instanceVBO:InstanceDataFromUnitIDs({unitID}, iT.unitIDattribID, index-1)
		end
		-- OR:
		--iT.instanceVBO:InstanceDataFromUnitIDs(iT.indextoUnitID, iT.unitIDattribID)
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
	local iTusedElements = iT.usedElements
	local iTStep    = iT.instanceStep 
	local endOffset = iTusedElements * iTStep
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
			endOffset = (thisInstanceIndex - 1) * iTStep
		end
	end
	
	for i =1, iTStep  do -- copy data, but fast
		iT.instanceData[endOffset + i] =  thisInstance[i]
	end
	
	if noUpload ~= true then --upload or mark as dirty
		iT.instanceVBO:Upload(thisInstance, nil, thisInstanceIndex - 1)
		if unitID ~= nil then --always upload?
			iT.indextoUnitID[thisInstanceIndex] = unitID
			--Spring.Echo("pushElementInstance,unitID, iT.unitIDattribID, thisInstanceIndex",unitID, iT.unitIDattribID, thisInstanceIndex)
			iT.instanceVBO:InstanceDataFromUnitIDs({unitID}, iT.unitIDattribID, thisInstanceIndex-1)
		end
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
	
	if iT.instanceIDtoIndex[instanceID] == nil then -- if key is instanceID yet does not exist, then warn and bail
		Spring.Echo("Tried to remove element ",instanceID,'From instanceTable', iT.myName, 'but it does not exist in it')
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
	
	-- if it had a related unitID stored, remove that:

	
	-- get the data of the last ones:
	local lastElementIndex = iT.usedElements
	
	-- if this one was already at the end of the queue, do nothing but decrement usedElements and clear mappings 
	if oldElementIndex == lastElementIndex then -- EARLY OPT DEVILRY BAD!
		--Spring.Echo("Removed end element of instanceTable", iT.myName)
		iT.usedElements = iT.usedElements - 1
		if iT.indextoUnitID then iT.indextoUnitID[oldElementIndex] = nil end
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
			-- Do the unitID shuffle if needed:
			if iT.indextoUnitID then
				--Spring.Echo("Shuffling",lastElementIndex,"->", oldElementIndex)
				--Spring.Echo("popElementInstance,unitID, iT.unitIDattribID, thisInstanceIndex",unitID, iT.unitIDattribID, oldElementIndex)
				local myunitID = iT.indextoUnitID[lastElementIndex]
				iT.indextoUnitID[oldElementIndex] = myunitID
				iT.indextoUnitID[lastElementIndex] = nil
				iT.instanceVBO:InstanceDataFromUnitIDs({myunitID}, iT.unitIDattribID, oldElementIndex-1)
			end
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
  iT.dirty = false
  if iT.indextoUnitID then
		iT.instanceVBO:InstanceDataFromUnitIDs(iT.indextoUnitID, iT.unitIDattribID)
	end
end

function uploadElementRange(iT,startElementIndex, endElementIndex)
	iT.instanceVBO:Upload(iT.instanceData, -- The lua mirrored VBO data
		nil, -- the attribute index, nil for all attributes
		startElementIndex, -- vboOffset optional, , what ELEMENT offset of the VBO to start uploading into, 0 based
		startElementIndex * iT.instanceStep + 1, --  luaStartIndex, default 1, what element of the lua array to start uploading from. 1 is the 1st element of a lua table. 
		endElementIndex * iT.instanceStep --] luaEndIndex, default #{array}, what element of the lua array to upload up to, inclusively
		)
end

function drawInstanceVBO(iT)
  if iT.usedElements > 0 then 
    iT.VAO:DrawArrays(iT.primitiveType, iT.numVertices, 0, iT.usedElements,0)
  end
end


--------- HELPERS FOR PRIMITIVES ------------------

function makeCircleVBO(circleSegments, radius)
	-- Makes circle of radius in xy space
	-- can be used in both GL.LINES and GL.TRIANGLE_FAN mode
	if not radius then radius = 1 end
	circleSegments  = circleSegments -1 -- for po2 buffers
	local circleVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if circleVBO == nil then return nil end
	
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

function makePointVBO(numPoints)
	-- makes points with xyzw
	-- can be used in both GL.LINES and GL.TRIANGLE_FAN mode
	if not numPoints then numPoints = 1 end
	local pointVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if pointVBO == nil then return nil end
	
	local VBOLayout = {
	 {id = 0, name = "position_w", size = 4},
	}
	
	local VBOData = {}
	
	for i = 1, numPoints  do -- 
		VBOData[#VBOData+1] = 0-- X
		VBOData[#VBOData+1] = 0-- Y
		VBOData[#VBOData+1] = 0---Z
		VBOData[#VBOData+1] = numPoints -- index for lolz?
	end	
	
	pointVBO:Define(
		numPoints,
		VBOLayout
	)
	pointVBO:Upload(VBOData)
	return pointVBO, numPoints
end

function makeRectVBO(minX,minY, maxX, maxY, minU, minV, maxU, maxV)
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
	return rectVBO, 6
end

function makeRectIndexVBO()
	local rectIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	if rectIndexVBO == nil then return nil end
	
	rectIndexVBO:Define(
		6
	)
	rectIndexVBO:Upload({0,1,2,3,4,5})
	return rectIndexVBO,6
end



function makeConeVBO(numSegments, height, radius) 
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
	return coneVBO, #VBOData/4
end


function makeBoxVBO(minX, minY, minZ, maxX, maxY, maxZ) -- make a box
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
	return boxVBO, #VBOData/4
end

