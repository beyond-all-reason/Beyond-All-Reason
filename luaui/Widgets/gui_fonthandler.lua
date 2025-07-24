local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Font handler",
		desc      = "handles font object creation",
		author    = "Floris",
		date      = "June 2020",
		license   = "GNU GPL, v2 or later",
		layer     = -1000001,
		enabled   = true
	}
end

local vsx,vsy = Spring.GetViewGeometry()

local defaultFont = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local defaultFont2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local defaultFont3 = "fonts/monospaced/" .. Spring.GetConfigString("bar_font3", "SourceCodePro-Medium.otf")

local defaultSize = 34

local defaultOutlineStrength = 1.7
local defaultOutlineSize -- assigned in ViewResize

local ui_scale = Spring.GetConfigFloat("ui_scale", 1)

local fonts = {}
local fontScale = 1
local sceduledDeleteFonts = {}
local sceduledDeleteFontsClock

local function createFont(file, size, outlineSize, outlineStrength)
	local id = file..'_'..size..'_'..outlineSize..'_'..outlineStrength
	if fonts[id] ~= nil then
		sceduledDeleteFonts[#sceduledDeleteFonts+1] = fonts[id]
		sceduledDeleteFontsClock = os.clock() + 5
	end
	fonts[id] = gl.LoadFont(file, size*fontScale, outlineSize*fontScale, outlineStrength)
end


local sec = 0
function widget:Update(dt)
	-- sec = sec + dt
	-- if sec > 4 then
	-- 	sec = 0
	-- 	local i = 0
	-- 	for id,font in pairs(fonts) do
	-- 		i = i + 1
	-- 		if string.find(id, 'Exo') then
	-- 			Spring.Echo(id)
	-- 		end
	-- 	end
	-- 	for id,font in pairs(fonts) do
	-- 		if not string.find(id, 'Exo') then
	-- 			Spring.Echo(id)
	-- 		end
	-- 	end
	-- 	Spring.Echo(i)
	-- end

	if sceduledDeleteFontsClock and sceduledDeleteFontsClock < os.clock() then
		for i,font in pairs(sceduledDeleteFonts) do
			gl.DeleteFont(font)
		end
		sceduledDeleteFonts = {}
		sceduledDeleteFontsClock = nil
	end
end

function widget:Initialize()
	if gl.AddFallbackFont then
		gl.AddFallbackFont('fallbacks/NotoEmoji-VariableFont_wght.ttf')
		gl.AddFallbackFont('fallbacks/SourceHanSans-Regular.ttc')
	end

	vsx,vsy = Spring.GetViewGeometry()
	widget:ViewResize(vsx, vsy, true)

	WG['fonts'] = {}
	WG['fonts'].getFont = function(file, size, outlineSize, outlineStrength)
		if not file or file == 1 then
			file = defaultFont
		elseif file == 2 then
			file = defaultFont2
		elseif file == 3 then
			file = defaultFont3
		end
		size = math.floor((defaultSize * (size and size or 1) + 0.5))
		outlineSize = math.floor((defaultSize * (outlineSize and outlineSize or defaultOutlineSize)) + 0.5)
		outlineStrength = (outlineStrength and outlineStrength or defaultOutlineStrength)

		local id = file..'_'..size..'_'..outlineSize..'_'..outlineStrength
		if fonts[id] == nil then
			createFont(file, size, outlineSize, outlineStrength)
		end
		return fonts[id], size*fontScale
	end
end

function widget:ViewResize(vsx, vsy, init)
	vsx,vsy = Spring.GetViewGeometry()
	local newFontScale = (vsy / 1080) * ui_scale

	local outlineMult = math.clamp(1/(vsy/1400), 1, 1.5)
	defaultOutlineSize = 0.22*(outlineMult*0.9)

	if fontScale ~= newFontScale then
		fontScale = newFontScale

		for id, font in pairs(fonts) do
			gl.DeleteFont(font)
		end
		fonts = {}
	end
end

function widget:GetConfigData()
	return {
		fonts = fonts,
		fontScale = fontScale
	}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 then
		if data.fonts ~= nil then
			fonts = data.fonts		-- not sure why BYAR.lua just shows empty table while it has the fonts when restoring o_0
			fontScale = data.fontScale
		end
	end
end
