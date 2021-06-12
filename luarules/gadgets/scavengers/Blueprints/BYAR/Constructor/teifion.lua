local UDN = UnitDefNames
local nameSuffix = '_scav'

local function TeifionT3Defences1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 96
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(56), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-8), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(8), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-56), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-24), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(24), posy, posz+(0), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences1)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences1)


local function TeifionT3Defences2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 64
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-64), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(64), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(64), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(0), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-64), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(64), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(0), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-64), posy, posz+(64), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences2)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences2)
    
    
local function TeifionT3Defences3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 104
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-6), posy, posz+(-104), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-30), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(42), posy, posz+(-56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-6), posy, posz+(-56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(42), posy, posz+(56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(42), posy, posz+(-104), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-54), posy, posz+(-56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-54), posy, posz+(56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(42), posy, posz+(104), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-6), posy, posz+(56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-6), posy, posz+(104), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences3)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences3)
    

local function TeifionT3Defences4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 144
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(36), posy, posz+(16), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(-28), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(-80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(16), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(-28), posy, posz+(-112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(-28), posy, posz+(112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-44), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(-112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(-16), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-44), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(36), posy, posz+(-16), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(4), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(36), posy, posz+(80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(-28), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(36), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(36), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(36), posy, posz+(-80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-44), posy, posz+(64), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences4)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences4)


local function TeifionT3Defences5(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 58
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-16), posy, posz+(18), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(8), posy, posz+(58), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-8), posy, posz+(-54), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(16), posy, posz+(18), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-16), posy, posz+(-14), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(16), posy, posz+(-14), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-56), posy, posz+(10), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(56), posy, posz+(-22), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences5)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences5)


local function TeifionT3Defences6(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 128
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(29), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-35), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-35), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(29), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-35), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-35), posy, posz+(-128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-35), posy, posz+(128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(93), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(29), posy, posz+(0), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences6)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences6)


local function TeifionT3Defences7(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 163
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-109), posy, posz+(-33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-125), posy, posz+(-129), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(19), posy, posz+(-129), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-109), posy, posz+(31), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(163), posy, posz+(-129), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-45), posy, posz+(-33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(179), posy, posz+(127), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(19), posy, posz+(-33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(19), posy, posz+(31), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armvulc_scav.id), {posx+(115), posy, posz+(15), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-109), posy, posz+(127), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(35), posy, posz+(127), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-45), posy, posz+(31), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences7)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences7)


local function TeifionT3Defences8(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 179
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-109), posy, posz+(-33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-125), posy, posz+(-129), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(19), posy, posz+(-129), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-109), posy, posz+(31), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(163), posy, posz+(-129), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-45), posy, posz+(-33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(179), posy, posz+(127), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(19), posy, posz+(-33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(19), posy, posz+(31), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armvulc_scav.id), {posx+(115), posy, posz+(15), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-109), posy, posz+(127), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(35), posy, posz+(127), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-45), posy, posz+(31), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences8)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences8)


local function TeifionT3Defences9(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 288
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(37), posy, posz+(288), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-43), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(37), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-43), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(37), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-43), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-43), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(37), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(37), posy, posz+(-288), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(37), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-43), posy, posz+(-240), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-43), posy, posz+(240), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(37), posy, posz+(-96), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences9)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences9)


local function TeifionT3Defences10(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 384
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-384), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-32), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(160), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-255), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(288), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-47), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-191), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-255), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-160), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(256), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(352), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-191), posy, posz+(-320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-288), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(32), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-47), posy, posz+(-320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-47), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(256), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(160), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-352), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-47), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-47), posy, posz+(320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(288), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(352), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-160), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(384), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-191), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-47), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-352), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-288), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-255), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(-256), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-32), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(33), posy, posz+(384), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-191), posy, posz+(320), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-191), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-384), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-191), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(-256), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(-255), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(BPWallOrPopup("scav")), {posx+(65), posy, posz+(32), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences10)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences10)


local function TeifionT3Defences11(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 162
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx+(56), posy, posz+(-46), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx+(56), posy, posz+(50), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-56), posy, posz+(130), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx+(-40), posy, posz+(50), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armvulc_scav.id), {posx+(40), posy, posz+(-158), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-56), posy, posz+(-142), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armvulc_scav.id), {posx+(40), posy, posz+(162), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx+(-40), posy, posz+(-46), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences11)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences11)


local function TeifionT3Defences13(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 89
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(70), posy, posz+(-7), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(22), posy, posz+(89), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(-50), posy, posz+(-31), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(-50), posy, posz+(33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(14), posy, posz+(33), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(14), posy, posz+(-31), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-18), posy, posz+(-79), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(22), posy, posz+(-87), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-18), posy, posz+(81), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences13)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences13)


local function TeifionT3Defences14(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 144
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-80), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-80), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(48), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corbuzz_scav.id), {posx+(96), posy, posz+(-160), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(48), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-16), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corbuzz_scav.id), {posx+(96), posy, posz+(160), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(-16), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-144), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-16), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-80), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(-16), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-16), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(128), posy, posz+(0), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences14)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences14)

local function TeifionT3Defences15(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 176
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(0), posy, posz+(176), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-176), posy, posz+(-176), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(176), posy, posz+(-176), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(176), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(0), posy, posz+(-176), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-176), posy, posz+(176), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(176), posy, posz+(176), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-176), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences15)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences15)


local function TeifionT4Defences16(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 144
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(56), posy, posz+(-56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(-56), posy, posz+(-56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(0), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-144), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(56), posy, posz+(56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(-56), posy, posz+(56), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(0), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(144), posy, posz+(0), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences16)


local function TeifionT3Defences17(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 327
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(5), posy, posz+(-65), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(69), posy, posz+(319), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(189), posy, posz+(327), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-91), posy, posz+(-193), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(53), posy, posz+(63), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-123), posy, posz+(-257), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(141), posy, posz+(199), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(61), posy, posz+(-57), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(-27), posy, posz+(-193), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(-75), posy, posz+(-321), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-203), posy, posz+(-321), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(53), posy, posz+(255), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-91), posy, posz+(-1), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-75), posy, posz+(-129), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(85), posy, posz+(191), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(5), posy, posz+(127), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(29), posy, posz+(-185), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(-19), posy, posz+(-313), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(21), posy, posz+(191), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-59), posy, posz+(-65), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(109), posy, posz+(71), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-139), posy, posz+(-321), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(5), posy, posz+(319), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-11), posy, posz+(63), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-27), posy, posz+(-1), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(133), posy, posz+(319), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences17)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences17)


local function TeifionT3Defences18(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 373
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-143), posy, posz+(156), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(359), posy, posz+(-181), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-218), posy, posz+(2), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(117), posy, posz+(-143), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-355), posy, posz+(151), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(285), posy, posz+(-5), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-97), posy, posz+(-135), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-294), posy, posz+(6), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(372), posy, posz+(-253), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(78), posy, posz+(291), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(338), posy, posz+(137), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(359), posy, posz+(299), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-145), posy, posz+(-280), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-162), posy, posz+(-141), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(72), posy, posz+(-281), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(287), posy, posz+(159), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-209), posy, posz+(296), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-73), posy, posz+(-281), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(73), posy, posz+(153), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-102), posy, posz+(21), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(352), posy, posz+(-289), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-219), posy, posz+(-287), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(133), posy, posz+(-14), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-281), posy, posz+(149), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-292), posy, posz+(-286), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(141), posy, posz+(-276), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-308), posy, posz+(-145), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(217), posy, posz+(162), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-213), posy, posz+(149), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(216), posy, posz+(301), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-333), posy, posz+(286), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-345), posy, posz+(221), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-138), posy, posz+(293), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-280), posy, posz+(300), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-74), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-236), posy, posz+(-147), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(51), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-1), posy, posz+(-282), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-367), posy, posz+(-63), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(4), posy, posz+(285), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(149), posy, posz+(294), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(339), posy, posz+(-142), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(64), posy, posz+(-6), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(273), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(335), posy, posz+(69), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(284), posy, posz+(300), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(286), posy, posz+(-283), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-74), posy, posz+(151), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(340), posy, posz+(9), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-373), posy, posz+(-138), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-66), posy, posz+(290), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(148), posy, posz+(155), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-26), posy, posz+(-138), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(190), posy, posz+(-139), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-362), posy, posz+(-282), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(5), posy, posz+(156), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(211), posy, posz+(-277), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(244), posy, posz+(-29), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-143), posy, posz+(-4), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx+(-363), posy, posz+(1), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences18)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences18)


local function TeifionT3Defences19(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 152
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-91), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(61), posy, posz+(152), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-91), posy, posz+(64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(-19), posy, posz+(72), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(61), posy, posz+(-152), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(61), posy, posz+(72), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(61), posy, posz+(-72), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(-19), posy, posz+(-72), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-91), posy, posz+(-64), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(-19), posy, posz+(-152), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(101), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(37), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(-27), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(-19), posy, posz+(152), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences19)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences19)


local function TeifionT3Defences20(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 416
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-260), posy, posz+(-208), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-196), posy, posz+(-208), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(220), posy, posz+(-208), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-260), posy, posz+(416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-196), posy, posz+(208), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-196), posy, posz+(-416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-260), posy, posz+(-416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(204), posy, posz+(416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(220), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-196), posy, posz+(416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(204), posy, posz+(208), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(220), posy, posz+(-416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-260), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(236), posy, posz+(416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(236), posy, posz+(208), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-196), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(252), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(252), posy, posz+(-208), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(252), posy, posz+(-416), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-260), posy, posz+(208), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences20)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences20)


local function TeifionT3Defences21(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 192
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(192), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(192), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(144), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(96), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(0), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(0), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(144), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-96), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-96), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-144), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-96), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(96), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-144), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(96), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-144), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-48), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-192), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-192), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(192), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-144), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(192), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(144), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-96), posy, posz+(192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(144), posy, posz+(-48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(48), posy, posz+(144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(0), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(48), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-192), posy, posz+(-192), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-96), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-192), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(96), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(192), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(0), posy, posz+(96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-48), posy, posz+(-144), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(96), posy, posz+(-96), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-192), posy, posz+(96), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences21)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences21)


local function TeifionT3Defences22(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 142
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.coraap_scav.id), {posx+(-50), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(14), posy, posz+(128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.coraap_scav.id), {posx+(142), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corasp_scav.id), {posx+(-122), posy, posz+(-136), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-34), posy, posz+(-80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.coraap_scav.id), {posx+(46), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-2), posy, posz+(-80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corasp_scav.id), {posx+(118), posy, posz+(136), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-2), posy, posz+(80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(30), posy, posz+(80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.coraap_scav.id), {posx+(-146), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(14), posy, posz+(-128), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-34), posy, posz+(80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(30), posy, posz+(-80), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corasp_scav.id), {posx+(118), posy, posz+(-136), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corasp_scav.id), {posx+(-122), posy, posz+(136), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences22)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences22)


local function TeifionT4Defences23(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 240
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.corgant_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(-96), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(-24), posy, posz+(-120), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgant_scav.id), {posx+(32), posy, posz+(-240), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corgant_scav.id), {posx+(32), posy, posz+(240), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(72), posy, posz+(120), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(-96), posy, posz+(224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(72), posy, posz+(-120), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(-24), posy, posz+(120), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences23)


local function TeifionT3Defences24(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 224
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-224), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(224), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(112), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(224), posy, posz+(112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(0), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(0), posy, posz+(112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-224), posy, posz+(112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-112), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(0), posy, posz+(224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(112), posy, posz+(224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-224), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-224), posy, posz+(-112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(224), posy, posz+(-224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(0), posy, posz+(-112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(224), posy, posz+(-112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(112), posy, posz+(112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(224), posy, posz+(224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-112), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-112), posy, posz+(112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-224), posy, posz+(224), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(112), posy, posz+(-112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(112), posy, posz+(0), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-112), posy, posz+(-112), 1}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-112), posy, posz+(224), 1}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,TeifionT3Defences24)
table.insert(ScavengerConstructorBlueprintsT4,TeifionT3Defences24)
