--special unit variations used in EvoCom
local unitsTable = {}
--Legion Lobber, for Legion Commander Botcannon
unitsTable['babyleglob'] = VFS.Include('units/Legion/Bots/leglob.lua').leglob --if this filepath is changed, the unit will no longer work!
unitsTable['babyleglob'].corpse = ""
unitsTable['babyleglob'].selfdestructas = ""
unitsTable['babyleglob'].mass = 150
unitsTable['babyleglob'].metalcost = 0
unitsTable['babyleglob'].movestate = 2
unitsTable['babyleglob'].power = 66
unitsTable['babyleglob'].customparams.i18nfromunit = 'leglob'

--Legion Goblin, for Legion Commander Botcannon
unitsTable['babyleggob'] = VFS.Include('units/Legion/Bots/leggob.lua').leggob --if this filepath is changed, the unit will no longer work!
unitsTable['babyleggob'].corpse = ""
unitsTable['babyleggob'].selfdestructas = ""
unitsTable['babyleggob'].mass = 25
unitsTable['babyleggob'].metalcost = 0
unitsTable['babyleggob'].movestate = 2
unitsTable['babyleggob'].power = 33
unitsTable['babyleggob'].customparams.i18nfromunit = 'leggob'

--Legion Phalanx, for Legion Commander Botcannon
unitsTable['babylegshot'] = VFS.Include('units/Legion/Bots/T2 Bots/legshot.lua').legshot --if this filepath is changed, the unit will no longer work!
unitsTable['babylegshot'].corpse = ""
unitsTable['babylegshot'].selfdestructas = ""
unitsTable['babylegshot'].metalcost = 0
unitsTable['babylegshot'].mass = 630
unitsTable['babylegshot'].movestate = 2
unitsTable['babylegshot'].power = 735
unitsTable['babylegshot'].customparams.i18nfromunit = 'legshot'

--Legion Heavy Drone, for Legion Commander Botcannon
unitsTable['babylegheavydrone'] = VFS.Include('units/Legion/Air/T2 Air/legheavydrone.lua').legheavydrone --if this filepath is changed, the unit will no longer work!
unitsTable['babylegheavydrone'].corpse = ""
unitsTable['babylegheavydrone'].selfdestructas = ""
unitsTable['babylegheavydrone'].metalcost = 0
unitsTable['babylegheavydrone'].movestate = 2
unitsTable['babylegheavydrone'].power = 1000
unitsTable['babylegheavydrone'].customparams.i18nfromunit = 'legheavydrone'

--Legion Drone, for Legion Commander Botcannon
unitsTable['babylegdrone'] = VFS.Include('units/Legion/Air/legdrone.lua').legdrone --if this filepath is changed, the unit will no longer work!
unitsTable['babylegdrone'].corpse = ""
unitsTable['babylegdrone'].selfdestructas = ""
unitsTable['babylegdrone'].metalcost = 0
unitsTable['babylegdrone'].movestate = 2
unitsTable['babylegdrone'].power = 500
unitsTable['babylegdrone'].customparams.i18nfromunit = 'legdrone'

return unitsTable
