
if addon.InGetInfo then
	return {
		name    = "LoadTexture",
		desc    = "",
		author  = "jK",
		date    = "2012",
		license = "GPL2",
		layer   = 2,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

math.randomseed( os.clock() )
math.random(); math.random(); math.random()

------------------------------------------
local loadscreens = VFS.DirList("bitmaps/loadpictures/")

local screenNum = math.random(#loadscreens)
--local backgroundTexture = loadscreens[screenNum]
local backgroundTexture = loadscreens[1+(math.floor((1000*os.clock())%#loadscreens))] -- hacky hotfix for http://springrts.com/mantis/view.php?id=4572
if not VFS.FileExists(backgroundTexture) then	-- because encountering white loadscreens once in a while (this is not a real fix ofc)
	backgroundTexture = loadscreens[1+(math.floor((1000*os.clock())%#loadscreens))] -- hacky hotfix for http://springrts.com/mantis/view.php?id=4572
end
if not backgroundTexture then
	backgroundTexture = loadscreens[1]
end
local aspectRatio

function addon.DrawLoadScreen()

	local loadProgress = SG.GetLoadProgress()

	if not aspectRatio then
		local texInfo = gl.TextureInfo(backgroundTexture)
		if not texInfo then return end
		aspectRatio = texInfo.xsize / texInfo.ysize
	end

	local vsx, vsy = gl.GetViewSizes()
	local screenAspectRatio = vsx / vsy

	local xDiv = 0
	local yDiv = 0
	local ratioComp = screenAspectRatio / aspectRatio

    if math.abs(ratioComp-1)>0.15 then
        if (ratioComp > 1) then
			yDiv = (1 - ratioComp) * 0.5;
        else
			xDiv = (1 - (1 / ratioComp)) * 0.5;
        end
    end

	-- background
	local scale = 1
	local ssx,ssy,spx,spy = Spring.GetScreenGeometry()
	if ssx / vsx < 1 then	-- adjust when window is larger than the screen resolution
		--scale = ssx / vsx
		--xDiv = xDiv * scale	-- this doesnt work
		--yDiv = yDiv * scale
	end
	gl.Color(1,1,1,1)
	gl.Texture(backgroundTexture)
	gl.TexRect(0+xDiv,(1-scale)+yDiv,scale-xDiv,1-yDiv)
	gl.Texture(false)
end

function addon.Shutdown()
	if backgroundTexture then
		gl.DeleteTexture(backgroundTexture)
	end
end
