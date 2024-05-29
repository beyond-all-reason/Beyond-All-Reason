// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// floatmotion.h
// This is a nice bobbing and rocking on the waves animation.
// Looks quite decent and performs like a champ due to interpolated proper speed turns
// Usage:
// 1.A. Define a WATER_ROCK_UNITSIZE between 1 and 25
// 1.B. Optionally override any of the defines below
// 2. Include this file

#ifndef WATER_ROCK_PIECE
	#define WATER_ROCK_PIECE base
#endif


#ifndef WATER_ROCK_UNITSIZE
    #define WATER_ROCK_UNITSIZE 10 
#endif

// How much to rock side to side in angle
#ifndef WATER_ROCK_AMPLITUDE
	#define WATER_ROCK_AMPLITUDE (<3.0> - (WATER_ROCK_UNITSIZE * <0.1>))
#endif

// How frequently to update in frames
#ifndef WATER_ROCK_FRAMES
	#define WATER_ROCK_FRAMES 10
#endif

// How fast to rock around X
#ifndef WATER_ROCK_FREQ_X 
	#define  WATER_ROCK_FREQ_X (30-  WATER_ROCK_UNITSIZE)
#endif

// How fast to rock around Z
#ifndef WATER_ROCK_FREQ_Z
	#define  WATER_ROCK_FREQ_Z (41-  WATER_ROCK_UNITSIZE)
#endif

// How fast bobbing up and down should be 
#ifndef WATER_ROCK_FREQ_Y
	#define  WATER_ROCK_FREQ_Y (52-  WATER_ROCK_UNITSIZE)
#endif

// How much to bob up and down in linear units
#ifndef WATER_BOB_HEIGHT
	#define WATER_BOB_HEIGHT (20000 + (2000 * WATER_ROCK_UNITSIZE))
#endif


FloatMotion()
{
	var curr;
	// curr is used as a temp variable throughout
	curr = (get MY_ID);

    #if (WATER_ROCK_FREQ_X > 0)
        var prevx, angx;
        angx = curr * WATER_ROCK_FREQ_X;
        prevx = 0;
    #endif
    #if WATER_ROCK_FREQ_Y > 0
        var prevy, angy;
        angy = curr * WATER_ROCK_FREQ_Y;
        prevy = 0;
    #endif

    #if WATER_ROCK_FREQ_Z > 0
        var prevz, angz;
        angz = curr * WATER_ROCK_FREQ_Z;
        prevz = 0;
    #endif
	
	while( TRUE )
	{
        #if WATER_ROCK_FREQ_X > 0
            // Calculate angle and wrap at 360
            angx = (angx + (WATER_ROCK_FREQ_X * <1>)) % <360>;

            // Get the the sine amplitude
            curr = WATER_ROCK_AMPLITUDE * get KSIN(angx) / 1024;

            // Save as delta
            prevx = curr - prevx;

            // Turn smoothly
            turn WATER_ROCK_PIECE to x-axis curr speed get ABS((prevx * 30) / WATER_ROCK_FRAMES);

            // Save previous
            prevx = curr;
        #endif

        #if WATER_ROCK_FREQ_Z > 0
            angz = (angz + (WATER_ROCK_FREQ_Z * <1>)) % <360>;
            curr = WATER_ROCK_AMPLITUDE * get KSIN(angz) / 1024;
            prevz = curr - prevz;
            turn WATER_ROCK_PIECE to z-axis curr speed get ABS((prevz * 30) / WATER_ROCK_FRAMES);
            prevz = curr;
        #endif


        #if WATER_ROCK_FREQ_Y > 0 
            angy = (angy + (WATER_ROCK_FREQ_Y * <1>)) % <360>;
            curr = WATER_BOB_HEIGHT * get KSIN(angy) / 1024;
            prevy = curr - prevy;
            move WATER_ROCK_PIECE to y-axis curr  speed get ABS((prevy * 30) / WATER_ROCK_FRAMES);
            prevy = curr;
        #endif

		sleep WATER_ROCK_FRAMES * 33 - 1;
	}
}