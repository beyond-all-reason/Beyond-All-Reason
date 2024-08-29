// This stub defines an aileron roll maneuver, with two configurable parameters
// Default piece is base, override if needed
// And a barrel roll speed, default <120> 
// Remember to start-script BarrelRoll(); in Create()!

// Author Beherith mysterme@gmail.com. License: GNU GPL v2.

#ifndef BARRELROLL_PIECE
    #define BARRELROLL_PIECE base
#endif

#ifndef BARRELROLL_SPEEED
    #define BARRELROLL_SPEEED <120>
#endif

#ifndef BARRELROLL_PROBABILITY
    #define BARRELROLL_PROBABILITY 20
#endif

BarrelRoll(maxSpeed, currentSpeed) 
{
    maxSpeed = (get MAX_SPEED);
    
    while (TRUE){
        sleep 2000;
        currentSpeed = (get CURRENT_SPEED);
        //get PRINT(98700001, maxSpeed, currentSpeed);
        if( (RAND(1,100) <= BARRELROLL_PROBABILITY) AND (maxSpeed < (currentSpeed+100) ) )
        {
            turn BARRELROLL_PIECE to z-axis <240> speed BARRELROLL_SPEEED;
            sleep (<120> * 990) /BARRELROLL_SPEEED  - 32;
            //wait-for-turn BARRELROLL_PIECE around z-axis;
            turn BARRELROLL_PIECE to z-axis <120> speed BARRELROLL_SPEEED * 3 / 2;
            sleep (<120> * 990) / (BARRELROLL_SPEEED * 3 / 2) - 32 ;
            //wait-for-turn BARRELROLL_PIECE around z-axis;
            turn BARRELROLL_PIECE to z-axis <0.0> speed BARRELROLL_SPEEED;
            sleep (<120> * 990) /BARRELROLL_SPEEED  - 32;
        }
    }
}
