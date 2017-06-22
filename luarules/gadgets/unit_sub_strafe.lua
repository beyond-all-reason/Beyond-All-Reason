function gadget:GetInfo()
	return {
		name = "SubmarineStrafe Slows BETA (arm only)",
		desc = "Slow strafing submarines (max = 0.4 * maxspeed @ 90 degrees and 0.5*maxspeed in reverse)",
		author = "[Fx]Doo",
		date = "03/28/17",
		license = "Free",
		layer = 0,
		enabled = true -- 
	}
end

function gadget:Initialize()
    for uDefID, uDef in pairs(UnitDefs) do
	-- Spring.Echo(uDef.name)
		if uDef.name == "armsub" then
			armsub = uDefID
		end
		-- if uDef.name == "corshark" then
			-- corshark = uDefID
		-- end
		if uDef.name == "armsubk" then
			armsubk = uDefID
		end
		if uDef.name == "armserp" then
			armserp = uDefID
		end
		if uDef.name == "corsub" then
			corsub = uDefID
		end
		-- if uDef.name == "corssub" then
			-- corssub = uDefID
		-- end
    end
end

Submarines = {}

if (gadgetHandler:IsSyncedCode()) then
function gadget:UnitFinished(unitID)
local DEFID = Spring.GetUnitDefID(unitID)
if DEFID == armsub or DEFID == armsubk or DEFID == armserp or DEFID == corsub then
Submarines[unitID] = DEFID
end
end

function UnitDestroyed(unitID)
if (Submarines[unitID]) then 
Submarines[unitID] = nil 
end
end

function gadget:GameFrame(f)
for uid,udid in pairs(Submarines) do
if Spring.ValidUnitID(uid) == true then
x,y,z = Spring.GetUnitPosition(uid)
local vx,vy,vz,vw = Spring.GetUnitVelocity(uid)
local maxVel = UnitDefs[udid].speed
local dux, duy, duz = vx/math.sqrt(vx^2+vy^2+vz^2), vy/math.sqrt(vx^2+vy^2+vz^2), vz/math.sqrt(vx^2+vy^2+vz^2)
local pwx, pwy, pwz, dwx, dwy, dwz = Spring.GetUnitPiecePosDir(uid, 1)
-- local pieces = Spring.GetUnitPieceList(uid)
-- for key, value in pairs(pieces) do
-- Spring.Echo(key.."= "..value)
-- end
if udid == armsub then
ndwx = dwz/math.sqrt(dwx^2+dwz^2)
ndwz = -dwx/math.sqrt(dwx^2+dwz^2)
end

if udid == corsub then
ndwx = -dwz/math.sqrt(dwx^2+dwz^2)
ndwz = dwx/math.sqrt(dwx^2+dwz^2)
-- Spring.Echo(rx)
-- Spring.SpawnCEG("ZEUS_FLASH", x, 100+y, z, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*100, 100+y, z+duz*100, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*100, 100+y, z+ndwz*100, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*90, 100+y, z+duz*90, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*90, 100+y, z+ndwz*90, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*80, 100+y, z+duz*80, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*80, 100+y, z+ndwz*80, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*70, 100+y, z+duz*70, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*70, 100+y, z+ndwz*70, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*60, 100+y, z+duz*60, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*60, 100+y, z+ndwz*60, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*50, 100+y, z+duz*50, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*50, 100+y, z+ndwz*50, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*40, 100+y, z+duz*40, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*40, 100+y, z+ndwz*40, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+dux*30, 100+y, z+duz*30, 0, 1, 0, 1, 1)
-- Spring.SpawnCEG("ZEUS_FLASH", x+ndwx*30, 100+y, z+ndwz*30, 0, 1, 0, 1, 1)
end

if udid == armserp then
ndwx = -dwx/math.sqrt(dwx^2+dwz^2)
ndwz = -dwz/math.sqrt(dwx^2+dwz^2)
end
if udid == armsubk then
ndwx = -dwz/math.sqrt(dwx^2+dwz^2)
ndwz = dwx/math.sqrt(dwx^2+dwz^2)
end



a = 1
b = 1
c = math.sqrt(((x + ndwx) - (x + dux))^2 + ((z+ndwz)-(z+duz))^2)
alpha = math.acos((0.5*(a^(2)+b^(2)-c^(2)))/(a*b))

rx = math.cos(alpha)
if rx > 0 and rx < 0.4 then 
rx = 0.4 
end
if rx < 0 then 
rx = 0.5 
end

local maxAllowedVel = rx * maxVel / 30
if vw and maxAllowedVel and vw > maxAllowedVel then 
local factor = maxAllowedVel/vw
Spring.SetUnitVelocity(uid, vx * factor, vy, vz * factor)
end
end
end
end
end
