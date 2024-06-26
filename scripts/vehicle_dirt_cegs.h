// For emitting dirt while moving
// Always ensure this is start-scripted from StartMoving(reversing), with a signal mask on move!

//#define VD_PIECE1 smoke1
//#define VD_PIECE2 smoke2
//#define VD_PIECE3 smoke3

// To emit bubbles underwater
//#define VD_AMPHIBIOUS

/*

StartMoving(reversing){
	signal SIGNAL_MOVE;
	set-signal-mask SIGNAL_MOVE;
	start-script Vehicle_Dirt_Ceg();
}
*/

// default first ceg
#ifndef VD_DIRTCEG 
	#define VD_DIRTCEG 1024
#endif

// default bubbles ceg
#ifndef VD_BUBBLECEG
	#define VD_BUBBLECEG 259
#endif

// Ensure minsleep is >1
#ifndef VD_MINSLEEP
	#define VD_MINSLEEP 29
#endif


Vehicle_Dirt_Ceg(){
	var VD_moveSpeed;
	VD_moveSpeed = get MAX_SPEED;
	var VD_currentSpeed;
	while (TRUE){
		VD_currentSpeed = (get CURRENT_SPEED) * 20 / VD_moveSpeed;
		if (VD_currentSpeed < 4) VD_currentSpeed = 4;
		VD_currentSpeed = 1800/VD_currentSpeed + VD_MINSLEEP + 1;
		
		if (get IN_WATER) {
		#ifdef VD_AMPHIBIOUS
			#ifdef VD_PIECE1
				emit-sfx VD_BUBBLECEG from VD_PIECE1;
			#endif
					
			#ifdef VD_PIECE2
				emit-sfx VD_BUBBLECEG from VD_PIECE2;
			#endif
				
			#ifdef VD_PIECE2
				emit-sfx VD_BUBBLECEG from VD_PIECE2;
			#endif
		#endif
		}else{
			#ifdef VD_PIECE1
				emit-sfx VD_DIRTCEG from VD_PIECE1;
			#endif
					
			#ifdef VD_PIECE2
				emit-sfx VD_DIRTCEG from VD_PIECE2;
			#endif
				
			#ifdef VD_PIECE2
				emit-sfx VD_DIRTCEG from VD_PIECE2;
			#endif
		}
		
		sleep VD_currentSpeed;
	}
}




