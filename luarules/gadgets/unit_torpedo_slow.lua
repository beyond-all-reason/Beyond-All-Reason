function gadget:GetInfo()
	return {
		name = "Torpedo Slow",
		desc = "Torpedo slows down units (add slowslength and slowstrength tags in wdefs' customParams to use custom values)",
		author = "[Fx]Doo",
		date = "03/28/17",
		license = "Free",
		layer = 0,
		enabled = true -- 
	}
end

function gadget:Initialize()
		slowStrength = {}
		slowLength = {}
    for wDefID, wDef in pairs(WeaponDefs) do
        slowStrength[wDefID] = wDef.customParams and wDef.customParams.slowstrength or 0
		slowLength[wDefID] = wDef.customParams and wDef.customParams.slowslength or 30
    end
end

if (gadgetHandler:IsSyncedCode()) then
slow = {}
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam) -- Get units damaged by torpedos
if (WeaponDefs[weaponDefID]) then --debris damages failsafe
if (WeaponDefs[weaponDefID].type) then --debris damages failsafe
if WeaponDefs[weaponDefID].type == "TorpedoLauncher" then  --check if torpedo wpn
local strength = slowStrength[weaponDefID] --checks slow str and len values
local length = slowLength[weaponDefID]
if slow[unitID] then
if (slow[unitID].strength) and (slow[unitID].endFrame) then --if already slowed, newslow(%) = existingslow + Addedslow*(100-existingslow)/100 and newendFrame = oldendFrame + addedlength
if slow[unitID].endFrame >= Spring.GetGameFrame() then
slow[unitID].startFrame = Spring.GetGameFrame()
slow[unitID].strength = slow[unitID].strength + ((100-slow[unitID].strength)/100)*strength
if slow[unitID].strength >= 50 then slow[unitID].strength = 50 end
slow[unitID].endFrame = Spring.GetGameFrame() + length
end
end
else
slow[unitID] = {}
slow[unitID].startFrame = Spring.GetGameFrame()
slow[unitID].strength = strength
slow[unitID].endFrame = Spring.GetGameFrame() + length
end
-- Spring.Echo(slow[unitID].startFrame)
-- Spring.Echo(slow[unitID].strength)
-- Spring.Echo(slow[unitID].endFrame)
end
end
end
end

function gadget:GameFrame(f)
for key,value in pairs(slow) do --for all slowed units, adjust velocity and spawn a CEG (should be changed with a more specific one).
if Spring.ValidUnitID(key) == true then
if (slow[key].startFrame) and (slow[key].endFrame) then
if f >= slow[key].startFrame and f <= slow[key].endFrame then
x,y,z = Spring.GetUnitPosition(key)
Spring.SpawnCEG("ZEUS_FLASH",x + math.random(-30,30),y+ math.random(-5,5),z+ math.random(-30,30),0,1,0,30,0)
local vx,vy,vz,vw = Spring.GetUnitVelocity(key)
local unitDefID = Spring.GetUnitDefID(key)
local maxVel = UnitDefs[unitDefID].speed
local fslow = (100 - slow[key].strength)/100
local maxAllowedVel = fslow * maxVel / 30
if vw and maxAllowedVel and vw > maxAllowedVel then 
local factor = maxAllowedVel/vw
Spring.SetUnitVelocity(key, vx * factor, vy * factor, vz * factor)


end
end
if f > slow[key].endFrame then slow[key] = nil end --clean up if slow ended
end

end
if Spring.ValidUnitID(key) == false then slow[key] = nil end -- clean up if dead
end
end

function UnitDestroyed(unitID)
slow[unitID] = nil -- clean up on death frame in case previous Spring.ValidUnitID wasnt enuff.
end
end