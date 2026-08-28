When(MatchFlow.Started()).After(30).Do(Scavengers.Skirmish.Begin().Against(Team.Player).From(0.85, 0.15).Intensity(0.3))
