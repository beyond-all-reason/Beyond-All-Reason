local function junoReworkTweaks(name, unitDef)
	if name == "armjuno" or name == "corjuno" then
		unitDef.metalcost = 500
		unitDef.energycost = 12000
		unitDef.buildtime = 15000
		unitDef.weapondefs.juno_pulse.energypershot = 7000
		unitDef.weapondefs.juno_pulse.metalpershot = 100
	end
end

return {
	Tweaks = junoReworkTweaks,
}
