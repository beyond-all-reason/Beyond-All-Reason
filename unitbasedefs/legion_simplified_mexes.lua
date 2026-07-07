local function legionSimplifiedMexes(name, uDef)
	if name == "legmex" then
		uDef.energyupkeep = 3
		uDef.extractsmetal = 0.001
	end
	if name == "legck" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1)
		uDef.energycost = math.ceil(uDef.energycost * 0.8)
	end
	if name == "leggob" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.25)
		uDef.energycost = math.ceil(uDef.energycost * 0.7)
	end
	if name == "leglob" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1)
		uDef.energycost = math.ceil(uDef.energycost * 0.8)
	end
	if name == "legaabot" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1)
		uDef.energycost = math.ceil(uDef.energycost * 0.8)
	end
	if name == "legcen" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.9)
		uDef.energycost = math.ceil(uDef.energycost * 1.1)
	end
	if name == "legkark" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.9)
		uDef.energycost = math.ceil(uDef.energycost * 1.3)
	end
	if name == "legbal" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.9)
		uDef.energycost = math.ceil(uDef.energycost * 1.2)
	end
	if name == "legcv" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1)
		uDef.energycost = math.ceil(uDef.energycost * 0.8)
	end
	if name == "leghades" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.2)
		uDef.energycost = math.ceil(uDef.energycost * 0.6)
	end
	if name == "leghelios" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1)
		uDef.energycost = math.ceil(uDef.energycost * 0.8)
	end
	if name == "legbar" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.9)
		uDef.energycost = math.ceil(uDef.energycost * 1.3)
	end
	if name == "legrail" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.95)
		uDef.energycost = math.ceil(uDef.energycost * 1.05)
	end
	if name == "leggat" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.9)
		uDef.energycost = math.ceil(uDef.energycost * 1.3)
	end
	if name == "legnavyscout" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.15)
		uDef.energycost = math.ceil(uDef.energycost * 0.7)
	end
	if name == "legnavyaaship" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.15)
		uDef.energycost = math.ceil(uDef.energycost * 0.7)
	end
	if name == "legnavysub" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.05)
		uDef.energycost = math.ceil(uDef.energycost * 0.9)
	end
	if name == "legnavysub" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.05)
		uDef.energycost = math.ceil(uDef.energycost * 0.9)
	end
	if name == "legnavyfrigate" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.2)
		uDef.energycost = math.ceil(uDef.energycost * 0.6)
	end
	if name == "legnavyconship" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1)
		uDef.energycost = math.ceil(uDef.energycost * 0.8)
	end
	if name == "legnavydestro" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.95)
		uDef.energycost = math.ceil(uDef.energycost * 1.1)
	end
	if name == "legnavyartyship" then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.95)
		uDef.energycost = math.ceil(uDef.energycost * 1.1)
	end
end

return {
	Tweaks = legionSimplifiedMexes,
}
