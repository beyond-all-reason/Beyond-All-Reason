local function legionSimplifiedMexes(name, uDef)
	if name == "legmex" then
		uDef.energyupkeep = 3
		uDef.extractsmetal = 0.001
	end
	if name == "leggob" then
		uDef.metalcost = 30
		uDef.energycost = 420
	end
	if name == "leglob" then
		uDef.energycost = 600
	end
	if name == "legwin" then
		uDef.metalcost = 43
	end
	if name == "legsolar" then
		uDef.metalcost = 150
	end
end

return {
	Tweaks = legionSimplifiedMexes,
}
