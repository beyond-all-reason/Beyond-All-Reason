pelvis = piece 'pelvis'
	aimy1 = piece 'aimy1'
		torso = piece 'torso'
			head = piece 'head'
			aimx1 = piece 'aimx1'
				luparm = piece 'luparm'
					lloarm = piece 'lloarm'
						lgun = piece 'lgun'
							lflare = piece 'lfire'
				ruparm = piece 'ruparm'
					rloarm = piece 'rloarm'
						rgun = piece 'rgun'
							rflare = piece 'rfire'
	rthigh = piece 'rthigh'
		rleg = piece 'rleg'
			rfoot = piece 'rfoot'
	lthigh = piece 'lthigh'
		lleg = piece 'lleg'
			lfoot = piece 'lfoot'

function InitialPiecesSetup()
	Turn(rflare, 1, ang(90))
	Turn(lflare, 1, ang(90))
end