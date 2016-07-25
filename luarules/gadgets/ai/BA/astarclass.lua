-- ======================================================================
-- Copyright (c) 2012 RapidFire Studio Limited 
-- All Rights Reserved. 
-- http://www.rapidfirestudio.com

-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:

-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ======================================================================
-- Modified by eronoobos for use in BA & BAR configs for Shard AI for Spring RTS
-- ======================================================================


----------------------------------------------------------------
-- local variables
----------------------------------------------------------------

local INF = 1/0


----------------------------------------------------------------
-- localized functions
----------------------------------------------------------------

local tInsert = table.insert
local mAbs = math.abs
local mCeil = math.ceil


----------------------------------------------------------------
-- local functions
----------------------------------------------------------------

local function dist ( x1, y1, x2, y2 )
	-- return math.sqrt ( math.pow ( x2 - x1, 2 ) + math.pow ( y2 - y1, 2 ) )
	local dx = x2 - x1
	local dy = y2 - y1
	return dx*dx + dy*dy
	-- return math.abs( (x2-x1) + (y2-y1) )
end

local function manhattan_dist ( x1, y1, x2, y2 )
	local dx = x2 - x1
	local dy = y2 - y1
	return mAbs(dx) + mAbs(dy)
end

local function dist_between (nodeA, nodeB)
	return dist(nodeA.x, nodeA.y, nodeB.x, nodeB.y)
end

local function heuristic_cost_estimate ( nodeA, nodeB )
	return manhattan_dist( nodeA.x, nodeA.y, nodeB.x, nodeB.y)
end

local function is_valid_node ( node )
	return true
end

local function is_neighbor_node ( node, neighbor )
	return true
end

local function lowest_f_score ( set, f_score )
	local lowest, bestNode = INF, nil
	for i = 1, #set do
		local node = set[i]
		local score = f_score[node]
		if score < lowest then
			lowest, bestNode = score, node
		end
	end
	return bestNode
end

local function neighbor_nodes ( theNode, nodes, isNeighborNode, isValidNode )
	local neighbors = {}
	local numInvalidNodes = 0
	local gotNeighCache = false
	if theNode.neighbors then
		nodes = theNode.neighbors
		gotNeighCache = true
	else
		theNode.neighbors = {}
	end
	for i = 1, #nodes do
		local node = nodes[i]
		if theNode ~= node and (gotNeighCache or isNeighborNode(theNode, node)) then
			if not gotNeighCache then theNode.neighbors[#theNode.neighbors+1] = node end
			if isValidNode(node) then
				neighbors[#neighbors+1] = node
			else
				numInvalidNodes = numInvalidNodes + 1
			end
		end
	end
	return neighbors, numInvalidNodes
end

local function not_in ( set, theNode )
	for i = 1, #set do
		local node = set[i]
		if node == theNode then return false end
	end
	return true
end

local function remove_node ( set, theNode )
	for i = 1, #set do
		local node = set[i]
		if node == theNode then 
			set [i] = set [#set]
			set [#set] = nil
			break
		end
	end	
end

local function unwind_path ( flat_path, map, current_node )
	if map[current_node] then
		tInsert(flat_path, 1, map[current_node]) 
		return unwind_path(flat_path, map, map[current_node])
	else
		return flat_path
	end
end


----------------------------------------------------------------
-- deferred pathfinder class
----------------------------------------------------------------

PathfinderAStar = class(function(a)
	--
end)

function PathfinderAStar:Init(start, goal, nodes, isNeighborNode, isValidNode, distFunc, heuristicDistFunc)
	self.start = start
	self.goal = goal
	self.nodes = nodes
	self.isNeighborNode = isNeighborNode or is_neighbor_node
	self.isValidNode = isValidNode or is_valid_node
	self.distFunc = distFunc or dist
	self.distBetween = dist_between
	if distFunc then
		self.distBetween = function(nodeA, nodeB) return distFunc(nodeA.x, nodeA.y, nodeB.x, nodeB.y) end
	end
	self.heuristicDistFunc = heuristicDistFunc or manhattan_dist
	self.heuristicEstimate = heuristic_cost_estimate
	if heuristicDistFunc then
		self.heuristicEstimate = function(nodeA, nodeB) return heuristicDistFunc(nodeA.x, nodeA.y, nodeB.x, nodeB.y) end
	end
	self.closedset = {}
	self.openset = { self.start }
	self.came_from = {}
	self.g_score = {}
	self.f_score = {}
	self.g_score[self.start] = 0
	self.f_score[self.start] = self.g_score[self.start] + self.heuristicEstimate(self.start, self.goal)
end

function PathfinderAStar:Find(iterations)
	iterations = iterations or 1
	local it = 1
	local nodes = self.nodes
	local isNeighborNode = self.isNeighborNode
	local isValidNode = self.isValidNode
	local distBetween = self.distBetween
	local heuristicEstimate = self.heuristicEstimate
	while #self.openset > 0 and it <= iterations do
		local current = lowest_f_score(self.openset, self.f_score)
		if current == self.goal then
			local path = unwind_path({}, self.came_from, self.goal)
			path[#path+1] = self.goal
			return path, #self.openset, self.maxInvalid
		end
		remove_node(self.openset, current)
		self.closedset[#self.closedset+1] = current
		local neighbors, numInvalidNodes = neighbor_nodes(current, nodes, isNeighborNode, isValidNode)
		if not self.maxInvalid or numInvalidNodes > self.maxInvalid then self.maxInvalid = numInvalidNodes end
		for i = 1, #neighbors do
			local neighbor = neighbors[i]
			if not_in(self.closedset, neighbor) then
				local tentative_g_score = self.g_score[current] + distBetween(current, neighbor)
				if not_in(self.openset, neighbor) or tentative_g_score < self.g_score[neighbor] then 
					self.came_from[neighbor] = current
					self.g_score[neighbor] = tentative_g_score
					self.f_score[neighbor] = self.g_score[neighbor] + heuristicEstimate(neighbor, self.goal)
					if not_in(self.openset, neighbor) then
						self.openset[#self.openset+1] = neighbor
					end
				end
			end
		end
		it = it + 1
	end
	return nil, #self.openset, self.maxInvalid
end


----------------------------------------------------------------
-- graph class, for storing a set of nodes and performing pathfinding operations on
----------------------------------------------------------------

GraphAStar = class(function(a)
	--
end)

function GraphAStar:Init(nodes, isNeighborNode, isValidNode, distFunc, heuristicDistFunc)
	self.nodes = nodes
	self.isNeighborNode = isNeighborNode or is_neighbor_node
	self.isValidNode = isValidNode or is_valid_node
	self.distFunc = distFunc or dist
	self.distBetween = dist_between
	if distFunc then
		self.distBetween = function(nodeA, nodeB) return distFunc(nodeA.x, nodeA.y, nodeB.x, nodeB.y) end
	end
	self.heuristicDistFunc = heuristicDistFunc or manhattan_dist
	self.heuristicEstimate = heuristic_cost_estimate
	if heuristicDistFunc then
		self.heuristicEstimate = function(nodeA, nodeB) return heuristicDistFunc(nodeA.x, nodeA.y, nodeB.x, nodeB.y) end
	end
end

-- provides a neighbor function for a grid with each node having four neighbors
-- assumes distFunc is the default of distance squared
function GraphAStar:SetQuadGridSize(gridSize)
	local nodeDist = 1 + (gridSize ^ 2)
	self.isNeighborNode = function ( node, neighbor ) 
		if self.distFunc( node.x, node.y, neighbor.x, neighbor.y) < nodeDist then
			return true
		end
	end
	self.gridSize = gridSize
	self.halfGridSize = mCeil(gridSize / 2)
	self.nodeDist = nodeDist
end

-- provides a neighbor function for a grid with each node having eight neighbors
-- assumes distFunc is the default of distance squared
function GraphAStar:SetOctoGridSize(gridSize)
	local nodeDist = 1 + (2 * (gridSize^2))
	self.isNeighborNode = function ( node, neighbor ) 
		if self.distFunc( node.x, node.y, neighbor.x, neighbor.y) < nodeDist then
			return true
		end
	end
	self.gridSize = gridSize
	self.halfGridSize = mCeil(gridSize / 2)
	self.nodeDist = nodeDist
end

function GraphAStar:NodeHere(x, y, isValidNode)
	isValidNode = isValidNode or self.isValidNode
	if self.gridSize then
		x = (x - (x % self.gridSize)) + self.halfGridSize
		y = (y - (y % self.gridSize)) + self.halfGridSize
	end
	local nodes = self.nodes
	for i = 1, #nodes do
		local node = nodes[i]
		if isValidNode(node) then
			if node.x == x and node.y == y then
				return node
			end
		end
	end
end

function GraphAStar:NearestNode(x, y, isValidNode, distFunc, minDist, maxDist)
	isValidNode = isValidNode or self.isValidNode
	distFunc = distFunc or self.distFunc
	local nodes = self.nodes
	local here = self:NodeHere(x, y, isValidNode)
	if here then return here end
	local bestDist
	local bestNode
	for i = 1, #nodes do
		local node = nodes[i]
		if isValidNode(node) then
			local d = distFunc(x, y, node.x, node.y)
			if (not minDist or d >= minDist) and (not maxDist or d <= maxDist) and (not bestDist or d < bestDist) then
				bestDist = d
				bestNode = node
			end
		end
	end
	return bestNode, bestDist
end

function GraphAStar:Pathfinder(start, goal, isNeighborNode, isValidNode, distFunc, heuristicDistFunc)
	local pathfinder = PathfinderAStar()
	pathfinder:Init(start, goal, self.nodes, isNeighborNode or self.isNeighborNode, isValidNode or self.isValidNode, distFunc or self.distFunc, heuristicDistFunc or self.heuristicDistFunc)
	return pathfinder
end

function GraphAStar:PathfinderXYXY(x1, y1, x2, y2, isNeighborNode, isValidNode, distFunc, heuristicDistFunc)
	local start = self:NodeHere(x1, y1) or self:NearestNode(x1, y1)
	if not start then return end
	local goal = self:NodeHere(x2, y2) or self:NearestNode(x2, y2)
	if not goal then return end
	return self:Pathfinder(start, goal, isNeighborNode, isValidNode, distFunc, heuristicDistFunc)
end