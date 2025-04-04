local function proposed_unit_reworksTweaks(name, uDef)

		if name == "armpw" then
			uDef.metalcost = 60
		end
		if name == "corak" then
			uDef.metalcost = 45
			uDef.weapondefs.gator_laser.range = 220
		end


	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
