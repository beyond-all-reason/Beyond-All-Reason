-- UnitDefs has no yardmap field; unitdefs_post exports it as customparams.buildsquare_yardmap.
-- The engine only honours a yardmap on buildings and is moving to reject one on anything mobile (beyond-all-reason/RecoilEngine#1597).
local function test()
	local offenders = {}
	for _, unitDef in pairs(UnitDefs) do
		if not unitDef.isImmobile and unitDef.customParams.buildsquare_yardmap then
			offenders[#offenders + 1] = unitDef.name
		end
	end
	table.sort(offenders)

	assertEqual(#offenders, 0, "mobile unit defs with a yardmap: " .. table.concat(offenders, ", "))
end

return { test = test }
