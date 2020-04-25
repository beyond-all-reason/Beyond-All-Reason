function gadget:GetInfo()
	return {
		name      = "Scavenger Texture Atlases Renderer",
		desc      = "Renders into scavengers texture atlases, so they look unique",
		author    = "ivand",
		date      = "2020",
		license   = "PD",
		layer     = -1,
		enabled   = false,
	}
end


if gadgetHandler:IsSyncedCode() then
	return
end

--unsynced gadget

GG.GetScavTexture = function() end

local drawScavAtlasClass
local drawScavAtlas

if gl.CreateShader == nil then
	Spring.Echo("ERROR: PBR enabler: gl.CreateShader is nil")
	return
end

if gl.CreateFBO == nil then
	Spring.Echo("ERROR: PBR enabler: gl.CreateFBO is nil")
	return
end

local headless = Spring.GetConfigInt("Headless", 0) > 0
if headless then
	return
end

local scavTex1, scavTex2, scavNormal

local function GetScavTexture(udID, texNum)
	if drawScavAtlas then
		return drawScavAtlas:GetTexture(udID, texNum)
	end
end

function gadget:DrawGenesis()
	if drawScavAtlas then
		drawScavAtlas:Execute(false)
	end
	gadgetHandler:RemoveCallIn("DrawGenesis")
end

function gadget:Initialize()
	drawScavAtlasClass = VFS.Include("LuaRules/Gadgets/Include/DrawScavAtlas.lua")
	if drawScavAtlasClass then
		drawScavAtlas = drawScavAtlasClass()
		if drawScavAtlas then
			drawScavAtlas:Initialize()
			GG.GetScavTexture = GetScavTexture
		end
	end
end

function gadget:Shutdown()
	if drawScavAtlas then
		GG.GetScavTexture = function() end
		drawScavAtlas:Finalize()
	end
end