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
			--Spring.Echo("Adding",k,v)
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
function widget:DrawScreen()
--function widget:DrawGenesis()
	MyAtlasOnDemand:DrawToScreen()
	if first then 
		MyAtlasOnDemand:AddText({text = t, font = font, options = 'bo'})
		first = false
		local vsx, vsy = Spring.GetViewGeometry()

		local width = font:GetTextWidth(t) * font.size
		t = t .. " " .. tostring(width) .. " x"..tostring(vsx) .. " y" .. tostring(vsy)
	end
	--local vsx, vsy = Spring.GetViewGeometry()
	font:Begin()
	font:Print(t, 10,256 + 10 + 32,64,'bo')
	font:End()
end

function widget:Initialize()
	local MakeAtlasOnDemand = VFS.Include("LuaUI/Widgets/include/AtlasOnDemand.lua")
	if not MakeAtlasOnDemand then
		Spring.Echo("Failed to load AtlasOnDemand")
		return 
	end
	MyAtlasOnDemand = MakeAtlasOnDemand({sizex = 1024, sizey =  512, xresolution = 96, yresolution = 24, name = "AtlasOnDemand Tester"})
	buildPicList = VFS.DirList("unitpics") 
	--font = WG['fonts'].getFont(nil, 1, 0.1, 13.0)
	font = gl.LoadFont("fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf"), 64, 1, 1)
end

function widget:ShutDown()
	if MyAtlasOnDemand then 
		MyAtlasOnDemand:Destroy()
	end
end
