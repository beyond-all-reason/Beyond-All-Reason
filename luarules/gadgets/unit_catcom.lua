local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Cat Commander",
		desc = "Makes the commander D-Guns meow, for the Cat Commander setting and lobby option",
		author = "MaxUint",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[
Cat Commander: commanders and decoy commanders with cat ears, black thigh-highs and a meowing D-Gun.
Cosmetic only, off by default, two independent switches:

1. Private setting, Settings > Game > Cat Commander (advanced; config CatCommander, read at game start).
   Only on that player's screen: their own commanders are cats and their D-Guns meow.
   Other players see and hear normal commanders, also when they turn the setting on for themselves.
   - gamedata/alldefs_post.lua: adds a featuredef that is never spawned, only to load the cat model, and names it in
     customparams.catcom_featuredef of the commanders.
   - luarules/gadgets/cus_gl4.lua: draws the player's own commanders with that model.
   - this gadget: plays the meow for the player's own commanders.
2. Hidden lobby option catcom (modoptions.lua). Every commander is a cat for all players in that match:
   alldefs_post.lua changes their model, and this gadget plays the meow for every commander.
   The lobby doesn't list it. In an autohost battle the host turns it on with !bset catcom 1 before the start.

The meow plays along with the normal D-Gun sounds. alldefs_post.lua names it in customparams.catcom_meow of the
commander D-Gun weapons.

Assets: objects3d/Units/{armcom,corcom,legcom}_cat.s3o are the stock models plus two shallow ears with a dark inner
ear, and with the legs mapped onto black texels of the stock textures. sounds/weapons/meow_{armcom,corcom,legcom}.wav
is one meow, higher for Armada and lower for Cortex, see license_sounds.txt.
Not covered: higher level commanders of the evolving commanders option. During the holiday events the private
setting only makes the D-Gun meow, because the holiday models have other pieces than the cat models.
]]

local meows = {} -- weaponDefID -> meow sound
for weaponDefID, weaponDef in pairs(WeaponDefs) do
	meows[weaponDefID] = weaponDef.customParams.catcom_meow
end

if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		for weaponDefID in pairs(meows) do
			Script.SetWatchProjectile(weaponDefID, true)
		end
	end

	function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
		if meows[weaponDefID] and ownerID then
			SendToUnsynced("catcomDGunFired", ownerID, weaponDefID)
		end
	end

	return
end

local forEveryone = Spring.GetModOptions().catcom
local settingOn = Spring.GetConfigInt("CatCommander", 0) == 1

-- like the engine plays the D-Gun sound: at the unit and moving with it, at that sound's volume, on the battle channel
local function dgunFired(_, unitID, weaponDefID)
	local mine = settingOn and not Spring.GetSpectatingState() and Spring.GetUnitTeam(unitID) == Spring.GetMyTeamID()
	local x, y, z = Spring.GetUnitPosition(unitID)
	if x and (forEveryone or mine) then
		local vx, vy, vz = Spring.GetUnitVelocity(unitID)
		local volume = WeaponDefs[weaponDefID].fireSound[1].volume
		Spring.PlaySoundFile(meows[weaponDefID], volume, x, y, z, vx, vy, vz, "battle")
	end
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("catcomDGunFired", dgunFired)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("catcomDGunFired")
end
