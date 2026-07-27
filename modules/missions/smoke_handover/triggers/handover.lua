When(MatchFlow.Started()).When(Unit("hub").IsSpotted(Team.Player)).Do(Transfer.Give("base", Team.Player))
