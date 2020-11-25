//Needs defines before usage:
//UNITSIZE 1-20, small for small units, large for large units, 
//MAXTILT ~100, how much unit should move
//BASEPIECE piecename, 
//HITSPEED <55>, for small units, <15> for large units

HitByWeapon(anglex, anglez, damage)	// angle[x|z] is always [-500;500], damage is multiplied by 100
{
	var amount;//, speedz, speedx;
	amount = damage / (100 * UNITSIZE);
	if (amount < 3  ) return (0);
	if (amount > MAXTILT){
		amount = MAXTILT;
		var randpiece;
		randpiece = RAND(1,3);
		if (randpiece == 1) emit-sfx 1025 from body;
		if (randpiece == 2) emit-sfx 1025 from head;
		if (randpiece == 3) emit-sfx 1025 from tail;
	}
	//get PRINT(anglex, anglez, amount, damage);
	//speedz = HITSPEED * get ABS(anglez) / 500; //nevermind this, the random error this produces actually looks better than the accurate version
	turn BASEPIECE to z-axis (anglez * amount) / 100  speed HITSPEED;
	turn BASEPIECE to x-axis <0> - (anglex * amount) /100 speed HITSPEED;
	wait-for-turn BASEPIECE around z-axis;
	wait-for-turn BASEPIECE around x-axis;
	turn BASEPIECE to z-axis <0.000000> speed HITSPEED / 4;
	turn BASEPIECE to x-axis <0.000000> speed HITSPEED / 4;
}
HitByWeaponId(anglex, anglez, weaponid, dmg) //weaponID is always 0,lasers and flamers give angles of 0
{
	start-script HitByWeapon(dmg, anglez,anglex); //I dont know why param order must be switched, and this also runs a frame later :(
	return (100); //return damage percent
}
