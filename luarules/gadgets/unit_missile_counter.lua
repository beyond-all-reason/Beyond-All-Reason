local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Burst overkill prevention",
		desc = "Limits a volley to only the shots needed to kill a target",
		author = "EnderRobo",
		date = "May 7, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--[[ HOW TO USE
----First in the unitdef file make each shot a seperate weapon. For example you have a 6 shot burst weapon, change it to 6 single shot weapons (but keep the burstrate variable).
----Slave all these weapons to one weapon. It can be one of these or a seperate one (like the bogus laser on the Medusa).


----To use this you will need to modify your unit's animation script, as this is a Lua-Cob script. Here is what you need to do:
----Add the following stat-vars
weapon, restore_delay, justFired, status, newTargetID, oldTargetID, burstDelay, timeout, canshoot, ready, opened, volleyCount, 
newLosState, oldLosState, missilesFired, newHealth, oldHealth, newExtraMissile, oldExtraMissile, newArmored, oldArmored

----Paste the following scripts somewhere near the top of your animation script:
----If you want multiple such volley weapons on your unit each group will need their own if check and variables in the shotCounter to make sure you update the correct ones each cycle.

#define VOLLEYCOUNT 6				//Amount of weapons in the volley group (max burst size)
#define WEAPONNUM 2					//Which weapon has the correct weapondef to pull data from. If you have multiple volley groups each one should pull from a different weapon so you can use it to seperate them in the shotCounter().

lua_ShotCounter()					//Cob-Lua callin
{
	return(0);
}

Timer()
{
	Signal SIG_TIMER;
	set-signal-mask SIG_TIMER;
	sleep 3500;						//time to impact, ideally at max range. After this passes the same target gets refreshed if it wasn't killed
	timeout = 0;
}

shotCounter(status, counter, targetID, burstrate, health, losstate, damage, armored)
{
	oldHealth = newHealth;
	newHealth = health;
	burstDelay = burstrate;
	oldTargetID = newTargetID;
	newTargetID = targetID;
	oldLosState = newLosState;
	newLosState = losstate;
	oldArmored = newArmored;
	newArmored = armored;
	
	if(newTargetID == oldTargetID)
	{
		if(NOT (newLosState == oldLosState))									//LOS state changed
		{
			canshoot = counter - missilesFired;									//Switches to new missile count. If some missiles were fired needs to shoot less missiles
			oldHealth = newHealth;												//Prevents bug: When out of LOS but in radar the health return is 0, so when unit enters LOS it triggers the repair script and fires additional missiles
			if(canshoot < 0)													//Prevents a bug that launches all missiles instantly
			{
				canshoot = 0;
			}
		}
		
		if(NOT (newArmored == oldArmored))										//Armored state changed
		{
			canshoot = counter - missilesFired;									//Switches to new missile count. If some missiles were fired needs to shoot less missiles
			if(canshoot < 0)													//Prevents a bug that launches all missiles instantly
			{
				canshoot = 0;
			}
		}
		
		if(newHealth > oldHealth)												//Target is being repaired
		{
			if(missilesFired == 0)												//If being repaired reset missile count until ready to fire
			{
				canshoot = counter;
			}
			else
			{
				if(newExtraMissile > oldExtraMissile)								//Only when an extra missile is needed
				{
					oldExtraMissile = newExtraMissile;
				}
				if(oldExtraMissile < 1)												//For first extra missile check how much health is needed to next damage treshold
				{
					if((((newHealth - oldHealth) / (((damage - (newHealth % damage)) / 20) + 1)) - 0.5) >= 1)		//checks if the current repair will get it to the next damage treshold before the missiles hit. +1 prevents division by 0 error
					{
						newExtraMissile = 1;
					}
				}
				else
				{
					newExtraMissile = (((newHealth - oldHealth) / 15));		//If the change is greater than 500 over 3.5s fire an extra missile. 2 extra for 1000 etc
				}
				if(newExtraMissile > oldExtraMissile)								//Only when an additional extra missile is needed
				{
					canshoot = canshoot + newExtraMissile - oldExtraMissile;
				}
			}
		}
		if(timeout == 1)														//Prevents same target refresh until missiles hit it
		{
			return(0);
		}
		
	}
	oldHealth = health;															//If new target reset old data
	oldTargetID = targetID;
	oldLosState = losstate;
	oldArmored = armored;
	missilesFired = 0;
	newExtraMissile = 0;
	oldExtraMissile = 0;
	canshoot = counter;
	return(0);
}

SetMaxReloadTime(Func_Var_1)
{
	restore_delay = Func_Var_1;			//Gets longest reload time. If incorrect you should set a custom one
	return (0);
}

----If you want the unit to close while reloading all weapons add CloseTimer() and modify Open() and Close() with the following code

CloseTimer()
{
	signal SIG_OPEN;
	start-script Close();
	sleep restore_delay - 4000;		//reload time - time to open back up with a bit of extra to ensure it opens back up soon enough
	justFired = justFired - 1;
}

Close()
{	
	opened = 0;
	set-signal-mask SIG_OPEN;
	sleep 1000;
	ready = 0;
	
	//the rest of the closing script
}

Open()
{
	if(justFired == volleyCount)					//Prevents opening if no launcher can shoot, so the hatches close for the reload
	{
		return (0);
	}
	signal SIG_OPEN;
	opened = 1;
	
	//the rest of the opening script
	
	ready = 1;
	set-signal-mask SIG_OPEN;
	sleep 1000;
	start-script Close();
}

----Every projectile in the volley will need to be a seperate weapon
----Modify your AimWeapon script for all weapons that use this

AimWeapon2(heading, pitch)
{
	call-script lua_ShotCounter(VOLLEYCOUNT, WEAPONNUM);			//Only one AimWeapon in the volley group should have this. This calls the script that calls the Lua and passes the required values
	
	Signal SIG_AIM_2;												//Seperate signal for each weapon
	
	if(opened == 0)													//Opens if it isn't already (use only if opening is required)
	{
		start-script Open(0);
	}
	
	//weapon turning here
	
	while(canshoot > 0 AND NOT (weapon == 1))						//Waits for its turn and terminates loops once no more shots are available
	{
		sleep 1;
	}
	set-signal-mask SIG_AIM_2;										//Prevents a bug where it can shoot the first missile while still closed
	
	//Waiting for turn here
	
	if(canshoot == 0)												//Checks if shots are available
	{
		return (0);
	}
	if(ready == 0)													//Checks if fully open 	(use only if opening is required)
	{
		return (0);
	}
	return (1);
}

----Add this to FireWeapon script for all weapons that use this

FireWeapon2()
{
	timeout = 1;
	justFired = justFired + 1;										//Used to delay next opening of hatches, so they close between shots
	canshoot = canshoot - 1;
	start-script Timer();
	start-script CloseTimer();
	start-script RestoreAfterDelay();
	missilesFired = missilesFired + 1;
	sleep (burstDelay - 80);
	weapon = (weapon + 1) % volleyCount;							//Set weapon to 0 in ExecuteAfterDelay to reset it to first launcher. The delay should be as long as the reload
}
--]]

local isCommander = {}

local function shotCounter(unitID, unitDefID, team, volleyCount, weaponNum)
	
	local armored, armorMultiplier
	local damage = Spring.GetUnitWeaponDamages(unitID, weaponNum, Game.armorTypes.standard)
	local health, maxHealth
	local counter
	local losState
	local targetType, isUserTarget, targetID = Spring.GetUnitWeaponTarget(unitID, 1) 
	local burstRate = (Spring.GetUnitWeaponState(unitID, weaponNum, "burstRate") * 1000)
	local targetDefID
	if targetType == 1 then -- target is a unit
		losState = Spring.GetUnitLosState(targetID, team, true)
		targetDefID = Spring.GetUnitDefID(targetID)
		
		if isCommander[targetDefID] then																					--if its a commander fire a full volley
			counter = volleyCount
			
		elseif losState == 6 and not UnitDefs[targetDefID].isBuilding then													--fire full volley at radar blobs
			counter = volleyCount
			
		elseif losState == 2 then																							--fire full volley at radar blobs
			counter = volleyCount
			
		elseif losState == 15 or losState == 1 then																			--check how many missiles for visible target
			armored, armorMultiplier = Spring.GetUnitArmored(targetID)
			health = Spring.GetUnitHealth(targetID)
			if damage <= 0 or armored and armorMultiplier <= 0 then
				counter = volleyCount
			elseif armored then
				counter = math.floor(health / (damage * armorMultiplier)) + 1												--account for armored state
			else
				counter = math.floor(health / damage) + 1	
			end	
			
		elseif losState == (14) or (losState == 6 and UnitDefs[targetDefID].isBuilding) then								--check how many missiles for radar ghost target at max health
			maxHealth = UnitDefs[targetDefID].health
			if damage <= 0 then
				counter = volleyCount
			else 
				counter = math.floor(maxHealth / damage) + 1
			end
		end
	else																													--fire full volley at ground
		counter = volleyCount
	end
	Spring.CallCOBScript(unitID, "shotCounter", 6, counter, targetID, burstRate, health, losState, damage, armored)
	return 1
end

function gadget:Initialize()
	gadgetHandler:RegisterGlobal("ShotCounter", shotCounter)
	for targetDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander or unitDef.customParams.isdecoycommander then
			isCommander[targetDefID] = true
		end
	end
end