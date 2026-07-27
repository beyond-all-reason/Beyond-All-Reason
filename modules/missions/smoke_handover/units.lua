-- Fixture for the handover machinery's headless test: a two-building derelict
-- on Gaia, inert until seen, handed over by fiat when the hub is spotted.
Spawn(UnitDef("corlab"), "gaia").At(0.42, 0.42).Named("hub").Grouped("base").Neutral()
Spawn(UnitDef("corllt"), "gaia").At(0.44, 0.42).Grouped("base").Neutral()
