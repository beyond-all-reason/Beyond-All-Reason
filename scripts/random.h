// random.h
// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// This is a linear feedback shift register implementation of a 31 bit pseudo random number generator
// The NEXTRANDOM func:
//    - Takes the last two bits of the current random number and XOR's them
//    - Shifts the entire random number to the right by 1 (/2)
//    - Puts the result of the XOR as the 30th bit
//    - Care is taken that the result stays positive
// The goal of this is to generate random numbers in a way that is MT-safe within the unit animation scripts, and does not depend on
// Recoil's global synced RNG
//
// USAGE:
// 1. Initialize with INITRANDOM(0)
//    - Passing anything other than 0 to the seed will force the seed to be what you specify, otherwise the unitID is used as a seed
// 2. Get a random number
//    - Generate the next random number with the NEXTRANDOM; statement
//    - Get a number between 0 and TOP-1 by using the RANDOM(TOP) statement
// Note:
//    - You cannot use NEXTRANDOM in an expression like "if (NEXTRANDOM == 1) {...}"
//    - You must:
//    - NEXTRANDOM;
//    - if (RANDOM(100) < 50){...}
//    - If you need two different random numbers from one generation, use different TOP values 
//    - Not only is this only half as fast as engine RAND(), but it also takes up an extra static-var

#ifndef RANDOM
   Static-var my_random;

   //damn no xor opcode in compiler
   //#define NEXTRANDOM  r = (((r/2) xor r) & 0x01) *0x40000000 + r /2 ;

   // This is approx 74 ns per call, which works out well at 25 cob instructions
   // This is half as fast as true engine Rand(), which is about 35 ns per call
   #define NEXTRANDOM  my_random = (((my_random/2)  & 0x01) != (my_random & 0x01)) *0x40000000 + my_random /2 ;

   // Evaluates to a random number between 0 and TOP-1
   #define RANDOM(TOP) (my_random % TOP)

   // Initialize with the seed with UNITID if the seed is 0, otherwise use the seed
   // 25 cob instructions
   #define INITRANDOM(seed) my_random = ((((get MY_ID)+(get MY_ID)*0x7fff) & 0x7FFFFFFF)) * (!seed) + (seed & 0x7FFFFFFF); 
   
   // only 13 cob instructions
   //#define INITRANDOM(seed) my_random = (get MY_ID)+(get MY_ID)*0x7fff; 
#endif