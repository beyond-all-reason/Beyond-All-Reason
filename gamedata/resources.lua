local resources = {
	graphics = {
		 maps = {
			detailtex = 'default/detailtex2.bmp',
			watertex  = 'default/ocean.jpg',
		 },
		 groundfx = {
			groundflash      = 'default/groundflash.tga',
			groundflashwhite = 'default/groundflashwhite.tga',
			groundring       = 'default/groundring.tga',
			seismic          = 'default/circles.tga',
			circlefx0        = 'default/circlefx0.png',
			circlefx1        = 'default/circlefx1.png',
			circlefx2        = 'default/circlefx2.png',
			circlefx3        = 'default/circlefx3.png',
			radarfx2ground   = 'ui/radarping2.png',
			scar50glow		 = 'projectiletextures/decal_scar_50_glow.tga',
			centersplatsh    = 'default/centersplatsh_white.tga',
			barshockwave     = 'default/BARshockwave1.tga',
		 },
		 projectiletextures  = {
			circularthingy    = 'default/circularthingy.tga',
			circles           = 'default/circles.tga',
			gfxtexture        = 'projectiletextures/nanopart.tga',
			laserend          = 'default/laserend.tga',
			laserfalloff      = 'default/laserfalloff.tga',
			randdots          = 'default/randdots.tga',
			smoketrail        = 'default/smoketrail.tga',
			smoketrailaa      = 'default/smoketrailaa.tga',
			railguntrail      = 'default/railguntrail.tga',
			trail             = 'default/trail.tga',
			wake              = 'default/wake.tga',
			wakegrey          = 'projectiletextures/wakegrey.tga',
			flashside3        = 'projectiletextures/flashside3.tga',
			flare             = 'default/flare.tga',
			flare2            = 'default/flare2.tga',
			explo             = 'default/explo.tga',
			explo2            = 'default/explo2.tga',
			sakexplo2         = 'default/sakexplo2.tga',
			explofade         = 'default/explofade.tga',
			exploflare        = 'projectiletextures/exploflare.tga',
			heatcloud         = 'default/explo.tga',
			blastwave         = 'projectiletextures/blastwave.tga',
			flame             = 'default/flame.tga',
			flame_dark        = 'projectiletextures/flame.tga',
			flame_alt         = 'gpl/flame.tga',
			flame_alt2        = 'gpl/flame_alt.tga',
			fire              = 'gpl/fire.tga',
			flamestream       = 'atmos/flamestream.tga',
			treefire          = 'gpl/treefire.png',
			muzzlesideflipped = 'default/muzzlesideflipped.tga',
			muzzleside        = 'default/muzzleside.tga',
			muzzlefront       = 'default/muzzlefront.tga',
			largebeam         = 'default/largelaserfalloff.tga',
			gunshotxl         = 'default/gunshotxl.tga',

			radarfx1          = 'ui/radarping1.png',
			radarfx2          = 'ui/radarping2.png',

			lavachunk		  = 'atmos/lavachunk.tga',
			lavasplats		  = 'atmos/lavasplats.tga',
			lavaplosion		  = 'atmos/lavaplosion.tga',

			fogdirty          = 'atmos/fogdirty.tga',
			rain              = 'atmos/rain.tga',
			cloudpuff         = 'atmos/cloudpuff.tga',
			cloudmist         = 'atmos/cloudmist.tga',
			barmist           = 'atmos/barmist.tga',
			sandblast         = 'atmos/sandblast.tga',
			smoke_puff        = 'atmos/smoke_puff.tga',
			smoke_puff2       = 'atmos/smoke_puff2.tga',
			smoke_puff_red    = 'atmos/smoke_puff_red.tga',
			dirtrush          = 'atmos/dirtdebrisexplo.tga',
			dirtpuff          = 'atmos/dirtpuff.tga',
			explowater        = 'projectiletextures/explowater.tga',
			waterrush         = 'projectiletextures/waterrush.tga',
			waterfoam         = 'atmos/waterfoam.tga',
			subwak            = 'projectiletextures/subwake.tga',
			scar50			  = 'projectiletextures/decal_scar_50.tga',

			--Raptor Defense effects
			uglynovaexplo           = 'CC/uglynovaexplo.tga',
			sporetrail              = 'GPL/sporetrail.tga',
			sporetrail_xl           = 'GPL/sporetrail_xl.tga',
			blooddrop               = 'PD/blooddrop.tga',
			blooddrop2              = 'raptors/blooddrop2.tga',
			blooddrop2white         = 'raptors/blooddrop2_white.tga',
			bloodblast              = 'PD/bloodblast.tga',
			bloodblast2             = 'raptors/bloodblast2.tga',
			bloodblast2white        = 'raptors/bloodblast2_white.tga',
			bloodsplat              = 'PD/bloodsplat.tga',
			bloodsplat2             = 'raptors/bloodsplat2.tga',
			bloodsplat2white        = 'raptors/bloodsplat2_white.tga',
			bloodspark2             = 'raptors/blood_splat.tga',
			bloodspark2white        = 'raptors/blood_splat_white.tga',
			bloodcentersplatsh      = 'raptors/blood_centersplatsh.tga',
			bloodcentersplatshwhite = 'raptors/blood_centersplatsh_white.tga',
			blooddropwhite          = 'PD/blooddropwhite.tga',
			bloodblastwhite         = 'PD/bloodblastwhite.tga',
			lightningbeam			= 'PD/lightning.tga',
		 },
	  }
   }

local function AutoAdd(subDir, map, filter)
	local dirList = VFS.DirList("bitmaps/" .. subDir, nil, nil, true)
	for _, fullPath in ipairs(dirList) do
		local path, key, ext = fullPath:match("bitmaps/(.*/(.*)%.(.*))")
		if not fullPath:match("/%.svn") then
			local subTable = resources["graphics"][subDir] or {}
			resources["graphics"][subDir] = subTable
			if not filter or filter == ext then
				if not map then
				table.insert(subTable, path)
				else -- a mapped subtable
				subTable[key] = path
				end
			end
		end
	end
end

-- Add default caustics, smoke and scars
AutoAdd("caustics", false)
AutoAdd("smoke", false, "tga")
AutoAdd("scars", false)
-- Add mod groundfx and projectiletextures
AutoAdd("groundfx", true)
AutoAdd("projectiletextures", true)

return resources
