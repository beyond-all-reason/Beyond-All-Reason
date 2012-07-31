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

local spGetUnitViewPosition 	= Spring.GetUnitViewPosition
local spGetUnitDefID			= Spring.GetUnitDefID
local spGetGroundHeight			= Spring.GetGroundHeight
local spGetVectorFromHeading	= Spring.GetVectorFromHeading

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
local glDepthTest				= gl.DepthTest
local glCallList				= gl.CallList

local udefTab					= UnitDefs

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
local pieceprojectilecolor={1,1,0.5,0.25} -- This is the color of piece projectiles, set to nil to disable

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
				if (WeaponDefs[weaponID]['type'] == 'Cannon') then
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
function widget:DrawWorldPreUnit()
	local sx,sy,px,py=Spring.GetViewGeometry()
	--Spring.Echo('viewport=',sx,sy,px,py)
	local x1=0
	local y1=0
	local x2=Game.mapSizeX 
	local y2=Game.mapSizeZ
	--[[
	at, bl=Spring.TraceScreenRay(0,0,true,false,false) --bottom left
	--Spring.Echo('bl',at,bl)
	if at=='ground' then
		x1=math.max(x1, bl[1])
		--x2=math.min(x2, tl[1])
		--y1=math.max(y1, bl[3])
		y2=math.min(y2, bl[3])
	end
	at, br=Spring.TraceScreenRay(sx-1,0,true,false,false)
	if at=='ground' then
		--x1=math.max(x1, tl[1])
		x2=math.min(x2, br[1])
		--y1=math.max(y1, tl[3])
		y2=math.min(y2, br[3])
	end
	at, tl=Spring.TraceScreenRay(0,sy-1,true,false,false)
	if at=='ground' then
		x1=math.max(x1, tl[1])
		--x2=math.min(x2, tl[1])
		y1=math.max(y1, tl[3])
		--y2=math.min(y2, tl[3])
	end
	at, tr=Spring.TraceScreenRay(sx-1,sy-1,true,false,false)
	--Spring.Echo('tr',at)
	if at=='ground' then
	--	Spring.Echo('tr',at,tr)
		--x1=math.max(x1, tl[1])
		x2=math.min(x2, tr[1])
		y1=math.max(y1, tr[3])
		--y2=math.min(y2, tl[3])
	end]]--
	local plist=Spring.GetProjectilesInRectangle(x1,y1,x2,y2,false,false) --todo, only those in view or close:P
	--Spring.Echo('mapview',x1,y1,x2,y2)
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
		local fx,fy 
		gl.Blending("alpha_add") --makes it go into +
		local lightparams
		-- AND NOW FOR THE FUN STUFF!
		for i=1, #plist do
			local pID=plist[i]
			x,y,z=Spring.GetProjectilePosition(pID)
			local wep,piece=Spring.GetProjectileType(pID)
			--Spring.Echo('Proj',pID,'name',Spring.GetProjectileName(pID),' wep/piece',wep,piece,'pos=',math.floor(x),math.floor(y),math.floor(z))
			lightparams=nil
			if piece then
				lightparams={1,1,0.5,0.3}
			else
				lightparams=plighttable[Spring.GetProjectileName(pID)]
			end
			if Spring.GetProjectileName(pID) == 'armllt_arm_lightlaser' then
				--Spring.Echo('angle',Spring.GetProjectileSpinAngle(pID),'/',Spring.GetProjectileSpinAngle(pID),'/',Spring.GetProjectileSpinVec(pID),'/',Spring.GetProjectileVelocity(pID))
			end
			if (lightparams ~= nil and x and y>0) then -- projectile is above water
				fx = 32
				fy = 32 --footprint
				 
				local height = math.max(0,spGetGroundHeight(x,z)) --above water projectiles should show on water surface
				local diff = height-y  -- this is usually 5 for land units, 5+cruisehieght for others
										-- the plus 5 is do that itdoesnt clip all ugly like, unneeded with depthtest and mask both false!
										-- diff is negative, cause we need to put the lighting under it
				--diff defines size and diffusion rate)
				local factor=math.max(0.01,(100.0+diff)/100.0) --factor=1 at when almost touching ground, factor=0 when above 100 height)
				
				if (factor >0.01) then 
					
					glColor(lightparams[1],lightparams[2],lightparams[3],lightparams[4]*factor*factor*noise[math.floor(x+z+pID)%10+1]) -- attentuation is x^2
					factor = math.max(factor,0.3) -- clamp the size
					glPushMatrix()
					glTranslate(x,y+diff+5,z)  -- push in y dir by height (to push it on the ground!), +5 to keep it above surface
					glScale(fx*(1.1-factor),1.0,fy*(1.1-factor)) --scale it by size
					glCallList(list) --draw it :)
					glPopMatrix()
				end
			end
		end

		gl.Texture(false) --be nice, reset stuff 
		gl.Color(1.0,1.0,1.0,1.0)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------