
function widget:GetInfo()
	return {
		name      = "Loop Select",
		desc      = "Selects units inside drawn loop (Hold meta to draw loop)",
		author    = "Niobium",
		version   = "v1.1",
		date      = "Jul 18, 2009",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

---------------------------------------------------------------------------
-- Variables
---------------------------------------------------------------------------
local fadeRate = 3.0 -- Alpha reduces at fadeRate per second
local conLineAlpha = 0.1 -- Alpha of connecting line when drawing loop

---------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------
local dragging = false -- Obvious
local sNodes = {} -- Loop nodes
local fNodes = {} -- Fading nodes
local fAlpha = 0 -- Fade alpha
local sx, sy, sz -- Start pos
local lx, ly, lz -- Last added pos

---------------------------------------------------------------------------
-- Speedups
---------------------------------------------------------------------------

local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINE_STRIP = GL.LINE_STRIP

local glDepthTest = gl.DepthTest
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd

local spGetMouseState = Spring.GetMouseState
local spGetActiveCommand = Spring.GetActiveCommand
local spGetDefaultCommand = Spring.GetDefaultCommand
local spGetModKeyState = Spring.GetModKeyState
local spGetSpecState = Spring.GetSpectatingState
local spGetMyTeamID = Spring.GetMyTeamID
local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetUnitPos = Spring.GetUnitPosition
local spTraceScreenRay = Spring.TraceScreenRay
local spGetSelUnits = Spring.GetSelectedUnits
local spSelUnitArray = Spring.SelectUnitArray

local tremove = table.remove

---------------------------------------------------------------------------
-- Code
---------------------------------------------------------------------------

function widget:Update(dt)
	
	if (fAlpha > 0) then
		fAlpha = fAlpha - fadeRate * dt
	end
	
	if dragging then
		
		local mx, my = spGetMouseState()
		local _, pos = spTraceScreenRay(mx, my, true)
		
		if pos then
			
			local wx, wy, wz = pos[1], pos[2], pos[3]
			
			if ((wx ~= lx) or (wy ~= ly) or (wz ~= lz)) then
				sNodes[#sNodes + 1] = {wx, wy, wz}
				lx = wx; ly = wy; lz = wz
			end
		end
	end
end

local function sVerts(nodes)
	for i=1, #nodes do
		local node = nodes[i]
		glVertex(node[1], node[2], node[3])
	end
end

function widget:DrawWorld()
	
	glDepthTest(false)
	glLineWidth(2.0)
	
	if (#sNodes > 1) then
		
		glColor(1.0, 1.0, 1.0, 1.0)
		glBeginEnd(GL_LINE_STRIP, sVerts, sNodes)
		
		glColor(1.0, 1.0, 1.0, conLineAlpha)
		glBeginEnd(GL_LINE_STRIP, sVerts, {{sx, sy, sz}, {lx, ly, lz}})
	end
	
	if ((fAlpha > 0) and (#fNodes > 1)) then
		
		glColor(1.0, 1.0, 1.0, fAlpha)
		glBeginEnd(GL_LINE_LOOP, sVerts, fNodes)
	end
end

function widget:MousePress(mx, my, mButton)
	
	-- Only left click
	if (mButton ~= 1) then return false end
	
	-- Only handle if there is no active command
	local _, actCmdID = spGetActiveCommand()
	if (actCmdID ~= nil) then return false end
	
	-- Only handle if meta is also pressed
	local _, _, meta, _ = spGetModKeyState()
	if not meta then return false end
	
	-- Start dragging
	local _, pos = spTraceScreenRay(mx, my, true)
	
	if not pos then return false end
	
	local wx, wy, wz = pos[1], pos[2], pos[3]
	sNodes[1] = {wx, wy, wz}
	sx = wx; sy = wy; sz = wz
	lx = wx; ly = wy; lz = wz
	
	-- Return true, this gives us the next MouseMove/MouseRelease calls.
	dragging = true
	return true
end

function widget:MouseMove(mx, my, mdx, mdy, mButton)
	
	local _, pos = spTraceScreenRay(mx, my, true)
	
	if not pos then return end
	
	local wx, wy, wz = pos[1], pos[2], pos[3]
	sNodes[#sNodes + 1] = {wx, wy, wz}
	lx = wx; ly = wy; lz = wz
end

function widget:MouseRelease(mx, my, mButton)
	
	-- Add final node (If different)
	local _, pos = spTraceScreenRay(mx, my, true)
	
	if pos then
		local wx, wy, wz = pos[1], pos[2], pos[3]
		if ((wx ~= lx) or (wy ~= ly) or (wz ~= lz)) then
			sNodes[#sNodes + 1] = {wx, wy, wz}
			lx = wx; ly = wy; lz = wz
		end
	end
	
	if (#sNodes < 2) then
		-- Not enough nodes
		-- Reset nodes
		sNodes = {}
		dragging = false
		return
	end
	
	-- We need list of {x1, y1, x2, y2, M, C}
	local sLines = {}
	
	-- First point is end-node
	local s2x, s2y = lx, lz
	
	-- Retain consistancy, check if last nodes value would be modifier in last interation 
	-- i.e. if it was horz/vert w.r.t prev node
	-- If it would be modified then, then we also need to modify it here, 
	-- otherwise we can get a 'break' in the loop
	local sp = sNodes[#sNodes - 1]
	local spx, spy = sp[1], sp[3]
	if (s2x == spx) then
		s2x = s2x + 0.01
	end
	if (s2y == spy) then
		s2y = s2y + 0.01
	end
	
	for i=1, #sNodes do
		
		local s1x = s2x
		local s1y = s2y
		
		local s2 = sNodes[i]
		s2x = s2[1]
		s2y = s2[3]
		
		-- Our code fails with near horizontal/verticle lines
		-- This happens often due to integer screen coords
		-- Proper solution: Handle vert/horz cases
		-- Easiest solution: Add small number to make non-vert/horz
		-- Note: These changes will propogate due to 's1x = s2x' etc
		-- So changing values does not bring about inconsistancies or non-connecting lines
		if (s2y == s1y) then
			s2y = s2y + 0.01
		end
		if (s2x == s1x) then
			s2x = s2x + 0.01
		end
		
		local Ms = (s2y - s1y) / (s2x - s1x)
		
		sLines[i] = {s1x, s1y, s2x, s2y, Ms, s1y - Ms * s1x}
	end
	
	-- Now we find the selected units
	-- We need a list of all units we can see
	-- Spectators can select all units, players can only select their own
	local spec = spGetSpecState()
	local visUnits
	
	if spec then
		visUnits = spGetVisibleUnits()
	else
		visUnits = spGetVisibleUnits(spGetMyTeamID())
	end
	
	-- Units to select will be an array (Maps are OK too)
	local toSel = {}
	local toSelCount = 0
	
	-- Loop over each unit
	for i=1, #visUnits do
		
		-- Get screen position for unit
		local uID = visUnits[i]
		local ux, _, uz = spGetUnitPos(uID)
		
		-- The 'line' we use for this unit goes from (0, 0) to (sx, sy), why? Easy M and no C
		local Mu = uz / ux
		-- Cu = 0
		
		-- Check if point is in selection polygon
		-- Count intercepts
		local intercepts = 0
		
		for i=1, #sNodes do
			
			-- Speed
			local sLine = sLines[i]
			
			-- Get interception point
			local ix = sLine[6] / (Mu - sLine[5])
			local iy = Mu * ix
			
			-- Check bounds
			if ((-ix) * (ix - ux) >= 0) and
			   ((-iy) * (iy - uz) >= 0) and
			   ((sLine[1] - ix) * (ix - sLine[3]) >= 0) and
			   ((sLine[2] - iy) * (iy - sLine[4]) >= 0) then
			   
			   intercepts = intercepts + 1
			end
		end
		
		-- Even = outside, Odd = inside.
		if ((intercepts % 2) == 1) then
			toSelCount = toSelCount + 1
			toSel[toSelCount] = uID
		end
	end
	
	-- Select the units
	-- Different things happen depending on mod keys
	local _, ctrl, _, shift = spGetModKeyState()
	
	if ctrl then
	
		-- ctrl 'inverts' when selecting
		-- For units that we are going to select, if they are already selected, they become unselected
		local selUnits = spGetSelUnits()
		
		-- Loop over selected units
		for i=1, #selUnits do
			
			local uID = selUnits[i]
			local match = false
			
			-- Check this unit against poly units
			for j=1, toSelCount do
				if (toSel[j] == uID) then
					match = j
					break
				end
			end
			
			if match then
				-- Selected unit is also in poly
				-- So we shouldn't select it
				-- Remove from toSel
				tremove(toSel, match)
			else
				toSelCount = toSelCount + 1
				toSel[toSelCount] = uID
			end
		end
	else
		if shift then
			
			-- Easy, add units we already have selected, unless they are in poly
			-- We probably don't want to have duplicates in what we select
			local selUnits = spGetSelUnits()
			
			for i=1, #selUnits do
				
				local uID = selUnits[i]
				local inPoly = false
				
				-- Check this unit against poly units
				for j=1, toSelCount do
					if (toSel[j] == uID) then
						inPoly = true
						break
					end
				end
				
				-- Add if wasn't found
				if not inPoly then
					toSelCount = toSelCount + 1
					toSel[toSelCount] = uID
				end
			end
		end
	end
	
	-- Modifiers handled, select units
	spSelUnitArray(toSel)
	
	-- Reset nodes
	fNodes = sNodes
	fAlpha = 1.0
	sNodes = {}
	dragging = false
end

---------------------------------------------------------------------------
