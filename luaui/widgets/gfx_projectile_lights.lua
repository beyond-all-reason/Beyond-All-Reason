--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Projectile lights",
    desc      = "Glows them projectiles!",
    author    = "Beherith",
    date      = "july 2012",
    license   = "GNU GPL, v2 or later",
    layer     = -1,
    enabled   = true  
  }
end

local opacityMultiplier = 0.14

local spGetUnitViewPosition 	= Spring.GetUnitViewPosition
local spGetUnitDefID			= Spring.GetUnitDefID
local spGetGroundHeight			= Spring.GetGroundHeight
local spGetVectorFromHeading	= Spring.GetVectorFromHeading
local spGetViewGeometry		    = Spring.GetViewGeometry 
local spTraceScreenRay 			= Spring.TraceScreenRay
local spGetProjectilesInRectangle=Spring.GetProjectilesInRectangle
local spGetProjectilePosition	= Spring.GetProjectilePosition
local spGetProjectileType		= Spring.GetProjectileType
local spGetProjectileName		= Spring.GetProjectileName
local spGetGameFrame 			= Spring.GetGameFrame

local max						= math.max
local floor						= math.floor
local sqrt						= math.sqrt

local glPushMatrix				= gl.PushMatrix
local glTranslate				= gl.Translate
local glScale					= gl.Scale
local glPopMatrix				= gl.PopMatrix
local glBeginEnd				= gl.BeginEnd
local glVertex					= gl.Vertex
local glTexCoord				= gl.TexCoord
local glTexture					= gl.Texture
local glColor					= gl.Color
local glDepthMask				= gl.DepthMask
local glBlending				= gl.Blending
local glDepthTest				= gl.DepthTest
local glCallList				= gl.CallList

local list      
local plighttable ={}
local noise = {--this is so that it flashes a bit, should be addressed with (x+z)%10 +1
	1.1,
	1,
	0.9,
	1.3,
	1.2,
	0.8,
	0.9,
	1.1,
	1,
	0.7,
	}
local pieceprojectilecolor={1,1,0.5,0.2} -- This is the color of piece projectiles, set to nil to disable

list = gl.CreateList(function() 
	glBeginEnd(GL.QUAD_STRIP,function()  
    --point1
    glTexCoord(0,0)
    glVertex(-4,0,-4)
    --point2                                 
    glTexCoord(0,1)                           
    glVertex(4,0,-4)                   
    --point3
    glTexCoord(1,0)
    glVertex(-4,0,4)
    --point4
    glTexCoord(1,1)
    glVertex(4,0,4)
    end)
end)

function widget:Initialize() -- create lighttable
	--The GetProjectileName function returns 'unitname_weaponnname'. EG: armcom_armcomlaser
	-- This is fine with BA, because unitnames dont use '_' characters
	--Spring.Echo('init')
	for u=1,#UnitDefs do
		if UnitDefs[u]['weapons'] and #UnitDefs[u]['weapons']>0 then --only units with weapons
			--These projectiles should have lights:
				--Cannon (projectile size: tempsize = 2.0f + std::min(wd.damages[0] * 0.0025f, wd.damageAreaOfEffect * 0.1f);)
				--Dgun
				--MissileLauncher
				--StarburstLauncher
				--LightningCannon --projectile is centered on emit point
			--Shouldnt:
				--AircraftBomb
				--BeamLaser --Beamlasers shouldnt, because they are buggy (GetProjectilePosition returns center of beam, no other info avalable)
				--LaserCannon --only sniper uses it, no need to make shot more visible
				--Melee
				--Shield
				--TorpedoLauncher
				--EmgCannon (only gorg uses it, and lights dont look so good too close to ground)
				--Flame --a bit iffy cause of long projectile life... too bad it looks great.
				
			for w=1,#UnitDefs[u]['weapons'] do 
				--Spring.Echo(UnitDefs[u]['weapons'][w]['weaponDef'])
				weaponID=UnitDefs[u]['weapons'][w]['weaponDef']
				--Spring.Echo(UnitDefs[u]['name']..'_'..WeaponDefs[weaponID]['name'])
				--WeaponDefs[weaponID]['name'] returns: armcom_armcomlaser
				if (WeaponDefs[weaponID]['type'] == 'Cannon') and (not WeaponDefs[weaponID]['waterWeapon']) then --hack! for armlun/corsok
					--Spring.Echo('Cannon',WeaponDefs[weaponID]['name'],'size', WeaponDefs[weaponID]['size'])
					size=WeaponDefs[weaponID]['size']
					plighttable[WeaponDefs[weaponID]['name']]={1,1,0.5,0.5*((size-1)/3)}
					
				elseif (WeaponDefs[weaponID]['type'] == 'Dgun') then
					--Spring.Echo('Dgun',WeaponDefs[weaponID]['name'],'size', WeaponDefs[weaponID]['size'])
					--size=WeaponDefs[weaponID]['size']
					plighttable[WeaponDefs[weaponID]['name']]={1,1,0.5,0.5}
					
				elseif (WeaponDefs[weaponID]['type'] == 'MissileLauncher') then
					--Spring.Echo('MissileLauncher',WeaponDefs[weaponID]['name'],'size', WeaponDefs[weaponID]['size'])
					size=WeaponDefs[weaponID]['size']
					plighttable[WeaponDefs[weaponID]['name']]={1,1,0.8,0.5*((size-1)/3)}
					
				elseif (WeaponDefs[weaponID]['type'] == 'StarburstLauncher') then
					--Spring.Echo('StarburstLauncher',WeaponDefs[weaponID]['name'],'size', WeaponDefs[weaponID]['size'])
					--size=WeaponDefs[weaponID]['size']
					plighttable[WeaponDefs[weaponID]['name']]={1,1,0.8,0.5}
				elseif (WeaponDefs[weaponID]['type'] == 'LightningCannon') then
					--Spring.Echo('LightningCannon',WeaponDefs[weaponID]['name'],'size', WeaponDefs[weaponID]['size'])
					--size=WeaponDefs[weaponID]['size']
					plighttable[WeaponDefs[weaponID]['name']]={0.2,0.2,1,0.6}
				end
			end
		end
	end
end

local sx, sy, px, py = spGetViewGeometry()
function widget:ViewResize(viewSizeX, viewSizeY)
	sx, sy, px, py = spGetViewGeometry()
end

local plist = {}
local frame = 0
local x1, y1 = 0, 0
local x2, y2 = Game.mapSizeX, Game.mapSizeZ
function widget:DrawWorldPreUnit()

	if frame < spGetGameFrame() then
		frame = spGetGameFrame()
	
		local at, p = spTraceScreenRay(sx*0.5,sy*0.5,true,false,false)
		if at=='ground' then
			local cx, cy = p[1], p[3]
			local dcxp1, dcxp3
			local outofbounds = 0
			local d = 0
			--x2=math.min(x2, tl[1])
			--y2=math.min(y2, tl[3])
			
			at, p = spTraceScreenRay(0, 0, true, false, false) --bottom left
			if at=='ground' then
				dcxp1, dcxp3 = cx-p[1], cy-p[3]
				d = max(d, dcxp1*dcxp1 + dcxp3*dcxp3)
			else 
				outofbounds = outofbounds+1
			end
			at, p = spTraceScreenRay(sx-1, 0, true, false, false) --bottom left
			if at=='ground' then
				dcxp1, dcxp3 = cx-p[1], cy-p[3]
				d = max(d, dcxp1*dcxp1 + dcxp3*dcxp3)
			else 
				outofbounds = outofbounds+1
			end
			at, p = spTraceScreenRay(sx-1, sy-1, true, false, false) --bottom left
			if at=='ground' then
				dcxp1, dcxp3 = cx-p[1], cy-p[3]
				d = max(d, dcxp1*dcxp1 + dcxp3*dcxp3)
			else 
				outofbounds = outofbounds+1
			end
			at, p = spTraceScreenRay(0, sy-1, true, false, false) --bottom left
			if at=='ground' then
				dcxp1, dcxp3 = cx-p[1], cy-p[3]
				d = max(d, dcxp1*dcxp1 + dcxp3*dcxp3)
			else 
				outofbounds = outofbounds+1
			end
			if outofbounds>=3 then
				plist = spGetProjectilesInRectangle(x1, y1, x2, y2, false, false) --todo, only those in view or close:P
			else
				d = sqrt(d)
				plist = spGetProjectilesInRectangle(cx-d, cy-d, cx+d, cy+d, false, false) 
			end
		else -- if we are not pointing at ground, get the whole list.
			plist = spGetProjectilesInRectangle(x1, y1, x2, y2, false, false) --todo, only those in view or close:P
		end
	end
	--Spring.GetCameraPosition 
	--Spring.GetCameraPosition() -> number x, number y, number z
	--Spring.GetCameraDirection() -> number forward_x, number forward_y, number forward_z
	--Spring.GetCameraFOV( ) -> number fov

	--Spring.Echo('mapview',nplist,outofbounds,d,cx,cy)
	--Spring.Echo('fov',Spring.GetCameraFOV(),Spring.GetCameraPosition())
	if #plist>0 then --dont do anything if there are no projectiles in range of view
		--Spring.Echo('#projectiles:',#plist)
		glTexture('luaui/images/pointlight.tga') --simple white square with alpha white blurred circle
		
		--enabling both test and mask means they wont be drawn over cliffs when obscured
			--but also means that they will flicker cause of z-fighting when scrolling around...
			--and ESPECIALLY when overlapping
		-- mask=false and test=true is perfect, no overlap flicker, no cliff overdraw
			--BUT it clips into cliffs from the side....
		glDepthMask(false)
		--glDepthMask(true)
		glDepthTest(false)
		--glDepthTest(GL.LEQUAL) 

		local x,y,z
		--local fx, fy = 32, 32	--footprint
		glBlending("alpha_add") --makes it go into +
		local lightparams
		-- AND NOW FOR THE FUN STUFF!
		for i=1, #plist do
			local pID=plist[i]
			x,y,z=spGetProjectilePosition(pID)
			local wep,piece=spGetProjectileType(pID)
			if piece then
				lightparams={1,1,0.5,0.3}
			else
				lightparams=plighttable[spGetProjectileName(pID)]
			end
			if (lightparams and x and y>0) then -- projectile is above water
				local height = max(0, spGetGroundHeight(x, z)) --above water projectiles should show on water surface
				--local diff = height-y	-- this is usually 5 for land units, 5+cruisehieght for others
										-- the plus 5 is do that it doesn't clip all ugly like, unneeded with depthtest and mask both false!
										-- diff is negative, cause we need to put the lighting under it
										-- diff defines size and diffusion rate)
				local factor = max(0.01, (100.0+height-y)*0.01) --factor=1 at when almost touching ground, factor=0 when above 100 height)
				if (factor >0.01) then 
					local n=noise[floor(x+z+pID)%10+1]
					glColor(lightparams[1],lightparams[2],lightparams[3],(lightparams[4]*factor*factor*n)*opacityMultiplier) -- attentuation is x^2
					factor = 32*(1.1-max(factor/(n*0.5+0.5),0.3)) -- clamp the size
					glPushMatrix()
					glTranslate(x, height+5, z)  -- push in y dir by height (to push it on the ground!), +5 to keep it above surface
					glScale(factor, 1.0, factor) --scale it by size
					glCallList(list) --draw it :)
					glPopMatrix()
				end
			end
		end
		glTexture(false) --be nice, reset stuff 
		glColor(1.0,1.0,1.0,1.0)
		glBlending(false)
		glDepthTest(true)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
