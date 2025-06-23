//Needs defines before usage:
//UNITSIZE 1-20, small for small units, large for large units, 
//MAXTILT ~100, how much unit should move
//BASEPIECE piecename, 
//HITSPEED <55>, for small units, <15> for large units


// angle[x|z] is always [-500;500], damage is multiplied by 100
// thus if our maxtilt is 100/100, then we get 500, which is about 2.7 degrees of max tilt, which should also kind of scale with unitsize, e.g. smaller units should tilt more, while larger less
// 

// hitspeed should be a part of unitsize, to simplify scaling
HitByWeapon(anglex, anglez, damage)	// angle[x|z] is always [-500;500], damage is multiplied by 100
{
	var amount;//, speedz, speedx;
	amount = damage / (100 * UNITSIZE);
	var randpiece;
	randpiece = 0;
	if (amount < 3  ) return (0);
	//if (RAND(1, MAXTILT) < amount){
	if (1){
		randpiece = RAND(1, 3);
		if (randpiece == 1) emit-sfx 1024 from body;
		if (randpiece == 2) emit-sfx 1024 from head;
		if (randpiece == 3) emit-sfx 1024 from tail;
	}
	if (amount > MAXTILT){
		amount = MAXTILT;
	}	
	if (anglex ==0 ) { //this happens when hit by lasers
		if (anglez == 0){
			amount = amount / 2;
			anglex = RAND(1,500);
			anglez = RAND(1,500);
		}
	} 
	//get PRINT(anglex, anglez, amount, randpiece);
	//speedz = HITSPEED * get ABS(anglez) / 500; //nevermind this, the random error this produces actually looks better than the accurate version
	turn BASEPIECE to z-axis (anglez * amount) / 100  speed HITSPEED;
	turn BASEPIECE to x-axis <0> - (anglex * amount) /100 speed HITSPEED;
	wait-for-turn BASEPIECE around z-axis;
	wait-for-turn BASEPIECE around x-axis;
	turn BASEPIECE to z-axis <0.0> speed HITSPEED / 6;
	turn BASEPIECE to x-axis <0.0> speed HITSPEED / 6;
}

HitByWeaponId(anglex, anglez, weaponid, dmg) //weaponID is always 0,lasers and flamers give angles of 0
{
	if( get BUILD_PERCENT_LEFT) return (100);

	start-script HitByWeapon(dmg, anglez,anglex); //I dont know why param order must be switched, and this also runs a frame later :(
	return (100); //return damage percent
}
