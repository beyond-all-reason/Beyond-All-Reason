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
		debugZombies 		= false,  -- this is new, and its for debugging non-existing stuff on unitdestroyed
	}

	if unitIDattribID ~= nil then
		instanceTable.indextoUnitID = {}
		instanceTable.unitIDattribID = unitIDattribID
		instanceTable.popUnitIDFailuresInGameFrame = {}
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
		res = res .. tostring(k) .. ':' .. tostring(v) ..','
		count = count + 1
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
				local fdefname = UnitDefs[Spring.GetUnitDefID(unitID)].name
				iT.validinfo[unitID] = {px = px, py = py, pz = pz, unitdefname = fdefname}
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
		local new_usedElements = 0
		local new_instanceIDtoIndex = {}
		local new_indextoInstanceID = {}
		local new_indextoUnitID = {}
		local invalidcount = 0

		for i, objectID in ipairs(iT.indextoUnitID) do
			local isValidID = false
			if iT.featureIDs then isValidID = Spring.ValidFeatureID(objectID)
			else isValidID = Spring.ValidUnitID(objectID) end
			if isValidID then
				for j = 1, iT.instanceStep do 
					new_instanceData[#new_instanceData + 1 ] = iT.instanceData[j + new_usedElements * iT.instanceStep]
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
	end
	local iTusedElements = iT.usedElements
	local iTStep    = iT.instanceStep 
	local endOffset = iTusedElements * iTStep
	if instanceID == nil then instanceID = iTusedElements + 1 end
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

	for i =1, iTStep  do -- copy data, but fast
		iT.instanceData[endOffset + i] =  thisInstance[i]
	end

	if unitID ~= nil then 
		local isvalidid
		if iT.featureIDs then isvalidid = Spring.ValidFeatureID(unitID) 
		else isvalidid = Spring.ValidUnitID(unitID) end
		if isvalidid == false then 
			Spring.Echo("Error: Attempted to push an invalid unit/featureID",unitID, "into", iT.myName)
			noUpload = true
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
								s = s .. " " .. tostring(zombie)
								Spring.Echo("ZOMBIE AT", zombie, Spring.GetUnitPosition(zombie))
								Spring.SendCommands({"pause 1"})
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
					Spring.Echo("Warning: Tried to pop back an invalid" .. ((iT.featureIDs and "featureID") or "unitID"), popunitID, "from", iT.myName, "while removing instance", instanceID, counttable(iT.instanceIDtoIndex), counttable(iT.indextoInstanceID), counttable(iT.indextoUnitID))
					Spring.Debug.TraceFullEcho()
					local gf = Spring.GetGameFrame()
					if iT.lastpopgameframe == nil or iT.lastpopgameframe ~= gf then -- New gameframe
						iT.lastpopgameframe = gf
						iT.zombies = {}
						iT.numZombies = 0
					end 
					iT.zombies[popunitID] = gf
					iT.numZombies = iT.numZombies + 1 
				end
			end 
		end
		iT.usedElements = iT.usedElements - 1
	end
	
	if iT.debug then validateInstanceVBOTable(iT,'pop') end 
	return oldElementIndex
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
	if iT.usedElements == 0 then return end
	--Spring.Echo("uploadAllElements", iT.usedElements)
	--Spring.Debug.TableEcho(iT.indextoUnitID)
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
		for i = startElementIndex, endElementIndex do
			unitIDRange[#unitIDRange + 1] = iT.indextoUnitID[i]
		end
		if iT.featureIDs then
			iT.instanceVBO:InstanceDataFromFeatureIDs(unitIDRange, iT.unitIDattribID, startElementIndex - 1)
		else
			iT.instanceVBO:InstanceDataFromUnitIDs(unitIDRange, iT.unitIDattribID, startElementIndex - 1)
		end
	end
end

function drawInstanceVBO(iT)
	if iT.usedElements > 0 then 
		iT.VAO:DrawArrays(iT.primitiveType, iT.numVertices, 0, iT.usedElements,0)
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

function makePlaneVBO(xsize, ysize, xresolution, yresolution) -- makes a plane from [-xsize to xsize] with xresolution subdivisions
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

	--Spring.Echo("PlaneVBOData up:",#VBOData, "Down", #planeVBO:Download())
	return planeVBO, #VBOData/2
end

function makePlaneIndexVBO(xresolution, yresolution)
	xresolution = math.floor(xresolution)
	if not yresolution then yresolution = xresolution end
	local planeIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	if planeIndexVBO == nil then return nil end
	local numindices = yresolution*xresolution*6
	planeIndexVBO:Define(
		numindices
	)
	local IndexVBOData = {}
	local qindex = 0
	local colsize = yresolution + 1
	for x = 0, xresolution-1  do -- this is +1
		for y = 0, yresolution-1 do
			IndexVBOData[#IndexVBOData + 1] = qindex
			IndexVBOData[#IndexVBOData + 1] = qindex +1
			IndexVBOData[#IndexVBOData + 1] = qindex + colsize
			IndexVBOData[#IndexVBOData + 1] = qindex +1
			IndexVBOData[#IndexVBOData + 1] = qindex + colsize + 1
			IndexVBOData[#IndexVBOData + 1] = qindex + colsize
			qindex = qindex + 1
		end
		qindex = qindex + 1
	end	
	planeIndexVBO:Upload(IndexVBOData)
	--Spring.Echo("PlaneIndexVBO up:",#IndexVBOData, "Down", #planeIndexVBO:Download())
	return planeIndexVBO,numindices
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



function makeCylinderVBO(numSegments, height, radius, hastop, hasbottom) 
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
	return cylinderVBO, #VBOData/4
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

