-- $Id: lups_napalm.lua 3171 2008-11-06 09:06:29Z det $

function gadget:GetInfo()
  return {
    name      = "Napalm",
    desc      = "",
    author    = "jK",
    date      = "Sep. 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false,
  }
end


if (gadgetHandler:IsSyncedCode()) then

  local napalmWeapons = {}
  local wantedList = {}

  --// find napalms
  for i=1,#WeaponDefs do
    local wd = WeaponDefs[i]
    if (wd.description:find("Napalm") or (wd.customParams and (wd.customParams.lups_napalm_fx or wd.customParams.lups_heat_fx))) then
      Script.SetWatchWeapon(wd.id,true)
      napalmWeapons[wd.id] = true
      wantedList[#wantedList + 1] = wd.id
    end
  end

  local napalmExplosions  = {}

  --// Speed-ups
  local SendToUnsynced = SendToUnsynced

  function gadget:Explosion_GetWantedWeaponDef()
	return wantedList
  end
  
  function gadget:Explosion(weaponID, px, py, pz)
    if (napalmWeapons[weaponID]) then
      napalmExplosions[#napalmExplosions+1] = {weaponID, px, py, pz}
    end
    return false
  end

  function gadget:GameFrame(n)
    if (#napalmExplosions>0) then
      _G.napalmExplosions =  napalmExplosions
      _G.napalmCount      = #napalmExplosions
      SendToUnsynced("napalm_GameFrame")
      napalmExplosions = {}
    end
  end

else

  local napalmFX, heatFX = include("LuaRules/Configs/lups_napalm_fxs.lua")

  local Lups
  local LupsAddParticles 
  local SYNCED = SYNCED

  local function SpawnNapalmFX(data)
	local nFXkey = WeaponDefs[data[1]].customParams and WeaponDefs[data[1]].customParams.lups_napalm_fx or "default"
	local hFXkey = WeaponDefs[data[1]].customParams and WeaponDefs[data[1]].customParams.lups_heat_fx or "default"
	
	local nFX = napalmFX[nFXkey]
	local hFX = heatFX[hFXkey]
	
    nFX.pos = {data[2],data[3],data[4]}
    Lups.AddParticles('SimpleParticles2',nFX)
    hFX.pos = nFX.pos
    Lups.AddParticles('JitterParticles2',hFX)
  end

  local function GameFrame()
    if (not Lups) then Lups = GG['Lups']; LupsAddParticles = Lups.AddParticles end
    local explosions = SYNCED.napalmExplosions
    local napalmCount = SYNCED.napalmCount
    for i=1,napalmCount do
      SpawnNapalmFX(explosions[i])
    end
  end


  function gadget:Initialize()
    gl.DeleteTexture(napalmFX.texture)
    gadgetHandler:AddSyncAction("napalm_GameFrame", GameFrame)
  end


  function gadget:Shutdown()
    gadgetHandler.RemoveSyncAction("napalm_GameFrame")
  end

end