local SpatialAssignment = require("common/round_robin_nearest")

local function bruteNearest(pointX, pointY, pointCount, claimed, originX, originY, acceptPoint)
	local bestDistance = math.huge
	local bestPointIndex = nil
	for pointIndex = 1, pointCount do
		if not claimed[pointIndex] and (acceptPoint == nil or acceptPoint(pointIndex)) then
			local offsetX = pointX[pointIndex] - originX
			local offsetY = pointY[pointIndex] - originY
			local distance = offsetX * offsetX + offsetY * offsetY
			if bestPointIndex == nil or distance < bestDistance or (distance == bestDistance and pointIndex < bestPointIndex) then
				bestDistance = distance
				bestPointIndex = pointIndex
			end
		end
	end
	return bestPointIndex, bestDistance
end

local function gridPoints()
	local pointX = {}
	local pointY = {}
	local pointCount = 0
	for column = 0, 19 do
		for row = 0, 19 do
			pointCount = pointCount + 1
			pointX[pointCount] = column * 10 + (row % 3) * 0.1
			pointY[pointCount] = row * 10 + (column % 5) * 0.25
		end
	end
	return pointX, pointY, pointCount
end

local function assertNoDuplicateTargets(result)
	for agentIndex = 1, #result.assignments do
		local seen = {}
		local targets = result.assignments[agentIndex]
		for targetIndex = 1, #targets do
			local assignedTarget = targets[targetIndex]
			assert.is_nil(seen[assignedTarget])
			seen[assignedTarget] = true
		end
	end
end

describe("round_robin_nearest", function()
	describe("buildKdTree", function()
		it("matches a linear scan for nearest, including claims", function()
			local pointX, pointY, pointCount = gridPoints()
			local tree = SpatialAssignment.buildKdTree(pointX, pointY, pointCount)
			local claimed = {}
			local origins = {
				{ -25, -25 },
				{ 0, 0 },
				{ 95, 5 },
				{ 47, 188 },
				{ 200, 20 },
				{ 33.2, 71.4 },
			}
			for originIndex = 1, #origins do
				local originX = origins[originIndex][1]
				local originY = origins[originIndex][2]
				local treePoint, treeDistance = tree.nearest(originX, originY)
				local brutePoint, bruteDistance = bruteNearest(pointX, pointY, pointCount, claimed, originX, originY)
				assert.are.equal(brutePoint, treePoint)
				assert.are.equal(bruteDistance, treeDistance)
			end
			local claimedTotal = 0
			for pointIndex = 1, pointCount, 7 do
				tree.claim(pointIndex)
				claimed[pointIndex] = true
				claimedTotal = claimedTotal + 1
			end
			assert.are.equal(pointCount - claimedTotal, tree.unclaimedCount())
			for originIndex = 1, #origins do
				local originX = origins[originIndex][1]
				local originY = origins[originIndex][2]
				local treePoint, treeDistance = tree.nearest(originX, originY)
				local brutePoint, bruteDistance = bruteNearest(pointX, pointY, pointCount, claimed, originX, originY)
				assert.are.equal(brutePoint, treePoint)
				assert.are.equal(bruteDistance, treeDistance)
			end
			tree.unclaim(1)
			claimed[1] = nil
			local restoredPoint = tree.nearest(0, 0)
			local bruteRestored = bruteNearest(pointX, pointY, pointCount, claimed, 0, 0)
			assert.are.equal(bruteRestored, restoredPoint)
			tree.resetClaims()
			local resetPoint = tree.nearest(0, 0)
			local bruteReset = bruteNearest(pointX, pointY, pointCount, {}, 0, 0)
			assert.are.equal(bruteReset, resetPoint)
			assert.are.equal(pointCount, tree.unclaimedCount())
		end)

		it("skips points rejected by the acceptor and keeps the nearer accepted point", function()
			local pointX = { 0, 1, 5, 9 }
			local pointY = { 0, 0, 0, 0 }
			local tree = SpatialAssignment.buildKdTree(pointX, pointY, 4)
			local function acceptPoint(pointIndex)
				return pointIndex ~= 2 and pointIndex ~= 3
			end
			local pointIndex, distance = tree.nearest(2, 0, acceptPoint)
			assert.are.equal(1, pointIndex)
			assert.are.equal(4, distance)
		end)

		it("breaks distance ties toward the lower point index", function()
			local pointX = { 5, -5 }
			local pointY = { 0, 0 }
			local tree = SpatialAssignment.buildKdTree(pointX, pointY, 2)
			local pointIndex = tree.nearest(0, 0)
			assert.are.equal(1, pointIndex)
		end)

		it("returns nil when every point is claimed", function()
			local tree = SpatialAssignment.buildKdTree({ 1, 2 }, { 0, 0 }, 2)
			tree.claim(1)
			tree.claim(2)
			assert.is_nil(tree.nearest(0, 0))
			assert.are.equal(0, tree.unclaimedCount())
		end)

		it("finds the nearest point when many points share a coordinate", function()
			local pointX = {}
			local pointY = {}
			local pointCount = 80
			for pointIndex = 1, pointCount - 1 do
				pointX[pointIndex] = 4
				pointY[pointIndex] = 4
			end
			pointX[pointCount] = 100
			pointY[pointCount] = 4
			local tree = SpatialAssignment.buildKdTree(pointX, pointY, pointCount)
			assert.are.equal(1, tree.nearest(4, 4))
			assert.are.equal(pointCount, tree.nearest(100, 4))
			assert.are.equal(pointCount, tree.nearest(70, 4))
			tree.claim(pointCount)
			assert.are.equal(1, tree.nearest(70, 4))
		end)

		it("returns nil for an empty tree", function()
			local tree = SpatialAssignment.buildKdTree({}, {}, 0)
			assert.is_nil(tree.nearest(0, 0))
			assert.are.equal(0, tree.unclaimedCount())
		end)
	end)

	describe("assignRoundRobinNearest", function()
		it("gives one unit the closest targets first", function()
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = { 0 },
				agentY = { 0 },
				targetX = { 10, 1, 4 },
				targetY = { 0, 0, 0 },
				exclusive = true,
			})
			assert.are.same({ 2, 3, 1 }, result.assignments[1])
			assert.are.equal(3, result.totalOrders)
			assert.is_false(result.trimmed)
		end)

		it("splits targets between units standing at opposite ends", function()
			local function assertEndsSplit(targetCount)
				local targetX = {}
				local targetY = {}
				for targetIndex = 1, targetCount do
					targetX[targetIndex] = targetIndex
					targetY[targetIndex] = 0
				end
				local result = SpatialAssignment.assignRoundRobinNearest({
					agentX = { 0, targetCount + 1 },
					agentY = { 0, 0 },
					targetX = targetX,
					targetY = targetY,
					targetCount = targetCount,
					exclusive = true,
				})
				assert.are.equal(targetCount, result.totalOrders)
				assert.is_false(result.trimmed)
				assertNoDuplicateTargets(result)
				local leftMax = 0
				local rightMin = targetCount + 1
				for targetIndex = 1, #result.assignments[1] do
					local assignedTarget = result.assignments[1][targetIndex]
					if assignedTarget > leftMax then
						leftMax = assignedTarget
					end
				end
				for targetIndex = 1, #result.assignments[2] do
					local assignedTarget = result.assignments[2][targetIndex]
					if assignedTarget < rightMin then
						rightMin = assignedTarget
					end
				end
				assert.is_true(leftMax < rightMin)
				assert.are.equal(math.floor(targetCount / 2), #result.assignments[1])
				assert.are.equal(targetCount - #result.assignments[1], #result.assignments[2])
			end
			assertEndsSplit(8)
			assertEndsSplit(70)
		end)

		it("caps shared targets when the KD-tree path has more units than targets", function()
			local agentCount = 60
			local targetCount = 50
			local agentX = {}
			local agentY = {}
			local targetX = {}
			local targetY = {}
			for agentIndex = 1, agentCount do
				agentX[agentIndex] = agentIndex
				agentY[agentIndex] = 0
			end
			for targetIndex = 1, targetCount do
				targetX[targetIndex] = targetIndex
				targetY[targetIndex] = 0
			end
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = agentX,
				agentY = agentY,
				agentCount = agentCount,
				targetX = targetX,
				targetY = targetY,
				targetCount = targetCount,
				exclusive = true,
			})
			assert.are.equal(agentCount, result.totalOrders)
			assert.is_false(result.trimmed)
			local targetUses = {}
			for agentIndex = 1, agentCount do
				assert.are.equal(1, #result.assignments[agentIndex])
				local targetIndex = result.assignments[agentIndex][1]
				targetUses[targetIndex] = (targetUses[targetIndex] or 0) + 1
			end
			for targetIndex = 1, targetCount do
				local uses = targetUses[targetIndex] or 0
				assert.is_true(uses <= 2)
				assert.is_true(uses >= 1)
			end
		end)

		it("shares targets when there are more units than targets", function()
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = { 0, 10, 20 },
				agentY = { 0, 0, 0 },
				targetX = { 0, 20 },
				targetY = { 0, 0 },
				exclusive = true,
			})
			assert.are.equal(3, result.totalOrders)
			assert.is_false(result.trimmed)
			assert.are.same({ 1 }, result.assignments[1])
			assert.are.same({ 2 }, result.assignments[3])
			assert.are.equal(1, #result.assignments[2])
			assertNoDuplicateTargets(result)
		end)

		it("keeps assigning passes until the order budget is spent", function()
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = { 0, 10 },
				agentY = { 0, 0 },
				targetX = { 0, 10, 3 },
				targetY = { 0, 0, 0 },
				orderBudget = 4,
				exclusive = false,
			})
			assert.are.equal(4, result.totalOrders)
			assert.is_false(result.trimmed)
			assertNoDuplicateTargets(result)
			assert.are.equal(2, #result.assignments[1])
			assert.are.equal(2, #result.assignments[2])
		end)

		it("does not mark an exact budget fill as trimmed", function()
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = { 0, 5 },
				agentY = { 0, 0 },
				targetX = { 0, 5 },
				targetY = { 0, 0 },
				orderBudget = 4,
				exclusive = false,
			})
			assert.are.equal(4, result.totalOrders)
			assert.is_false(result.trimmed)
		end)

		it("skips a nearer target the unit is not allowed to claim", function()
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = { 0 },
				agentY = { 0 },
				targetX = { 1, 30 },
				targetY = { 0, 0 },
				exclusive = true,
				canClaim = function(agentIndex, targetIndex)
					return agentIndex == 1 and targetIndex ~= 1
				end,
			})
			assert.are.same({ 2 }, result.assignments[1])
			assert.are.equal(1, result.totalOrders)
			assert.is_false(result.trimmed)
		end)

		it("balances a larger exclusive set across the KD-tree path", function()
			local agentCount = 50
			local targetCount = 200
			local agentX = {}
			local agentY = {}
			local targetX = {}
			local targetY = {}
			for agentIndex = 1, agentCount do
				agentX[agentIndex] = agentIndex * 3
				agentY[agentIndex] = (agentIndex % 5) * 2
			end
			for targetIndex = 1, targetCount do
				targetX[targetIndex] = targetIndex * 0.75
				targetY[targetIndex] = (targetIndex % 7) * 1.5
			end
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = agentX,
				agentY = agentY,
				agentCount = agentCount,
				targetX = targetX,
				targetY = targetY,
				targetCount = targetCount,
				exclusive = true,
			})
			assert.are.equal(targetCount, result.totalOrders)
			assert.is_false(result.trimmed)
			assertNoDuplicateTargets(result)
			local seen = {}
			local minimumCount = targetCount
			local maximumCount = 0
			for agentIndex = 1, agentCount do
				local assignedCount = #result.assignments[agentIndex]
				if assignedCount < minimumCount then
					minimumCount = assignedCount
				end
				if assignedCount > maximumCount then
					maximumCount = assignedCount
				end
				for orderIndex = 1, assignedCount do
					local targetIndex = result.assignments[agentIndex][orderIndex]
					assert.is_nil(seen[targetIndex])
					seen[targetIndex] = true
				end
			end
			assert.is_true(maximumCount - minimumCount <= 1)
			local seenCount = 0
			for targetIndex = 1, targetCount do
				if seen[targetIndex] then
					seenCount = seenCount + 1
				end
			end
			assert.are.equal(targetCount, seenCount)
		end)

		it("stays inside a multi-pass budget without repeating a pair", function()
			local agentCount = 80
			local targetCount = 140
			local agentX = {}
			local agentY = {}
			local targetX = {}
			local targetY = {}
			for agentIndex = 1, agentCount do
				agentX[agentIndex] = (agentIndex % 17) * 11
				agentY[agentIndex] = math.floor(agentIndex / 17) * 13
			end
			for targetIndex = 1, targetCount do
				targetX[targetIndex] = (targetIndex % 19) * 9
				targetY[targetIndex] = math.floor(targetIndex / 19) * 8
			end
			local orderBudget = 1000
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = agentX,
				agentY = agentY,
				agentCount = agentCount,
				targetX = targetX,
				targetY = targetY,
				targetCount = targetCount,
				orderBudget = orderBudget,
				exclusive = false,
			})
			assert.are.equal(orderBudget, result.totalOrders)
			assert.is_false(result.trimmed)
			assertNoDuplicateTargets(result)
			local minimumCount = orderBudget
			local maximumCount = 0
			local targetUses = {}
			for agentIndex = 1, agentCount do
				local assignedCount = #result.assignments[agentIndex]
				if assignedCount < minimumCount then
					minimumCount = assignedCount
				end
				if assignedCount > maximumCount then
					maximumCount = assignedCount
				end
				local assignedTargets = result.assignments[agentIndex]
				for orderIndex = 1, assignedCount do
					local targetIndex = assignedTargets[orderIndex]
					targetUses[targetIndex] = (targetUses[targetIndex] or 0) + 1
				end
			end
			assert.is_true(maximumCount - minimumCount <= 1)
			for targetIndex = 1, targetCount do
				assert.is_true((targetUses[targetIndex] or 0) >= 1)
			end
		end)

		it("fills the order budget after every target has one order", function()
			local agentCount = 40
			local nearTargetCount = 15
			local farTargetCount = 45
			local targetCount = nearTargetCount + farTargetCount
			local agentX = {}
			local agentY = {}
			local targetX = {}
			local targetY = {}
			for agentIndex = 1, agentCount do
				agentX[agentIndex] = (agentIndex % 5) * 2
				agentY[agentIndex] = math.floor(agentIndex / 5) * 2
			end
			for targetIndex = 1, nearTargetCount do
				targetX[targetIndex] = targetIndex % 4
				targetY[targetIndex] = math.floor(targetIndex / 4)
			end
			for targetIndex = 1, farTargetCount do
				local pointIndex = nearTargetCount + targetIndex
				targetX[pointIndex] = 800 + (targetIndex % 9) * 40
				targetY[pointIndex] = math.floor(targetIndex / 9) * 40
			end
			local orderBudget = 150
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = agentX,
				agentY = agentY,
				agentCount = agentCount,
				targetX = targetX,
				targetY = targetY,
				targetCount = targetCount,
				orderBudget = orderBudget,
				exclusive = false,
			})
			assert.are.equal(orderBudget, result.totalOrders)
			assert.is_false(result.trimmed)
			assertNoDuplicateTargets(result)
			local targetUses = {}
			local minimumCount = orderBudget
			local maximumCount = 0
			for agentIndex = 1, agentCount do
				local assignedTargets = result.assignments[agentIndex]
				local assignedCount = #assignedTargets
				if assignedCount < minimumCount then
					minimumCount = assignedCount
				end
				if assignedCount > maximumCount then
					maximumCount = assignedCount
				end
				for orderIndex = 1, assignedCount do
					local targetIndex = assignedTargets[orderIndex]
					targetUses[targetIndex] = (targetUses[targetIndex] or 0) + 1
				end
			end
			assert.is_true(maximumCount - minimumCount <= 1)
			for targetIndex = 1, targetCount do
				assert.is_true((targetUses[targetIndex] or 0) >= 1)
			end
		end)

		it("marks the budget trimmed when targets are left without an order", function()
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = { 0, 10, 20, 30 },
				agentY = { 0, 0, 0, 0 },
				targetX = { 0, 10, 20, 30, 40, 50 },
				targetY = { 0, 0, 0, 0, 0, 0 },
				orderBudget = 3,
				exclusive = false,
			})
			assert.are.equal(3, result.totalOrders)
			assert.is_true(result.trimmed)
		end)

		it("returns empty assignments when there is nothing to assign", function()
			local result = SpatialAssignment.assignRoundRobinNearest({
				agentX = {},
				agentY = {},
				targetX = { 1 },
				targetY = { 1 },
			})
			assert.are.equal(0, result.totalOrders)
			assert.is_false(result.trimmed)
			local budgetResult = SpatialAssignment.assignRoundRobinNearest({
				agentX = { 0 },
				agentY = { 0 },
				targetX = { 1, 2 },
				targetY = { 0, 0 },
				orderBudget = 0,
			})
			assert.are.equal(0, budgetResult.totalOrders)
			assert.is_true(budgetResult.trimmed)
			assert.are.same({}, budgetResult.assignments[1])
		end)
	end)
end)
