--pieces
        local body = piece "body"

        local turret = piece "turret"

        local launcher = piece "launcher"

        local flare1 = piece "flare1"
        local flare2 = piece "flare2"
        local flare3 = piece "flare3"
        local flare4 = piece "flare4"
        local flare5 = piece "flare5"
        local flare6 = piece "flare6"
        local flare7 = piece "flare7"
        local flare8 = piece "flare8"

        local currBarrel = 1

	local dmgPieces = { piece "body", piece "turret" }


-- includes
	include "dmg_smoke.lua"
	include "animation.lua"


--signals
        local SIG_AIM = 1


        function script.Create()
		Hide(flare1)
		Hide(flare2)
		Hide(flare3)
		Hide(flare4)
		Hide(flare5)
		Hide(flare6)
		Hide(flare7)
		Hide(flare8)

		StartThread(dmgsmoke, dmgPieces)

                Turn(launcher, x_axis, math.rad(-55.000000), math.rad(60.000000))
                WaitForTurn(launcher, x_axis)

		StartThread (animSpin, unitID, turret, y_axis, math.rad(25.000000))
        end

        local function RestoreAfterDelay(unitID)
                Sleep(2500)
                --Turn(turret, x_axis, 0, math.rad(50))
				--Turn(launcher, x_axis, 0, math.rad(50))
        end


        function script.QueryWeapon1()
                if (currBarrel == 1) then
                        return flare1 end
                if (currBarrel == 2) then
                        return flare2 end
                if (currBarrel == 3) then
                        return flare3 end
                if (currBarrel == 4) then
                        return flare4 end
                if (currBarrel == 5) then
                        return flare5 end
                if (currBarrel == 6) then
                        return flare6 end
                if (currBarrel == 7) then
                        return flare7 end
                if (currBarrel == 8) then
                        return flare8 end
        end

        function script.AimFromWeapon1() return turret end

        function script.AimWeapon1( heading, pitch )
                Signal(SIG_AIM)
                SetSignalMask(SIG_AIM)
                Turn(turret, y_axis, heading, math.rad(245.000000))
                Turn(launcher, x_axis, -pitch, math.rad(185.000000))
                WaitForTurn(turret, y_axis)
                WaitForTurn(launcher, x_axis)
                return true
        end

        function script.FireWeapon1()
                if currBarrel == 1 then
			--EmitSfx(flare1, 1024+0)
			Sleep (150)
                end

                if currBarrel == 2 then
			--EmitSfx(flare2, 1024+0)
			Sleep (150)
                end


                if currBarrel == 3 then
			--EmitSfx(flare3, 1024+0)
			Sleep (150)
                end


                if currBarrel == 4 then
			--EmitSfx(flare4, 1024+0)
			Sleep (150)
                end

                if currBarrel == 5 then
			--EmitSfx(flare5, 1024+0)
			Sleep (150)
                end

                if currBarrel == 6 then
			--EmitSfx(flare6, 1024+0)
			Sleep (150)
                end

                if currBarrel == 7 then
			--EmitSfx(flare7, 1024+0)
			Sleep (150)
                end

                if currBarrel == 8 then
			--EmitSfx(flare8, 1024+0)
			Sleep (150)
                end

                currBarrel = currBarrel + 1

                if currBarrel == 9 then currBarrel = 1 end

			Sleep (5000)
			StartThread (animSpin, unitID, turret, y_axis, math.rad(25.000000))
			Turn(launcher, x_axis, math.rad(-35.000000), math.rad(60.000000))
        end

	function script.Killed(recentDamage, maxHealth)
		local severity = recentDamage / maxHealth

		if severity <= .25 then
			Explode(turret, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(launcher, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(flare1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(flare1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			return 1 -- corpsetype

		elseif severity <= .5 then
			Explode(turret, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(launcher, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(flare1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(flare1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			return 2 -- corpsetype
		else
			Explode(turret, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(launcher, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(flare1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			Explode(flare1, SFX.EXPLODE + SFX.NO_HEATCLOUD)
			return 3 -- corpsetype
		end
	end
