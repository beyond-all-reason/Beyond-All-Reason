When(Team.Player.Has(UnitDef("armpw"), 3))
	.Do(Objective("build_pawns").Complete())
	.Register()

When(Objective("build_pawns").IsComplete())
	.Do(MatchFlow.Victory(Team.Player))
	.Register()
