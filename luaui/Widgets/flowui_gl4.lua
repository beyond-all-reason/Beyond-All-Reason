

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = 'FlowUI GL4 Tester',
		desc      = 'FlowUI GL4 Testing',
		author    = 'Beherith',
		version   = '1.0',
		date      = '2021.05.020',
		license   = 'Lua code: GNU GPL, v2 or later; GLSL code: (c) Beherith mysterme@gmail.com',
		layer     = 100,
		enabled   = false,
	}
end

local debugmode = false

local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local GL_LINES = GL.LINES
local font, loadedFontSize
local rectRoundVBO = nil
local vsx, vsy = Spring.GetViewGeometry()
local groups = {} -- {energy = 'LuaUI/Images/groupicons/'energy.png',...}, retrieves from buildmenu in initialize
local unitGroup = {}	-- {unitDefID = 'energy'}retrieves from buildmenu in initialize
local unitIcon = {}	-- {unitDefID = 'icons/'}, retrieves from buildmenu in initialize


local iconTypes = VFS.Include("gamedata/icontypes.lua")
for udid, unitDef in pairs(UnitDefs) do
	if unitDef.iconType and iconTypes[unitDef.iconType] and iconTypes[unitDef.iconType].bitmap then
		unitIcon[udid] = iconTypes[unitDef.iconType].bitmap
	end
end
iconTypes = nil

--- OO stuff
-- Each uielement should have a parent, and can have any number of childrent
-- A uiElement may consist of any combination of geometric primitives
-- A uiElement may have a table of fonts assigned to it
-- Should have a known position, and maybe even have its own highlight instance
-- A uielement can be deleted, which will result in the deletion of all of its children
-- an element can be hidden, which will also hide all of its children
-- an element can be shown, which will show all of its children
	-- this is bad because of highlighting

-- element data members:

	-- flatprimitives{} -- an array of VBO keys
	-- blendedprimitives{} -- an array of VBO keys
	-- TextElements{} -- this one is kinda hard, but well figure it out
	-- bool mousehits()
		-- A nice recursive call,

	-- bool visible

-- element functions:

	-- Hide()
		-- hides self and all children
	-- Show()
		-- shows self and all children
	-- Toggle()
		-- inverts self, and sets all children to it
	-- Remove()
		-- deletes all children and self

	-- Update()
		-- Should update its own primitives (probably by deleting and recreating them)
		--
	-- Mouseover()
		-- a function on what to do when mouse is over it
	-- OnClick()
		--
	-- AddChild()
	-- RemoveChild()
	-- GetChildByName()



-- element 'Callbacks'


-- Draw Implementation
-- the Z depth of any element must be greater than its childrens
-- We need 2 separate VBOS, for flat blended and alpha blended stuff. Draw the flat first, then the alpha blended one
-- we need a manager for all text type UI elements, consider replacing as much text as posssible with textures!
-- Only textures that are actually in the atlas are renderable
-- the atlas is built once, and queried

-- We can entirely avoid alpha blended, if we specify a 'highlighttexture' and a blendfactor


-- Notes from 2022.10.21 ---------------------------------------------------------
-- We can ignore the WHOLE blendedprimitives shit from above because of in-shader highlighting!
-- WHERE IS THE ORIGIN IN SCREENSPACE: BOTTOM LEFT!
-- what if we just went the array table way?

-- TODO: 2022.10.28
-- Remove element, make sure that the Z order of individual graphical elements is correct when removing elements.
	-- the best way to ensure that removal happens in the correct order, is to set all drawn elements to nonhidden
	-- then override the rebuilding of the VBO
-- Allow the querying and creation of one 'root element and'  per widget.
-- rename the alignment stuff of left right top down etc with all caps!

-- todo 2022.11.04
-- DONE: auto Z with treedepth!

-- todo 2023.01.09
	-- hovertooltip
		-- a static, single element, that traces back on hoveredchanged
		-- Needs its own class that resizes itself (smartly)
	-- drag support (for sliders etc)

-- TODO 2023.02.03
	-- TODO: add support for requesting a 'layer' for a widget
	-- DONE: Clamp cornersize to half of min(width,height)
	-- DONE: compartmentalize slider
	-- DONE: add 'scissor' uniforms for each 'layer' object
	-- DONE: add 'scissor' uniforms for each 'layer' object
	-- TODO: Make the whole shit screen size aware
	-- DONE: drag is not 'sticky'

-- Regarding "Layers":
	-- Due to the way draw order must be preserved, layers are an important thing.
	-- Each layer has its own InstanceVBO!
	-- Layers are drawn in allocation order
	-- Layer Properties
		-- Each layer can have its own scissor test (ideally set to parent object)
		-- And each layer can have its own scrollscale
		-- Each layer has its own list of text elements
		-- Each layer can have its own default styling.
	-- A layer could be the child of a non-root object?

-- TODO 2023.02.07
	-- DONE: Add LEFT RIGHT TOP BOTTOM parent-relative coords
	-- DONE: Separate window title bar
	-- TODO: implement resizing via recreation...
	-- TODO: make highlightability dependend on having mouseEvents by default

-- TOOD 2023.02.19
	-- rewrite the entire goddamned shader to use a bitmask integer
	-- and to use rectangles instead of tris
	-- and to use a smaller number elements


local Draw = {}
local vsx, vsy = Spring.GetViewGeometry()
local nameCounter = 0
local ROOT -- this is the global root, its children can only be layers!
local Layers = {} -- A sorted list of Layer objects, each containing its own text list, its own scissor, and all kinds of other fun stuff. Maybe even setting its own stying like textcolor, outlinecolor? , keyed with layername
local LayerDrawOrder = {} --


local floor = math.floor
-- what if I enabled LEFT, RIGHT, TOP, BOTTOM?
-- and calced X,Y, W,H from it?


-- This will be the base metatable, and contains the functions and static members that we want
local metaElement = {
	vsx = vsx,
	vsy = vsy,
	vbokeys = {left = 1, bottom = 2, right=3, top = 4, tl = 5, tr = 6, br = 7, bl = 8,
		color1r = 9, color1g = 10, color1b = 11, color1a = 12, color2r = 13, color2g = 14, color2b = 15, color2a = 16,
		uvbottom = 17, uvleft = 18, uvtop = 19, uvright = 20,
		fronttexture = 21, edge = 22, zdepth = 23, progress = 24,
		hide = 25, blendmode = 26, globalbg = 27, unused = 28,
	},
	textalignments = {topleft = 1, top = 2, topright = 3, left = 4, center = 5, right = 6, bottomleft = 7, bottom = 8, bottomright =9},
	currtextcolor = {1,1,1,1},
	curroutlinecolor = {0,0,0,1},
	vboCache = {}, -- This is a 'reusable' table for getElementInstanceData
	textChanged = false, -- this is used to indicate wether rebuilding text display list is needed
}

local metaElement_mt = {
	__index = metaElement,
}

function metaElement:ProcessRelativeCoords()
	local padding = self.padding or 0
	local parent = self.parent
	if self.LEFT then
		if type(self.LEFT) == 'string' then
			self.left = parent.left + (parent.right-parent.left) * tonumber(string.sub(self.LEFT,1,-1))/100.0 + padding
		else
			self.left = parent.left + self.LEFT + padding
		end
	end

	if self.RIGHT then
		if type(self.RIGHT) == 'string' then
			self.right = parent.right - (parent.right-parent.left) * tonumber(string.sub(self.RIGHT,1,-1))/100.0 - padding
		else
			self.right = parent.right - self.LEFT - padding
		end
	end

	if self.BOTTOM then
		if type(self.BOTTOM) == 'string' then
			self.bottom = parent.bottom + (parent.top-parent.bottom) * tonumber(string.sub(self.BOTTOM,1,-1))/100.0 + padding
		else
			self.bottom = parent.bottom + self.BOTTOM + padding
		end
	end

	if self.TOP then
		if type(self.TOP) == 'string' then
			self.top = parent.top - (parent.top-parent.bottom) * tonumber(string.sub(self.TOP,1,-1))/100.0 - padding
		else
			self.top = parent.top - self.TOP - padding
		end
	end

	if self.WIDTH then
		if type(self.WIDTH) == 'string' then
			--Spring.Debug.TraceEcho(self.left, parent.right, parent.left, self.WIDTH,string.sub(self.WIDTH,1,-1))
			--Spring.Debug.TraceFullEcho(30,30,30)
			self.right = self.left + (parent.right-parent.left) * tonumber(string.sub(self.WIDTH,1,-1))/100.0 - padding
		else
			self.right = self.left + self.WIDTH - padding
		end
	end

	if self.HEIGHT then
		if type(self.HEIGHT) == 'string' then
			self.top = self.bottom + (parent.top-parent.bottom) * tonumber(string.sub(self.HEIGHT,1,-1))/100.0 - padding
		else
			self.top = self.bottom + self.HEIGHT - padding
		end
	end
	if not self.left   then self.left   = self.parent.left   + padding end
	if not self.right  then self.right  = self.parent.right  - padding end
	if not self.bottom then self.bottom = self.parent.bottom + padding end
	if not self.top    then self.top    = self.parent.top    - padding end
end

local function newElement(o) -- This table contains the default properties
	if o == nil then o = {} end
	if type(o) ~= 'table' then Spring.Debug.TraceEcho() end
	if o.name == nil then -- auto namer
		nameCounter = nameCounter + 1
	end

	local element =   {
		name = o.name or 'element'..tostring(nameCounter),
		--left = o.x or 0,
		--bottom = o.y or 0,
		--right = o.w or vsx,
		--top = o.h or vsy,
		depth = o.depth or 0.5, -- halfway?
		treedepth = 1, -- how deep we are in the render tree
		hidden = false,
		MouseEvents = o.MouseEvents or {}, --{left = func, right = func.., middle, enter, leave, hover} these funcs get self as first param
		--self.children = {},
		--textelements = {},
		--visible = true,
		--clickable = false,
		--parent = ROOT,
		--instanceKeys = {}, -- a table of the instancekeys corresponding to this piece of shit
	}
	-- Set the metatable, and update its values
	local obj = setmetatable(element, metaElement_mt)
	for k,v in pairs(o) do obj[k] = v end

	-- Here, we search for the objects parent, calculate its depth, and figure out which VBO to use
	if not obj.isroot then
		local parent = obj.parent or ROOT
		obj.parent = parent

		if parent.children == nil then
			parent.children = {[obj.name] = obj}
		else
			parent.children[obj.name] = obj
		end
		obj.treedepth = obj.parent.treedepth + 1
		-- autodepth here:
		if o.depth == nil then
			element.depth = 0.5 - obj.treedepth * 0.002
		end
		if parent.VBO then
			--Spring.Echo("Setting VBO of ",obj.name,'from parent', parent.name,'to', parent.VBO.myName)
			obj.VBO = parent.VBO
		end
		if parent.layer then
			obj.layer = parent.layer
		else
			Spring.Debug.TraceEcho(obj.name .. " parented to ".. obj.parent.name.. " has no layer")
		end
	end
	-- Ok, so this is where parent-relative positioning comes in, and is expressed in percent
	obj:ProcessRelativeCoords()


	if obj.textelements then
		local cachetextelements = obj.textelements
		obj.textelements = nil

		for i, te in ipairs(cachetextelements) do
			obj:AddText(te.ox, te.oy, te.text, te.fontsize, te.textoptions, te.alignment, te.textcolor, te.outlinecolor)
		end

		for i, te in ipairs(obj.textelements) do
			obj:UpdateTextPosition(te)
		end

	end

	return obj
end

-- Note that this takes
-- aligment can be any of ['top', 'left','bottom','right', 'center', 'topleft', 'topright', 'bottomleft', 'bottomright' ]
-- [1 2 3]
-- [4 5 6]
-- [7 8 9]
function metaElement:UpdateTextPosition(newtext) -- for internal use only!
	if newtext.text == nil then Spring.Debug.TraceEcho() end
	if newtext.fontsize == nil then Spring.Debug.TraceEcho() end
	newtext.textwidth  = font:GetTextWidth(newtext.text)  * newtext.fontsize
	newtext.textheight = font:GetTextHeight(newtext.text) * newtext.fontsize
	if newtext.alignment == nil then return end
	--Spring.Debug.TraceFullEcho(nil,nil,nil,newtext.alignment)
	if self.textalignments[newtext.alignment] == nil then
		Spring.Echo("Text alignment for",newtext.text, "is invalid:", newtext.alignment)
		--return
	end
	local elementwidth = self.right - self.left
	local elementheight = self.top - self.bottom
	local alignInteger = tonumber(newtext.alignment) or self.textalignments[newtext.alignment] or 5 --default center

	if debugmode then Spring.Echo(newtext.alignment, newtext.text, newtext.textwidth, newtext.textheight, elementwidth, elementheight) end
	--if true then return end
	--X coord
	if alignInteger % 3 == 1 then -- left
		newtext.ox = 0
	elseif alignInteger % 3 == 0 then -- right
		newtext.ox = elementwidth - newtext.textwidth
	else -- X center
		newtext.ox = (elementwidth - newtext.textwidth)/2
	end
	--Y coord
	if alignInteger <= 3 then -- top
		newtext.oy = elementheight - newtext.textheight
	elseif alignInteger >= 7 then -- bottom
		newtext.oy = 0
	else -- Y center
		newtext.oy = (elementheight - newtext.textheight)/2
	end
	newtext.ox = floor(newtext.ox)
	newtext.oy = floor(newtext.oy)
	self.layer.textChanged = true
end


function metaElement:AddText(ox, oy, text, fontsize, textoptions, alignment, textcolor, outlinecolor)
	-- it is now that we need to cache text height, and width
	if self.layer == nil then
		Spring.Debug.TraceEcho(self.name)
		--Spring.Debug.TraceFullEcho()
	end
	self.layer.textChanged = true
	local newtext = {
			ox = ox, -- offset from bottom left corner of parent element
			oy = oy,
			text = text or "notext",
			fontsize = fontsize or 12,
			textoptions = textoptions or "",
			textcolor = textcolor,
			outlinecolor = outlinecolor,
			alignment = alignment or 'center',
		}

	if self.textelements == nil then self.textelements = {} end
	self.textelements[#self.textelements + 1] = newtext
	self:UpdateTextPosition(newtext)
	return #self.textelements
end

function metaElement:RemoveText(textindex)
	if self.textelements then
		layer.textChanged = true
		return table.remove(self.textelements, textindex)
	end
end

-- returns number of texts drawn, can also just count them
function metaElement:DrawText(px,py,onlycount) -- parentx,parenty
	--Spring.Echo(self)
	local count = 0
	if self.textelements and not self.hidden then
		for i, text in ipairs(self.textelements) do
			if not onlycount then
				font:Print(text.text, text.ox + self.left, text.oy + self.bottom, text.fontsize, text.textoptions)
			end
			count = count + 1
			--Spring.Echo(text.text,text.ox, px, text.oy, py)
		end
	end
	if self.children then
		for name, child in pairs(self.children) do
			count = count + child:DrawText(self.left, self.bottom, onlycount)
		end
	end
	return count
end

function metaElement:GetElementUnderMouse(mx,my,depth)
	if self.hidden then return false end
	depth = depth or 1
	local hit = false
	self.x = 1
	--Spring.Echo("Testing",depth, self.name, self.left,self.right,self.top,self.bottom)
	if mx >= self.left and mx <= self.right and my <= self.top and my >= self.bottom then hit = true end
	--Spring.Echo("result:",hit)
	if hit == false then return nil end

	--Spring.Echo("Testing",self.name, self.left,self.right,self.top,self.bottom)
	local childHit
	if self.children then
		for _, childElement in pairs(self.children) do -- assume no overlap between children, hit-first
			childHit = childElement:GetElementUnderMouse(mx,my,depth + 1)
			if childHit then break end
		end
	end
	return childHit or self -- no children were hit, only us

end

-- Will set all children to that visibility state too!
function metaElement:SetVisibility(newvisibility)
	--Spring.Echo("SetVisibility", self.name, newvisibility)
	if newvisibility == false then
		self.hidden = true -- this is for hit tests
	else
		self.hidden = false
	end
	self.layer.textChanged = true
	self:UpdateVBOKeys('hide', newvisibility and 0 or 1)

	if self.children then
		for _, childElement in pairs(self.children) do
			childElement:SetVisibility(newvisibility)
		end
	end
end

function metaElement:UpdateVBOKeys(keyname, value, delta)
	if self.instanceKeys then
		for i,instanceKey in ipairs(self.instanceKeys) do
			local VBO = self.VBO or rectRoundVBO
			local success = getElementInstanceData(VBO, instanceKey, self.vboCache) -- this is empty! probbly instance does not exist in this
			if success == nil then
				Spring.Echo("element not found",self.name, VBO.myName,instanceKey)
				Spring.Debug.TraceFullEcho()
			end

			if delta then
				local cache = self.vboCache

				self.vboCache[self.vbokeys[keyname]] = self.vboCache[self.vbokeys[keyname]] + delta
			else
				self.vboCache[self.vbokeys[keyname]] = value
			end
			pushElementInstance(VBO,self.vboCache, instanceKey, true)
			--todo needs a 'refresh' trigger for the ivbo
		end
	end
end


function metaElement:Reposition(dx, dy)
	-- move elements
	self.left = self.left + dx
	self.bottom = self.bottom + dy
	self.right = self.right + dx
	self.top = self.top + dy

	-- if we are a layer, we must repos our own scissorLayer
	if self.scissorLayer then
		self.scissorLayer[1] = self.scissorLayer[1] + dx
		self.scissorLayer[2] = self.scissorLayer[2] + dy
		self.scissorLayer[3] = self.scissorLayer[3] + dx
		self.scissorLayer[4] = self.scissorLayer[4] + dy
	end
	---if not self.hidden then
		-- move parts
		if self.instanceKeys then
			for i,instanceKey in ipairs(self.instanceKeys) do
				local VBO = self.VBO or rectRoundVBO
				local vboCache = self.vboCache
				getElementInstanceData(VBO, instanceKey, vboCache)
				vboCache[1] = vboCache[1] + dx
				vboCache[2] = vboCache[2] + dy
				vboCache[3] = vboCache[3] + dx
				vboCache[4] = vboCache[4] + dy
				pushElementInstance(VBO,self.vboCache, instanceKey, true)
			end
		end
		-- move text
		if self.textelements then
			for i, textelement in ipairs(self.textelements) do
				--Spring.Echo(Spring.GetDrawFrame(),"repos", self.name, textelement.text)
				--textelement.ox = textelement.ox + dx
				--textelement.oy = textelement.oy + dy
			end
		end
	--end
	if self.children then
		for _, childElement in pairs(self.children) do
			childElement:Reposition(dx,dy)
		end
	end
	self.layer.textChanged = true

end

function metaElement:Destroy(depth)
	--Spring.Echo("Destroying",self.name)
	depth = (depth or 0 ) + 1
	-- 1. hide self and children
	self:SetVisibility(false)
	if self.textelements and  next(self.textelements) then self.layer.textChanged = true end
	-- somehow mark them as dead
	-- trigger a resize on critical amouts of elements changed?
	-- POPPING BACK ELEMENTS IS FORBIDDEN AS IT WILL BREAK DRAW ORDER!
	-- CANNOT USE popElementInstance !
	-- instead track the number of destroyed elements
	for i, instanceKey in ipairs(self.instanceKeys or {}) do
		local VBO = self.VBO or rectRoundVBO
		VBO.instanceIDtoIndex[instanceKey] = nil
		VBO.destroyedElements = (VBO.destroyedElements or 0) + 1 -- this is how we keep track
		metaElement:UpdateVBOKeys('hide',1)
	end
	if self.children then
		for _, childElement in pairs(self.children) do
			childElement:Destroy(depth)
		end
	end
	if (depth == 1) then
		local VBO = self.VBO or rectRoundVBO
		if VBO.destroyedElements * 3 > VBO.usedElements then
			--Spring.Echo("Compacting")
			VBO:compact()
		end
	end
	--deparent
	if self.parent then
		self.parent.children[self.name] = nil
		self.parent = nil
	else
		Spring.Echo("Tried to destroy an orphan element", self.name)
	end


end


function metaElement:CalculatePosition()
	-- to automatically do top left bototm right and percentage values
	-- also check if it changed, and then update it in vbo maybe?
end

function metaElement:AreRectsOverlapping(other)
	return (self.left <= other.right) and (self.right >= other.left) and (self.bottom <= other.top) and (self.top >= other.bottom)
end

local GetNewVBO = function (n) return nil end

-- create a new layer object from the table, but this has to be a metaElement!
function metaElement:CreateLayer(o)
	local obj = newElement(o)
	--for k,v in pairs(o) do obj[k] = v end
	obj.scissorLayer = obj.scissorLayer or {obj.left,obj.bottom,obj.right,obj.top}
	obj.scrollScale = obj.scrollScale or {0,0,1,1}
	obj.textChanged = obj.textChanged or false
	obj.textDisplayList = obj.textDisplayList or nil
	obj.VBO = GetNewVBO(obj.name)
	Layers[obj.name] = obj
	obj.layer = obj
	LayerDrawOrder[#LayerDrawOrder + 1] = obj.name
	obj.islayer = true
	return obj
end

function metaElement:NewContainer(o) -- A no-gfx empty container
	return newElement(o)
end

function metaElement:NewUiElement(o) -- A UiElement
	local obj = newElement(o)
	obj.instanceKeys = Draw.Element(obj.VBO or rectRoundVBO, obj.name, obj.depth, obj.left, obj.bottom, obj.right, obj.top,
		obj.tl, obj.tr, obj.br, obj.bl,  obj.ptl, obj.ptr, obj.pbr, obj.pbl,  obj.opacity, 		obj.color1, obj.color2, obj.bgpadding or 3)
	return obj
end

function metaElement:NewButton(o) -- yay this objs shit again!
	local obj = newElement(o)
	--Spring.Echo(obj.name, obj.left, obj.right, obj.top, obj.bottom)
	--parent, VBO, instanceID, z,px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding)
	obj.instanceKeys = Draw.Button( obj.VBO or rectRoundVBO, obj.name, obj.depth, obj.left, obj.bottom, obj.right, obj.top,
		obj.tl or 1, obj.tr or 1, obj.br or 1, obj.bl or 1,  obj.ptl or 1, obj.ptr or 1, obj.pbr or 1, obj.pbl or 1,  obj.opacity or 1, 		obj.color1, obj.color2, obj.bgpadding or 3)
	return obj
end

function metaElement:NewCheckBox(obj) end

-- creates rectangle, with text in it, set to the current default
-- creates an arrow which opens the combo box
-- The combo box is create on a new layer
-- The new layer is populated with the options of the combo box, each of which are buttons within a control
-- The selector's visibility is triggered by clicking into the combo box or onto the layer
-- Clicking anywhere else should deactivate the combo box (hide it, and its respective layer)
function metaElement:NewSelector(obj) end

-- this one is tricky, see how chili does it?
function metaElement:NewEditBox(obj)
end

function metaElement:NewComboBox(obj)

end

function metaElement:NewSlider(o)
	o.textelements = {
		{text = string.format('%s = %.'.. tostring(o.digits)..'f <D>',o.name, o.defaultvalue), alignment = 'center'},
		{text = string.format('%.'.. tostring(o.digits)..'f',o.min), alignment = 'left'},
		{text = string.format('%.'.. tostring(o.digits)..'f',o.max), alignment = 'right'},}

	o.MouseEvents = {
		left = function(obj, mx, my)
			-- get the offset of within the click?
			local wratio = math.max(0,math.min(1.0,(mx - obj.left) / (obj.right - obj.left)))
			local newvalue = math.round(obj.min + wratio * (obj.max-obj.min), obj.digits)
			local newright = ((newvalue - obj.min) / (obj.max - obj.min)) *(obj.right - obj.left) + obj.left
			if debugmode then Spring.Echo("left clicked", obj.name, mx, wratio, newvalue, newright) end
			obj.updateValue(obj, newvalue, obj.index)
			obj:UpdateVBOKeys('right', newright)
		end,
		right = function(obj, mx, my)
			obj.updateValue(obj, obj.defaultvalue, obj.index, " <D>")
			local newright = ((obj.value - obj.min) / (obj.max - obj.min)) *(obj.right - obj.left) + obj.left
			obj:UpdateVBOKeys('right', newright)
			if debugmode then  Spring.Echo("right clicked", obj.name, mx, my, newright, obj.value) end
		end,
		hover = function (obj,mx,my)
			if obj.tooltip and WG and WG['tooltip'] and WG['tooltip'].ShowTooltip then
				WG['tooltip'].ShowTooltip(obj.name, obj.tooltip)    -- x/y (optional): display coordinates
			end
		end
	}
	o.MouseEvents.drag = o.MouseEvents.left

	local obj = newElement(o)
	Spring.Echo('slidervboname',obj.VBO.myName)
	obj.updateValue = function (obj, newvalue, index, tag)
		if debugmode then  Spring.Echo("updateValue", obj.name, newvalue, index, tag, obj.valuetarget) end
		local oldvalue = obj.value
		if newvalue == nil then return end
		obj.value = newvalue
		if obj.valuetarget then
			if obj.index == nil then
				obj.valuetarget[obj.name] = newvalue
			else
				obj.valuetarget[string.sub(obj.name,1,-2)][index] = newvalue
			end
		end
		obj.textelements[1].text =  string.format('%s = %.'.. tostring(obj.digits)..'f' .. (tag or ""),obj.name, newvalue)
		obj:UpdateTextPosition(obj.textelements[1])
		if obj.callbackfunc then obj.callbackfunc(obj.name, newvalue, index, oldvalue) end
	end


	obj.instanceKeys = Draw.Slider(obj.VBO or rectRoundVBO, obj.name, obj.depth, obj.left, obj.bottom, obj.right, obj.top,
		obj.steps, obj.min, obj.max)

	if obj.VBO.dirty then uploadAllElements(obj.VBO) end

	local defaultPos = ((obj.value - obj.min) / (obj.max - obj.min)) *(obj.right - obj.left) + obj.left
	--Spring.Echo("Slider defaults",obj.value, obj.min, obj.max, obj.right, obj.left,defaultPos)
	obj:UpdateVBOKeys('right', defaultPos)

	return obj
end

--Toggle state = (default: 0) 0 / 0.5 / 1
function metaElement:NewToggle(o)
	local obj = newElement(o)
	obj.instanceKeys = Draw.Toggle(obj.VBO or rectRoundVBO, obj.name, obj.depth, obj.left, obj.bottom, obj.right, obj.top, obj.state)
end

function metaElement:NewUiUnit(o)
	local obj = newElement(o)

	obj.instanceKeys = Draw.Unit(obj.VBO or rectRoundVBO, obj.name, obj.depth, obj.left, obj.bottom, obj.right,obj.top,
			obj.cs, obj.tl or 1, obj.tr or 1, obj.br or 1, obj.bl or 1,  obj.zoom or 1, obj.bordersize ,0.8, --zoom,  borderSize, borderOpacity
			obj.texture,
			obj.radartexture,
			obj.grouptexture,
			obj.price,
			obj.queueCount
		)

			--Draw.Unit = function(VBO, instanceID, z, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom,  borderSize, borderOpacity,  texture, radarTexture, groupTexture, price, queueCount)
			--Draw.Unit(rectRoundVBO, nil, 0.5, x,y,w,y+2*s, 20,
			--1,1,1,1,
			--1, nil, 0.8, -- zoom, bordersize, borderOpacity
			--"unitpics/corcom.dds",
			--"icons/bantha.png",
			--"luaui/images/flowui_gl4/metal.png", --grouptexture
			--500, 7)
	end
function metaElement:NewRectRound(obj) end

function metaElement:NewWindow(o)
	-- Object Hierarchy of standard window:
	-- ROOT
		-- windowlayer
			-- titlebar
				--titlebutton
				--minimizebutton
				--closebutton
			-- window
				--child objects
	local windowlayer = metaElement:CreateLayer(o)
	--o.parent = windowlayer -- is this fucking parenting itself?
	if o.windowtitle == nil then return windowlayer end

	local titlebarheight = o.titlebarheight or 24

	local titlebar = metaElement:NewUiElement({
		name = o.name .. 'titlebar',
		left = o.left,
		right = o.right,
		top = o.top,
		bottom = o.top - titlebarheight,
		parent = windowlayer,
		bl = 0,
		br = 0,
	})

	local window = metaElement:NewUiElement({
		name = o.name .. 'windowcontents',
		left = o.left,
		right = o.right,
		top = o.top - titlebarheight,
		bottom = o.bottom,
		parent = windowlayer,
		tr = 0,
		tl = 0,
	})
	--window.parent = windowlayer
	--window.layer = windowlayer

	local titlebutton = metaElement:NewButton({
		name = o.name .. 'titlebutton',
		left = o.left + 2, bottom = o.top - (titlebarheight - 2) ,right = o.right - 42, top = o.top - 2,
		bl = 0, tr = 0, br = 0,
		parent = titlebar,
		tooltip = "Drag the window here",
		textelements = {{text = o.windowtitle or "Draggy boi", fontsize = 16, alignment = 'top'},},
		MouseEvents= {drag = function (obj, mx, my, lastmx, lastmy)
			--Spring.Echo(obj.name, 'drag', mx, lastmx, my, lastmy)
			obj.layer:Reposition(mx - lastmx, my - lastmy) --- ooooh this is really nasty
			--obj.layer.scissorLayer[1] = obj.layer.scissorLayer[1] + mx - lastmx
			--obj.layer.scissorLayer[2] = obj.layer.scissorLayer[2] + my - lastmy
			end },
	})

	local minimizebutton = metaElement:NewButton({
		name = o.name .. 'minimizebutton',
		left = o.right -42 , bottom = o.top - (titlebarheight - 2) ,right = o.right - 22, top = o.top - 2,
		tl = 0, tr = 0, bl = 0, br = 0,
		parent = titlebar,
		tooltip = "minimize",
		minimized = false,
		delta = o.top - 22 - o.bottom,
		textelements = {{text = "_", fontsize = 16, alignment = 'center'},},
		MouseEvents = {left = function(obj, mx, my)
			-- hide all children below top
			-- initstate
			Spring.Echo(obj.name, 'minimize')
			obj.minimized = not obj.minimized
			--obj.parent:UpdateVBOKeys('bottom', nil, obj.minimized and (obj.delta) or (-1* obj.delta))
			local siblings = obj.parent.parent.children
			for _, childElement in pairs(siblings) do
				if childElement.top < obj.bottom then
					childElement:SetVisibility(not obj.minimized)
				end
			end
			end}
	})

	local closebutton = metaElement:NewButton({
		name = o.name .. 'close',
		left = o.right -22 , bottom = o.top - 22 ,right = o.right - 2, top = o.top - 2,
		br = 0, tl = 0, bl = 0,
		parent = titlebar,
		tooltip = "close",
		textelements = {{text = "X", fontsize = 16, alignment = 'center'},},
		MouseEvents = {left = function(obj, mx, my)
			Spring.Echo(obj.name, "close")
			obj.parent.parent:Destroy()
			end}
	})
	if o.testsliders then
		-- some rando sliders:
		for i, rando in ipairs({"one","two","three","four","five","six","seven","eight","nine","ten",'1','2','3','4','5','6','7','8'}) do
			if i > 20 then break end
				local newSliderBorder = metaElement:NewUiElement({
					LEFT = 4,
					bottom = o.bottom + (i-1) * 20 + 4,
					RIGHT = 4,
					top = o.bottom + (i) * 20 + 4,
					parent = window,
					bl= 0, br = 0, tl = 0, tr = 0,
				})

				local newSlider = metaElement:NewSlider({
					padding = 2, -- note how not specifying any pos will just pad it within its parent!
					name = rando,
					tooltip = rando,
					min = 1,
					max = 10,
					digits = 2,
					parent =newSliderBorder,
					value = 3,
					defaultvalue = 3,
					valuetarget = nil,
					callbackfunc = function (name,val) Spring.Echo(name,val) end ,
					index = i,
				})
				i = i+1
		end
	end
	return windowlayer, window
end

local function BringLayerToFront(layername)
	local oldindex = nil
	for i,name in ipairs(LayerDrawOrder) do -- todo: iterate reverse for speed?
		if name == layername then
			oldindex = i
			break
		end
	end
	if oldindex and oldindex < #LayerDrawOrder then
		for i = oldindex, #LayerDrawOrder -1 do
			LayerDrawOrder[i] = LayerDrawOrder[i+1]
		end
		LayerDrawOrder[#LayerDrawOrder] = layername
	end
end

--function metaElement:NewEmpty(obj) end

ROOT = metaElement:NewContainer({isroot = true,name = "ROOOOOOOT", left = 0, right = vsx, bottom = 0, top = vsy})

local lastmouse = {mx = 0, my = 0, left = false, middle = false, right = false}
local lasthitelement = nil -- this is to store which one was last hit to fire off mouseentered mouseleft events
local draggableelement = nil
-- TODO: debounce clicking!

local function uiUpdate(mx,my,left,middle,right)
	--if true then return end
	-- this needs to be revamped, to trace the element under cursor, and then act based on clickedness
	local elementundercursor
	local bringtofront = false
	if false and mx == lastmouse.mx and my == lastmouse.my then -- this will probably be bad in the future!
		elementundercursor = lasthitelement
	else
		for i=#LayerDrawOrder, 1, -1 do
			local hittest = Layers[LayerDrawOrder[i]]:GetElementUnderMouse(mx,my)
			if hittest then
				elementundercursor = hittest
				break
			end
			--elementundercursor = ROOT:GetElementUnderMouse(mx,my) -- root will always hit!
		end
		if lasthitelement and lasthitelement.MouseEvents and (elementundercursor == nil or elementundercursor.name ~= lasthitelement.name) then
			if lasthitelement.MouseEvents.leave then
				lasthitelement.MouseEvents.leave(lasthitelement, mx, my)
			end
			if elementundercursor and elementundercursor.MouseEvents and elementundercursor.MouseEvents.enter then
				elementundercursor.MouseEvents.enter(elementundercursor, mx, my)
			end
		end
	end

	-- Sensible Drag:
	-- Click must _start_ inside of a draggable element

	if left and not lastmouse.left and elementundercursor
		and elementundercursor.MouseEvents and elementundercursor.MouseEvents.drag then
		draggableelement = elementundercursor
	elseif left == false then
		draggableelement = nil
	end

	if draggableelement and left and lastmouse.left and
		((mx ~= lastmouse.mx) or (my ~= lastmouse.my))
		then -- drag
		draggableelement.MouseEvents.drag(draggableelement,mx,my,lastmouse.mx, lastmouse.my)
		bringtofront = true
	end

	if lasthitelement ~= elementundercursor and elementundercursor then
		--Spring.Echo("hit",elementundercursor.name, elementundercursor.left, elementundercursor.right, elementundercursor.bottom, -elementundercursor.top)
	end

	lasthitelement = elementundercursor
	if elementundercursor and elementundercursor.MouseEvents then
		--Spring.Echo(elementundercursor, elementundercursor.name)
		if left and left ~= lastmouse.left then
			if elementundercursor.MouseEvents.left then
				elementundercursor.MouseEvents.left(elementundercursor,mx,my)
				bringtofront = true
			end
		end

		if left and lastmouse.left and (lastmouse.mx ~= mx or lastmouse.my ~= my) then
			--if elementundercursor.MouseEvents.drag then elementundercursor.MouseEvents.drag(elementundercursor,mx,my,lastmouse.mx, lastmouse.my) end
		end

		if middle and middle ~= lastmouse.middle then
			if elementundercursor.MouseEvents.middle then
				elementundercursor.MouseEvents.middle(elementundercursor, mx, my)
				bringtofront = true
			end
		end
		if right and right ~= lastmouse.right then
			if elementundercursor.MouseEvents.right then
				elementundercursor.MouseEvents.right(elementundercursor, mx, my)
				bringtofront = true
			end
		end
		if elementundercursor.MouseEvents.hover then
			elementundercursor.MouseEvents.hover(elementundercursor, mx, my)
		end
	end
	lastmouse.mx = mx
	lastmouse.my = my
	lastmouse.left = left
	lastmouse.middle = middle
	lastmouse.right = right
	if bringtofront and elementundercursor and elementundercursor.layer then
		BringLayerToFront(elementundercursor.layer.name)
	end
end

local textDisplayList = nil
local useTextDisplayList = true


local function RefreshText() -- make this a member of layer class?
	if useTextDisplayList then
		for layername, Layer in pairs(Layers) do
			if Layer.textChanged then
				if Layer.textDisplayList then gl.DeleteList(Layer.textDisplayList) end
				local textcount = Layer:DrawText(0,0,true)
				if textcount >0 then
					--Spring.Echo(Spring.GetDrawFrame(),"layer text rebuilt", layername)
					Layer.textDisplayList = gl.CreateList(
						function ()
						font:Begin()
						Layer:DrawText(0,0)
						--font:SubmitBuffered(true) -- doesnt help at all :(
						font:End()
					end)
				else
					Layer.textDisplayList = nil
				end
				Layer.textChanged = false
			end
		end
	end
end



local function DrawText()
	--if true then return end
	if useTextDisplayList then
		--Spring.Echo("ROOT.textChanged",ROOT.textChanged)
		if textDisplayList == nil or ROOT.textChanged then
			--Spring.Echo("Textchanged rebuilding display lists")
			ROOT.textChanged = false
			textDisplayList = gl.CreateList(function ()
			font:Begin()
			ROOT:DrawText(0,0)
			--font:SubmitBuffered(true) -- doesnt help at all :(
			font:End()
			end
			)
		end
		gl.CallList(textDisplayList)

	else
		font:Begin()
		ROOT:DrawText(0,0)
		--font:SubmitBuffered(true)
		font:End()
	end
end


-------------------------- SILLY UNIT TESTS --------------------------------
local sliderValues = {alpha = 1, beta = 2, gamma = 1, delta = 0, kappa = {0,1,2}}
local sliderParamsList = {
	{name = 'alpha', min = 0, max = 10, digits = 1},
	{name = 'beta', min = -1, max = 3, digits = 3},
	{name = 'gamma', min = 0, max = 1, digits = 1},
	{name = 'delta', min = 0, max = 1, digits = 0},
	{name = 'kappa', min = 0, max = 10, digits = 0},
}

local sliderListConfig = {
	name = 'TestSliders',
	left = vsx - 220,
	bottom = vsy - 300,
	width = 200,
	height = 32,
	valuetarget = sliderValues,
	sliderParamsList = sliderParamsList,
	callbackfunc = function (a,b,c) Spring.Echo("Callback",a,b,c) end,
}

local function requestWidgetLayer(widgetLayerParameters)
	local newWindow, contents = metaElement:NewWindow(widgetLayerParameters)
	return newWindow, contents
end


local function makeSliderList(sliderListConfig)
	local width = sliderListConfig.width or 200
	local sliderheight = sliderListConfig.sliderheight or 50
	local left = sliderListConfig.left or 0
	local bottom = sliderListConfig.bottom or 0
	local valuetarget= sliderListConfig.valuetarget

	local i = 0
	local numelements = 0
	for k1,v1 in ipairs(sliderListConfig.sliderParamsList) do
		if type (valuetarget[v1.name]) == 'table' then
			for k2,v2 in ipairs(valuetarget[v1.name]) do
				numelements = numelements + 1
			end
		else
			numelements = numelements + 1
		end
	end
	-- create a UI container:
	local container

	if sliderListConfig.parent == nil then
		container = metaElement:NewUiElement({
			name = sliderListConfig.name, left = left -4, bottom = bottom -4, right = left + width + 4, top = bottom + (numelements + 1) * sliderheight + 4,
			color1 = {1,1,1,0.5}, color2 = {0,0,0,1.0}, opacity = 0.2,
			parent = ROOT
		})
	else
		container = sliderListConfig.parent
	end

	for sliderorder, sliderParams in ipairs(sliderListConfig.sliderParamsList) do
		local nest = false
		local nestvals = {valuetarget[sliderParams.name]}
		if type(valuetarget[sliderParams.name]) == 'table' then
			nest = true
			nestvals = valuetarget[sliderParams.name]
		end

		for index, defaultvalue in ipairs(nestvals) do
			local nestname = ( nest and tostring(index)) or ""
			if nest == false then index = nil end
			local newSlider = metaElement:NewSlider({
				--left = left,
				padding = 4,
				bottom = bottom + i * sliderheight,
				--right = left + width,
				top = bottom + i * sliderheight + (sliderheight - 4),
				name = sliderParams.name..nestname,
				tooltip = sliderParams.tooltip,
				min = sliderParams.min,
				max = sliderParams.max,
				digits = sliderParams.digits,
				parent = container,
				value = defaultvalue,
				defaultvalue = defaultvalue,
				valuetarget = valuetarget,
				callbackfunc = sliderListConfig.callbackfunc,
				index = index,
			})
			i = i+1
		end
		--updateValue(newSlider, valuetarget[slidervalue.name])
	end

	local savebutton = metaElement:NewButton({
		padding = 4,
		--left = left,
		bottom = bottom + (i ) * sliderheight,
		--right = left + width,
		top = bottom + (i + 1) * sliderheight,
		parent = container,
		MouseEvents = {left = function()
			Spring.Echo("Exporting Settings")
			Spring.Echo(valuetarget)
		end},
		textelements = {{text = "Export "..sliderListConfig.name, fontsize = 16, alignment = 'center'},},
	})
	return container
end

local function makebuttonarray()
	for i = 1, 3 do
		for j = 1, 3 do
			--rectRoundVBO, nil, 0.4, x,y,w,h, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, {0.2, 0.8, 0.2, 0.8 }, WG.FlowUI.elementCorner * 0.5
			local newbtn = metaElement:NewButton({
					left = 100 + 100*i,
					bottom = 300 + 50 *j,
					right = 190 + 100*i,
					top = 340 + 50 *j,
					parent = ROOT,
					MouseEvents = {left = function() Spring.Echo("left clicked",i,j) end},
					textelements = {{text = "mytext"..tostring(i).."-"..tostring(j),ox = 0, oy= 16,fontsize = 16,textoptions = 'B'},},

				})


		end
	end
end

local function makeunitbuttonarray()
	local unitButtonLayer = metaElement:CreateLayer({
			name = "unitButtonLayer",
			left = 0,
			bottom = 0,
			top = vsy,
			right = vsx,
			})
	-- what can my boy build?
	local unitDef = UnitDefs[UnitDefNames['armcom'].id]
	for k,v in pairs(unitDef.buildOptions) do
		Spring.Echo(k,v)
	end
	local n = 3
	local s = 110
	for i = 1, n do
		for j = 1, n do
			--rectRoundVBO, nil, 0.4, x,y,w,h, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, {0.2, 0.8, 0.2, 0.8 }, WG.FlowUI.elementCorner * 0.5
			local idx = ((i-1)*10+j) % (#unitDef.buildOptions) + 1
			if unitDef.buildOptions[idx] then
				local thisunitdefid = unitDef.buildOptions[idx]
				local newbtn = metaElement:NewUiUnit({
						name = "unitbutton"..tostring(math.random()),
						LEFT = 1000 + s*i,
						BOTTOM = 100 + s *j,
						right = 1000 + s*(i + 1),
						--WIDTH = "10",
						top = 100 + s*(j+ 1),
						parent = unitButtonLayer,
						layer = unitButtonLayer,
						texture = 'unitpics/'.. UnitDefs[thisunitdefid].name ..'.dds',
						radartexture = unitIcon[thisunitdefid],
						grouptexture = groups[unitGroup[thisunitdefid]],
						MouseEvents = {left = function(obj)
								local instanceKeys = ''
								for i, instanceKey in ipairs(obj.instanceKeys) do instanceKeys = instanceKeys .. "," .. tostring(instanceKey) end
								Spring.Echo("left clicked unit",obj.name, instanceKeys)
						end,
							right = function(obj)
								Spring.Echo("right clicked", obj.name)
								obj:Destroy()
							end
						},
						textelements = {{text = unitDef.name,ox = 0, oy= 0,fontsize = 16,textoptions = 'B',alignment = (i%9 + 1)},},

					})
			else
				break
			end



		end
	end
end

local function AddRecursivelySplittingButton()
	local newbtn = metaElement:NewButton({
		left = 300 ,
		bottom = 100 ,
		right = 1100 ,
		top = 200 ,
		parent = ROOT,
		MouseEvents = {left = function(obj)
				-- add two buttons above self
				local lefthalf = metaElement:NewButton({
						left = obj.left,
						bottom = obj.bottom,
						right = obj.left + (obj.right - obj.left)/2,
						top = obj.top,
						MouseEvents = obj.MouseEvents,
						textelements = {{text = "left",ox = 0, oy= 0,fontsize = 16,textoptions = 'B',alignment = 5},},
						parent = obj,
					})
				local righthalf = metaElement:NewButton({
						left = obj.left + (obj.right - obj.left)/2,
						bottom = obj.bottom,
						right = obj.right,
						top = obj.top,
						MouseEvents = obj.MouseEvents,
						textelements = {{text = "right",ox = 0, oy= 0,fontsize = 16,textoptions = 'B',alignment = 5},},
						parent = obj,
						})

				Spring.Echo("left clicked unit",obj.name, instanceKeys)
		end,
			right = function(obj)
				-- destroy self
				Spring.Echo("right clicked", obj.name)
				obj:Destroy()
			end
		},
		textelements = {{text = "splitme",ox = 0, oy= 0,fontsize = 16,textoptions = 'B',alignment = 5},},

	})
end

--[[
local start = collectgarbage("count")
--makebuttonarray()
start = collectgarbage("count") - start
print ("yay", start)
local brk = 0
print ("end")
]]--
----------------------------------------------------------------
-- GL4 STUFF
----------------------------------------------------------------

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")
local rectRoundShader = nil
local rectRoundVAO = nil
local vsx,vsy = gl.GetViewSizes()
local atlasID = nil
local atlassedImages = {}
--local rectRoundVBO = nil

local vsSrc = [[
#version 420
#line 5000

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 screenpos; // left, bottom, right, top, in pixels
layout (location = 1) in vec4 cornersizes; // tl, tr, br, bl
layout (location = 2) in vec4 color1; // rgba
layout (location = 3) in vec4 color2; // rgba
layout (location = 4) in vec4 uvoffsets; // uvrect, bottom left, top right
layout (location = 5) in vec4 fronttexture_edge_z_progress; //  textured, edgewidth, z,progress
layout (location = 6) in vec4 hide_blendmode_globalbackground;

uniform vec4 scrollScale = vec4(0,0,1,1);

out DataVS {
	vec4 v_screenpos;
	vec4 v_cornersizes;
	vec4 v_color1;
	vec4 v_color2;
	vec4 v_uvoffsets;
	vec4 v_fronttexture_edge_z_progress;
	vec4 v_hide_blendmode_globalbackground;
};

#line 5100
void main() {
	// calculate scroll/scale offsets:
	gl_Position = vec4(screenpos.x * scrollScale.z + scrollScale.x, 0, screenpos.y * scrollScale.w + scrollScale.y,1.0);
	v_screenpos = screenpos * scrollScale.zwzw  + scrollScale.xyxy;
	//v_screenpos = screenpos * scrollScale.zwzw * (sin(timeInfo.x/100) + 1) + scrollScale.xyxy+(cos(timeInfo.x/100)* 100); // hue hue

	// ensure corners are no smaller than they can be
	v_cornersizes = cornersizes * scrollScale.zwzw + scrollScale.xyxy;
	v_cornersizes = min(v_cornersizes, vec4(v_screenpos.z - v_screenpos.x) * 0.5);
	v_cornersizes = min(v_cornersizes, vec4(v_screenpos.w - v_screenpos.y) * 0.5);
	v_color1 = color1;
	v_color2 = color2;
	v_uvoffsets = uvoffsets;
	v_fronttexture_edge_z_progress = fronttexture_edge_z_progress;
	v_hide_blendmode_globalbackground = hide_blendmode_globalbackground;
}
]]

local gsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (points) in;
layout (triangle_strip, max_vertices = 32) out; // 9 tris * 3


//__ENGINEUNIFORMBUFFERDEFS__

#line 20000
in DataVS {
	vec4 v_screenpos;// left, bottom, right, top, in pixels
	vec4 v_cornersizes;
	vec4 v_color1;
	vec4 v_color2;
	vec4 v_uvoffsets;
	vec4 v_fronttexture_edge_z_progress;
	vec4 v_hide_blendmode_globalbackground;
} dataIn[];

out DataGS {
	vec4 g_screenpos;
	vec4 g_uv; // should also contain 'background texture shit'
	vec4 g_color;
	vec4 g_color2;
	vec4 g_fronttex_edge_backtex_hide;
};



#define TL_CORNERSIZE dataIn[0].v_cornersizes.x
#define TR_CORNERSIZE dataIn[0].v_cornersizes.y
#define BR_CORNERSIZE dataIn[0].v_cornersizes.z
#define BL_CORNERSIZE dataIn[0].v_cornersizes.w

#define LEFT dataIn[0].v_screenpos.x
#define BOTTOM dataIn[0].v_screenpos.y
#define RIGHT dataIn[0].v_screenpos.z
#define TOP dataIn[0].v_screenpos.w

#define UV dataIn[0].v_uvoffsets

#define PROGRESS dataIn[0].v_fronttexture_edge_z_progress.w
#define EDGE dataIn[0].v_fronttexture_edge_z_progress.y
#define DEPTH dataIn[0].v_fronttexture_edge_z_progress.z
#define FRONTTEXTURE dataIn[0].v_fronttexture_edge_z_progress.y

#define HIDE dataIn[0].v_hide_blendmode_globalbackground.x
#define BLENDMODE dataIn[0].v_hide_blendmode_globalbackground.y
#define BACKTEXTURE dataIn[0].v_hide_blendmode_globalbackground.z

void addvertexflowui(float spx, float spy, float distfromside){
	g_screenpos = vec4(spx, spy, DEPTH, 1.0);
	g_uv.x = UV.x + (UV.z - UV.x)*((spx - LEFT) /(RIGHT - LEFT));// horz of maintexture
	g_uv.y = UV.y + (UV.w - UV.y)*((spy - BOTTOM)/(TOP - BOTTOM));// vert of maintexture

	g_screenpos.xy = (g_screenpos.xy / viewGeometry.xy)* 2.0 - 1.0; // viewGeometry.xy contains view size in pixels

	g_uv.z = spx; // world uv coords for global background
	g_uv.w = spy; // world uv coords for global background

	float topness = (spy - BOTTOM)/(TOP - BOTTOM); // top is 1, bottom is 0

	g_color = mix(dataIn[0].v_color1, dataIn[0].v_color2, topness);

	g_fronttex_edge_backtex_hide = dataIn[0].v_fronttexture_edge_z_progress;

	float future_feather = 200.0;
	if (EDGE > 0.5 ) {
		float borderwidth1_0 =  distfromside - EDGE ; // 50 - 10
		future_feather = distfromside / borderwidth1_0; // WIP 50 / (50-10)

		//future_feather = (1.0 / EDGE) * (distfromside
		if (distfromside > 1.0) {
			future_feather = -1.0 * distfromside/EDGE;
		}
		else {
			future_feather = 1.0;
		}
		g_color2 = mix(dataIn[0].v_color1, dataIn[0].v_color2, future_feather);
	}else{
		//g_fronttex_edge_backtex_hide.y = 200.0 ;
		g_color2 = vec4(1.0, 0.0, 1.0 , 1.0);
	}
	g_fronttex_edge_backtex_hide.y = future_feather;

	// pack mouseposness into 'backtex', ergo g_fronttex_edge_backtex_hide.z
	g_fronttex_edge_backtex_hide.z = 0.0;
	bvec2 righttopmouse = lessThanEqual(mouseScreenPos.xy, vec2(RIGHT, TOP));
	bvec2 leftbottommouse = greaterThanEqual(mouseScreenPos.xy, vec2(LEFT, BOTTOM));
	g_fronttex_edge_backtex_hide.z = 0;
	if (all(bvec4(righttopmouse, leftbottommouse)) ) {
		g_fronttex_edge_backtex_hide.z = BLENDMODE + 0.5;
		// also pack clickedness into this //	uint mouseStatus; // bits 0th to 32th: LMB, MMB, RMB, offscreen, mmbScroll, locked
		if ((mouseStatus & 1u) > 0u){
			g_fronttex_edge_backtex_hide.z += BLENDMODE + 0.5;
		}
	}



	g_fronttex_edge_backtex_hide.w = HIDE;

	gl_Position = vec4(g_screenpos.x, g_screenpos.y, DEPTH, 1.0);

	g_screenpos = vec4(spx, spy, DEPTH, 1.0);
	EmitVertex();
}


#define HALFPI 1.570796326794896

#define PI 3.1415926535897932384626433832795

#define TWOPI 6.283185307179586476925286766559

float centerx;
float centery;


#line 20149
void main() {
	if (HIDE > 0.5) return; // bail early for hidden elements
	vec4 gs_cornersizes = dataIn[0].v_cornersizes;

	// for progress angles, we will be idiots and only calc it for zero corners

	float invprogress = 1.0-PROGRESS; // at a PROGRESS of 30%, we want to draw the last 70% of the element
	float progress_offset;
	// a progress of 90% means an invprogress of 10%, so we
	float centery = (TOP + BOTTOM) * 0.5;
	float centerx = (LEFT + RIGHT) * 0.5;
	float distfromside = (TOP - BOTTOM) * 0.5;

	// TOPRIGHT side
	if (invprogress<0.125) {
		progress_offset = (RIGHT-LEFT - TR_CORNERSIZE) * clamp((invprogress - 0.0) * 4, 0, 1.0);

		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(RIGHT - TR_CORNERSIZE, TOP, 0.0);
		addvertexflowui(centerx + progress_offset , TOP, 0.0);
		EndPrimitive();

		//TR corner:
		if (TR_CORNERSIZE > 0.1) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(RIGHT, TOP - TR_CORNERSIZE, 0.0);
			addvertexflowui(RIGHT - TR_CORNERSIZE, TOP, 0.0);
			EndPrimitive();
		}
	}

	//RIGHT side:
	if (invprogress<0.375) {
		progress_offset = (TOP-BOTTOM - TR_CORNERSIZE - BR_CORNERSIZE) * clamp((invprogress - 0.125) * 4, 0, 1.0);

		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(RIGHT, BOTTOM + BR_CORNERSIZE, 0.0);
		addvertexflowui(RIGHT, TOP - TR_CORNERSIZE - progress_offset, 0.0);
		EndPrimitive();

		//BR corner:

		if (BR_CORNERSIZE > 0.1) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(RIGHT - BR_CORNERSIZE, BOTTOM, 0.0);
			addvertexflowui(RIGHT, BOTTOM + BR_CORNERSIZE, 0.0);
			EndPrimitive();
		}
	}

	//BOTTOM side:
	if (invprogress<0.625) {
		progress_offset = (RIGHT-LEFT - BL_CORNERSIZE - BR_CORNERSIZE) * clamp((invprogress - 0.375) * 4, 0, 1.0);

		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(LEFT + BL_CORNERSIZE, BOTTOM, 0.0);
		addvertexflowui(RIGHT - BR_CORNERSIZE - progress_offset, BOTTOM, 0.0);
		EndPrimitive();

		//BL corner:
		if (BL_CORNERSIZE > 0.01) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(LEFT , BOTTOM + BL_CORNERSIZE, 0.0);
			addvertexflowui(LEFT + BL_CORNERSIZE, BOTTOM, 0.0);
			EndPrimitive();
		}
	}

	//LEFT side:
	if (invprogress<0.875) {
		progress_offset = (TOP-BOTTOM - BL_CORNERSIZE - TL_CORNERSIZE) * clamp((invprogress - 0.625) * 4, 0, 1.0);

		addvertexflowui(centerx, centery, distfromside); //center vertex:
		addvertexflowui(LEFT, TOP - TL_CORNERSIZE, 0.0);
		addvertexflowui(LEFT, BOTTOM + BL_CORNERSIZE + progress_offset, 0.0);
		EndPrimitive();

		//TL corner:
		if (TL_CORNERSIZE > 0.01) {
			addvertexflowui(centerx, centery, distfromside); //center vertex:
			addvertexflowui(LEFT + TL_CORNERSIZE, TOP, 0.0);
			addvertexflowui(LEFT, TOP - TL_CORNERSIZE, 0.0);
			EndPrimitive();
		}
	}

	//TOPLEFT side:
	progress_offset = (RIGHT-LEFT - TL_CORNERSIZE) * clamp((invprogress - 0.875) * 4, 0, 1.0);
	addvertexflowui(centerx, centery, distfromside); //center vertex:
	addvertexflowui(centerx, TOP, 0.0);
	addvertexflowui(LEFT + TL_CORNERSIZE + progress_offset, TOP, 0.0);
	EndPrimitive();


	//for (float i = 0; i<4; i = i+1){ // LOL ROUNDING?!
	//	float a1 = HALFPI * i /4.0;
	//	float a2 = HALFPI * (i+1) /4.0;
	//	addvertexflowui((LEFT + RIGHT) * 0.5, (TOP + BOTTOM) * 0.5);//center vertex:
	//	addvertexflowui(LEFT + (1.0-sin(a1)) * BL_CORNERSIZE, BOTTOM + (1.0-cos(a1)) * BL_CORNERSIZE);
	//	addvertexflowui(LEFT + (1.0-sin(a2)) * BL_CORNERSIZE, BOTTOM + (1.0-cos(a2)) * BL_CORNERSIZE);
	//	EndPrimitive();
	//}
}

]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require


uniform sampler2D bgTex;
uniform sampler2D uiAtlas;

uniform vec4 scissorLayer;

#define BACKGROUND_TILESIZE 64

in DataGS {
	vec4 g_screenpos;
	vec4 g_uv; // should also contain 'background texture shit'
	vec4 g_color;
	vec4 g_color2;
	vec4 g_fronttex_edge_backtex_hide; //v_fronttexture_edge_z_progress
};

out vec4 fragColor;



#line 20000
void main() {
	// silly mans scissor test?
	if ((gl_FragCoord.x < scissorLayer.x) ||
		(gl_FragCoord.y < scissorLayer.y) ||
		(gl_FragCoord.x > scissorLayer.z) ||
		(gl_FragCoord.y > scissorLayer.w)){
		fragColor.rgba = vec4(fract(gl_FragCoord.xyx * 0.01),0.0);
		return;
	}
	//vec4 bgTex = texture(bgTex, g_uv.zw/BACKGROUND_TILESIZE); // sample background texture, even if we might discard it
	vec4 fronttex = texture(uiAtlas, g_uv.xy, - 0.75);
	fragColor = g_color;
	//fragColor.rgb = mix(fragColor.rgb, bgTex.rgb, bgTex.a * g_fronttex_edge_backtex_hide.y);
	fragColor.rgba = mix(fragColor.rgba, fronttex.rgba, g_fronttex_edge_backtex_hide.x);// * g_fronttex_edge_backtex_hide.x );
	fragColor.a = max(fragColor.a, g_fronttex_edge_backtex_hide.x*fronttex.a);

	if (g_fronttex_edge_backtex_hide.y <= 99.0) {
		fragColor = g_color2;
		//fragColor.rgba = mix(fragColor.rgba, g_color2, clamp((g_fronttex_edge_backtex_hide.y),0.0, 1.0));
		fragColor.a = min(fragColor.a,clamp(( sign(g_fronttex_edge_backtex_hide.y)),0.0, 1.0));
	}
	//fragColor.rgb  = vec3(clamp((1.0 - g_fronttex_edge_backtex_hide.y),0.0, 1.0), fract(g_fronttex_edge_backtex_hide.y), 0.0);
	//fragColor.a = 1.0;
	//fragColor.a = min(fragColor.a,0.5);
	//fragColor.rgba = vec4(1.0,1.0,1.0,0.3);

	// Do the mousepos based highlighting?
	fragColor.rgb += fragColor.rgb * g_fronttex_edge_backtex_hide.z;


}
]]



local function goodbye(reason)
  Spring.Echo(widget:GetInfo().name .." widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget(self)
end

local function makeRectRoundVBO(name)
	local rectRoundVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'screenpos', size = 4},
			{id = 1, name = 'cornersizes', size = 4},
			{id = 2, name = 'color1', size = 4},
			{id = 3, name = 'color2', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'fronttexture_edge_z_progress', size = 4},
			{id = 6, name = 'hide_blendmode_globalbackground', size = 4}, -- TODO: maybe Hide, BlendMode, globalbackground

		},
		1024	,
		"rectRoundVBO" .. (name or "")
	)
	if rectRoundVBO == nil then goodbye("Failed to create rectRoundVBO") end

	for i = 1, 0 do
		local l = math.floor(math.random() * vsx/2)
		local b = math.floor(math.random() * vsy/2)
		local r = math.floor(l + math.random() * vsx/4)
		local t = math.floor(b + math.random() * vsx/4)
		local VBOData = {
			l,b,r,t,
			math.random() * 10, math.random() *20, math.random() * 30, math.random() * 40,
			math.random() , math.random(), math.random() , math.random() ,
			math.random() , math.random(), math.random() , math.random() ,
			0,0,1,1, --math.random() , math.random(), math.random() , math.random() ,
			math.random() , math.random(), math.random() , math.random() ,
			0,0,0,0,
		}

		pushElementInstance(rectRoundVBO,VBOData,i,true)
	end

	rectRoundVAO = gl.GetVAO()
	rectRoundVAO:AttachVertexBuffer(rectRoundVBO.instanceVBO)
	rectRoundVBO.instanceVAO = rectRoundVAO
	return rectRoundVBO
end

GetNewVBO = makeRectRoundVBO

local function makeShaders()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	gsSrc = gsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	rectRoundShader =  LuaShader(
		{
			vertex = vsSrc,
			fragment = fsSrc,
			geometry = gsSrc,

			uniformInt = {
				bgTex = 0,
				uiAtlas = 1,
			},
			uniformFloat = {
				scissorLayer = {0,0,vsx,vsy},
				scrollScale = {0,0,1,1},
			},
		},
		"rectRoundShader GL4"
	)
	--Spring.Echo("GS ############################################################ \n",gsSrc)
	shaderCompiled = rectRoundShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile rectRoundShader GL4 ")

		--Spring.Echo("VS ############################################################ \n",vsSrc)
		--Spring.Echo("GS ############################################################ \n",gsSrc)
		--Spring.Echo("FS ############################################################ \n",fsSrc)
	else
		Spring.Echo("Compile OK"	)
	end

end


---------------------- FlowUI emulation ------------------------
-- Notes
-- the shader should be shared, but each widget should have its own:
--	VBO
--	Atlas

-- TODO:
--	TexturedRectRound:
		--texture UV calcs are wierd
--	RectRoundCircle
	--	Radius in one vertex param! (doable with tris)
	--	 implement centerOffset!
	-- DOESNT WORK?
	-- COMPLETELY FUCKED!
--	UiElement
	-- repurpose blendalpha to bgtexture, and have that global
--	Draw.TexRect
	-- implement the UV offsets from atlastexture
-- Configints
	-- somehow mash them into this table?

	--[[			{id = 0, name = 'screenpos', size = 4},
			{id = 1, name = 'cornersizes', size = 4},
			{id = 2, name = 'color1', size = 4},
			{id = 3, name = 'color2', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'fronttexture_edge_z_progress', size = 4},]]--



Draw.TransformUVAtlasxXyY = function (atlascoordsxXyY, uvcoordsxyXY)
	if atlascoordsxXyY == nil or uvcoordsxyXY == nil then
		return {0,0,1,1}
	end
	local a = atlascoordsxXyY[2] - atlascoordsxXyY[1]
	local b = atlascoordsxXyY[4] - atlascoordsxXyY[3]
	return {
		atlascoordsxXyY[1] + a * uvcoordsxyXY[1],
		atlascoordsxXyY[3] + b * uvcoordsxyXY[2],
		atlascoordsxXyY[1] + a * uvcoordsxyXY[3],
		atlascoordsxXyY[3] + b * uvcoordsxyXY[4],
		}
end


--[[
	RectRound
		draw rectangle with chopped off corners
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		c1, c2 = top color, bottom color
]]--
Draw.RectRound = function (VBO, instanceID, z, px, py, sx, sy,  cs,  tl, tr, br, bl,   c1, c2, progress) -- returns table of instanceIDs

	if z == nil then z = 0.5 end  -- fools depth sort
	if c1 == nil then c1 = {1.0,1.0,1.0,1.0} end
	if c2 == nil then c2 = c1 end
	progress = progress or 1
	--Spring.Echo(c1)
	--Spring.Echo(c2)

	--cs = 10
	local VBOData = {
		px, py, sx, sy,
		cs*tl, cs*tr, cs*br, cs*bl,
		c1[1], c1[2], c1[3], c1[4],
		c2[1], c2[2], c2[3], c2[4],
		0,0,0,0,
		0, 0, z, 1,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)
end

-- this is just an overload for replacing gl.TexRect
Draw.TexRect = function (VBO, instanceID, z, px, py, sx, sy,  texture, color, uvs) -- returns table of instanceIDs
	return Draw.TexturedRectRound(VBO, instanceID, z, px, py, sx, sy,  0,  0, 0, 0, 0,  0, 0, 0,  texture)
end
--[[
	TexturedRectRound
		draw rectangle with chopped off corners and a textured background tile
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		size = texture tile size
		offset, offsetY = texture offset coordinates (offsetY=offset when offsetY isnt defined)
		texture = file location
]]--

Draw.TexturedRectRound =  function (VBO, instanceID, z, px, py, sx, sy,  cs,  tl, tr, br, bl,  size, offset, offsetY,  texture, color) -- returns table of instanceIDs
	-- texture should be a table of UV coords from atlas
	local fronttextalpha = 0

	if texture == nil then
	end

	if atlasID == nil then
			texture = {0,0,1,1}
	else
		fronttextalpha = 1.0
		texture = ({gl.GetAtlasTexture(atlasID, texture)})
	end

	if color == nil then color = {1,1,1,0.5} end
	--uvs = Draw.TransformUVAtlasxXyY(texture, uvs) -- DO OFFSET!
	local scale = size and (size / (sx-px)) or 1
	--local offset = offset or 0
	local csyMult = 1 / ((sy - py) / cs)
	local ycMult = (sy-py) / (sx-px)

	if z == nil then z = 0.50 end  -- fools depth sort
	if c2 == nil then c2 = c1 end
	local VBOData = {
		px, py, sx, sy,
		cs*tl, cs*tr, cs*br, cs*bl,
		color[1],color[2],color[3],color[4],
		color[1],color[2],color[3],color[4],
		texture[1],texture[4],texture[2],texture[3],
		fronttextalpha, 0, z, 1,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)
end


--[[
	RectRoundProgress
		draw rectangle pie (TODO: not with actual chopped off corners yet)
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		progress
		color
]]
Draw.RectRoundProgress =  function (VBO, instanceID, z, left, bottom, right, top, cs, progress, c1, c2) -- returns table of instanceIDs
	return Draw.RectRound(VBO, instanceID, z, left, bottom, right, top, cs, 1,1,1,1, c1, c2, progress)
	--[[
	if z == nil then z = 0.55 end  -- fools depth sort
	if c2 == nil then c2 = c1 end
	local VBOData = {
		left, bottom, right, top,
		cs*tl, cs*tr, cs*br, cs*bl,
		c1[1], c1[2], c1[3], c1[4],
		c1[1], c1[2], c1[3], c1[4],
		0,0,0,0,
		0, 0, z, progress,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)]]--
end



--[[
	RectRoundCircle
		draw a square with border edge/fade
	params
		x,y,z, radius
	optional
		c1 : outercolor
		c2 : innercolor
		centeroffset: the width of the highlight is gonna be radius-centeroffset

]]
Draw.RectRoundCircle = function (VBO, instanceID, z, x, y, radius, cs, centerOffset, c1, c2) -- returns table of instanceIDs
	Spring.Echo("Draw.RectRoundCircle", x, y, radius, cs, centerOffset, c1, c2)
	Spring.Echo(radius, radius - centerOffset)
	if z == nil then z = 0.5 end  -- fools depth sort
	if c1 == nil then c1 = {1.0,1.0,1.0,1.0} end
	if c2 == nil then c2 = c1 end
	if centerOffset == nil then centerOffset = 0 end
	--centerOffset = 50

	--local cs = radius / 2

	local VBOData = {
		x - radius, y - radius, x + radius, y + radius,
		cs, cs, cs, cs,
		c1[1], c1[2], c1[3], c1[4],
		c2[1], c2[2], c2[3], c2[4],
		0,0,0,0,
		0, radius - centerOffset , z, 1,
		0,0,0,0,
		}
	return pushElementInstance(VBO, VBOData, instanceID,true)
end

--[[
	Circle
		draw a circle
	params
		x,z, radius
		sides = number outside vertexes
		color1 = (center) color
	optional
		color2 = edge color
]]-- -- TODO


--[[
	UiElement
		draw a complete standardized ui element having: border, tiled background, gloss on top and bottom
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		ptl, ptr, pbr, pbl = inner border padding/size multiplier (default: 1) (set to 0 when you want to attach this ui element to another element so there is only padding done by one of the 2 elements)
		opacity = (default: ui_opacity springsetting)
		color1, color2 = (color1[4] value overrides the opacity param defined above)
		bgpadding = custom border size
]]--

Draw.Element = function(VBO, instanceID, z,px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding)
	local opacity = opacity or Spring.GetConfigFloat("ui_opacity", 0.7)
	local color1 = color1 or { 0, 0, 0, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1}
	local ui_scale = Spring.GetConfigFloat("ui_scale", 1)
	local bgpadding = bgpadding or WG.FlowUI.elementPadding
	local cs = WG.FlowUI.elementCorner * (bgpadding/WG.FlowUI.elementPadding)
	local glossMult = 1 + (2 - (opacity * 1.5))
	local tileopacity = Spring.GetConfigFloat("ui_tileopacity", 0.012)
	local bgtexScale = Spring.GetConfigFloat("ui_tilescale", 7)
	local bgtexSize = math.floor(WG.FlowUI.elementPadding * bgtexScale)

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < WG.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < WG.FlowUI.vsy and 1 or 0) * (ptl or 1)

	if z == nil then z = 0.5 end  -- fools depth sort

	-- background, color1 only, used for the edge
	--gl.Texture(false)
	local background1 = Draw.RectRound(VBO, nil, z-0.000, px, py, sx, sy, cs, tl, tr, br, bl, { color1[1], color1[2], color1[3], color1[4] }, { color1[1], color1[2], color1[3], color1[4] })

	--background2 is color2 only, used for the internal background color, has a gradient of 1/3 rd brightness from top
	cs = cs * 0.6
	local background2 = Draw.RectRound(VBO, nil, z-0.001,px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, { color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, color2[4] }, { color2[1], color2[2], color2[3], color2[4] })

	-- gloss on top and bottom of the button, very faint
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	local glossHeight = math.floor(0.02 * WG.FlowUI.vsy * ui_scale)
	-- top
	local topgloss = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, sy - syPad - glossHeight, sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.07 * glossMult })
	-- bottom
	local botgloss = Draw.RectRound(VBO, nil, z-0.003,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, cs, 0, 0, br, bl, { 1, 1, 1, 0.03 * glossMult }, { 1 ,1 ,1 , 0 })

	-- highlight edges thinly
	-- top
	local topgloss2 = Draw.RectRound(VBO, nil, z-0.004,px + pxPad, sy - syPad - (cs*2.5), sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.04 * glossMult })
	-- bottom
	local botgloss2 = Draw.RectRound(VBO, nil, z-0.005,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (cs*2), cs, 0, 0, br, bl, { 1, 1, 1, 0.02 * glossMult }, { 1 ,1 ,1 , 0 })
	-- left
	--WG.FlowUI.Draw.RectRound(px + pxPad, py + syPad, px + pxPad + (cs*2), sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0.02 * glossMult }, { 1, 1, 1, 0 })
	-- right
	--WG.FlowUI.Draw.RectRound(sx - sxPad - (cs*2), py + syPad, sx - sxPad, sy - syPad, cs, tl, tr, 0, 0, { 1, 1, 1, 0.02 * glossMult }, { 1, 1, 1, 0 })

	--WG.FlowUI.Draw.RectRound(px + (pxPad*1.6), sy - syPad - math.ceil(bgpadding*0.25), sx - (sxPad*1.6), sy - syPad, 0, tl, tr, 0, 0, { 1, 1, 1, 0.012 }, { 1, 1, 1, 0.07 * glossMult })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)


	-- darkening bottom 2/3rds of element
	local botdark = Draw.RectRound(VBO, nil, z-0.006,px, py, sx, py + ((sy-py)*0.75), cs*1.66, 0, 0, br, bl, { 0,0,0, 0.05 * glossMult }, { 0,0,0, 0 })
	local instanceIDs = {background1, background2, topgloss, botgloss,topgloss2, botgloss2, botdark}
	-- tile
	if tileopacity > 0 then
		--gl.Color(1,1,1, tileopacity)
		local bgtile = Draw.TexturedRectRound(VBO, nil, z-0.007,px + pxPad, py + pyPad, sx - sxPad, sy - syPad, cs, tl, tr, br, bl, bgtexSize, (px+pxPad)/WG.FlowUI.vsx/bgtexSize, (py+pyPad)/WG.FlowUI.vsy/bgtexSize, "luaui/images/flowui_gl4/backgroundtile.png", {1,1,1,tileopacity})
		instanceIDs[#instanceIDs + 1 ] = bgtile
	end
	return instanceIDs
end


--[[
	Button
		draw a complete standardized ui element having: border, tiled background, gloss on top and bottom
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		ptl, ptr, pbr, pbl = inner padding multiplier (default: 1) (set to 0 when you want to attach this ui element to another element so there is only padding done by one of the 2 elements)
		opacity = (default: ui_opacity springsetting)
		color1, color2 = (color1[4] alpha value overrides opacity define above)
		bgpadding = custom border size
]]
Draw.Button = function(VBO, instanceID, z,px, py, sx, sy,  tl, tr, br, bl,  ptl, ptr, pbr, pbl,  opacity, color1, color2, bgpadding)
	local opacity = opacity or 1
	local color1 = color1 or { 0, 0, 0, opacity}
	local color2 = color2 or { 1, 1, 1, opacity * 0.1}
	local bgpadding = math.floor(bgpadding or WG.FlowUI.buttonPadding*0.5)
	local glossMult = 1 + (2 - (opacity * 1.5))

	local tl = tl or 1
	local tr = tr or 1
	local br = br or 1
	local bl = bl or 1

	local pxPad = bgpadding * (px > 0 and 1 or 0) * (pbl or 1)
	local pyPad = bgpadding * (py > 0 and 1 or 0) * (pbr or 1)
	local sxPad = bgpadding * (sx < WG.FlowUI.vsx and 1 or 0) * (ptr or 1)
	local syPad = bgpadding * (sy < WG.FlowUI.vsy and 1 or 0) * (ptl or 1)

	if z == nil then z = 0.5 end  -- fools depth sort
	glossMult = glossMult * 1 -- TODO TESTING REMOVE!

	-- background
	--gl.Texture(false)
	local background = Draw.RectRound(VBO, nil, z-0.000,px, py, sx, sy, bgpadding * 1.6, tl, tr, br, bl, { color1[1], color1[2], color1[3], color1[4] }, { color2[1], color2[2], color2[3], color2[4] })
	--WG.FlowUI.Draw.RectRound(px + pxPad, py + pyPad, sx - sxPad, sy - syPad, bgpadding, tl, tr, br, bl, { color2[1]*0.33, color2[2]*0.33, color2[3]*0.33, color2[4] }, { color2[1], color2[2], color2[3], color2[4] })

	-- highlight edges thinly
	-- top
	local highlighttop = Draw.RectRound(VBO, nil, z-0.001,px + pxPad, sy - syPad - (bgpadding*2.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.04 * glossMult })
	-- bottom
	local highlightbottom = Draw.RectRound(VBO, nil, z-0.001,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + (bgpadding*2), bgpadding, 0, 0, br, bl, { 1, 1, 1, 0.02 * glossMult }, { 0 ,0 ,0 , 0 })

	-- gloss
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	local glossHeight = math.floor((sy-py)*0.5)
	local gloss1 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, sy - syPad - math.floor((sy-py)*0.5), sx - sxPad, sy - syPad, bgpadding, tl, tr, 0, 0, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.1 * glossMult })
	local gloss2 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + glossHeight, bgpadding, 0, 0, br, bl, { 1, 1, 1, 0.03 * glossMult }, { 1 ,1 ,1 , 0 })
	local gloss3 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + ((sy-py)*0.2), bgpadding, 0, 0, br, bl, { 1,1,1, 0.02 * glossMult }, { 1,1,1, 0 })
	local gloss4 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, sy- ((sy-py)*0.5), sx - sxPad, sy, bgpadding, tl, tr, 0, 0, { 1,1,1, 0 }, { 1,1,1, 0.07 * glossMult })
	local gloss5 = Draw.RectRound(VBO, nil, z-0.002,px + pxPad, py + pyPad, sx - sxPad, py + pyPad + ((sy-py)*0.5), bgpadding, 0, 0, br, bl, { 1,1,1, 0.05 * glossMult }, { 1,1,1, 0 })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	return {background,highlighttop,highlightbottom, gloss1, gloss2, gloss3, gloss4, gloss5}
end

--[[
	Unit
		draw a unit buildpic
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		cs = corner size
		tl, tr, br, bl = enable/disable corners for TopLeft, TopRight, BottomRight, BottomLeft (default: 1)
		zoom = how much to enlarge/zoom into the buildpic (default:  0)
		borderSize, borderOpacity,
		texture, radarTexture, groupTexture,
		price = {metal, energy}
		queueCount
]]
Draw.Unit = function(VBO, instanceID, z, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom,  borderSize, borderOpacity,  texture, radarTexture, groupTexture, price, queueCount)
	local borderSize = borderSize~=nil and borderSize or math.min(math.max(1, math.floor((sx-px) * 0.024)), math.floor((WG.FlowUI.vsy*0.0015)+0.5))	-- set default with upper limit
	local cs = cs~=nil and cs or math.max(1, math.floor((sx-px) * 0.024))

	-- draw unit
	--[[
	if texture then
		gl.Texture(texture)
	end
	gl.BeginEnd(GL.QUADS, DrawTexRectRound, px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom)
	if texture then
		gl.Texture(false)
	end]]--

	if texture then
		--texture = gl.GetAtlasTexture(atlasID, texture)
	else
		--texture = {0,0,0,0}
	end

	local unitpic = Draw.TexturedRectRound(VBO, nil, z + 0.001,
		px, py, sx, sy,  cs,  tl, tr, br, bl,  zoom, nil,nil,
		texture
	)


	-- darken gradually
	local darken = Draw.RectRound(VBO, nil, z + 0.002, px, py, sx, sy, cs, 0, 0, 1, 1, { 0, 0, 0, 0.2 }, { 0, 0, 0, 0 })

	-- make shiny
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)

	local shiny = Draw.RectRound(VBO, nil, z + 0.003, px, sy-((sy-py)*0.4), sx, sy, cs, 1,1,0,0,{1,1,1,0}, {1,1,1,0.06})

	-- lighten feather edges
	borderOpacity = borderOpacity or 0.1
	local halfSize = ((sx-px) * 0.5)

	local lighten = Draw.RectRoundCircle(VBO, nil, z + 0.004,
		px + halfSize,
		py + halfSize,
		halfSize, cs*0.7, halfSize*0.82,
		--{ 1, 1, 1, 0 }, { 1, 1, 1, 0.04 } -- original
		{ 1, 1, 1, 0 }, { 1, 1, 1, 0.24 } -- original
		--{ 1, 0, 1, 1.0 }, { 0, 1, 0, 1.0 }
	)

	local elementIDs = {unitpic, darken, shiny, lighten}

	-- border

	if borderSize > 0 then
		elementIDs[#elementIDs+1] = Draw.RectRoundCircle(
			VBO, nil, z + 0.005,
			px + halfSize,
			py + halfSize,
			halfSize, cs*0.7, halfSize -  borderSize,
			{ 1, 1, 1, borderOpacity }, { 1, 1, 1, borderOpacity }
		)
	end
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if groupTexture then
		local iconSize = math.floor((sx - px) * 0.3)
		--gl.Color(1, 1, 1, 0.9)
		--gl.Texture(groupTexture)
		--gl.TexRect(px, sy - iconSize, px + iconSize, sy)
		--gl.Texture(false)

		elementIDs[#elementIDs+1] = Draw.TexRect(VBO, nil, z + 0.006,
			px, sy - iconSize, px + iconSize, sy,
			groupTexture,
			{1, 1, 1, 0.9})

	end
	if radarTexture then
		local iconSize = math.floor((sx - px) * 0.25)
		local iconPadding = math.floor((sx - px) * 0.03)
		--gl.Color(1, 1, 1, 0.9)
		--gl.Texture(radarTexture)
		--gl.TexRect(sx - iconPadding - iconSize, py + iconPadding, sx - iconPadding, py + iconPadding + iconSize)
		--gl.Texture(false)

		elementIDs[#elementIDs+1] = Draw.TexRect(VBO, nil, z + 0.006,
			sx - iconPadding - iconSize, py + iconPadding, sx - iconPadding, py + iconPadding + iconSize,
			radarTexture,
			{1, 1, 1, 0.9})
	end
	local cnt = 0
	for k,v in pairs(elementIDs) do
		cnt = cnt + 1
	end
	if cnt < 7 then
		Spring.Echo("Some elements not spawned in ",texture)

		for k,v in pairs(elementIDs) do
			Spring.Echo(k,v)
		end
	end
	return elementIDs
end

--[[
	Scroller
		draw a slider
	params
		px, py, sx, sy = left, bottom, right, top
		contentHeight = content height px
	optional
		position = (default: 0) current height px
]]
Draw.Scroller = function(VBO, instanceID, z, px, py, sx, sy, contentHeight, position)
	if z == nil then z = 0.5 end
	local padding = math.floor(((sx-px)*0.25) + 0.5)
	local sliderHeight =  (sy - py - padding - padding) / contentHeight
	--if sliderHeight < 1 then
	position = position or 0
	sliderHeight = math.floor((sliderHeight * (sy - py)) + 0.5)
	local sliderPos = math.floor((sy - ((sy - py) * (position / contentHeight))) + 0.5)

	-- background
	local background = Draw.RectRound(VBO, nil, z, px, py, sx, sy, (sx-px)*0.2, 1,1,1,1, { 0,0,0,0.2 })

	-- slider
	local slider = Draw.RectRound(VBO, nil, z -0.001, px+padding, sliderPos-sliderHeight-padding, sx-padding, sliderPos-padding, (sx-px-padding-padding)*0.2, 1,1,1,1, { 1, 1, 1, 0.16 })

	return {background, slider}
	--end
end

--[[
	Toggle
		draw a toggle
	params
		px, py, sx, sy = left, bottom, right, top
	optional
		state = (default: 0) 0 / 0.5 / 1
]]
Draw.Toggle = function(VBO, instanceID, z, px, py, sx, sy, state)
	local cs = (sy-py)*0.1
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))

	-- faint dark outline edge
	local outlineedge = Draw.RectRound(VBO, nil, z - 0.000, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- top
	local top = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local highlighttop = Draw.RectRound(VBO, nil, z - 0.002, px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.035 })
	-- bottom
	local highlightbottom = Draw.RectRound(VBO, nil, z - 0.003, px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.025 }, { 1,1,1,0  })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- draw state
	local padding = math.floor((sy-py)*0.2)
	local radius = math.floor((sy-py)/2) - padding
	local y = math.floor(py + ((sy-py)/2))
	local x, color, glowMult
	if state == true or state == 1 then		-- on
		x = sx - padding - radius
		color = {0.8,1,0.8,1}
		glowMult = 1
	elseif not state or state == 0 then		-- off
		x = px + padding + radius
		color = {0.95,0.66,0.66,1}
		glowMult = 0.3
	else		-- in between
		x = math.floor(px + ((sx-px)*0.42))
		color = {1,0.9,0.7,1}
		glowMult = 0.6
	end
	local sliderknob  = Draw.SliderKnob(VBO, nil, z - 0.004, x, y, radius, color)

	local instanceIDs = {outlineedge, top, highlighttop, highlightbottom}
	for _, iID in ipairs(sliderknob) do
		instanceIDs[#instanceIDs + 1] = iID
	end
	if glowMult > 0 then
		local boolGlow = radius * 1.75
		--gl.Blending(GL.SRC_ALPHA, GL.ONE)
		--gl.Color(color[1], color[2], color[3], 0.33 * glowMult)
		--gl.Texture(":l:LuaUI/Images/glow.dds")
		--gl.TexRect(x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow)
		color[4] = 0.33 * glowMult
		local glow1 = Draw.TexRect(VBO, nil, z - 0.005, x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow,"LuaUI/Images/flowui_gl4/glow.dds", color, nil)

		boolGlow = boolGlow * 2.2
		--gl.Color(0.55, 1, 0.55, 0.1 * glowMult)
		--gl.TexRect(x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow)
		local glow2 = Draw.TexRect(VBO, nil, z - 0.006, x-boolGlow, y-boolGlow, x+boolGlow, y+boolGlow,"LuaUI/Images/flowui_gl4/glow.dds" ,{0.55, 1, 0.55, 0.1 * glowMult},nil)
		--gl.Texture(false)
		--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		instanceIDs[#instanceIDs + 1] = glow1
		instanceIDs[#instanceIDs + 1] = glow2

	end
	return instanceIDs
end

--[[
	Slider
		draw a slider knob
	params
		x, y, radius
	optional
		color
]]
Draw.SliderKnob = function(VBO, instanceID, z, x, y, radius, color)
	if z == nil then z = 0.5 end
	local color = color or {0.95,0.95,0.95,1}
	local color1 = {color[1]*0.55, color[2]*0.55, color[3]*0.55, color[4]}
	local edgeWidth = math.max(1, math.floor(radius * 0.05))
	local cs = math.max(1.1, radius*0.15)

	-- faint dark outline edge
	local outline = Draw.RectRound(VBO, nil, z - 0.000, x-radius-edgeWidth, y-radius-edgeWidth, x+radius+edgeWidth, y+radius+edgeWidth, cs, 1,1,1,1, {0,0,0,0.1})
	-- knob
	local knob = Draw.RectRound(VBO, nil, z - 0.001,x-radius, y-radius, x+radius, y+radius, cs, 1,1,1,1, color1, color)
	-- lighten knob inside edges
	-- TODO:
	local lighttenknob = Draw.RectRoundCircle(VBO, nil, z - 0.002, x, y, radius, cs*0.5, radius*0.85, {1,1,1,0.1})
	return {outline, knob, lighttenknob}
end


--[[
	Slider
		draw a slider
	params
		px, py, sx, sy = left, bottom, right, top
		steps = either a table of values or a number of smallest step size
		min, max = when steps is number: min/max scope of steps
]]
Draw.Slider = function(VBO, instanceID, z, px, py, sx, sy, steps, min, max)
	if z == nil then z = 0.5 end

	local cs = (sy-py)*0.25
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))
	-- faint dark outline edge
	local darkoutline = Draw.RectRound(VBO, nil, z - 0.000, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- top
	local top = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { 0.1, 0.1, 0.1, 0.22 }, { 0.9,0.9,0.9, 0.22 })
	-- bottom
	local bottom = Draw.RectRound(VBO, nil, z - 0.002, px, py, sx, sy, cs, 1,1,1,1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0 })
	local instanceIDs = {darkoutline, top, bottom}
	-- steps
	if steps then
		local numSteps = 0
		local sliderWidth = sx-px
		local processedSteps = {}
		if type(steps) == 'table' then
			min = steps[1]
			max = steps[#steps]
			numSteps = #steps
			for _,value in pairs(steps) do
				processedSteps[#processedSteps+1] = math.floor((px + (sliderWidth*((value-min)/(max-min)))) + 0.5)
			end
			-- remove first step at the bar start
			processedSteps[1] = nil
		elseif min and max then
			numSteps = (max-min)/steps
			for i=1, numSteps do
				processedSteps[#processedSteps+1] = math.floor((px + (sliderWidth/numSteps) * (#processedSteps+1)) + 0.5)
				i = i + 1
			end
		end
		-- remove last step at the bar end
		processedSteps[#processedSteps] = nil

		-- dont bother when steps too small
		if numSteps and numSteps < (sliderWidth/7) then
			local stepSizeLeft = math.max(1, math.floor(sliderWidth*0.01))
			local stepSizeRight = math.floor(sliderWidth*0.005)
			for _,posX in pairs(processedSteps) do
				local step = Draw.RectRound(VBO, nil, z - 0.001 * #instanceIDs,posX-stepSizeLeft, py+1, posX+stepSizeRight, sy-1, stepSizeLeft, 1,1,1,1, { 0.12,0.12,0.12,0.22 }, { 0,0,0,0.22 })
				instanceIDs[#instanceIDs + 1] = step
			end
		end
	end

	-- add highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local tophighlight = Draw.RectRound(VBO, nil, z - 0.001 * #instanceIDs,px, sy-edgeWidth-edgeWidth, sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.06 })
	instanceIDs[#instanceIDs + 1] = tophighlight
	-- bottom

	local bottomhighlight = Draw.RectRound(VBO, nil, z - 0.001 * #instanceIDs,px, py, sx, py+edgeWidth+edgeWidth, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.04 })
	instanceIDs[#instanceIDs + 1] = bottomhighlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	return instanceIDs
end

--[[
	Selector
		draw a selector (drop-down menu)
	params
		px, py, sx, sy = left, bottom, right, top
]]
Draw.Selector = function(VBO, instanceID, z, px, py, sx, sy)
	z = z or 0.5
	local cs = (sy-py)*0.1
	local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))

	-- faint dark outline edge
	local darkoutline = Draw.RectRound(VBO, nil, z - 0.00, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- body
	local body = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { 0.5, 0.5, 0.5, 0.12 }, { 1, 1, 1, 0.12 })

	-- highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local tophighlight = Draw.RectRound(VBO, nil, z - 0.002, px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.035 })
	-- bottom
	local bottomhighlight = Draw.RectRound(VBO, nil, z - 0.003, px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.025 }, { 1,1,1,0  })
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- button
	local button = Draw.RectRound(VBO, nil, z - 0.004, sx-(sy-py), py, sx, sy, cs, 1, 1, 1, 1, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.14 })

	return {darkoutline, body, tophighlight, bottomhighlight, button}
	--WG.FlowUI.Draw.Button(sx-(sy-py), py, sx, sy, 1, 1, 1, 1, 1,1,1,1, nil, { 1, 1, 1, 0.1 }, nil, cs)
end

--[[
	SelectHighlight
		draw a highlighted area in a selector (drop-down menu)
		(also usable to highlight some other generic area)
	params
		px, py, sx, sy = left, bottom, right, top
		cs = corner size
		opacity
		color = {1,1,1}
]]
Draw.SelectHighlight = function(VBO, instanceID, z, px, py, sx, sy,  cs, opacity, color)
	z = z or 0.5
	local cs = cs or (sy-py)*0.08
	local edgeWidth = math.max(1, math.floor((WG.FlowUI.vsy*0.001)))
	local opacity = opacity or 0.35
	local color = color or {1,1,1}

	-- faint dark outline edge
	local darkoutline = Draw.RectRound(VBO, nil, z - 0.00, px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
	-- body
	local body = Draw.RectRound(VBO, nil, z - 0.001, px, py, sx, sy, cs, 1,1,1,1, { color[1]*0.5, color[2]*0.5, color[3]*0.5, opacity }, { color[1], color[2], color[3], opacity })

	-- highlight
	--gl.Blending(GL.SRC_ALPHA, GL.ONE)
	-- top
	local top = Draw.RectRound(VBO, nil, z - 0.002, px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.03 + (0.18*opacity) })
	-- bottom
	local bottom = Draw.RectRound(VBO, nil, z - 0.003, px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.015 + (0.06*opacity) }, { 1,1,1,0  })
	--gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	return {darkoutline, body, top, bottom}
end


----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

local function forwardslider(...)
	return makeSliderList(...)
end

local btninstance = nil

function widget:Initialize()
	rectRoundVBO = makeRectRoundVBO("ROOT")
	makeShaders()



	WG['flowui_gl4'] = {}
	WG['flowui_gl4'].forwardslider = forwardslider
	WG['flowui_gl4'].requestWidgetLayer = requestWidgetLayer

	--WG['flowui_shader'] = rectRoundShader
	--WG['flowui_draw'] = Draw

	font, loadedFontSize = WG['fonts'].getFont(nil, 1.4, 0.35, 1.4)
	if WG['buildmenu'] then
		if WG['buildmenu'].getGroups then
			groups, unitGroup = WG['buildmenu'].getGroups()
		end
	end

	if atlasID == nil then
		atlasID = WG['flowui_atlas']
		atlassedImages = WG['flowui_atlassedImages']
	end

	--makebuttonarray()
	makeunitbuttonarray()
	--makeSliderList(sliderListConfig)
	--AddRecursivelySplittingButton()
	--local mywindow = metaElement:NewWindow({name = 'W'..tostring(i), left = 300+1*200, right = 490+1*200, top = 600, bottom = 200, testsliders = true})



end

function widget:Shutdown()
	WG['flowui_gl4'] = nil

	if rectRoundShader then
		rectRoundShader:Finalize()
	end
end

elems = 0

local nonoverlapping = {}
local numoverlapping = 1
local i = 0;

function widget:Update()
	i = i + 1
	if i %100 == 0 then -- todo, if a layer doesnt have text then it can be batch drawn under a layer that does
		nonoverlapping = {}
		numoverlapping = 0
		for a = 1, #LayerDrawOrder  do
			local alayer = Layers[LayerDrawOrder[a]]
			local aclear = true
			for b = 1, #LayerDrawOrder do
				local blayer = Layers[LayerDrawOrder[b]]
				if a~=b and alayer:AreRectsOverlapping(blayer) then
					aclear = false
					numoverlapping = numoverlapping + 1
					break
				end
			end
			if aclear then nonoverlapping[LayerDrawOrder[a]] = true end
		end
		--Spring.Echo("overlaps:", numoverlapping)
	end
end

local function DrawLayer(layername)
	local Layer = Layers[layername]
	if Layer.VBO.dirty then uploadAllElements(Layer.VBO) end
	--Spring.Echo(Layer.name, Layer.VBO.usedElements)
	rectRoundShader:SetUniformFloat("scissorLayer", Layer.scissorLayer[1], Layer.scissorLayer[2], Layer.scissorLayer[3], Layer.scissorLayer[4])
	rectRoundShader:SetUniformFloat("scrollScale", Layer.scrollScale[1], Layer.scrollScale[2], Layer.scrollScale[3], Layer.scrollScale[4])
	Layer.VBO.instanceVAO:DrawArrays(GL.POINTS,Layer.VBO.usedElements, 0, nil, 0)
end

function widget:DrawScreen()
	if atlasID == nil then
		atlasID = WG['flowui_atlas']
		atlassedImages = WG['flowui_atlassedImages']
	end
	if elems < 0  then
		elems = elems+1
		local x = math.floor(math.random()*vsx)
		local y = math.floor(math.random()*vsy)
		local s = math.floor(math.random()*35+70)
		local w = x+s*2
		local h = y+s
		local r = math.random()
		if r < 0.1 then
			--btninstance = Draw.Button(rectRoundVBO, nil, 0.4, x,y,w,h, 1,1,1,1, 1,1,1,1, nil, { math.random(), math.random(), math.random(), 0.8 }, { math.random(), math.random(), math.random(), 0.8 },  WG.FlowUI.elementCorner*0.4)
		elseif r < 0.2 then
			btninstance = Draw.Button(rectRoundVBO, nil, 0.4, x,y,w,h, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, {0.2, 0.8, 0.2, 0.8 }, WG.FlowUI.elementCorner * 0.5)
			--Draw.SelectHighlight(rectRoundVBO, nil, 0.5, x,y,w,h,1)
		elseif r < 0.3 then
			Draw.Selector(rectRoundVBO, nil, 0.5, x,y,w,h)
		elseif r < 0.4 then
			Draw.Slider(rectRoundVBO, nil, 0.5, x,y,w,h, 10, 1, 11)
		elseif r < 0.6 then
			Draw.SliderKnob(rectRoundVBO, nil, 0.5, x,y,s)

		elseif r < 0.7 then
			Draw.Toggle(rectRoundVBO, nil, 0.5, x,y,w,h, true)

		elseif r < 0.8 then
			--Draw.TexturedRectRound(rectRoundVBO, nil, 0.5, x,y,w,h, 10,1,1,1,1,nil,nil,nil,"icons/armpwt4.png")
			Draw.Element(
			rectRoundVBO, nil, 0.5, x,y,w,h,
				1,1,1,1,
				1,1,1,1,
				nil,
				{ 0, 0, 0, 0.8 }, { 0.2, 0.8, 0.2, 0.8 },nil

			)
		elseif r < 0.9 then

			Draw.Unit(rectRoundVBO, nil, 0.5, x,y,w,y+2*s, 20,
			1,1,1,1,
			1, nil, 0.8, -- zoom, bordersize, borderOpacity
			"unitpics/corcom.dds",
			"icons/bantha.png",
			"luaui/images/flowui_gl4/metal.png", --grouptexture
			500, 7)

		elseif r < 1.0 then
			Draw.Scroller( rectRoundVBO, nil, 0.5, x,y,x+s/2,y+2*s, 1000, 20)
		end
	end
	--local UiButton = WG.FlowUI.Draw.Button
	--UiButton(500, 500, 600, 550, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, { 0.2, 0.8, 0.2, 0.8 }, WG.FlowUI.elementCorner * 0.5)

	local mx, my, left, middle, right = Spring.GetMouseState()
	uiUpdate(mx, my, left, middle, right)
	RefreshText()

	if rectRoundVBO.dirty then uploadAllElements(rectRoundVBO) end -- do updates!
	--gl.Blending(GL.SRC_ALPHA, GL.ONE) -- bloomy
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- regular
	gl.DepthTest(false);
	gl.DepthMask(false);

	gl.Texture(0, "luaui/images/backgroundtile.png")
	if atlasID then
		gl.Texture(1, atlasID)
	else
		gl.Texture(1, 'luaui/images/backgroundtile.png')
	end


	-- Draw non-overlapping in one go:
	rectRoundShader:Activate()
	for layername, _ in pairs(nonoverlapping) do
		DrawLayer(layername)
	end
	rectRoundShader:Deactivate()

	for layername, _ in pairs(nonoverlapping) do
		local Layer = Layers[layername]
		if Layer.textDisplayList then gl.CallList(Layer.textDisplayList) end
	end

	-- Then draw the ones that overlap others
	if numoverlapping > 0 then
		for i= 1, #LayerDrawOrder do
			local layername = LayerDrawOrder[i]
			if nonoverlapping[layername] == nil then
				rectRoundShader:Activate()
				DrawLayer(layername)
				rectRoundShader:Deactivate()
				gl.Texture(1, false)
				gl.Texture(0, false)

				local Layer = Layers[layername]
				if Layer.textDisplayList then gl.CallList(Layer.textDisplayList) end
			end
		end
	end

	--DrawText()
end
