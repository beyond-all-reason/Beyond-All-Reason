// Compensated turret aim. A per frame controller cancels the hull rotation while aiming so walking
// turns never disturb the aim, tracks the target at constant speed (or with acceleration when
// configured) and lets AimWeapon answer honestly.
//
// Usage. Include recoil_common_includes.h first, define the settings below, then include this file
// after the piece declarations.
//   Create()            start-script COMPAIM1_Controller();
//   AimWeapon1()        call-script COMPAIM1_Aim(heading); then return (0) if !COMPAIM1ready, else return (1)
//                       with COMPAIM1_PIECE_X defined the call is COMPAIM1_Aim(heading, pitch)
//   idle restore        call-script COMPAIM1_StopAiming();
//                       the piece returns to COMPAIM1_REST_YAW, or keeps turning when COMPAIM1_IDLE_SPIN is 1
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

// Yaw speed when returning to rest
#ifndef COMPAIM1_RESTORE_SPEED
	#define COMPAIM1_RESTORE_SPEED COMPAIM1_YAW_SPEED
#endif

// Yaw piece angle when not aiming
#ifndef COMPAIM1_REST_YAW
	#define COMPAIM1_REST_YAW <0>
#endif

// Set COMPAIM1_IDLE_SPIN to 1 to keep the yaw piece turning at the restore speed while idle
#ifndef COMPAIM1_IDLE_SPIN
	#define COMPAIM1_IDLE_SPIN 0
#endif
#if COMPAIM1_IDLE_SPIN
	static-var COMPAIM1idleYaw;
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
// COMPAIM1_PITCH_ACCEL does the same for pitch
#ifdef COMPAIM1_PITCH_ACCEL
	#define COMPAIM1_PITCH_ACCEL_STEP (COMPAIM1_PITCH_ACCEL / 30 / 30)
#endif
#ifdef COMPAIM1_PIECE_X
	#ifndef COMPAIM1_FIRE_ANGLE_PITCH
		#define COMPAIM1_FIRE_ANGLE_PITCH COMPAIM1_FIRE_ANGLE
	#endif
#endif

// Aim calls at most this many frames apart set the rate that carries the goal between calls
#ifndef COMPAIM1_RATE_FRAMES
	#define COMPAIM1_RATE_FRAMES 6
#endif

static-var COMPAIM1goalHeading, COMPAIM1belief, COMPAIM1lastHullHeading, COMPAIM1active, COMPAIM1stunned, COMPAIM1ready;
static-var COMPAIM1goalRate, COMPAIM1lastAimHeading, COMPAIM1lastAimFrame;
#ifdef COMPAIM1_PIECE_X
	static-var COMPAIM1goalPitch, COMPAIM1pitchBelief, COMPAIM1pitchRate, COMPAIM1lastAimPitch;
#endif
#ifdef COMPAIM1_YAW_ACCEL
	static-var COMPAIM1yawVelocity;
#endif
#ifdef COMPAIM1_PITCH_ACCEL
	static-var COMPAIM1pitchVelocity;
#endif

// Singleton, started once from Create, the only writer of the aim pieces
COMPAIM1_Controller()
{
	var hullHeading;
	var hullDelta;
	var step;
	var delta;
	#if defined(COMPAIM1_YAW_ACCEL) || defined(COMPAIM1_PITCH_ACCEL)
		var brakeDistance;
		var relativeVelocity;
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
				COMPAIM1goalHeading = WRAPDELTA(COMPAIM1goalHeading - hullDelta + COMPAIM1goalRate);
				COMPAIM1lastAimHeading = WRAPDELTA(COMPAIM1lastAimHeading - hullDelta);
				COMPAIM1belief = WRAPDELTA(COMPAIM1belief - hullDelta);
				step = (COMPAIM1_YAW_SPEED / 30);
			}
			else
			{
				#if COMPAIM1_IDLE_SPIN
					COMPAIM1idleYaw = WRAPDELTA(COMPAIM1idleYaw + (COMPAIM1_RESTORE_SPEED / 30));
					COMPAIM1goalHeading = WRAPDELTA(COMPAIM1_REST_YAW + COMPAIM1idleYaw);
				#else
					COMPAIM1goalHeading = COMPAIM1_REST_YAW;
				#endif
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
				relativeVelocity = COMPAIM1yawVelocity - COMPAIM1goalRate;
				brakeDistance = ((get ABS(relativeVelocity)) / COMPAIM1_YAW_ACCEL_STEP) * (get ABS(relativeVelocity)) / 2;
				if (((relativeVelocity * SIGN(delta)) < 0) OR ((get ABS(delta)) <= brakeDistance))
				{
					if ((get ABS(relativeVelocity)) <= COMPAIM1_YAW_ACCEL_STEP)
					{
						relativeVelocity = 0;
					}
					else
					{
						relativeVelocity = relativeVelocity - SIGN(relativeVelocity) * COMPAIM1_YAW_ACCEL_STEP;
					}
				}
				else
				{
					relativeVelocity = relativeVelocity + SIGN(delta) * COMPAIM1_YAW_ACCEL_STEP;
				}
				COMPAIM1yawVelocity = COMPAIM1goalRate + relativeVelocity;
				if ((get ABS(COMPAIM1yawVelocity)) > step)
				{
					COMPAIM1yawVelocity = SIGN(COMPAIM1yawVelocity) * step;
				}
				if (((get ABS(COMPAIM1yawVelocity)) > (get ABS(delta))) AND ((COMPAIM1yawVelocity * SIGN(delta)) > 0))
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
			turn COMPAIM1_PIECE_Y to y-axis COMPAIM1belief speed COMPAIM1_YAW_SPEED;

			#ifdef COMPAIM1_PIECE_X
				if (COMPAIM1active)
				{
					COMPAIM1goalPitch = WRAPDELTA(COMPAIM1goalPitch + COMPAIM1pitchRate);
					step = (COMPAIM1_PITCH_SPEED / 30);
				}
				else
				{
					COMPAIM1goalPitch = 0 - (COMPAIM1_REST_PITCH);
					step = (COMPAIM1_RESTORE_PITCH_SPEED / 30);
				}
				delta = WRAPDELTA(COMPAIM1goalPitch - COMPAIM1pitchBelief);
				#ifdef COMPAIM1_PITCH_ACCEL
					relativeVelocity = COMPAIM1pitchVelocity - COMPAIM1pitchRate;
					brakeDistance = ((get ABS(relativeVelocity)) / COMPAIM1_PITCH_ACCEL_STEP) * (get ABS(relativeVelocity)) / 2;
					if (((relativeVelocity * SIGN(delta)) < 0) OR ((get ABS(delta)) <= brakeDistance))
					{
						if ((get ABS(relativeVelocity)) <= COMPAIM1_PITCH_ACCEL_STEP)
						{
							relativeVelocity = 0;
						}
						else
						{
							relativeVelocity = relativeVelocity - SIGN(relativeVelocity) * COMPAIM1_PITCH_ACCEL_STEP;
						}
					}
					else
					{
						relativeVelocity = relativeVelocity + SIGN(delta) * COMPAIM1_PITCH_ACCEL_STEP;
					}
					COMPAIM1pitchVelocity = COMPAIM1pitchRate + relativeVelocity;
					if ((get ABS(COMPAIM1pitchVelocity)) > step)
					{
						COMPAIM1pitchVelocity = SIGN(COMPAIM1pitchVelocity) * step;
					}
					if (((get ABS(COMPAIM1pitchVelocity)) > (get ABS(delta))) AND ((COMPAIM1pitchVelocity * SIGN(delta)) > 0))
					{
						COMPAIM1pitchVelocity = delta;
					}
					COMPAIM1pitchBelief = WRAPDELTA(COMPAIM1pitchBelief + COMPAIM1pitchVelocity);
				#else
					if ((get ABS(delta)) > step)
					{
						COMPAIM1pitchBelief = WRAPDELTA(COMPAIM1pitchBelief + SIGN(delta) * step);
					}
					else
					{
						COMPAIM1pitchBelief = COMPAIM1goalPitch;
					}
				#endif
				turn COMPAIM1_PIECE_X to x-axis (0 - COMPAIM1pitchBelief) speed COMPAIM1_PITCH_SPEED;
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
	var frames;
	frames = (get GAME_FRAME) - COMPAIM1lastAimFrame;
	if (frames > 0)
	{
		COMPAIM1goalRate = 0;
		#ifdef COMPAIM1_PIECE_X
			COMPAIM1pitchRate = 0;
		#endif
		if (frames <= COMPAIM1_RATE_FRAMES)
		{
			COMPAIM1goalRate = WRAPDELTA(heading - COMPAIM1lastAimHeading) / frames;
			if ((get ABS(COMPAIM1goalRate)) > (COMPAIM1_YAW_SPEED / 30))
			{
				COMPAIM1goalRate = 0;
			}
			#ifdef COMPAIM1_PIECE_X
				COMPAIM1pitchRate = WRAPDELTA(pitch - COMPAIM1lastAimPitch) / frames;
				if ((get ABS(COMPAIM1pitchRate)) > (COMPAIM1_PITCH_SPEED / 30))
				{
					COMPAIM1pitchRate = 0;
				}
			#endif
		}
		COMPAIM1lastAimHeading = heading;
		COMPAIM1lastAimFrame = get GAME_FRAME;
		#ifdef COMPAIM1_PIECE_X
			COMPAIM1lastAimPitch = pitch;
		#endif
	}
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
