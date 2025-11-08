
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = 'FlowUI GL4 Atlas',
		desc      = 'FlowUI GL4 Atlas Maker',
		author    = 'Beherith',
		version   = '1.0',
		date      = '2021.05.26',
		license   = 'GNU GPL, v2 or later',
		layer     = 100000000,
		enabled   = false,
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- TODO 2022.10.21
-- Dont load all the 3d shit from luaui images root!

local atlasID = nil
local atlassedImages = {}

local function addDirToAtlas(atlas, path)
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local numadded = 0
	local files = VFS.DirList(path)
	spEcho("Adding",#files, "images to atlas from", path)
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] then
			gl.AddAtlasTexture(atlas,files[i])
			atlassedImages[files[i]] = true 
			numadded = numadded + 1
			--spEcho("Adding",files[i], "to atlas")
			--if i > (#files)*0.57 then break end
		else
			--spEcho(files[i],' not an image',string.sub(files[i],-3,-1))
		end
	end
	return numadded
end

local function makeAtlas()
	local atlasSize = 8192
	spEcho("attempt to make atlas")
	atlasID = gl.CreateTextureAtlas(atlasSize,atlasSize,1)
	spEcho("Attempt to add texture")

	addDirToAtlas(atlasID, "unitpics/")
	--addDirToAtlas(atlasID, "luaui/images")
	addDirToAtlas(atlasID, "luaui/images/flowui_gl4/")
	addDirToAtlas(atlasID, "luaui/images/advplayerslist")
	addDirToAtlas(atlasID, "luaui/images/advplayerslist/flags")
	addDirToAtlas(atlasID, "luaui/images/advplayerslist/ranks")
	addDirToAtlas(atlasID, "luaui/images/advplayerslist_mascot")
	addDirToAtlas(atlasID, "luaui/images/commandsfx")
	addDirToAtlas(atlasID, "luaui/images/ecostats")
	addDirToAtlas(atlasID, "luaui/images/ecostats")
	addDirToAtlas(atlasID, "luaui/images/groupicons")
	addDirToAtlas(atlasID, "luaui/images/mapmarksfx")
	addDirToAtlas(atlasID, "luaui/images/music")
	addDirToAtlas(atlasID, "luarules/images/")
	addDirToAtlas(atlasID, "icons/")
	addDirToAtlas(atlasID, "icons/inverted/")
	spEcho("Attempt to finalize")
	gl.FinalizeTextureAtlas(atlasID)
end


function widget:Initialize()
	makeAtlas()
	WG['flowui_atlas'] = atlasID
	WG['flowui_atlassedImages'] = atlassedImages
end

function widget:Shutdown()
	if atlasID ~= nil then 
		gl.DeleteTextureAtlas(atlasID)
	end
end
