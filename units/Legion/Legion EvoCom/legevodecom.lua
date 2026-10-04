local unitsTable = {}

for i = 2, 10 do
    unitsTable['legdecomlvl' .. i] = VFS.Include('units/Legion/Legion EvoCom/legcomlvl' .. i .. '.lua')['legcomlvl' .. i] --if this filepath is changed, the unit will no longer work!
    unitsTable['legdecomlvl' .. i].selfdestructas = "decoycommander"
    unitsTable['legdecomlvl' .. i].explodeas = "decoycommander"
    unitsTable['legdecomlvl' .. i].corpse = nil
    unitsTable['legdecomlvl' .. i].customparams.evolution_target = nil
    unitsTable['legdecomlvl' .. i].customparams.iscommander = nil
    unitsTable['legdecomlvl' .. i].customparams.effigy = nil
    unitsTable['legdecomlvl' .. i].customparams.i18nfromunit = "legcomlvl" .. i
    unitsTable['legdecomlvl' .. i].customparams.isdecoycommander = true
    unitsTable['legdecomlvl' .. i].decoyfor = "legcomlvl" .. i
    unitsTable['legdecomlvl' .. i].customparams.decoyfor = "legcomlvl" .. i
    unitsTable['legdecomlvl' .. i].health = math.ceil(unitsTable['legdecomlvl' .. i].health*0.5)
    unitsTable['legdecomlvl' .. i].weapondefs.disintegrator.damage.default = 40
    if unitsTable['legdecomlvl' .. i].weapondefs.botcannon and unitsTable['legdecomlvl' .. i].weapondefs.botcannon.customparams.stockpilelimit then
        unitsTable['legdecomlvl' .. i].weapondefs.botcannon.customparams.stockpilelimit = math.ceil(unitsTable['legdecomlvl' .. i].weapondefs.botcannon.customparams.stockpilelimit*0.4)
    end
end

return unitsTable
