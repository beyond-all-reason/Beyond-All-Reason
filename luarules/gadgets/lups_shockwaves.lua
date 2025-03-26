local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Shockwaves",
		desc      = "",
		author    = "jK",
		date      = "Jan. 2008",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if (gadgetHandler:IsSyncedCode()) then
	-----------------------------------
	-- Synced
	-----------------------------------

	local hasShockwave = {} -- other gadgets can do Script.SetWatchWeapon and it is a global setting
	local wantedList = {}

	--// find weapons which cause a shockwave
	for i=1,#WeaponDefs do
		local wd = WeaponDefs[i]
		local customParams = wd.customParams or {}

		if (not customParams.lups_noshockwave) then
			local speed = 1
			local life = 1
			local normalShockwave = (wd.damageAreaOfEffect>62 and not wd.paralyzer and not customParams.disarmdamageonly)

			if customParams.lups_explodespeed then
				speed = wd.customParams.lups_explodespeed
				normalShockwave = true
			end

			if customParams.lups_explodelife then
				life = wd.customParams.lups_explodelife
				normalShockwave = true
			end

			if normalShockwave then
				hasShockwave[wd.id] = {
					life = 8*life,
					speed = speed,
					growth = wd.damageAreaOfEffect/11*speed
				}
				Script.SetWatchExplosion(wd.id,true)
				wantedList[#wantedList + 1] = wd.id
			elseif (wd.type == "DGun") then
				hasShockwave[wd.id] = {DGun = true}
				Script.SetWatchExplosion(wd.id,true)
				wantedList[#wantedList + 1] = wd.id
			end
		end
	end

	function gadget:Explosion_GetWantedWeaponDef()
		return wantedList
	end

	function gadget:Explosion(weaponID, px, py, pz, ownerID)
		local shockwave = hasShockwave[weaponID]
			if shockwave then
				if shockwave.DGun then
					SendToUnsynced("lups_shockwave", px, py, pz, 5, 7.5, 0.11, true)
				elseif shockwave.special == 1 then
					SendToUnsynced("lups_shockwave", px, py, pz, 5, 25, 0.1, true)
				else
					SendToUnsynced("lups_shockwave", px, py, pz, shockwave.growth, shockwave.life)
				end
			end
		return false
	end

else
	-----------------------------------
	-- Unsynced
	-----------------------------------

	local function SpawnShockwave(_,px,py,pz, growth, life, strength, desintergrator)
		local Lups = GG['Lups']

		if (desintergrator) then
			Lups.AddParticles('SphereDistortion',{pos={px,py,pz}, life=life, strength=strength, growth=growth})
		else
			Lups.AddParticles('ShockWave',{pos={px,py,pz}, growth=growth, life=life})
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("lups_shockwave", SpawnShockwave)
	end

	function gadget:Shutdown()
		gadgetHandler.RemoveSyncAction("lups_shockwave")
	end

end