# Weapon attribute tables

Documentation for the attributes controller, showing the tables that store a weapon attribute.

```
 unitdef 42 has two weapons and a death explosion.   weapondef damage, default class:
 unit 4117 is one of them, on team 0.                weapon 1   100
                                                     weapon 2    30
                                                     explode    500
                                                     selfd        0  <-- will be ignored.

 FIVE FACTORS EXIST:

 root                       unitID  defID  team  attribute  weapon  source      factor
 ------------------------   ------  -----  ----  ---------  ------  ---------   ---------------------
 unitWeaponFactors            4117      -     -  damage          0  veterancy   multiply 1.25  seq 74
 unitWeaponFactors            4117      -     -  damage          2  overheat    multiply 0.50  seq 90
 unitWeaponFactors            4117      -     -  damage         -1  unstable    multiply 3.00  seq 92
 unitdefTeamWeaponFactors        -     42     0  damage          0  teambuff    multiply 1.20  seq 55
 unitdefWeaponFactors            -     42     -  damage          1  upgrade     multiply 2.00  seq 60
```

```
 THE FACTORS AS THE ACTUAL TABLES:

 unitWeaponFactors = {
   [4117] = {
     ["damage"] = {
       [ 0] = { ["veterancy"] = { kind="multiply", value=1.25, sequence=74 } },
       [ 2] = { ["overheat" ] = { kind="multiply", value=0.50, sequence=90 } },
       [-1] = { ["unstable" ] = { kind="multiply", value=3.00, sequence=92 } },
     },
   },
 }
 unitdefTeamWeaponFactors = {
   [42] = {
     [0] = {
       ["damage"] = {
         [ 0] = { ["teambuff"] = { kind="multiply", value=1.20, sequence=55 } },
       },
     },
   },
 }
 unitdefWeaponFactors = {
   [42] = {
     ["damage"] = {
       [ 1] = { ["upgrade" ] = { kind="multiply", value=2.00, sequence=60 } },
     },
   },
 }
```

```
 WEAPON SLOTS ARE NOT WEAPON NUMBERS ARE NOT WEAPON KEYS.

   weapon key       meaning                   slot index
   ----------       -----------------------   ----------
           -2       self-destruct             4
           -1       death explosion           3
            0       all of the weapons        none
            1       weapon 1                  1
            2       weapon 2                  2

   Key 0 has no slot. Slots 1 and 2 read it.
   Slot indices are in sequence: 1, 2, 3, 4.
```

```
 COMPOSING EACH SLOT. Six keys are read per slot, in this order.
 Key `0` is all weapons. Key `w` is specific to a weapon number.
 The first `set` op ends the search; every `multiply` is applied.

                     slot 1        slot 2        slot 3        slot 4
                     weapon 1      weapon 2      explode       selfDestruct
                     base 100      base 30       base 500      base 0
 ------------------  -----------   -----------   -----------   ------------
 unitdef   [ 0]      -             -             (not read)    (not read)
 unitdef   [ w]      upgrade 2.00  -             -             -
 team      [ 0]      teambuff 1.20 teambuff 1.20 (not read)    (not read)
 team      [ w]      -             -             -             -
 unit      [ 0]      vet 1.25      vet 1.25      (not read)    (not read)
 unit      [ w]      -             overheat 0.50 unstable 3.00 -
 ------------------  -----------   -----------   -----------   ------------
 composed            3.00          0.75          3.00          1.00
 final value         300           22.5          1500          -
```

```
 THE "VECTOR": BASE, COMPOSED, AND APPLIED.

                            slot 1   slot 2   slot 3   slot 4
                           -------  -------  -------  -------
  baseVectors[42].damage      1.00     1.00     1.00     1.00
  composed this frame         3.00     0.75     3.00     1.00
  appliedWeapons[4117]        3.00     1.00     1.00     1.00
                           -------  -------  -------  -------
                             equal     DIFF     DIFF    equal
                                          |        |
  SetUnitWeaponDamages(4117, 2, ...)  <---+        |
  SetUnitWeaponDamages(4117, "explode", ...)  <----+

  Slot 4 is never written at all. baseExplosions[42][2] does not exist.
  The self-destruct weapondef deals no damage, so is ignored (for now).
```

```
 ALL ROOTS AND THEIR KEY PATHS.

 unitFactors                [unitID][attribute][source]              = factor
 unitdefTeamFactors         [defID][teamID][attribute][source]       = factor
 unitdefFactors             [defID][attribute][source]               = factor
 unitWeaponFactors          [unitID][attribute][weapon][source]      = factor
 unitdefTeamWeaponFactors   [defID][teamID][attribute][weapon][src]  = factor
 unitdefWeaponFactors       [defID][attribute][weapon][source]       = factor

 dirty                      [unitID][attribute]  = true
 dirtyWeapons               [unitID][attribute]  = true
 appliedValues              [unitID][attribute]  = number
 appliedWeapons             [unitID][attribute]  = number[] by slot

 baseValues                 [defID][attribute]   = number
 baseWeapons                [defID]              = { {range=,reload=}, ... }
 baseVectors                [defID][attribute]   = number[] by slot
 baseDamages                [defID][weapon]      = {armourClass = damage}
 baseExplosions             [defID][1 or 2]      = {armourClass = damage}
 weaponNumsByDef            [defID]              = integer[] slot -> weapon key
 explosionNumsByDef         [defID]              = integer[] slot -> weapon key

 baseDamages and baseExplosions omit anything with no nonzero damages.
```
