// Compensated turret aim. A per frame controller cancels the hull rotation while aiming so walking
// turns never disturb the aim, tracks the target at constant speed (or with acceleration when
// configured) and lets AimWeapon answer honestly. Related to constant_acceleration_turret_turning.h
// (CATT) by Beherith. Changeheading compensation and belief servo ideas by DoodVanDaag.
// License GNU GPL v2 or later.
//
// Usage. Include recoil_common_includes.h first, define the settings below, then include this file
// after the piece declarations.
//   Create()            start-script COMPAIM1_Controller();
//   AimWeapon1()        call-script COMPAIM1_Aim(heading); then return (0) if !COMPAIM1ready, else return (1)
//                       with COMPAIM1_PIECE_X defined the call is COMPAIM1_Aim(heading, pitch)
//   idle restore        call-script COMPAIM1_StopAiming();
//   SetStunned(State)   call-script COMPAIM1_SetStunned(State);
// Several weapons on one turret share the instance, each AimWeapon calls COMPAIM1_Aim the same way.

// Yaw piece, written only by the controller
#ifndef COMPAIM1_PIECE_Y
	#define COMPAIM1_PIECE_Y aimy1
#endif

// Define COMPAIM1_PIECE_X to let the controller own and gate pitch as well

#ifndef COMPAIM1_YAW_SPEED
	#define COMPAIM1_YAW_SPEED <300>
#endif

#ifdef COMPAIM1_PIECE_X
	#ifndef COMPAIM1_PITCH_SPEED
		#define COMPAIM1_PITCH_SPEED <100>
	#endif
	// Pitch piece angle when not aiming
	#ifndef COMPAIM1_REST_PITCH
		#define COMPAIM1_REST_PITCH <0>
	#endif
	#ifndef COMPAIM1_RESTORE_PITCH_SPEED
		#define COMPAIM1_RESTORE_PITCH_SPEED COMPAIM1_PITCH_SPEED
	#endif
#endif

// Yaw speed when returning to center
#ifndef COMPAIM1_RESTORE_SPEED
	#define COMPAIM1_RESTORE_SPEED COMPAIM1_YAW_SPEED
#endif

// Fire is withheld while the turret is further than this from the target
#ifndef COMPAIM1_FIRE_ANGLE
	#define COMPAIM1_FIRE_ANGLE <25>
#endif

// Define COMPAIM1_YAW_LIMIT to keep the turret within that angle either side of forward,
// targets beyond it are reported not ready

// Define COMPAIM1_YAW_ACCEL in degrees per second squared to ramp the yaw speed up and down
// instead of turning at full speed instantly
#ifdef COMPAIM1_YAW_ACCEL
	#define COMPAIM1_YAW_ACCEL_STEP (COMPAIM1_YAW_ACCEL / 30 / 30)
#endif
#ifdef COMPAIM1_PIECE_X
	#ifndef COMPAIM1_FIRE_ANGLE_PITCH
		#define COMPAIM1_FIRE_ANGLE_PITCH COMPAIM1_FIRE_ANGLE
	#endif
#endif

static-var COMPAIM1goalHeading, COMPAIM1belief, COMPAIM1lastHullHeading, COMPAIM1active, COMPAIM1stunned, COMPAIM1ready;
#ifdef COMPAIM1_PIECE_X
	static-var COMPAIM1goalPitch, COMPAIM1pitchBelief;
#endif
#ifdef COMPAIM1_YAW_ACCEL
	static-var COMPAIM1yawVelocity;
#endif

// Singleton, started once from Create, the only writer of the aim pieces
COMPAIM1_Controller()
{
	var hullHeading;
	var hullDelta;
	var step;
	var delta;
	#ifdef COMPAIM1_YAW_ACCEL
		var brakeDistance;
	#endif
	COMPAIM1lastHullHeading = get HEADING;
	while (TRUE)
	{
		hullHeading = get HEADING;
		hullDelta = WRAPDELTA(hullHeading - COMPAIM1lastHullHeading);
		COMPAIM1lastHullHeading = hullHeading;
		if (!COMPAIM1stunned)
		{
			if (COMPAIM1active)
			{
				COMPAIM1goalHeading = WRAPDELTA(COMPAIM1goalHeading - hullDelta);
				COMPAIM1belief = WRAPDELTA(COMPAIM1belief - hullDelta);
				step = (COMPAIM1_YAW_SPEED / 30);
			}
			else
			{
				COMPAIM1goalHeading = 0;
				step = (COMPAIM1_RESTORE_SPEED / 30);
			}
			#ifdef COMPAIM1_YAW_LIMIT
				if (COMPAIM1goalHeading > COMPAIM1_YAW_LIMIT)
				{
					COMPAIM1goalHeading = COMPAIM1_YAW_LIMIT;
				}
				if (COMPAIM1goalHeading < (0 - COMPAIM1_YAW_LIMIT))
				{
					COMPAIM1goalHeading = 0 - COMPAIM1_YAW_LIMIT;
				}
			#endif
			delta = WRAPDELTA(COMPAIM1goalHeading - COMPAIM1belief);
			#ifdef COMPAIM1_YAW_ACCEL
				brakeDistance = ((get ABS(COMPAIM1yawVelocity)) / COMPAIM1_YAW_ACCEL_STEP) * (get ABS(COMPAIM1yawVelocity)) / 2;
				if (((COMPAIM1yawVelocity * SIGN(delta)) < 0) OR ((get ABS(delta)) <= brakeDistance))
				{
					if ((get ABS(COMPAIM1yawVelocity)) <= COMPAIM1_YAW_ACCEL_STEP)
					{
						COMPAIM1yawVelocity = 0;
					}
					else
					{
						COMPAIM1yawVelocity = COMPAIM1yawVelocity - SIGN(COMPAIM1yawVelocity) * COMPAIM1_YAW_ACCEL_STEP;
					}
				}
				else
				{
					COMPAIM1yawVelocity = COMPAIM1yawVelocity + SIGN(delta) * COMPAIM1_YAW_ACCEL_STEP;
				}
				if ((get ABS(COMPAIM1yawVelocity)) > step)
				{
					COMPAIM1yawVelocity = SIGN(COMPAIM1yawVelocity) * step;
				}
				if ((get ABS(COMPAIM1yawVelocity)) > (get ABS(delta)))
				{
					COMPAIM1yawVelocity = delta;
				}
				COMPAIM1belief = WRAPDELTA(COMPAIM1belief + COMPAIM1yawVelocity);
			#else
				if ((get ABS(delta)) > step)
				{
					COMPAIM1belief = WRAPDELTA(COMPAIM1belief + SIGN(delta) * step);
				}
				else
				{
					COMPAIM1belief = COMPAIM1goalHeading;
				}
			#endif
			turn COMPAIM1_PIECE_Y to y-axis COMPAIM1belief now;

			#ifdef COMPAIM1_PIECE_X
				if (COMPAIM1active)
				{
					step = (COMPAIM1_PITCH_SPEED / 30);
				}
				else
				{
					COMPAIM1goalPitch = 0 - (COMPAIM1_REST_PITCH);
					step = (COMPAIM1_RESTORE_PITCH_SPEED / 30);
				}
				delta = WRAPDELTA(COMPAIM1goalPitch - COMPAIM1pitchBelief);
				if ((get ABS(delta)) > step)
				{
					COMPAIM1pitchBelief = WRAPDELTA(COMPAIM1pitchBelief + SIGN(delta) * step);
				}
				else
				{
					COMPAIM1pitchBelief = COMPAIM1goalPitch;
				}
				turn COMPAIM1_PIECE_X to x-axis (0 - COMPAIM1pitchBelief) now;
			#endif
		}
		sleep 1;
	}
}

#ifdef COMPAIM1_PIECE_X
COMPAIM1_Aim(heading, pitch)
#else
COMPAIM1_Aim(heading)
#endif
{
	COMPAIM1active = 1;
	COMPAIM1goalHeading = heading;
	#ifdef COMPAIM1_PIECE_X
		COMPAIM1goalPitch = pitch;
	#endif

	COMPAIM1ready = 1;
	var delta;
	delta = WRAPDELTA(heading - COMPAIM1belief);
	if ((get ABS(delta)) > COMPAIM1_FIRE_ANGLE)
	{
		COMPAIM1ready = 0;
	}
	#ifdef COMPAIM1_YAW_LIMIT
		if ((get ABS(heading)) > COMPAIM1_YAW_LIMIT)
		{
			COMPAIM1ready = 0;
		}
	#endif
	#ifdef COMPAIM1_PIECE_X
		delta = WRAPDELTA(pitch - COMPAIM1pitchBelief);
		if ((get ABS(delta)) > COMPAIM1_FIRE_ANGLE_PITCH)
		{
			COMPAIM1ready = 0;
		}
	#endif
}

COMPAIM1_StopAiming()
{
	COMPAIM1active = 0;
}

COMPAIM1_SetStunned(state)
{
	COMPAIM1stunned = state;
}
