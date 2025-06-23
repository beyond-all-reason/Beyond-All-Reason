// damagedsmoke.h
// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// This header is a very simple thing that should be start-scripted in Create after unit is finshed building. 
// Emits more frequently as unit becomes more damaged
#ifndef SMOKE_PIECE
    #define SMOKE_PIECE base
#endif

#ifndef SMOKE_SFX
    #define SMOKE_SFX 257
#endif

DamagedSmoke(){
    var healthleft;
    while(1){
        healthleft = (get HEALTH);
        if (healthleft < 4) healthleft = 4;
        if (healthleft < 65){
            #if SMOKE_SFX == 257
                emit-sfx 257 + (healthleft % 2) from SMOKE_PIECE;
            #else
                emit-sfx SMOKE_SFX from SMOKE_PIECE;
            #endif

            sleep (70 - healthleft) * 50;
        }else{
            sleep 2000;
        }
    }
}