
function gadget:GetInfo()
    return {
        name      = 'Juno Damage',
        desc      = 'Handles Juno damage',
        author    = 'Niobium, Bluestone',
        version   = 'v2.0',
        date      = '05/2013',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local tokillUnits = {
    [UnitDefNames.armarad.id] = true,
    [UnitDefNames.armaser.id] = true,
    [UnitDefNames.armason.id] = true,
    [UnitDefNames.armeyes.id] = true,
    [UnitDefNames.armfrad.id] = true,
    [UnitDefNames.armjam.id] = true,
    [UnitDefNames.armjamt.id] = true,
    [UnitDefNames.armmark.id] = true,
    [UnitDefNames.armrad.id] = true,
    [UnitDefNames.armseer.id] = true,
    [UnitDefNames.armsjam.id] = true,
    [UnitDefNames.armsonar.id] = true,
    [UnitDefNames.armveil.id] = true,
    [UnitDefNames.corarad.id] = true,
    [UnitDefNames.corason.id] = true,
    [UnitDefNames.coreter.id] = true,
    [UnitDefNames.coreyes.id] = true,
    [UnitDefNames.corfrad.id] = true,
    [UnitDefNames.corjamt.id] = true,
    [UnitDefNames.corrad.id] = true,
    [UnitDefNames.corshroud.id] = true,
    [UnitDefNames.corsjam.id] = true,
    [UnitDefNames.corsonar.id] = true,
    [UnitDefNames.corspec.id] = true,
    [UnitDefNames.corvoyr.id] = true,
    [UnitDefNames.corvrad.id] = true,
	
    [UnitDefNames.corfav.id] = true, 
    [UnitDefNames.armfav.id] = true,
    [UnitDefNames.armflea.id] = true,
}

local todenyUnits = {
    [UnitDefNames.corfav.id] = true, 
    [UnitDefNames.armfav.id] = true,
    [UnitDefNames.armflea.id] = true,
}


local radius = 450 --outer radius of area denial ring
local width = 30 --width of area denial ring
local effectlength = 30 --how long area denial lasts, in seconds
local fadetime = 2 --how long fade in/out effect lasts in seconds

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local SpGetGameSeconds = Spring.GetGameSeconds
local SpGetUnitsInCylinder = Spring.GetUnitsInCylinder
local SpDestroyUnit = Spring.DestroyUnit
local SpGetUnitDefID = Spring.GetUnitDefID

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

-- kill appropriate things from initial juno blast --

local junoWeapons = {
    [WeaponDefNames.ajuno_juno_pulse.id] = true,
    [WeaponDefNames.cjuno_juno_pulse.id] = true,
}

function gadget:UnitDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, aID, aDefID, aTeam)
    if junoWeapons[weaponID] and tokillUnits[uDefID] then
        SpDestroyUnit(uID, false, false, aID)
    end
end

-- area denial --

local centers = {} --table of where juno missiles hit etc
local counter = 1 --index each explosion of juno missile with this counter

function gadget:Initialize()
	Script.SetWatchWeapon(WeaponDefNames.ajuno_juno_pulse.id, true)
	Script.SetWatchWeapon(WeaponDefNames.cjuno_juno_pulse.id, true)
	_G.centers = centers
	_G.widh = width
	_G.radius = radius
	_G.effectlength = effectlength
	_G.fadetime = fadetime
end

function gadget:Explosion(weaponID, px, py, pz, ownerID)
	if junoWeapons[weaponID] then
		local curtime = SpGetGameSeconds()
		local junoExpl = {x=px, y=py, z=pz, t=curtime, show=true}
		centers[counter] = junoExpl
		counter = counter + 1 		
	end
end

function gadget:GameFrame(frame)
	
	local curtime = SpGetGameSeconds()
	local update = false
	
	for counter,expl in pairs(centers) do
		if (expl.t >= curtime - effectlength) then
			local unitIDsBig   = SpGetUnitsInCylinder(expl.x, expl.z, radius)
			local unitIDsSmall = SpGetUnitsInCylinder(expl.x, expl.z, radius-width)

			for _,unitID in pairs(unitIDsBig) do
				local unitDefID = SpGetUnitDefID(unitID)
				if todenyUnits[unitDefID] then
					local foundmatch = false
					for _,testUnitID in pairs(unitIDsSmall) do
						if (unitID == testUnitID) then
							foundmatch = true 
							break
						end
					end
				
					if (not foundmatch) then					
						SpDestroyUnit(unitID,false,false) --TODO aID
					end
				end			
			end

			if ((expl.t + fadetime >= curtime) or (expl.t + effectlength - fadetime <= curtime) and (curtime <= expl.t + effectlength)) then --if we are during fade in/out of some center
				update = true
			end	
			
		else
			centers[counter].show = false --this seems to make passing to unsynced work properly, otherwise it can lag
			table.remove(centers, counter)
		end		
	end
	
	if (update==true) then 
		SendToUnsynced("UpdateList", curtime)
	end
end

-----------------------------------------------------
else -- UNSYNCED
-----------------------------------------------------

function gadget:Initialize()
	gadgetHandler:AddSyncAction("UpdateList", UpdateList)
end

local glCreateList = gl.CreateList
local glBeginEnd = gl.BeginEnd
local glDepthTest = gl.DepthTest
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glCallList = gl.CallList
local glColor = gl.Color
local glVertex = gl.Vertex
local glDeleteList = gl.DeleteList
local GL_TRIANGLES = GL.TRIANGLES
local GL_LEQUAL = GL.LEQUAL
local SpGetGameSeconds = Spring.GetGameSeconds
local SpGetGroundHeight = Spring.GetGroundHeight
local Mmin = math.min
local Mmath = math.max
local Mtan = math.tan
local Mcos = math.cos
local Msin = math.sin
local Mrandom = math.random
local Mpow = math.pow
local Mpi = math.pi


function DrawCircle(cx, cz, r, num_segs, alpha) 
	local theta = 2 * Mpi / num_segs --quick and dirty circle drawing here
	local tangential_factor = Mtan(theta) 
	local radial_factor = Mcos(theta)
	local x = r
	local z = 0 
	local prevx, prevy, prevz
	local cy = 0
	
	circle = glCreateList(function()
	glBeginEnd(GL_TRIANGLES, function()	
	
		for i=0,num_segs do 
			local bx = cx + x
			local bz = cz + z
			local by = 0
		
			if i>0 then
				glColor(0.05, 0.8, 0.1, alpha) -- colour of effect 
				glVertex(cx, cy, cz)
				glColor(0,0,0,0)
				glVertex(prevx, prevy, prevz)
				glVertex(bx,by,bz)
			end
			
			prevx = bx
			prevy = by
			prevz = bz
		
			local tx = -z
			local tz = x
			x = x + tx * tangential_factor 
			z = z + tz * tangential_factor 
			x = x * radial_factor
			z = z * radial_factor
		end
		
	end)
	end)
	
	return circle
		
end

local FadedCircle = DrawCircle(0,0,25,3,0.115)
local num_segments = 300
local radius = SYNCED.radius
local width = SYNCED.width
local effectlength = SYNCED.effectlength
local centers = SYNCED.centers
local ran_num_table = {}
local fadetime = SYNCED.fadetime
local ring 

local count = 0

function UpdateList(_,curtime)
	
	if ring then
		glDeleteList(ring)
	end
	
	ring = glCreateList(function()

	glDepthTest(GL_LEQUAL) --needed else it will draw on top of some trees/grass
	--gl.PolygonOffset(1,1)	

	for counter,expl in spairs(centers) do 

		if expl.show then
			if ran_num_table[counter]==nil then
				local ran_nums = {}
				for i=0,num_segments-1 do
					ran_nums[i] = Mpow(Mrandom(),1/4) -- the 1/4 here controls how quickly the circle appears sa it spreads out
				end
				ran_num_table[counter] = ran_nums				
			end
								
						local theta = 0
			local incr = 2 * Mpi / num_segments
			
			for i=0,num_segments-1 do 
			
				local drawcircle = false
				if ((expl.t + fadetime <= curtime) and (curtime <= expl.t + effectlength - fadetime)) then
					drawcircle = true
				else
					local p = (1/fadetime) * Mmin(curtime-expl.t, expl.t+effectlength-curtime) --tent function, |slope|=1/fadetime, up at expl.t and back down to expl.t+effectlength. controls 'fade' in/out.
					if (ran_num_table[counter][i] <= p) then
						drawcircle = true
					end
				end

				if drawcircle == true then					
					if (expl.t + fadetime >= curtime) then 
						local q = (1/fadetime) * Mmin(curtime-expl.t,fadetime) --controls movement outwards from center on fade in
						x = radius * q * Msin(theta)
						z = radius * q * Mcos(theta)
					else	
						x = radius * Msin(theta)
						z = radius * Mcos(theta)						
					end
				
					local bx = expl.x + x
					local bz = expl.z + z				
					local by = SpGetGroundHeight(bx,bz) + 9 --hover texture above ground slightly, to prevent imperfections appearing on slopes through GL_LEQUAL
					glPushMatrix()			
					glTranslate(bx, by, bz)
					glCallList(FadedCircle)
					glPopMatrix()	
				end
				
				theta = theta + incr
			end
		else
			table.remove(ran_num_table, counter)	
		end	
	end
	
	end)

end



function gadget:DrawWorldPreUnit()
	if ring then
		glCallList(ring)
	end
end





end

