function gadget:GetInfo()
	return {
		name = "Single-Hit Weapon",
		desc = "Forces marked weapons to only inflict damage once per projectile per unit",
		author = "Anarchid, mauled by Hornet",
		date = "25.03.2013",
		license = "Public domain",
		layer = 21,
		enabled = true
	}
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetGameFrame = Spring.GetGameFrame

local wantedWeaponList = {}

local singleHitWeapon = {}
local singleHitUnitId = {}

local singleHitMultiWeapon = {}
local singleHitProjectile = {}

function gadget:Initialize()
	for wdid = 1, #WeaponDefs do
		local wd = WeaponDefs[wdid]
		if wd.customParams then
			if wd.customParams.single_hit then
				Spring.Echo('hornet debug')
				Spring.Echo(wd.name)
				singleHitWeapon[wd.id] = true;
				wantedWeaponList[#wantedWeaponList + 1] = wdid
			end
			if wd.customParams.single_hit_multi then
				singleHitMultiWeapon[wd.id] = true;
				wantedWeaponList[#wantedWeaponList + 1] = wdid
				Script.SetWatchProjectile(wd.id, true)
			end
		end
	end
	Spring.Debug.TableEcho(wantedWeaponList)
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponID)
	if singleHitMultiWeapon[weaponID] then
		singleHitProjectile[proID] = {}
	end
end

function gadget:ProjectileDestroyed(proID)
	if singleHitMultiWeapon[proID] then
		singleHitProjectile[proID] = nil
	end
end

function gadget:UnitPreDamaged_GetWantedWeaponDef()
	return wantedWeaponList
end

function gadget:UnitPreDamaged(unitID,unitDefID,_, damage,_, weaponDefID,attackerID,_,_, projectileID)
	if singleHitWeapon[weaponDefID] then
		if attackerID then
			local frame = spGetGameFrame()
			if singleHitUnitId[attackerID] == nil then
				singleHitUnitId[attackerID] = {}
				singleHitUnitId[attackerID][unitID] = frame
			else
				if singleHitUnitId[attackerID][unitID] and frame - singleHitUnitId[attackerID][unitID] < 10 then
					singleHitUnitId[attackerID][unitID] = frame
					return 0
				else
					singleHitUnitId[attackerID][unitID] = frame
				end
			end
			return damage
		end
	end
	
	if singleHitMultiWeapon[weaponDefID] then
		if not singleHitProjectile[projectileID] then
			singleHitProjectile[projectileID] = {}
		end
		if singleHitProjectile[projectileID][unitID] then
			return 0
		else
			singleHitProjectile[projectileID][unitID] = true
		end
		return damage
	end
	return damage;
end
