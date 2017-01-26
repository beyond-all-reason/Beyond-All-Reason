--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function gadget:GetInfo()
	return {
		name = "Projectile Lups",
		desc = "Attaches Lups FX to projectiles",
		author = "KingRaptor (L.J. Lim)",
		date = "2013-06-28",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = false
	}
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local weapons = include("LuaRules/Configs/lups_projectile_fxs.lua")	--{}

--[[
for i=1,#WeaponDefs do
	local wd = WeaponDefs[i]
	if wd.customParams and wd.customParams.projectilelups then
		local data
		local func, err = loadstring("return" .. (ud.customParams.projectilelups or ""))
		if func then
			data = func()
		elseif err then
			Spring.Log(gadget:GetInfo().name, LOG.WARNING, "malformed projectile Lups definition for weapon " .. wd.name .. "\n" .. err  )
		end
		if data then
			Script.SetWatchWeapon(i, true)
			weapons[i] = data
		end
	end
end
]]
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then

--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------
local projectiles = {}

function gadget:ProjectileCreated(proID, proOwnerID, weaponID)
	if weapons[weaponID] then
		projectiles[proID] = true;
		SendToUnsynced("lupsProjectiles_AddProjectile", proID, proOwnerID, weaponID)
	end
end	

function gadget:ProjectileDestroyed(proID)
	if projectiles[proID] then
		SendToUnsynced("lupsProjectiles_RemoveProjectile", proID)
		projectiles[proID] = nil
	end
end

function gadget:Initialize()
	for weaponID in pairs(weapons) do
		Script.SetWatchWeapon(weaponID, true)
	end
end

function gadget:Shutdown()
for weaponID in pairs(weapons) do
		Script.SetWatchWeapon(weaponID, false)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
else
--------------------------------------------------------------------------------
-- unsynced
--------------------------------------------------------------------------------

local Lups
local LupsAddParticles 
local SYNCED = SYNCED

local projectiles = {}

local function AddProjectile(_, proID, proOwnerID, weaponID)
  if (not Lups) then Lups = GG['Lups']; LupsAddParticles = Lups.AddParticles end
  projectiles[proID] = {}
  local def = weapons[weaponID]
  for i=1,#def do
    local fxTable = projectiles[proID]
    local fx = def[i]
    local options = Spring.Utilities.CopyTable(fx.options)
    --options.unit = proOwnerID
    options.projectile = proID
    options.weapon = weaponID
    --options.worldspace = true
    local fxID = LupsAddParticles(fx.class, options)
    if fxID ~= -1 then
      fxTable[#fxTable+1] = fxID
    end
  end
end

local function RemoveProjectile(_, proID)
  if projectiles[proID] then
    for i=1,#projectiles[proID] do
      local fxID = projectiles[proID][i]
      local fx = Lups.GetParticles(fxID)
      if fx.persistAfterDeath then
	fx.isvalid = nil
      else
	Lups.RemoveParticles(fxID)
      end
    end
    projectiles[proID] = nil
  end
end



function gadget:Initialize()
  gadgetHandler:AddSyncAction("lupsProjectiles_AddProjectile", AddProjectile)
  gadgetHandler:AddSyncAction("lupsProjectiles_RemoveProjectile", RemoveProjectile)
end


function gadget:Shutdown()
  gadgetHandler:RemoveSyncAction("lupsProjectiles_AddProjectile")
  gadgetHandler:RemoveSyncAction("lupsProjectiles_RemoveProjectile")
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
