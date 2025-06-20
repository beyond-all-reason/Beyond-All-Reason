local function makeInstanceVBOTable(layout, maxElements, myName, objectTypeAttribID, objecttype)
	-- layout: this must be an array of tables with at least the following specified: {{id = 1, name = 'optional', size = 4}}
	-- maxElements: will be dynamic anyway, but defaults to 64
	-- myName: optional name, useful for debugging
	-- objectTypeAttribID: the attribute ID in the layout of the uvec4 of unitID bindings (e.g. 4 for	{id = 4, name = 'instData', type = GL.UNSIGNED_INT, size= 4} )
	-- objectType : must be ["unitID"|"unitDefID"|"featureID"|"featureDefID"]

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
		debugZombies 		= true,
	}

	if objectTypeAttribID ~= nil then
		instanceTable.indextoUnitID = {}
		instanceTable.indextoObjectType = {} -- ["unitID"|"unitDefID"|"featureID"|"featureDefID"]
		instanceTable.objectTypeAttribID = objectTypeAttribID
		instanceTable.objecttype = objecttype
	end
	--Spring.Echo(myName,": VBO upload of #elements:",#instanceData)
	newInstanceVBO:Upload(instanceData)

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

local function clearInstanceTable(iT)
	-- this wont resize it, but quickly sets it to empty
	iT.usedElements = 0
	iT.instanceIDtoIndex = {}
	iT.indextoInstanceID = {}
	if iT.indextoUnitID then iT.indextoUnitID = {} end
	if iT.indextoObjectType then iT.indextoObjectType = {} end
	if iT.VAO then iT.VAO:ClearSubmission() end
end

local function makeVAOandAttach(vertexVBO, instanceVBO, indexVBO) -- Attach a vertex buffer to an instance buffer, and optionally, an index buffer if one is supplied.
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

local function resizeInstanceVBOTable(iT)
	--[[
		Spring.Echo("Resizing", iT.myName, "from size",iT.maxElements, "currently", iT.usedElements)
		for i = 0, iT.usedElements - 1  do
			tstr = tostring(i)
			for j = 1, iT.instanceStep do
				tstr =  tstr .. " " .. tostring(iT.instanceData[i* iT.instanceStep + j])
			end
			Spring.Echo(tstr)
		end
	]]--
	-- iT: the InstanceVBOTable to double in size 'dynamically' resize the VBO, to double its size
	iT.maxElements = iT.maxElements * 2
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	newInstanceVBO:Define(iT.maxElements, iT.layout)
	if iT.instanceVBO then iT.instanceVBO:Delete() end -- release if previous one existed
	iT.instanceVBO = newInstanceVBO
	iT.instanceVBO:Upload(iT.instanceData,nil,0,1,iT.usedElements * iT.instanceStep)
	if iT.VAO then -- reattach new if updated :D
		iT.VAO:Delete()
		iT.VAO = makeVAOandAttach(iT.vertexVBO,iT.instanceVBO, iT.indexVBO)
	end


	for i, unitID in ipairs(iT.indextoUnitID) do
		local objecttype = iT.indextoObjectType[i]
		--Spring.Echo("Resize", iT.myName, i, unitID, objecttype)
		if objecttype == "unitID" then
			-- Sanity check for unitIDs
			if Spring.ValidUnitID(unitID) ~= true then
				Spring.Echo("Invalid unitID",unitID, "at", i, "during resizing", iT.myName)
			else
				iT.instanceVBO:InstanceDataFromUnitIDs(unitID, iT.objectTypeAttribID, i-1)
			end
			iT.VAO:AddUnitsToSubmission(unitID)
		elseif objecttype == "unitDefID" then	-- TODO
			iT.instanceVBO:InstanceDataFromUnitDefIDs(unitID, iT.objectTypeAttribID, nil, i-1)
			iT.VAO:AddUnitDefsToSubmission(unitID)
		elseif objecttype == "featureID" then
			if Spring.ValidFeatureID(unitID) ~= true then
				Spring.Echo("Invalid featureID",unitID, "at", i, "during resizing", iT.myName)
			else
				iT.instanceVBO:InstanceDataFromFeatureIDs(unitID, iT.objectTypeAttribID, i-1)
			end
			iT.VAO:AddFeaturesToSubmission(unitID)
		elseif objecttype == "featureDefID" then
			iT.instanceVBO:InstanceDataFromFeatureDefIDs(unitID, iT.objectTypeAttribID, i-1)
			iT.VAO:AddFeatureDefsToSubmission(unitID)
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

local function pushElementInstance(iT,thisInstance, instanceID, updateExisting, noUpload, unitID, objecttype, teamID)
	-- iT: instanceTable created with makeInstanceTable
	-- thisInstance: is a lua array of values to add to table, MUST BE INSTANCESTEP SIZED LUA ARRAY
	-- instanceID: an optional key given to the item, so it can be easily removed/updated by reference, defaults to the index of the instance in the buffer (1 based)
	-- updateExisting: allow updating an existing element (same instanceID key)
	-- noUpload: prevent the VBO from being uploaded, if you feel like you are going to do a lot of ops and wish to manually upload when done instead
	-- unitID: if given, it will store then unitID corresponding to this instance, and will try to update the InstanceDataFromUnitIDs for this unit
	-- returns: the index of the instanceID in the table on success, else nil
	if (objecttype == "unitID" and (Spring.ValidUnitID(unitID) == false)) or
		(objecttype == "featureID" and (Spring.ValidFeatureID(unitID) == false)) or
		(objecttype == "unitDefID" and (UnitDefs[unitID] == nil)) or
		(objecttype == "featureDefID" and (FeatureDefs[unitID] == nil)) then
		Spring.Echo("Tried to push invalid",objecttype,unitID,"into", iT.myName,"with instanceID", instanceID, "returning nil")
		return nil
	end

	if #thisInstance ~= iT.instanceStep then
		Spring.Echo("Trying to upload an oddly sized instance into",iT.myName, #thisInstance, "instead of ",iT.instanceStep)
	end
	local iTusedElements = iT.usedElements
	local iTStep		= iT.instanceStep
	local endOffset = iTusedElements * iTStep
	if instanceID == nil then instanceID = iTusedElements + 1 end
	local thisInstanceIndex = iT.instanceIDtoIndex[instanceID]

	if (iTusedElements + 1 ) >= iT.maxElements then
		resizeInstanceVBOTable(iT)
		iTusedElements = iT.usedElements -- because during validation of unitIDs during resizing, we can decrease the actual size of the table!
		thisInstanceIndex = iT.instanceIDtoIndex[instanceID]	-- this too, can change, TODO, also do this in VBOIDtable!
	end
	local isnewid = false
	if thisInstanceIndex == nil then -- new, register it
		thisInstanceIndex = iTusedElements + 1
		iT.usedElements	 = iTusedElements + 1
		iT.instanceIDtoIndex[instanceID] = thisInstanceIndex
		iT.indextoInstanceID[thisInstanceIndex] = instanceID
		isnewid = true
	else -- pre-existing ID, update or bail
		if updateExisting == nil then
			Spring.Echo("Tried to add existing element to an instanceTable",iT.myName, instanceID)
			return nil
		else
			endOffset = (thisInstanceIndex - 1) * iTStep
		end
	end

	local instanceData = iT.instanceData
	for i =1, iTStep	do -- copy data, but fast
		instanceData[endOffset + i] =	thisInstance[i]
	end

	if unitID ~= nil then --always upload?
		iT.indextoUnitID[thisInstanceIndex] = unitID
		iT.indextoObjectType[thisInstanceIndex] = objecttype
	end

	if noUpload ~= true then --upload or mark as dirty
		iT.instanceVBO:Upload(thisInstance, nil, thisInstanceIndex - 1)

		if unitID ~= nil then --always upload?
			-- [3:58 PM] ivand: InstanceDataFromUnitDefIDs(const sol::stack_table& ids, int attrID, sol::optional<int> teamIdOpt, sol::optional<int> elemOffsetOpt)
			--[3:59 PM] ivand: teamId is the 3rd arg
			--Spring.Echo("pushElementInstance,unitID, iT.objectTypeAttribID, thisInstanceIndex",unitID, iT.objectTypeAttribID, thisInstanceIndex)
			if objecttype == "unitID" then
				iT.instanceVBO:InstanceDataFromUnitIDs(unitID, iT.objectTypeAttribID, thisInstanceIndex-1)
				if isnewid then iT.VAO:AddUnitsToSubmission(unitID) end
			elseif objecttype == "unitDefID" then	-- TODO
				iT.instanceVBO:InstanceDataFromUnitDefIDs(unitID, iT.objectTypeAttribID, teamID, thisInstanceIndex-1)
				if isnewid then iT.VAO:AddUnitDefsToSubmission(unitID) end
			elseif objecttype == "featureID" then
				iT.instanceVBO:InstanceDataFromFeatureIDs(unitID, iT.objectTypeAttribID, thisInstanceIndex-1)
				if isnewid then iT.VAO:AddFeaturesToSubmission(unitID) end
			elseif objecttype == "featureDefID" then
				iT.instanceVBO:InstanceDataFromFeatureDefIDs(unitID, iT.objectTypeAttribID, thisInstanceIndex-1)
				if isnewid then iT.VAO:AddFeatureDefsToSubmission(unitID) end
			end

		end
	else
		iT.dirty = true
	end

	return instanceID
end

local function popElementInstance(iT, instanceID, noUpload)
	-- iT: instanceTable created with makeInstanceTable
	-- instanceID: an optional key given to the item, so it can be easily removed by reference, defaults to the last element of the buffer, but this will screw up the instanceIDtoIndex table if used in mixed keys mode
	-- noUpload: prevent the VBO from being uploaded, if you feel like you are going to do a lot of ops and wish to manually upload when done instead
	-- returns nil on failure, the the index of the element on success
	if instanceID == nil then instanceID = iT.usedElements	end

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
		--Spring.Echo("Removed end element of instanceTable", lastElementIndex, instanceID, iT.indextoUnitID[oldElementIndex], iT.myName)
		iT.usedElements = iT.usedElements - 1
		if iT.indextoUnitID then iT.indextoUnitID[oldElementIndex] = nil end
		if iT.indextoObjectType then	iT.indextoObjectType[oldElementIndex] = nil end
		if iT.VAO then
			iT.VAO:RemoveFromSubmission(oldElementIndex-1)
			--Spring.Echo("RemoveFromSubmissionLast",oldElementIndex-1 )
		end

		if iT.debugZombies then
			if iT.zombies and iT.zombies[instanceID] then
				--Spring.Echo("Good, we are killing a stupid zombie at the end", instanceID, iT.numZombies)
				iT.zombies[instanceID] = nil
				iT.numZombies = iT.numZombies - 1
			end
		end

	else
		local lastElementInstanceID = iT.indextoInstanceID[lastElementIndex]
		local iTStep = iT.instanceStep
		local endOffset = (iT.usedElements - 1)*iTStep

		iT.instanceIDtoIndex[lastElementInstanceID] = oldElementIndex
		iT.indextoInstanceID[oldElementIndex] = lastElementInstanceID
		iT.indextoInstanceID[lastElementIndex] = nil --- somehow this got forgotten? TODO for VBOIDtable

		--oldElementIndex = (oldElementIndex)*iTStep
		local oldOffset = (oldElementIndex-1)*iTStep
		local instanceData = iT.instanceData
		for i= 1, iTStep do
			instanceData[oldOffset + i ] = instanceData[endOffset + i]
		end
		--size_t LuaVBOImpl::Upload(const sol::stack_table& luaTblData, const sol::optional<int> attribIdxOpt, const sol::optional<int> elemOffsetOpt, const sol::optional<int> luaStartIndexOpt, const sol::optional<int> luaFinishIndexOpt)
		--Spring.Echo("Removing instanceID",instanceID,"from iT at position", oldElementIndex, "shuffling back at", iT.usedElements,"endoffset=",endOffset,'oldOffset=',oldOffset)
		if noUpload ~= true then
			--Spring.Echo("Upload", oldElementIndex -1, oldOffset+1, oldOffset+iTStep)
			iT.instanceVBO:Upload(iT.instanceData, nil, oldElementIndex-1, oldOffset +1, oldOffset + iTStep)
			-- Do the unitID shuffle if needed:
			if iT.indextoUnitID then
				--Spring.Echo("Shuffling",lastElementIndex,"->", oldElementIndex)
				--Spring.Echo("popElementInstance,unitID, iT.objectTypeAttribID, thisInstanceIndex",unitID, iT.objectTypeAttribID, oldElementIndex)
				local myunitID = iT.indextoUnitID[lastElementIndex]

				--Spring.Echo("Removing",instanceID,"/",iT.indextoUnitID[oldElementIndex], "Popping back", myunitID, "is it valid?", Spring.ValidUnitID(myunitID), oldElementIndex, lastElementIndex)

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
							-- this is a very special case, where we clobber the zombie we had stored in the _next_ frame:
							if iT.zombies and iT.zombies[instanceID] then
								iT.numZombies = iT.numZombies - 1
								iT.zombies[instanceID] = nil
							end

							if iT.numZombies and iT.numZombies > 0 then -- WE HAVE ZOMBIES AAAAARGH
								--Error: validateInstanceVBOIDTable [string "LuaUI/'
								local s = 'Error: popElementInstance [string "LuaUI/  We have ' .. tostring(iT.numZombies) .. " zombie units left over in " .. iT.myName .. " after removing:" .. tostring(instanceID) .. " zombies:"
								for zombie, gf in pairs(iT.zombies) do
									s = s .. " " .. tostring(zombie)
									--Spring.SendCommands({"pause 1"})
								end
								Spring.Echo(s)
								Spring.Debug.TraceFullEcho(nil,nil, nil, dbgt(iT.indextoUnitID), dbgt(iT.indextoInstanceID))
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

				iT.indextoUnitID[oldElementIndex] = myunitID
				iT.indextoUnitID[lastElementIndex] = nil

				local objecttype = iT.indextoObjectType[lastElementIndex]
				iT.indextoObjectType[oldElementIndex] = objecttype
				iT.indextoObjectType[lastElementIndex] = nil

				if iT.VAO then
					iT.VAO:RemoveFromSubmission(oldElementIndex-1)
					--Spring.Echo("RemoveFromSubmission",objecttype,oldElementIndex-1)
				end

				if objecttype == "unitID" or objecttype == "featureID" then
					if objecttype == "unitID" and Spring.ValidUnitID(myunitID) then
						iT.instanceVBO:InstanceDataFromUnitIDs(myunitID, iT.objectTypeAttribID, oldElementIndex-1)
					 --iT.VAO:AddUnitDefsToSubmission(unitID)
					elseif objecttype == "featureID" and Spring.ValidFeatureID(myunitID)  then
						iT.instanceVBO:InstanceDataFromFeatureIDs(myunitID, iT.objectTypeAttribID, oldElementIndex-1)
					else
						if iT.debugZombies then
							--Spring.Echo("Warning: Tried to pop back an invalid " .. ((iT.featureIDs and "featureID") or "unitID"), myunitID, "with instanceid:",lastElementInstanceID, "from", iT.myName, "while removing instance", instanceID, counttable(iT.instanceIDtoIndex), counttable(iT.indextoInstanceID), counttable(iT.indextoUnitID))
							--Spring.Debug.TraceFullEcho()
							--dbgt(iT.indextoUnitID)
							--dbgt(iT.indextoInstanceID)
							local gf = Spring.GetGameFrame()
							if iT.lastpopgameframe == nil or iT.lastpopgameframe ~= gf then -- New gameframe
								iT.lastpopgameframe = gf
								iT.zombies = {}
								iT.numZombies = 0
							end
							if iT.zombies[lastElementInstanceID] then
								-- ah, this is possible, because the same invalid unitID can be at the back of the queue twice!
								--Spring.Echo("We are double-marking a unit as a zombie:",lastElementInstanceID, myunitID, instanceID)
							else
								iT.zombies[lastElementInstanceID] = gf
								iT.numZombies = iT.numZombies + 1
							end
						else
							Spring.Echo("Tried to pop back an invalid unitID ", myunitID, "from", iT.myName, "while removing instance", instanceID,". Ensure that you remove invalid units from your instance tables")
							Spring.Debug.TraceFullEcho()
						end
					end
				elseif objecttype == "unitDefID" then
					iT.instanceVBO:InstanceDataFromUnitDefIDs(myunitID, iT.objectTypeAttribID,nil,	oldElementIndex-1)
				elseif objecttype == "featureDefID" then
					iT.instanceVBO:InstanceDataFromFeatureDefIDs(myunitID, iT.objectTypeAttribID, oldElementIndex-1)
				end
			end
		else
			iT.dirty = true
		end
		iT.usedElements = iT.usedElements - 1
		--dbgt(iT.indextoInstanceID, "indextoInstanceID")
		--dbgt(iT.indextoUnitID, "indextoUnitID")
	end
	return oldElementIndex
end

local function getElementInstanceData(iT, instanceID)
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

local function dumpAndCompareInstanceData(iT)
	local gpuContents = iT.instanceVBO:Download(nil,nil,nil,true)
	for i = 1, iT.usedElements do
		Spring.Echo(string.format("%s, instanceID =%s, element %d of %d", iT.myName, tostring(iT.indextoInstanceID[i]), i, iT.usedElements))
		local index = 1
		local offset = (i -1) * (iT.instanceStep)
		for j, layout in ipairs(iT.layout) do
			local gpuData = ''
			local luaData = ''
			for k= 1, layout.size do
				luaData = luaData .. tostring(iT.instanceData[index + offset]) .. ","
				gpuData = gpuData .. tostring(gpuContents[index + offset]) .. ","
				index = index + 1
			end
			local layoutstr = string.format("  ID=%d, name = %s, size = %d, type = %d, luaData = {%s}, gpuData={%s}",
				layout.id, layout.name, layout.size, layout.type or GL.FLOAT,
				luaData,
				gpuData
			)
			Spring.Echo(layoutstr)
		end
	end
end



local function uploadAllElements(iT)
	-- DANGER: stuff should be removed first!
	-- upload all USED elements
	if iT.usedElements == 0 then return end
	iT.instanceVBO:Upload(iT.instanceData,nil,0, 1, iT.usedElements * iT.instanceStep)
	iT.dirty = false

	if iT.VAO then iT.VAO:ClearSubmission() end
	for i, unitID in ipairs(iT.indextoUnitID) do
		local objecttype = iT.indextoObjectType[i]
		--Spring.Echo("Resize", iT.myName, i, unitID, objecttype)
		if objecttype == "unitID" then
			-- Sanity check for unitIDs
			if Spring.ValidUnitID(unitID) ~= true then
				Spring.Echo("Invalid unitID",unitID, "at", i, "during resizing", iT.myName)
			else
				iT.instanceVBO:InstanceDataFromUnitIDs(unitID, iT.objectTypeAttribID, i-1)
			end
			iT.VAO:AddUnitsToSubmission(unitID)
		elseif objecttype == "unitDefID" then	-- TODO
			iT.instanceVBO:InstanceDataFromUnitDefIDs(unitID, iT.objectTypeAttribID, nil, i-1)
			iT.VAO:AddUnitDefsToSubmission(unitID)
		elseif objecttype == "featureID" then
			if Spring.ValidFeatureID(unitID) ~= true then
				Spring.Echo("Invalid featureID",unitID, "at", i, "during resizing", iT.myName)
			else
				iT.instanceVBO:InstanceDataFromFeatureIDs(unitID, iT.objectTypeAttribID, i-1)
			end
			iT.VAO:AddFeaturesToSubmission(unitID)
		elseif objecttype == "featureDefID" then
			iT.instanceVBO:InstanceDataFromFeatureDefIDs(unitID, iT.objectTypeAttribID, i-1)
			iT.VAO:AddFeatureDefsToSubmission(unitID)
		end
	end
end


local function validateInstanceVBOIDTable(iT, calledfrom)
	-- Check each instance, and see if it has a valid unitID associated with it
	-- Report with this key: "Error: validateInstanceVBOIDTable: error(2) = [string "LuaUI/Widgets
	local errorKey = 'Error: validateInstanceVBOIDTable [string "LuaUI/' ..calledfrom  or " " .. ' ]'
	local removethese = {}
	for i=1, iT.usedElements do
		if iT.indextoInstanceID[i] == nil then
			Spring.Echo(errorKey, "There is a hole in indextoInstanceID", iT.myName, "at", i,"out of",iT.usedElements, calledfrom)
			--Spring.Echo()
			if iT.indextoUnitID[i] == nil then
				Spring.Echo(errorKey, "It is also missing from indextoUnitID")
			else
				Spring.Echo(errorKey, "But it does exist in indextoUnitID with an unitID of ", iT.indextoUnitID[i])
				Spring.Echo(errorKey, "This is valid?", Spring.GetUnitPosition(iT.indextoUnitID[i]))
			end

		else
			local instanceID = iT.indextoInstanceID[i]
			local objecttype = iT.indextoObjectType[i]
			if iT.instanceIDtoIndex[instanceID] == nil then
				Spring.Echo(errorKey,"There is a hole instanceIDtoIndex", iT.myName, "at", i," iT.instanceIDtoIndex[instanceID] == nil ")
			elseif iT.instanceIDtoIndex[instanceID] ~= i then
				Spring.Echo(errorKey,"There is a problem in indextoInstanceID", iT.myName, "at i =", i,"  iT.indextoInstanceID[instanceID] ~= i, it is instead: ", iT.indextoInstanceID[instanceID] )
			end
			if instanceID and objecttype and objecttype == 'unitID' then
				local unitID = iT.indextoUnitID[i]
				if Spring.ValidUnitID(unitID) ~= true then
					removethese[instanceID] = true
				end
			end
		end
	end
	local idsremoved = ""
	for instanceID, _ in pairs(removethese) do
		idsremoved = idsremoved .. ';' .. tostring(instanceID)
		popElementInstance(iT, instanceID)
	end
	if string.len(idsremoved) > 1 then
		Spring.Echo(errorKey, " removed invalid instanceIDs", idsremoved)
	end
	--[[
	local indextoInstanceIDsize = counttable(iT.indextoInstanceID)
	local instanceIDtoIndexsize = counttable(iT.instanceIDtoIndex)
	local indextoUnitID = counttable(iT.indextoUnitID)
	if (indextoInstanceIDsize ~= instanceIDtoIndexsize) or (instanceIDtoIndexsize ~= indextoUnitID) then
		Spring.Echo("Table size mismatch during validation of", iT.myName, indextoInstanceIDsize, instanceIDtoIndexsize, indextoUnitID)
	end
	]]--

end


--[[

function uploadElementRange(iT, startElementIndex, endElementIndex)
	iT.instanceVBO:Upload(iT.instanceData, -- The lua mirrored VBO data
		nil, -- the attribute index, nil for all attributes
		startElementIndex, -- vboOffset optional, , what ELEMENT offset of the VBO to start uploading into, 0 based
		startElementIndex * iT.instanceStep + 1, --	luaStartIndex, default 1, what element of the lua array to start uploading from. 1 is the 1st element of a lua table.
		endElementIndex * iT.instanceStep --] luaEndIndex, default #{array}, what element of the lua array to upload up to, inclusively
	)
	if iT.indextoUnitID then
	--we need to reslice the table
	local unitIDRange = {}
	for i = startElementIndex, endElementIndex do
		unitIDRange[#unitIDRange + 1] = iT.indextoUnitID[i]
	end
		iT.instanceVBO:InstanceDataFromUnitIDs(unitIDRange, iT.objectTypeAttribID, startElementIndex - 1)
	end
end
]]--

return {
	makeInstanceVBOTable = makeInstanceVBOTable,
	clearInstanceTable = clearInstanceTable,
	makeVAOandAttach = makeVAOandAttach,
	resizeInstanceVBOTable = resizeInstanceVBOTable,
	pushElementInstance = pushElementInstance,
	popElementInstance = popElementInstance,
	getElementInstanceData = getElementInstanceData,
	dumpAndCompareInstanceData = dumpAndCompareInstanceData,
	uploadAllElements = uploadAllElements,
	validateInstanceVBOIDTable = validateInstanceVBOIDTable,
	uploadElementRange = uploadElementRange,
}
