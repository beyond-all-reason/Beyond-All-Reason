function gadget:GetInfo()
   return {
      name         = "ARMCRUS_FrontWeapon_Fix",
      desc         = "Copies velocity value from proj #1 to proj #2 for parralel shots",
      author       = "Doo",
      date         = "05/03/2017",
      license      = "GPL 2.0 or later", -- should be compatible with Spring
      layer        = 0,
      enabled      = true
   }
end

if (gadgetHandler:IsSyncedCode()) then
testedweaponname = "armcrus_heavyplasmacannon_front"
ProOwner = {}
function gadget:Initialize()
for wname, wdef in pairs(WeaponDefNames) do
	if wname == testedweaponname then testedweaponID = wdef.id end
end
end

function gadget:ProjectileCreated(proID, proOwner, weaponDefID)

if (Spring.GetProjectileDefID(proID)) and (testedweaponID) then
if Spring.GetProjectileDefID(proID) == testedweaponID then
if ProOwner[proOwner] then
if ProOwner[proOwner]["f"] then
	if ProOwner[proOwner]["f"] >= Spring.GetGameFrame() + 4 then
	ProOwner[proOwner] = nil
	end
end
end

if not (ProOwner[proOwner]) then
ProOwner[proOwner] = {}
ProOwner[proOwner]["n"] = 1
-- Spring.Echo("table created")
end

ProOwner[proOwner]["f"] = Spring.GetGameFrame()

if ProOwner[proOwner]["n"] == 1 then
ProOwner[proOwner]["vx"], ProOwner[proOwner]["vy"], ProOwner[proOwner]["vz"] = Spring.GetProjectileVelocity(proID)
-- Spring.Echo("1")
end

if ProOwner[proOwner]["n"] == 2 then
Spring.SetProjectileVelocity(proID, ProOwner[proOwner]["vx"], ProOwner[proOwner]["vy"], ProOwner[proOwner]["vz"])
-- Spring.Echo("2")
end

ProOwner[proOwner]["n"] = ProOwner[proOwner]["n"] + 1

if ProOwner[proOwner]["n"] == 3 then
ProOwner[proOwner]["n"] = 1
-- Spring.Echo("3 = 1")
end



f1 = Spring.GetGameFrame()
-- Spring.Echo("Projectile ("..proID..") created at frame "..f1)
end
end
end


end