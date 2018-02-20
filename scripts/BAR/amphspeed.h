//File: amphspeed.h
//Description: Makes the unit move as fast underwater as on land.
//Author: Evil4Zerggin
//Date: 22 February 2008

//Directions:
//1. Include this file by putting the line
//
//	#include "amphspeed.h" 
//
//at the top.
//2. In Create() put the following line: 
//
//	start-script AmphSpeed();
//
//That's all.

#ifndef AMPHSPEED_H
#define AMPHSPEED_H

static-var amphspeed_h_base_speed;

AmphSpeed() {
	amphspeed_h_base_speed = GET MAX_SPEED;
    while(TRUE) {
		if(GET IN_WATER){   
			SET MAX_SPEED to amphspeed_h_base_speed * 2;
		} else {
			SET MAX_SPEED to amphspeed_h_base_speed;
		}
		sleep 30;
	}
}

#endif