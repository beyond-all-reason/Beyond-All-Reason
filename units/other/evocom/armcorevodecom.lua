local unitsTable = {}

for i = 2, 10 do
	unitsTable["armdecomlvl" .. i] = VFS.Include("units/other/evocom/armcomlvl" .. i .. ".lua")["armcomlvl" .. i] --if this filepath is changed, the unit will no longer work!
	unitsTable["armdecomlvl" .. i].selfdestructas = "decoycommander"
	unitsTable["armdecomlvl" .. i].explodeas = "decoycommander"
	unitsTable["armdecomlvl" .. i].corpse = nil
	unitsTable["armdecomlvl" .. i].customparams.evolution_target = nil
	unitsTable["armdecomlvl" .. i].customparams.iscommander = nil
	unitsTable["armdecomlvl" .. i].customparams.effigy = nil
	unitsTable["armdecomlvl" .. i].customparams.i18nfromunit = "armcomlvl" .. i
	unitsTable["armdecomlvl" .. i].decoyfor = "armcomlvl" .. i
	unitsTable["armdecomlvl" .. i].customparams.decoyfor = "armcomlvl" .. i
	unitsTable["armdecomlvl" .. i].customparams.isdecoycommander = true
	unitsTable["armdecomlvl" .. i].health = math.ceil(unitsTable["armdecomlvl" .. i].health * 0.5)
	unitsTable["armdecomlvl" .. i].weapondefs.disintegrator.damage.default = 40
	if unitsTable["armdecomlvl" .. i].weapondefs.backlauncher and unitsTable["armdecomlvl" .. i].weapondefs.backlauncher.customparams.stockpilelimit then
		unitsTable["armdecomlvl" .. i].weapondefs.backlauncher.customparams.stockpilelimit = math.ceil(unitsTable["armdecomlvl" .. i].weapondefs.backlauncher.customparams.stockpilelimit * 0.4)
	end

	unitsTable["cordecomlvl" .. i] = VFS.Include("units/other/evocom/corcomlvl" .. i .. ".lua")["corcomlvl" .. i] --if this filepath is changed, the unit will no longer work!
	unitsTable["cordecomlvl" .. i].selfdestructas = "decoycommander"
	unitsTable["cordecomlvl" .. i].explodeas = "decoycommander"
	unitsTable["cordecomlvl" .. i].corpse = nil
	unitsTable["cordecomlvl" .. i].customparams.evolution_target = nil
	unitsTable["cordecomlvl" .. i].customparams.iscommander = nil
	unitsTable["cordecomlvl" .. i].customparams.effigy = nil
	unitsTable["cordecomlvl" .. i].customparams.i18nfromunit = "corcomlvl" .. i
	unitsTable["cordecomlvl" .. i].decoyfor = "corcomlvl" .. i
	unitsTable["cordecomlvl" .. i].customparams.decoyfor = "corcomlvl" .. i
	unitsTable["cordecomlvl" .. i].customparams.isdecoycommander = true
	unitsTable["cordecomlvl" .. i].health = math.ceil(unitsTable["cordecomlvl" .. i].health * 0.5)
	unitsTable["cordecomlvl" .. i].weapondefs.disintegrator.damage.default = 40
	if unitsTable["cordecomlvl" .. i].weapondefs.repulsor and unitsTable["cordecomlvl" .. i].weapondefs.repulsor.shield.power then
		unitsTable["cordecomlvl" .. i].weapondefs.repulsor.shield.power = unitsTable["cordecomlvl" .. i].weapondefs.repulsor.shield.power * 0.2
	end
end

return unitsTable
