local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "AtlasOnDemand Tester",
		desc = "This is just a test",
		author = "Beherith",
		date = "2023.",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end


-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spEcho = Spring.Echo

local MyAtlasOnDemand 
local buildPicList = {}
local font

local t = "ABCDEFGHIJKLabcdefghij"
local n = 0
function widget:Update()
	n = n+ 1 
	if n % 100 == 0 then
		for i = 1,10 do 
			local k,v = next(buildPicList) 
			--spEcho("Adding",k,v)
			if k then 
				--MyAtlasOnDemand:AddImage(v, 256,128)
				buildPicList[k] = nil
				--MyAtlasOnDemand:AddText({text = "TgTq"..tostring(n + i), font = font, options = 'bo'})
			end
		end
	end
end

-- Draw everything to texture first here
function widget:DrawGenesis() -- YES WE CAN!	
	MyAtlasOnDemand:RenderTasks()
end

local first = true
local textItems = {}

function widget:DrawScreen()
	-- perform draw tasks, if any
	MyAtlasOnDemand:RenderTasks()
	
	
	-- Draw a grey background:
	gl.Color(0.5, 0.5, 0.5, 1.0)
	local o = 10
	gl.Rect(o,o,MyAtlasOnDemand.xsize + o, MyAtlasOnDemand.ysize + o )
	gl.Color(1.0, 1.0, 1.0, 1.0)
	
	-- Draw the Atlas:
	MyAtlasOnDemand:DrawToScreen() 

	-- Add our random tester texts to the atlas
	if first then 
		for j, num in ipairs({"59", "Tlgfi", "g1","60"}) do 
			for i,fontsize in ipairs({9, 13,16,27, 36}) do 
				local id = tostring(num).."_"..tostring(fontsize)
				local textItem = {text = tostring(num), font = font, size = fontsize, id = id}
				local uvcoords = MyAtlasOnDemand:AddText(tostring(num), textItem)
				textItem.uvcoords = uvcoords
				textItems[id] = textItem
				spEcho(id, uvcoords.x, uvcoords.y)
			end
		end
		first = false
	end
	
	-- Draw with the actual font renderer as second column
	font:Begin()
	local offsetX = 64
	for id,textItem in pairs(textItems) do 
		local xpos = mathFloor(o + offsetX + textItem.uvcoords.x * MyAtlasOnDemand.xsize)
		local ypos = mathFloor(o + textItem.uvcoords.y * MyAtlasOnDemand.ysize + textItem.uvcoords.d)
		font:Print(textItem.text, xpos,ypos ,textItem.size,'')
	end
	font:End()
	
	-- Draw With silly TextRect overrider as third column
	gl.Texture(MyAtlasOnDemand.textureID)
	local offsetX = 128
	--gl.Blending(GL.ONE, GL.ZERO) -- do full opaque
	gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA) -- do full opaque
	for id,textItem in pairs(textItems) do 
		MyAtlasOnDemand:TextRect(id, o + offsetX + textItem.uvcoords.x * MyAtlasOnDemand.xsize, o + textItem.uvcoords.y *MyAtlasOnDemand.ysize + textItem.uvcoords.d)
	end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- reset blending
	
end

function widget:Initialize()
	--font = WG['fonts'].getFont()
	font = gl.LoadFont("fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf"), 64, 1, 1)
	
	local MakeAtlasOnDemand = VFS.Include("LuaUI/Include/AtlasOnDemand.lua")
	if not MakeAtlasOnDemand then
		spEcho("Failed to load AtlasOnDemand")
		return 
	end
	MyAtlasOnDemand = MakeAtlasOnDemand({sizex = 1024, sizey =  512, xresolution = 224, yresolution = 24, name = "AtlasOnDemand Tester", font = {font = font}, debug = true})
	buildPicList = VFS.DirList("unitpics") 
	
	MyAtlasOnDemand:AddImage('luaui/images/aliasing_test_grid_128.tga', 256, 256)
	MyAtlasOnDemand:AddImage('unitpics/armcom.dds', 256, 256)
end

function widget:ShutDown()
	if MyAtlasOnDemand then 
		MyAtlasOnDemand:Destroy()
	end
end
