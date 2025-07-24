local unitsTable = {}

unitsTable['legdecomlvl3'] = VFS.Include('units/Legion/Legion EvoCom/legcomlvl3.lua').legcomlvl3 --if this filepath is changed, the unit will no longer work!
unitsTable['legdecomlvl3'].selfdestructas = "decoycommander"
unitsTable['legdecomlvl3'].explodeas = "decoycommander"
unitsTable['legdecomlvl3'].corpse = nil
unitsTable['legdecomlvl3'].customparams.evolution_target = nil
unitsTable['legdecomlvl3'].customparams.iscommander = nil
unitsTable['legdecomlvl3'].customparams.effigy = nil
unitsTable['legdecomlvl3'].customparams.i18nfromunit = "legcomlvl3"
unitsTable['legdecomlvl3'].customparams.isdecoycommander = true
unitsTable['legdecomlvl3'].decoyfor = "legcomlvl3"
unitsTable['legdecomlvl3'].customparams.decoyfor = "legcomlvl3"
unitsTable['legdecomlvl3'].health = math.ceil(unitsTable['legdecomlvl3'].health*0.5)
unitsTable['legdecomlvl3'].weapondefs.disintegrator.damage.default = 40
unitsTable['legdecomlvl3'].weapondefs.botcannon.customparams.stockpilelimit = 1

unitsTable['legdecomlvl6'] = VFS.Include('units/Legion/Legion EvoCom/legcomlvl6.lua').legcomlvl6 --if this filepath is changed, the unit will no longer work!
unitsTable['legdecomlvl6'].selfdestructas = "decoycommander"
unitsTable['legdecomlvl6'].explodeas = "decoycommander"
unitsTable['legdecomlvl6'].corpse = nil
unitsTable['legdecomlvl6'].customparams.evolution_target = nil
unitsTable['legdecomlvl6'].customparams.iscommander = nil
unitsTable['legdecomlvl6'].customparams.effigy = nil
unitsTable['legdecomlvl6'].customparams.i18nfromunit = "legcomlvl6"
unitsTable['legdecomlvl6'].decoyfor = "legcomlvl6"
unitsTable['legdecomlvl6'].customparams.decoyfor = "legcomlvl6"
unitsTable['legdecomlvl6'].customparams.isdecoycommander = true
unitsTable['legdecomlvl6'].health = math.ceil(unitsTable['legdecomlvl6'].health*0.5)
unitsTable['legdecomlvl6'].weapondefs.disintegrator.damage.default = 40
unitsTable['legdecomlvl6'].weapondefs.botcannon.customparams.stockpilelimit = 2

unitsTable['legdecomlvl10'] = VFS.Include('units/Legion/Legion EvoCom/legcomlvl10.lua').legcomlvl10 --if this filepath is changed, the unit will no longer work!
unitsTable['legdecomlvl10'].selfdestructas = "decoycommander"
unitsTable['legdecomlvl10'].explodeas = "decoycommander"
unitsTable['legdecomlvl10'].corpse = nil
unitsTable['legdecomlvl10'].customparams.evolution_target = nil
unitsTable['legdecomlvl10'].customparams.iscommander = nil
unitsTable['legdecomlvl10'].customparams.effigy = nil
unitsTable['legdecomlvl10'].customparams.i18nfromunit = "legcomlvl10"
unitsTable['legdecomlvl10'].decoyfor = "legcomlvl10"
unitsTable['legdecomlvl10'].customparams.decoyfor = "legcomlvl10"
unitsTable['legdecomlvl10'].customparams.isdecoycommander = true
unitsTable['legdecomlvl10'].health = math.ceil(unitsTable['legdecomlvl10'].health*0.5)
unitsTable['legdecomlvl10'].weapondefs.disintegrator.damage.default = 40
unitsTable['legdecomlvl10'].weapondefs.botcannon.customparams.stockpilelimit = 3

return unitsTable
