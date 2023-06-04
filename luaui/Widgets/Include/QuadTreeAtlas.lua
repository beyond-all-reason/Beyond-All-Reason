-- Author: (c) Beherith mysterme@gmail.com

-- QuadTreeAtlas class
-- Size in the total size of the texture
-- Resolution is the size of the splits (e.g. 128 size 'patches'
-- Funny notes: Loading a texture in with gl.Texture(0,':n:'..name) nearest mode is actually slow!!

-- TODO 2023.05.08
-- DONE : Match gl.TextureInfo 
-- DONE Validate image size
-- DONE unbind loaded tex after render
-- DONE font rendering and cacheing
-- DONE Hmm yes nearest neighbour would be prudent for font atlasses maybe?
-- DONE set padding differently for nearest neighbour version?
-- DONE be smart and dont double-cache same thing
-- DONE for fonts either hue hue
-- add arbitrary splitting, and better configability of atlas
-- Add CustomTask for drawing mixed mode stuff, which should draw a display list (or even just a function, just like a display list?)
-- Centering/Labeling: So for this case, we should try to draw centered, onto a given sized part of the atlas!
-- Fix font color tracking
-- Add a return value for fonts that show the descender line, to consistently be able to position fontses // https://springrts.com/wiki/GetTextHeight

-- QuadTreePrototype:
	-- Not always square!
	-- Always split on power of two


-- UNIT TESTING:
local UNITTEST = false
if not Spring then 
	UNITTEST = true
	Spring = {
		Echo = function(s) print(s) end,
	}
	gl = {
		CreateTexture = function() return 0 end
	}
	GL = {}
end


--- Create a new texture atlas for any image/text type
-- The atlas is a regularly spaced grid, and items will occupy at least 1 cell of the grid
-- You can queue any item to be added at any time, but they will only be finalized to atlas when told to do so
-- Any addition, will immediately return with the UV coordinates of the allocation
-- For text elements, the allocation will also return the width and height
-- The atlas gets filled up columns first from the bottom left
-- For ideal allocation speed, identical sized elements which are divisors of the cell size are recommended
-- These parameters cannot be changed after creation, and are passed in through the config table
-- xresolution and yresolution define the size of the cells of the atlas, they do not have to be power of two (but should be for images)
-- specify a name so that you can read error messages
-- texProps is a table that contains the usual CreateTexture parameters.
-- A defaultfont is a table {font = luaFontObj, outlinecolor = {...}, options = 'bo'} can also be passed if desired
-- @param config A table of configuration values for this atlas
-- @return a table with all the helper funcs the atlas itself
local function MakeQTAtlas(config)
	-- make sane defaults
	config = config or {}
	config.sizex = config.sizex or 1024
	config.sizey = config.sizey or 1024
	config.xresolution = config.xresolution or config.resolution or 128
	config.yresolution = config.yresolution or config.resolution or 128
	config.name = config.name or "Unnamed Atlas"

	
	--------------------------------- Below is the unfinished quadtree split implementation ---------------------------
	--[[
	local QuadTreeNode = {}
	local QuadTreePrototype = {children = {}, x = 0, y = 0, X = sizex, Y = sizey, w = sizex, h = sizey, used = false, }
	-- used = true means that all of its children are occupied. propagating this is non-trivial.
	
	function QuadTreePrototype:New(parent)
		local o = {}
		setmetatable(o, QuadTreePrototype)
		return o
	end
	

	function QuadTreePrototype:Split(width, height)
		-- By default, split in half, otherwise take input args
		width = width or math.floor(self.w)/2
		height = height or math.floor(self.h)/2
		self.children[1] = QuadTreePrototype:New(self)
		
	end
	
	function QuadTreePrototype:Print()
		Spring.Echo(string.format("QTP c = %d, x = %d, y = %d, X = %d, Y = %d, used = %s",#self.children, self.x, self.y, self.X, self.Y, tostring(self.used)))
	end
	
	function QuadTreePrototype:FindSpot(width, height)
		-- If it doesnt fit at all, return false
		if self.w < width or self.h < height then 
			return false
			
		--  if it smaller than half of our size, then split and continue recursing
		elseif self.w * self.h >= width * height * 2 then 
		
		elseif self.w >= 2 * width and self.h >= 2*height then 
			if #self.children == 0 then 
				self:Split()
			end
			-- check the children
		-- It just about fits here:
		-- Reserve this, and split the children accordingly
		else
			--if it takes up > 50% of the area, then dont split further
			if self.w * self.h >= width * height * 2 then
				-- add to self
			elseif false then 
				-- We need to split 
				
			end
		end
	end
	
	function QuadTreePrototype:RecurseUpdateUsed()
	end

	function QuadTreePrototype:Free()
		-- remove the used status. and if it was the last node with a used status, then merge its children, then call its parent to check for this.
	end
	
	QuadTreeNode.metatable = QuadTreePrototype
	]]--
	--------------------------------- ABOVE is the unfinished quadtree split implementation ---------------------------
	
	local QTAtlas = {
		name = config.name or "MyQTAtlas",
		xsize = config.sizex,
		ysize = config.sizey,
		xresolution = config.xresolution,
		yresolution = config.yresolution,
		xslots = config.sizex/config.xresolution,
		yslots = config.sizey/config.yresolution,
		textureID = nil,
		fill = {}, -- double array of bools indicated used = true status
		uvcoords = {}, -- maps imgpath to padded UV set, in xXyY format
		texelcoords = {}, -- 
		renderImageTaskList = {}, -- 
		textID = 1,
		renderTextTaskList = {}, -- 
		padx = 0.5/config.sizex,
		pady = 0.5/config.sizey,
		firstemptycolumn = 1,
		freeslots = config.sizex/config.xresolution * config.sizey/config.yresolution,
		blankimg = 'icons/blank.png',
		aliasing_grid_test_image = 'luaui/images/aliasing_test_grid_128.tga',
		drawmode = config.drawmode or '', -- can be any mode like ':n:' for nearest neighbour
		defaultfont = config.defaultfont,
		config = config, -- store it, why not
		debug = config.debug,
		hastasks = false,
	}
	for x = 1, QTAtlas.xslots do
		QTAtlas.fill[x] = {}
		for y = 1, QTAtlas.yslots do 
			QTAtlas.fill[x][y] = false
		end
	end 
	local GL_RGBA = 0x1908
	QTAtlas.texProps = config.texProps or {
		min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		--min_filter = GL.NEAREST, mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP, wrap_t = GL.CLAMP, format = GL_RGBA}
	QTAtlas.texProps.fbo = true -- need so that we can RenderToTexture it
	QTAtlas.textureID = gl.CreateTexture(config.sizex, config.sizey, QTAtlas.texProps)

	---Deletes the entire texture atlas and frees vram
	function QTAtlas:Delete() 
		if self.textureID then 
			gl.DeleteTexture(self.textureID) 
			self.textureID = nil 
		end
	end
	
	---Internal function for allocating areas of the texture
	-- Returns a pair of uvcoords, task
	-- yvcoords is always guaranteed,
	-- task is only returned on success
	-- @param id is a unique identifier so that stuff can easily be retrieved and to prevent duplicate allocations
	-- @param xsize width of the item
	-- @param ysize is the height of the item
	-- @return an array of UV coordinates in xXyY format
	function QTAtlas:ReserveSpace(id, xsize, ysize) 
		if self.uvcoords[id] then 
			Spring.Echo(string.format("QTAtlas %s Warning: ID %s is already added to this atlas", self.name, tostring(id)))
			return self.uvcoords[id]
		end
		
		local xresolution = self.xresolution
		local yresolution = self.yresolution
		local xstep = math.ceil(xsize/xresolution)
		local ystep = math.ceil(ysize/yresolution)
		local foundspot = false
		local xpos = -1
		local ypos = -1
		local iterations = 0
		for xs = self.firstemptycolumn, self.xslots - xstep + 1 do 
			for ys = 1, self.yslots - ystep + 1 do 
				local fits = true
				for w = 0, xstep -1 do 
					for h = 0, ystep-1 do 
						iterations = iterations + 1
						--Spring.Echo(xs+w, ys +h, iterations)
						if self.fill[xs+w][ys+h] then 
							--xpos = xs+w
							--ypos = ys+h
							fits = false
							break
						end
					end
					if not fits then break end
				end
				
				if fits then
					xpos = xs
					ypos = ys
					foundspot = true
					break 
				end 
			end
			if foundspot then break end 
		end
		--Spring.Echo("Iterations", iterations, self.firstemptycolumn)
		if foundspot then 
				-- create render task
				local task = {id =id, w = xsize, h =  ysize, x = (xpos-1) * xresolution, y = (ypos-1) * yresolution}
				local uvcoords = {
					(xpos -1 ) / self.xslots + self.padx *0,
					--(xpos + xstep - 1) / self.xslots - self.padx *0, -- this is incorrect, it should be up the extents only
					(xpos -1 ) / self.xslots + self.padx *0 + xsize/self.xsize,

					(ypos  -1)  / self.yslots + self.pady *0,
					(ypos  -1 ) / self.yslots - self.pady *0 + ysize/self.ysize,
					--(ypos + ystep -1 ) / self.yslots - self.pady *0,
					xsize, ysize,
				}
				-- Add it to uvcoords map
				self.uvcoords[id] = uvcoords
				
				-- fill cells
				for x = xpos, xpos + xstep - 1 do 
					for y = ypos, ypos + ystep - 1 do
						self.fill[x][y] = id
					end
				end
				
				-- maintain empty rows pointer
				
				for x = self.firstemptycolumn, self.firstemptycolumn + xstep -1 do 
					local columnfull = true
					for y = 1, self.yslots do 
						if self.fill[x][y] == false then 
							columnfull = false
							break
						end
					end
					if columnfull then 
						if self.debug then Spring.Echo("Column Full!", self.firstemptycolumn) end 
						self.firstemptycolumn = self.firstemptycolumn + 1 
					end 
				end
				--Spring.Echo(string.format("Found spot for %s at %d %d",tostring(img),xpos,ypos))
				-- return uv coords
				self.hastasks = true
				return uvcoords, task
				
		else
				Spring.Echo(string.format("QTAtlas %s Error: cant find space for %s of size %d x %d", self.name, tostring(id), xsize, ysize))
				return {0,0,1,1,xsize, ysize,0}
		end
	end
	
	---Add an image to the atlas
	-- Note that the size is optional, and might be changed in the future to allow allocations outside of GL scope
	-- @param image is a valid VFS path to the image
	-- @param xsize width of the image, optional, but will override if specified
	-- @param ysize width of the image, optional, but will override if specified
	-- @return an array of UV coordinates in xXyYwh format
	function QTAtlas:AddImage(image, xsize, ysize)
		if self.uvcoords[image] then 
			Spring.Echo(string.format("QTAtlas %s Warning: image %s is already added to this atlas", self.name, tostring(image)))
			return self.uvcoords[image]
		end
		if xsize and ysize then 
			-- is the desired size, this can force scaling
		else
			local texInfo = gl.TextureInfo(image)
			if texInfo and (texInfo.xsize ~= xsize or texInfo.ysize ~= ysize) then 
				Spring.Echo(string.format("QTAtlas %s Warning: image %s size does not match %dx%d given, %dx%d from TextureInfo", self.name, tostring(image), xsize, ysize, texInfo.xsize, texInfo.ysize))	
				if xsize == nil then xsize = texInfo.xsize end 
				if ysize == nil then ysize = texInfo.ysize end 
			end
		end
		
		local uvcoords, task = self:ReserveSpace(image,xsize,ysize)
		if task then 
			self.renderImageTaskList[#self.renderImageTaskList + 1 ] = task
		end
		return uvcoords
	end
	
	-- This should return a width, height and UV set for pixel-perfect rendering
	-- This does not support redundancy checking yet! That is up to the user, as there are too many params to check.
	
	---Add a text element to the atlas
	-- normalization, scaling, and centering/alignment are not supported. 
	-- The text itself can use a font as well.
	-- Adding a pure text element, without a font will attempt to use the init time defined defaultfont object
	-- This will also result in the ID of the object being the text itself for easy use
	-- @param text the text itself
	-- @param params optional table of at least { font = fontObject (or specify the default font!)}
	-- @return an array of {x,X,y,Y,w,h,descender}
	function QTAtlas:AddText(text, params)
		local textparams
		if not params then -- render with default fot
			if self.uvcoords[text] then
				return self.uvcoords[text]
			else
				if not self.defaultfont then 
					Spring.Echo(string.format("QTAtlas %s Warning: text %s without font cannot be added because atlas has no default font set", self.name, tostring(id)))
					self.uvcoords[text] = {0,1,0,1,1,1} -- add a fallback so we only warn once per item
					return self.uvcoords[text]
				else
					-- we have a default font 
					textparams = {
						text = text,
						font = self.defaultfont.font,
						size = self.defaultfont.font.size,			
						outlinewidth = self.defaultfont.font.outlinewidth,
						outlineweight = self.defaultfont.font.outlineweight ,
						options = 'b' .. (self.defaultfont.options or "") , -- default bottom vertical alignment
						textcolor = self.defaultfont.textcolor or {1,1,1,1},
						outlinecolor = self.defaultfont.outlinecolor or {0,0,0,1},
						id = text,
						pad = 0,
					}
				end
			end
		else
			-- TODO this table copy is completely unnessecary
			textparams = {
				text = text,
				font = params.font,
				--fontfilename = params.font.path or params.fontfilename or (self.defaultfont and self.defaultfont.fontfilename),
				size = params.size or params.font.size ,
				outlinewidth = params.outlinewidth or params.font.outlinewidth,
				outlineweight = params.outlineweight or params.font.outlineweight,
				options = "b" .. (params.options or ""), -- default bottom vertical alignment
				textcolor = params.textcolor or {1,1,1,1},
				outlinecolor = params.outlinecolor or {0,0,0,1},
				id = params.id,
				pad = params.pad or 0,
			}
			if params.id == nil then 
				self.textID = self.textID + 1
				params.id = self.textID
			end
		end
		

		-- case 'N': { options |= FONT_NORM;         } break;
		-- case 'S': { options |= FONT_SCALE;        } break;
		-- textparams.options = 'N' .. textparams.options

		
		if self.uvcoords[textparams.id] then 
			Spring.Echo(string.format("QTAtlas %s Warning: text %s is already added to this atlas", self.name, tostring(textparams.id)))
			return self.uvcoords[textparams.id]
		end
		-- get the actual width and height of the text object:
		-- We need to fix the actual size of the font here! 
		local width = math.ceil(textparams.font:GetTextWidth(textparams.text) * textparams.size )
		
		-- Height needs to take into account outlines as well! (and maybe even
		local textheight, textdescender, numlines = textparams.font:GetTextHeight(textparams.text) -- See https://springrts.com/wiki/GetTextHeight
		local height = math.ceil((textheight + textdescender) * textparams.size)
		textdescender = textdescender * textparams.size
		if self.debug then Spring.Echo(string.format("Pre adjusted textsize for %s at size %d is w=%d h=%d", textparams.text, textparams.size, width,height )) end
		local pad = 0
		if string.find(textparams.options ,'o', nil, true) then 
			textparams.options = textparams.options .. 'o'
			pad = math.ceil(textparams.font.outlinewidth/2)
		end
		if string.find(textparams.options ,'s', nil, true) then 
			textparams.options = textparams.options .. 's'
		end
		if string.find(textparams.options ,'O', nil, true) then 
			textparams.options = textparams.options .. 'O'
			pad = math.ceil(textparams.font.outlinewidth/2)
		end
		textparams.pad = pad + textparams.pad
		pad = textparams.pad
		width = width + 2*pad
		height = height + 2*pad
		textdescender = math.ceil(textdescender + pad)
		local vsx, vsy = Spring.GetViewGeometry()
		
		if self.debug then Spring.Echo(string.format("AddText Size: %s, size=%d, w=%d h=%d d=%d", textparams.text, textparams.size, width, height, textdescender)) end
		
		local uvcoords, task = self:ReserveSpace(textparams.id, width, height)
		if task then 
			task.textparams = textparams
			self.renderTextTaskList[#self.renderTextTaskList + 1 ] = task 
		end
		uvcoords[7] = textdescender
		self.uvcoords[textparams.id] = uvcoords
		return uvcoords
	end
	
	---Clears a part of the atlas where a specific ID item is stored
	-- Will attempt to clear the entire cells
	-- @param uvcoords array of xXyY formatted UV coordinates of the target area to clear
	-- @param id the identifier of the item, needed for clearing its uv coordinate cache
	function QTAtlas:RemoveFromAtlas(uvcoords, id)
		-- since it kinda has to by dynamic, it would be nice if we could mark some space as free on this
		local xmin = math.floor(uvcoords[1] * self.xslots)
		local xmax =  math.ceil(uvcoords[2] * self.xslots)
		local ymin = math.floor(uvcoords[3] * self.xslots)
		local ymax =  math.ceil(uvcoords[4] * self.xslots)
		for x = xmin, xmax -1 do 
			self.firstemptyrow = math.min(self.firstemptyrow, x)
			for y = ymin, ymax -1 do 
				self.fill[x][y] = nil 
			end
		end
		if id then 
			self.uvcoords[id] = nil
		end
		local drawblanktask = {id = self.blankimg, w = xmax-xmin * self.xresolution, h =  ymax - ymin * yresolution, 
			x = xmin * self.xresolution, y = ymin * self.yresolution,
		}
		self.renderImageTaskList[#self.renderImageTaskList+1] = drawblanktask
		self.hastasks = true
	end
	
	---To free the default font object if we are already done with it all
	function QTAtlas:DeleteDefaultFont()
		if self.defaultfont then
			gl.DeleteFont(self.defaultfont)
			self.defaultfont = nil 
		end
	end

	---Internal function to execute the rendering of image tasks
	function QTAtlas:RenderImageTasks() 
		gl.Color(1,1,1,1) -- sanity check
		--gl.Rect( 0,0,0.5,0.1)
		--gl.Blending(GL.ONE, GL.ZERO) -- do full opaque
		for i, task in ipairs(self.renderImageTaskList) do 
			local drawmodeTexName = self.drawmode..task.id
			gl.Texture(0, drawmodeTexName)
			local p = self.padx*0
			local o = self.padx*0
			local w = (task.w/self.xsize) * 2 
			local h = (task.h/self.ysize) * 2 
			local x = (task.x/self.xsize -0.5 ) * 2  
			local y = (task.y/self.ysize -0.5 ) * 2 
			--Spring.Echo("QTAtlas:RenderImageTasks", task.id,task.w, task.h, task.x, task.y,x,y,w,h)
			
			gl.TexRect(x,y,x+w,y+h)
			gl.Texture(0,false)
			gl.DeleteTexture(drawmodeTexName) -- Maybe this helps free stuff?
		end
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- 
	end
	
	---Internal function to execute the rendering of text tasks
	function QTAtlas:RenderTextTasks() 
		local currentParams = {}
		
		gl.Color(1,1,1,1) -- Set Color to default
		local taskList = self.renderTextTaskList
		gl.Blending(GL.ONE, GL.ZERO) -- do full opaque
		
		-- EXTREMELY IMPORTANT: 
		-- this entire matrix silliness is needed cause font:Print takes integer positions
		-- And because otherwise it cant draw unstreched to non-square images
		gl.PushMatrix()
		local xscale = self.xsize
		local yscale = self.ysize
		gl.Scale(1/xscale, 1/yscale, 1/yscale) 
		for i, task in ipairs(taskList) do 
			local textparams = task.textparams
			if currentParams.font ~= textparams.font then 
				--Spring.Echo("Swapping Font")
				if currentParams.font then
					currentParams.font:End()
				end
				textparams.font:Begin()
				if self.debug then Spring.Echo("Font set to", textparams.font.path,textparams.size) end
				currentParams.font = textparams.font
			end
			
			local font = textparams.font 
			
			-- Check if text color matches, if not then switch it
			local colormatches = true 
			if not currentParams.textcolor then
				colormatches = false
			else
				local colormatches = true
				for i=1, 4 do 
					if currentParams.textcolor[i] ~= textparams.textcolor[i] then
						colormatches = false
						break
					end
				end
			end
			if not colormatches then 
				font:SetTextColor(textparams.textcolor[1], textparams.textcolor[2], textparams.textcolor[3], textparams.textcolor[4])
				currentParams.textcolor = textparams.textcolor
			end
			
			-- Check if outline color is the same, if not then switch it
			local outlinematches = true 
			if not currentParams.outlinecolor then
				outlinematches = false
			else
				for i=1, 4 do 
					if currentParams.outlinecolor[i] ~= textparams.outlinecolor[i] then
						outlinematches = false
						break
					end
				end
			end
			if not outlinematches then 
				font:SetOutlineColor(textparams.outlinecolor[1], textparams.outlinecolor[2], textparams.outlinecolor[3], textparams.outlinecolor[4])
				currentParams.outlinecolor = textparams.outlinecolor
			end
	

			local x = ((task.x + textparams.pad)/self.xsize -0.5 ) * 2 *xscale
			local y = ((task.y + textparams.pad)/self.ysize -0.5 ) * 2 *yscale
			--x = task.x * 0.01
			--y = task.y * 0.01
			-- TODO: fix alignment!
			if self.debug then 
				string.format("Task params: id = %s w=%d h=%d x=%d y=%d", task.id,task.w,task.h,task.x,task.y)
				Spring.Echo(string.format("Task params: id = %s w=%d h=%d x=%d y=%d", task.id,task.w,task.h,task.x,task.y))
				Spring.Echo("renderText:",textparams.text, x,y,textparams.size, textparams.options)
			end
			local fscale = 2 -- FREAKING WHY?
			font:Print(textparams.text, x,y,fscale * textparams.size, textparams.options)
		end
		currentParams.font:End()
		gl.PopMatrix()
	end

	---Perform the render target switch and draw all pending tasks
	-- Take care when you call this, ideally, right before drawing with the atlas, its quite lightweight, so dont worry about that part. 
	function QTAtlas:RenderTasks()
		if self.hastasks then 
			if next(self.renderImageTaskList) then 
				gl.RenderToTexture(self.textureID, self.RenderImageTasks, self)
				-- work backwards through the buffer of tasks:
				self.renderImageTaskList = {}
			end
			if next(self.renderTextTaskList) then 
				gl.RenderToTexture(self.textureID, self.RenderTextTasks, self)
				self.renderTextTaskList = {}
			end
			self.hastasks = false
		end
	end
	
	---Prints an allocation map of the elements in the atlas
	-- handy for debugging
	function QTAtlas:PrintAtlas()
		for x = 1, self.xslots do 
			local s = ''
			for y = 1, self.yslots do 
				s = s .. string.format('% 5s',self.fill[x][y])
			end
			Spring.Echo(s)
		end
	end
	
	---Draws the contents of the atlas to the bottom left corner of the screen
	-- very useful for debugging what is on the atlas iself
	-- @param aliastest i dont remember what this does, so dont use it
	-- @param noalpha draw the atlas without transparency
	function QTAtlas:DrawToScreen(aliastest,noalpha)
		gl.Color(1,1,1,1.0)
		if noalpha then 
			gl.Blending(GL.ONE, GL.ZERO) -- the default mode
		else
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- 
		end
 
		gl.Texture(0, self.textureID)
		local o = 10
		--o = o + math.sin(Spring.GetDrawFrame()*0.01)
		local vsx, vsy = Spring.GetViewGeometry()
		gl.TexRect(o,o,math.min(vsx - o, self.xsize + o), math.min(vsy-o,self.ysize + o), 0,0,1,1)
		
		if aliastest then 
			local aliasUV = self.uvcoords[self.aliasing_grid_test_image]
			Spring.Echo( aliasUV[1],aliasUV[3],aliasUV[2],aliasUV[4],aliasUV[5],aliasUV[6])
			local x, X, y, Y, w, h = aliasUV[1],aliasUV[2],aliasUV[3],aliasUV[4],aliasUV[5],aliasUV[6],aliasUV[5],aliasUV[6]
			local xs = 0
			for i =1, 6 do
				gl.TexRect(xs, vsy - i * h, xs + i*w, vsy, x,y, X, Y)
				xs = xs + i * w
			end
		end
		
		gl.Texture(0, false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- 
		gl.Color(1,1,1,1)
	end
	
	--QTAtlas:AddImage(QTAtlas.aliasing_grid_test_image,256,256)
	return QTAtlas
end

if UNITTEST then 
	local atlas = MakeQTAtlas({sizex = 124, sizey =  512, xresolution = 96, yresolution = 24, name = "QuadTree Atlas Tester"})

	for i = 1,10 do 
		for j = 1,10 do 
			--atlas:ReserveSpace(string.format('%dx%d',i,j), 64,64)
		end
	end

	atlas:PrintAtlas()
else
	return MakeQTAtlas
end



