local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Font handler",
		desc = "handles font object creation",
		author = "Floris",
		date = "June 2020",
		license = "GNU GPL, v2 or later",
		layer = -1200001,
		enabled = true,
	}
end

-- Localized functions for performance
local mathFloor = math.floor
local mathAbs = math.abs

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local defaultFont = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local defaultFont2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local defaultFont3 = "fonts/monospaced/" .. Spring.GetConfigString("bar_font3", "SourceCodePro-Medium.otf")

local defaultSize = 34

local defaultOutlineStrength = 1.7
local defaultOutlineSize -- assigned in ViewResize

local ui_scale = Spring.GetConfigFloat("ui_scale", 1)

local rescaleTolerance = 0.05 -- fonts are remade only when the view scale moves further than this from theirs
local mergeTolerance = 0.1 -- a request this close in size to a loaded font of the same face and outline gets that font

-- the scale the loaded fonts were made at; 0 makes the first ViewResize set it
local fontScale = 0 ---@type number
local fonts = {} -- by request
local loadedFonts = {} -- by face and outline: { font, size } for each size loaded

function widget:Initialize()
	if gl.AddFallbackFont then
		gl.AddFallbackFont("fallbacks/NotoEmoji-VariableFont_wght.ttf")
		gl.AddFallbackFont("fallbacks/SourceHanSans-Regular.ttc")
	end

	widget:ViewResize(spGetViewGeometry())

	WG.fonts = {}
	WG.fonts.getFont = function(file, size, outlineSize, outlineStrength)
		if not file or file == 1 then
			file = defaultFont
		elseif file == 2 then
			file = defaultFont2
		elseif file == 3 then
			file = defaultFont3
		end
		size = mathFloor((defaultSize * (size and size or 1) + 0.5))
		outlineSize = mathFloor((defaultSize * (outlineSize and outlineSize or defaultOutlineSize)) + 0.5)
		outlineStrength = (outlineStrength and outlineStrength or defaultOutlineStrength)

		local id = file .. "_" .. size .. "_" .. outlineSize .. "_" .. outlineStrength
		local loaded = fonts[id]
		if loaded == nil then
			local face = file .. "_" .. outlineSize .. "_" .. outlineStrength
			local sameFace = loadedFonts[face]
			if sameFace == nil then
				sameFace = {}
				loadedFonts[face] = sameFace
			end
			local closest = mergeTolerance
			for i = 1, #sameFace do
				local difference = mathAbs(sameFace[i].size / size - 1)
				if difference <= closest then
					loaded, closest = sameFace[i], difference
				end
			end
			if loaded == nil then
				local px, outlinePx = mathFloor(size * fontScale), mathFloor(outlineSize * fontScale)
				loaded = { font = gl.LoadFont(file, px, outlinePx, outlineStrength), size = size }
				sameFace[#sameFace + 1] = loaded
			end
			fonts[id] = loaded
		end
		return loaded.font, loaded.size * fontScale
	end
end

function widget:ViewResize(_, vsy)
	local newFontScale = (vsy / 1080) * ui_scale
	if mathAbs(newFontScale / fontScale - 1) <= rescaleTolerance then
		return
	end
	fontScale = newFontScale

	local outlineMult = math.clamp(1 / (vsy / 1400), 1, 1.5)
	defaultOutlineSize = 0.22 * (outlineMult * 0.9)

	-- Not gl.DeleteFont: widgets still hold these fonts until they ask again, and a deleted font
	-- errors on use. The garbage collector frees each one once nobody holds it.
	fonts = {}
	loadedFonts = {}
end
