local mathFloor = math.floor
local mathCeil = math.ceil
local mathHuge = math.huge

local AXIS_X = 1
local AXIS_Y = 2
local BRUTE_FORCE_POINT_LIMIT = 48
local NO_NODE = 0
local NO_POINT = 0
local PHASE_COVER = 1
local PHASE_COVER_RESCUE = 2
local PHASE_FILL = 3

local function coordinateLess(pointIndexA, pointIndexB, axis, pointX, pointY)
	local coordinateA = pointX[pointIndexA]
	local coordinateB = pointX[pointIndexB]
	if axis == AXIS_Y then
		coordinateA = pointY[pointIndexA]
		coordinateB = pointY[pointIndexB]
	end
	if coordinateA == coordinateB then
		return pointIndexA < pointIndexB
	end
	return coordinateA < coordinateB
end

local function siftDown(indexOrder, startIndex, count, rootOffset, axis, pointX, pointY)
	while true do
		local leftOffset = rootOffset * 2 + 1
		if leftOffset >= count then
			return
		end
		local largestOffset = rootOffset
		local largestIndex = startIndex + largestOffset
		local leftIndex = startIndex + leftOffset
		if coordinateLess(indexOrder[largestIndex], indexOrder[leftIndex], axis, pointX, pointY) then
			largestOffset = leftOffset
			largestIndex = leftIndex
		end
		local rightOffset = leftOffset + 1
		if rightOffset < count then
			local rightIndex = startIndex + rightOffset
			if coordinateLess(indexOrder[largestIndex], indexOrder[rightIndex], axis, pointX, pointY) then
				largestOffset = rightOffset
			end
		end
		if largestOffset == rootOffset then
			return
		end
		local rootIndex = startIndex + rootOffset
		local swapIndex = startIndex + largestOffset
		local swappedPoint = indexOrder[rootIndex]
		indexOrder[rootIndex] = indexOrder[swapIndex]
		indexOrder[swapIndex] = swappedPoint
		rootOffset = largestOffset
	end
end

local function sortSlice(indexOrder, startIndex, endIndex, axis, pointX, pointY)
	local count = endIndex - startIndex + 1
	if count < 2 then
		return
	end
	for rootOffset = mathFloor(count / 2) - 1, 0, -1 do
		siftDown(indexOrder, startIndex, count, rootOffset, axis, pointX, pointY)
	end
	for lastOffset = count - 1, 1, -1 do
		local startValue = indexOrder[startIndex]
		indexOrder[startIndex] = indexOrder[startIndex + lastOffset]
		indexOrder[startIndex + lastOffset] = startValue
		siftDown(indexOrder, startIndex, lastOffset, 0, axis, pointX, pointY)
	end
end

local function emptySpatialIndex()
	local function nearest()
		return nil
	end
	local function claim()
	end
	local function unclaim()
	end
	local function resetClaims()
	end
	local function unclaimedCount()
		return 0
	end
	return {
		nearest = nearest,
		claim = claim,
		unclaim = unclaim,
		resetClaims = resetClaims,
		unclaimedCount = unclaimedCount,
	}
end

local function buildBruteForceIndex(pointX, pointY, pointCount)
	if pointCount < 1 then
		return emptySpatialIndex()
	end
	local claimed = {}
	local unclaimedTotal = pointCount

	local function nearest(originX, originY, acceptPoint)
		local bestDistance = mathHuge
		local bestPointIndex = NO_POINT
		for pointIndex = 1, pointCount do
			if not claimed[pointIndex] then
				if acceptPoint == nil or acceptPoint(pointIndex) then
					local offsetX = pointX[pointIndex] - originX
					local offsetY = pointY[pointIndex] - originY
					local distance = offsetX * offsetX + offsetY * offsetY
					if bestPointIndex == NO_POINT or distance < bestDistance or (distance == bestDistance and pointIndex < bestPointIndex) then
						bestDistance = distance
						bestPointIndex = pointIndex
					end
				end
			end
		end
		if bestPointIndex == NO_POINT then
			return nil
		end
		return bestPointIndex, bestDistance
	end

	local function claim(pointIndex)
		if pointIndex == nil or claimed[pointIndex] then
			return
		end
		claimed[pointIndex] = true
		unclaimedTotal = unclaimedTotal - 1
	end

	local function unclaim(pointIndex)
		if pointIndex == nil or not claimed[pointIndex] then
			return
		end
		claimed[pointIndex] = false
		unclaimedTotal = unclaimedTotal + 1
	end

	local function resetClaims()
		for pointIndex = 1, pointCount do
			claimed[pointIndex] = false
		end
		unclaimedTotal = pointCount
	end

	local function unclaimedCount()
		return unclaimedTotal
	end

	return {
		nearest = nearest,
		claim = claim,
		unclaim = unclaim,
		resetClaims = resetClaims,
		unclaimedCount = unclaimedCount,
	}
end

local function buildKdTree(pointX, pointY, pointCount)
	if pointCount == nil then
		pointCount = pointX and #pointX or 0
	end
	if pointCount < 1 then
		return emptySpatialIndex()
	end

	local indexOrder = {}
	for pointIndex = 1, pointCount do
		indexOrder[pointIndex] = pointIndex
	end

	local nodePointIndex = {}
	local nodeLeft = {}
	local nodeRight = {}
	local nodeParent = {}
	local nodeAxis = {}
	local nodeSplit = {}
	local nodeUnclaimed = {}
	local nodeSubtree = {}
	local nodeClaimed = {}
	local nodeByPoint = {}
	local stackNode = {}
	local stackPhase = {}
	local nodeCount = 0

	local function buildRange(startIndex, endIndex, axis)
		if startIndex > endIndex then
			return NO_NODE
		end
		sortSlice(indexOrder, startIndex, endIndex, axis, pointX, pointY)
		local medianOffset = mathFloor((endIndex - startIndex) / 2)
		local medianIndex = startIndex + medianOffset
		local pointIndex = indexOrder[medianIndex]
		local splitCoordinate = pointX[pointIndex]
		local nextAxis = AXIS_Y
		if axis == AXIS_Y then
			splitCoordinate = pointY[pointIndex]
			nextAxis = AXIS_X
		end
		nodeCount = nodeCount + 1
		local node = nodeCount
		nodePointIndex[node] = pointIndex
		nodeByPoint[pointIndex] = node
		nodeAxis[node] = axis
		nodeSplit[node] = splitCoordinate
		nodeClaimed[node] = false
		nodeParent[node] = NO_NODE
		nodeLeft[node] = NO_NODE
		nodeRight[node] = NO_NODE
		local leftNode = buildRange(startIndex, medianIndex - 1, nextAxis)
		local rightNode = buildRange(medianIndex + 1, endIndex, nextAxis)
		nodeLeft[node] = leftNode
		nodeRight[node] = rightNode
		local subtree = 1
		if leftNode ~= NO_NODE then
			nodeParent[leftNode] = node
			subtree = subtree + nodeSubtree[leftNode]
		end
		if rightNode ~= NO_NODE then
			nodeParent[rightNode] = node
			subtree = subtree + nodeSubtree[rightNode]
		end
		nodeSubtree[node] = subtree
		nodeUnclaimed[node] = subtree
		return node
	end

	local root = buildRange(1, pointCount, AXIS_X)
	local activeStateBase = 0
	local claimStateCount = 1

	local function adjustUnclaimed(node, delta)
		while node ~= NO_NODE do
			local slot = activeStateBase + node
			nodeUnclaimed[slot] = nodeUnclaimed[slot] + delta
			node = nodeParent[node]
		end
	end

	local function claim(pointIndex)
		local node = nodeByPoint[pointIndex]
		if node == nil or nodeClaimed[activeStateBase + node] then
			return false
		end
		nodeClaimed[activeStateBase + node] = true
		adjustUnclaimed(node, -1)
		return true
	end

	local function unclaim(pointIndex)
		local node = nodeByPoint[pointIndex]
		if node == nil or not nodeClaimed[activeStateBase + node] then
			return
		end
		nodeClaimed[activeStateBase + node] = false
		adjustUnclaimed(node, 1)
	end

	local function resetClaims()
		for node = 1, nodeCount do
			nodeClaimed[node] = false
			nodeUnclaimed[node] = nodeSubtree[node]
		end
	end

	local function unclaimedCount()
		return nodeUnclaimed[activeStateBase + root] or 0
	end

	local function nearest(originX, originY, acceptPoint)
		if root == NO_NODE or nodeUnclaimed[activeStateBase + root] == 0 then
			return nil
		end
		local bestDistance = mathHuge
		local bestPointIndex = NO_POINT
		local stackSize = 1
		local visitCount = 0
		local visitCap = pointCount * 3 + 4
		local stateBase = activeStateBase
		stackNode[1] = root
		stackPhase[1] = 0
		while stackSize > 0 do
			visitCount = visitCount + 1
			if visitCount > visitCap then
				break
			end
			local node = stackNode[stackSize]
			local phase = stackPhase[stackSize]
			if node == NO_NODE or nodeUnclaimed[stateBase + node] == 0 then
				stackSize = stackSize - 1
			elseif phase == 0 then
				if not nodeClaimed[stateBase + node] then
					local pointIndex = nodePointIndex[node]
					if acceptPoint == nil or acceptPoint(pointIndex) then
						local offsetX = pointX[pointIndex] - originX
						local offsetY = pointY[pointIndex] - originY
						local distance = offsetX * offsetX + offsetY * offsetY
						if bestPointIndex == NO_POINT or distance < bestDistance or (distance == bestDistance and pointIndex < bestPointIndex) then
							bestDistance = distance
							bestPointIndex = pointIndex
						end
					end
				end
				stackPhase[stackSize] = 1
				local originCoordinate = originX
				if nodeAxis[node] == AXIS_Y then
					originCoordinate = originY
				end
				local nearNode = nodeLeft[node]
				if originCoordinate > nodeSplit[node] then
					nearNode = nodeRight[node]
				end
				if nearNode ~= NO_NODE and nodeUnclaimed[stateBase + nearNode] > 0 then
					stackSize = stackSize + 1
					stackNode[stackSize] = nearNode
					stackPhase[stackSize] = 0
				end
			else
				local originCoordinate = originX
				if nodeAxis[node] == AXIS_Y then
					originCoordinate = originY
				end
				local splitCoordinate = nodeSplit[node]
				local farNode = nodeRight[node]
				if originCoordinate > splitCoordinate then
					farNode = nodeLeft[node]
				end
				local planeOffset = originCoordinate - splitCoordinate
				local planeDistance = planeOffset * planeOffset
				stackSize = stackSize - 1
				if planeDistance <= bestDistance and farNode ~= NO_NODE and nodeUnclaimed[stateBase + farNode] > 0 then
					stackSize = stackSize + 1
					stackNode[stackSize] = farNode
					stackPhase[stackSize] = 0
				end
			end
		end
		if bestPointIndex == NO_POINT then
			return nil
		end
		return bestPointIndex, bestDistance
	end

	local function useClaimState(state)
		activeStateBase = (state - 1) * nodeCount
	end

	local function addClaimState()
		claimStateCount = claimStateCount + 1
		local stateBase = (claimStateCount - 1) * nodeCount
		for node = 1, nodeCount do
			nodeClaimed[stateBase + node] = false
			nodeUnclaimed[stateBase + node] = nodeSubtree[node]
		end
		return claimStateCount
	end

	local function nearestInState(state, originX, originY, acceptPoint)
		local previousBase = activeStateBase
		useClaimState(state)
		local pointIndex, distance = nearest(originX, originY, acceptPoint)
		activeStateBase = previousBase
		return pointIndex, distance
	end

	local function claimInState(state, pointIndex)
		local previousBase = activeStateBase
		useClaimState(state)
		local claimedNow = claim(pointIndex)
		activeStateBase = previousBase
		return claimedNow
	end

	local function unclaimInState(state, pointIndex)
		local previousBase = activeStateBase
		useClaimState(state)
		unclaim(pointIndex)
		activeStateBase = previousBase
	end

	local function unclaimedCountInState(state)
		local previousBase = activeStateBase
		useClaimState(state)
		local count = unclaimedCount()
		activeStateBase = previousBase
		return count
	end

	return {
		nearest = nearest,
		claim = claim,
		unclaim = unclaim,
		resetClaims = resetClaims,
		unclaimedCount = unclaimedCount,
		addClaimState = addClaimState,
		nearestInState = nearestInState,
		claimInState = claimInState,
		unclaimedCountInState = unclaimedCountInState,
		unclaimInState = unclaimInState,
	}
end

local function emptyAssignment(agentCount, trimmed)
	local assignments = {}
	for agentIndex = 1, agentCount do
		assignments[agentIndex] = {}
	end
	return {
		assignments = assignments,
		totalOrders = 0,
		trimmed = trimmed == true,
	}
end

local function assignRoundRobinNearest(request)
	if request == nil then
		return emptyAssignment(0, false)
	end
	local agentX = request.agentX
	local agentY = request.agentY
	local targetX = request.targetX
	local targetY = request.targetY
	local agentCount = request.agentCount
	if agentCount == nil then
		agentCount = agentX and #agentX or 0
	end
	local targetCount = request.targetCount
	if targetCount == nil then
		targetCount = targetX and #targetX or 0
	end
	local exclusive = request.exclusive == true
	local canClaim = request.canClaim
	local coverageGoal = agentCount * targetCount
	local assignmentsPerAgent = targetCount
	local claimCap = mathHuge
	if exclusive and agentCount > 0 and targetCount > 0 then
		if agentCount > targetCount then
			claimCap = mathCeil(agentCount / targetCount)
			assignmentsPerAgent = 1
			coverageGoal = agentCount
		else
			claimCap = 1
			assignmentsPerAgent = mathCeil(targetCount / agentCount)
			coverageGoal = targetCount
		end
	end
	local orderBudget = request.orderBudget
	if orderBudget == nil or orderBudget > coverageGoal then
		orderBudget = coverageGoal
	end
	if orderBudget < 0 then
		orderBudget = 0
	end
	if agentCount < 1 or targetCount < 1 then
		return emptyAssignment(agentCount, false)
	end
	if orderBudget < 1 then
		return emptyAssignment(agentCount, coverageGoal > 0)
	end

	local spatialIndex
	if targetCount <= BRUTE_FORCE_POINT_LIMIT then
		spatialIndex = buildBruteForceIndex(targetX, targetY, targetCount)
	else
		spatialIndex = buildKdTree(targetX, targetY, targetCount)
	end

	local permanentClaims = exclusive and claimCap == 1
	local perAgentClaims = exclusive and not permanentClaims and spatialIndex.addClaimState ~= nil
	local agentClaimState = nil
	if perAgentClaims then
		agentClaimState = {}
		agentClaimState[1] = 1
		for agentIndex = 2, agentCount do
			agentClaimState[agentIndex] = spatialIndex.addClaimState()
		end
	end
	local assignments = {}
	local agentOrderCount = {}
	local alreadyAssigned = {}
	local claimCount = {}
	for agentIndex = 1, agentCount do
		assignments[agentIndex] = {}
		agentOrderCount[agentIndex] = 0
		if not perAgentClaims then
			alreadyAssigned[agentIndex] = {}
		end
	end
	for targetIndex = 1, targetCount do
		claimCount[targetIndex] = 0
	end

	local currentAgentIndex = 1
	local skipGeneration = 0
	local skipStamp = {}
	local roundTaken = {}
	local phase = PHASE_FILL
	local minimumOrders = 0
	local balanceToMinimum = not exclusive
	if not exclusive then
		phase = PHASE_COVER
	end
	local acceptPoint = nil
	if perAgentClaims then
		acceptPoint = function(targetIndex)
			if roundTaken[targetIndex] then
				return false
			end
			if claimCount[targetIndex] >= claimCap then
				return false
			end
			if phase ~= PHASE_FILL and claimCount[targetIndex] > 0 then
				return false
			end
			return true
		end
	elseif canClaim ~= nil or not permanentClaims then
		acceptPoint = function(targetIndex)
			if alreadyAssigned[currentAgentIndex][targetIndex] then
				return false
			end
			if claimCount[targetIndex] >= claimCap then
				return false
			end
			if skipStamp[targetIndex] == skipGeneration then
				return false
			end
			if phase ~= PHASE_FILL and claimCount[targetIndex] > 0 then
				return false
			end
			return true
		end
	end

	local totalOrders = 0
	local roundStartAgent = 1
	local roundClaimIndexes = {}
	local roundClaimCount = 0
	local unboundedClaims = claimCap == mathHuge
	while totalOrders < orderBudget and totalOrders < coverageGoal do
		if permanentClaims and spatialIndex.unclaimedCount() < 1 then
			break
		end
		local assignedThisRound = false
		for agentOffset = 0, agentCount - 1 do
			if totalOrders >= orderBudget or totalOrders >= coverageGoal then
				break
			end
			local agentIndex = roundStartAgent + agentOffset
			if agentIndex > agentCount then
				agentIndex = agentIndex - agentCount
			end
			local orderCountForAgent = agentOrderCount[agentIndex]
			local eligibleForRound = orderCountForAgent < assignmentsPerAgent
			if eligibleForRound and balanceToMinimum and phase ~= PHASE_COVER_RESCUE then
				eligibleForRound = orderCountForAgent == minimumOrders
			end
			if eligibleForRound then
				currentAgentIndex = agentIndex
				skipGeneration = skipGeneration + 1
				if skipGeneration > 1000000000 then
					skipGeneration = 1
					for targetIndex = 1, targetCount do
						skipStamp[targetIndex] = nil
					end
				end
				local originX = agentX[agentIndex]
				local originY = agentY[agentIndex]
				local claimState = nil
				local queryFilter = acceptPoint
				if perAgentClaims then
					claimState = agentClaimState[agentIndex]
					if canClaim == nil and unboundedClaims and phase == PHASE_FILL and roundClaimCount == 0 then
						queryFilter = nil
					end
				end
				local targetIndex = nil
				while true do
					if perAgentClaims then
						targetIndex = spatialIndex.nearestInState(claimState, originX, originY, queryFilter)
					else
						targetIndex = spatialIndex.nearest(originX, originY, queryFilter)
					end
					if targetIndex == nil then
						break
					end
					if canClaim == nil or canClaim(agentIndex, targetIndex) then
						break
					end
					if perAgentClaims then
						spatialIndex.claimInState(claimState, targetIndex)
					else
						skipStamp[targetIndex] = skipGeneration
						queryFilter = acceptPoint
					end
				end
				if targetIndex ~= nil then
					if perAgentClaims then
						local nextClaimCount = claimCount[targetIndex] + 1
						if nextClaimCount >= claimCap then
							for claimAgentIndex = 1, agentCount do
								spatialIndex.claimInState(agentClaimState[claimAgentIndex], targetIndex)
							end
						else
							spatialIndex.claimInState(claimState, targetIndex)
						end
						roundTaken[targetIndex] = true
						roundClaimCount = roundClaimCount + 1
						roundClaimIndexes[roundClaimCount] = targetIndex
					else
						spatialIndex.claim(targetIndex)
						if not permanentClaims then
							roundClaimCount = roundClaimCount + 1
							roundClaimIndexes[roundClaimCount] = targetIndex
						end
					end
					claimCount[targetIndex] = claimCount[targetIndex] + 1
					if not perAgentClaims then
						alreadyAssigned[agentIndex][targetIndex] = true
					end
					local orderCount = agentOrderCount[agentIndex] + 1
					agentOrderCount[agentIndex] = orderCount
					assignments[agentIndex][orderCount] = targetIndex
					totalOrders = totalOrders + 1
					assignedThisRound = true
				end
			end
		end
		if perAgentClaims then
			for claimIndex = 1, roundClaimCount do
				roundTaken[roundClaimIndexes[claimIndex]] = nil
				roundClaimIndexes[claimIndex] = nil
			end
			roundClaimCount = 0
		elseif phase == PHASE_FILL and not permanentClaims then
			for claimIndex = 1, roundClaimCount do
				spatialIndex.unclaim(roundClaimIndexes[claimIndex])
				roundClaimIndexes[claimIndex] = nil
			end
			roundClaimCount = 0
		else
			for claimIndex = 1, roundClaimCount do
				roundClaimIndexes[claimIndex] = nil
			end
			roundClaimCount = 0
		end
		if not assignedThisRound then
			if phase == PHASE_COVER then
				phase = PHASE_COVER_RESCUE
			elseif phase == PHASE_COVER_RESCUE then
				phase = PHASE_FILL
				if not exclusive then
					spatialIndex.resetClaims()
				end
			else
				break
			end
		else
			if phase == PHASE_COVER_RESCUE then
				phase = PHASE_COVER
			end
			if balanceToMinimum then
				local lowestOrderCount = agentOrderCount[1]
				for agentIndex = 2, agentCount do
					local orderCount = agentOrderCount[agentIndex]
					if orderCount < lowestOrderCount then
						lowestOrderCount = orderCount
					end
				end
				minimumOrders = lowestOrderCount
			end
			roundStartAgent = roundStartAgent + 1
			if roundStartAgent > agentCount then
				roundStartAgent = 1
			end
		end
	end

	local missedTarget = false
	if not exclusive then
		for targetIndex = 1, targetCount do
			if claimCount[targetIndex] == 0 then
				missedTarget = true
				break
			end
		end
	end
	local trimmed = totalOrders >= orderBudget and totalOrders < coverageGoal
	if not exclusive then
		trimmed = totalOrders >= orderBudget and missedTarget
	end
	return {
		assignments = assignments,
		totalOrders = totalOrders,
		trimmed = trimmed,
	}
end

return {
	assign = assignRoundRobinNearest,
	assignRoundRobinNearest = assignRoundRobinNearest,
	buildKdTree = buildKdTree,
}
