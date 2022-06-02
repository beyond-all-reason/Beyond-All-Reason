function widget:GetInfo()
	return {
		name = "Atlas Tester",
		desc = "Find why order is different",
		author = "Beherith",
		date = "2021.11.02",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end

local atlasColorAlpha = nil
local atlasNormals = nil
local atlasHeights = nil
local atlasORM = nil 

local atlasSize = 4096
local atlassedImages = {}


local function addDirToAtlas(atlas, path, key)
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local files = VFS.DirList(path)
	Spring.Echo("Adding images to atlas from", path)
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] and string.find(files[i], key, nil, true) then
			Spring.Echo(files[i])
			gl.AddAtlasTexture(atlas,files[i])
			atlassedImages[files[i]] = atlas
		end
	end
end

local function makeAtlases()
	local success
	atlasColorAlpha = gl.CreateTextureAtlas(atlasSize,atlasSize,1)
	addDirToAtlas(atlasColorAlpha, "luaui/images/decals_gl4/groundScars", '_a.png')
	success = gl.FinalizeTextureAtlas(atlasColorAlpha)
	if success == false then return false end
	
	atlasNormals = gl.CreateTextureAtlas(atlasSize,atlasSize,1)
	addDirToAtlas(atlasNormals, "luaui/images/decals_gl4/groundScars", '_n.png')
	success = gl.FinalizeTextureAtlas(atlasNormals)
	if success == false then return false end
	
	atlasHeights = gl.CreateTextureAtlas(atlasSize,atlasSize,1)
	addDirToAtlas(atlasHeights, "luaui/images/decals_gl4/groundScars", '_h.png')
	success = gl.FinalizeTextureAtlas(atlasHeights)
	if success == false then return false end
	
	atlasORM = gl.CreateTextureAtlas(atlasSize,atlasSize,1)
	addDirToAtlas(atlasORM, "luaui/images/decals_gl4/groundScars", '_orm.png')
	success = gl.FinalizeTextureAtlas(atlasORM)
	if success == false then return false end
	return true
end

function widget:DrawScreen()
	local vsx, vsy = Spring.GetViewGeometry()
	gl.Texture(atlasColorAlpha)
	gl.TexRect(vsx * 0.5, vsy * 0.5, vsx * 0.75, vsy *0.75)
	gl.Texture(atlasNormals)
	gl.TexRect(vsx * 0.25, vsy * 0.25, vsx * 0.5, vsy *0.5)
	gl.Texture(atlasHeights)
	gl.TexRect(vsx * 0.25, vsy * 0.5, vsx * 0.5, vsy *0.75)
	gl.Texture(atlasORM)
	gl.TexRect(vsx * 0.5, vsy * 0.25, vsx * 0.75, vsy *0.5)
end

function widget:Initialize()
	if makeAtlases() == false then 
		goodbye("Failed to init texture atlas for DecalsGL4")
		return
	end
end

function widget:ShutDown()
	if atlasColorAlpha ~= nil then
		gl.DeleteTextureAtlas(atlasColorAlpha)
	end
	if atlasHeights ~= nil then
		gl.DeleteTextureAtlas(atlasHeights)
	end
	if atlasNormals ~= nil then
		gl.DeleteTextureAtlas(atlasNormals)
	end
	if atlasORM ~= nil then
		gl.DeleteTextureAtlas(atlasORM)
	end
end
