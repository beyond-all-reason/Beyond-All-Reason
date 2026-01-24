# Contributing to Beyond All Reason (BAR)

## Code Style & Standards

### General review

Your code should be clear, correct, and easy to maintain. These guidelines will help you to achieve that result, but the rest is up to you. Pull requests are not rejected according to this guide but failure to make the requested corrections will prevent them from being merged.

### Basic performance pitfalls

Know the basics of Lua and use effective best practices that are up-to-date. We use Lua 5.1, which is not the version used in many other game development corners. You might need to ignore the advice you find across the internet, generally for Love2D or Roblox and such.

Our code also uses some custom bindings for Lua 5.1 — for security, functionality, and anti-tampering — that you might be discouraged from overusing during code review.

#### Engine calls

* Minimize your calls to the engine (`Spring.CallName()`) if possible.  
* Minimize the data you pass to and receive from the engine if possible.  
  * Especially reduce the number of tables created solely for engine calls. Excessive table creations seems to cause lots of garbage collection.  
  * Prefer e.g. `GetUnitCurrentCommand` over `GetUnitCommands`.  

* Prefer to receive multi-value returns from engine calls over tables, generally. There are many functions for getting general data about a unit in a table. These are not individually expensive but are orders of magnitude more costly than the alternative.

#### Protected tables

Reading from the “Defs” tables — UnitDefs, WeaponDefs, and FeatureDefs — is more expensive than from an ordinary table. Each gadget and widget should cache the information it needs from these tables.

###### Bad code example

```lua
local function getSpeed(unitDefID)
	return UnitDefs[unitDefID].speed -- slow table access  
end
```

###### Good code example

```lua
local unitSpeed = {}

for unitDefID, unitDef in ipairs(UnitDefs) do  
	unitSpeed[unitDefID] = unitDef.speed -- cached access
end

local function getSpeed(unitDefID)  
	return unitSpeed[unitDefID] -- fast table access  
end
```

### Lua code practices

Use the correct iterator to loop over tables. Use `ipairs` for arrays and `pairs` for hash tables. Some performance-sensitive contexts might prefer `for` and/or `next`, instead.

Some of our tables contain sequential integer IDs but also include ID 0 (and/or negatives), so you cannot use `ipairs`, which starts at index 1\. The WeaponDefs table is one example that requires a for loop, e.g. `for weaponDefID = 0, #WeaponDefs do <inner loop> end`.

Reusable code should not be siloed into gadgets and widgets. For example, common math functions and identities can be added to numberfunctions.lua or in rare cases (and when you know what you are doing) directly into the `math` module.

You should prefer common functions, then, over potential shortcuts. For example, prefer `math.hypot` to `math.sqrt` for its numerical stability when you need the hypotenuse.

#### General code style

* Comments must explain reasons, not behavior. What your code does should be self-explanatory from reading the code. We want to know only “why”, not “what”.  
* Do not use magic numbers. Constant values should be declared together toward the top of the file and labeled as configurable or not, when non-obvious.  
* Do not avoid newlines in code. Add extra newlines after blocks (loops, if/then statements) to aid future readers and reviewers. You can skip some extra newlines, like between immediately-nested if/elseif/else/then/end statements.  
* Do not keep dead code. This includes all dead (unreachable), unused (not called), or removed (commented) code in any file. Delete all code not in active use.  
* Do not keep throwaway debug code. Logging invalid or unexpected state is ok, as is debug code gated behind a debug flag or modoption.  


#### Variable naming

* Use local variables often and name them using `camelCase`.  
* Use globals as necessary and name them using `PascalCase`.  
* Constants can be treated as locals or globals or named using `ALL_CAPS`.  
* Do not use abbreviations, with notable exceptions like `ID` for “identifier”.  
* Do not use mathematical shorthands, with notable exceptions like “x” coordinates.  
* Try, as possible, not to be unique. Use familiar names from similar code to your own.  
* Do not pollute method signatures with “\_” as an excluded argument to call-ins.

## Licensing and versioning

The license we prefer is “GNU GPL, v2 or later”. Code contributed outside this license falls outside the contributor guidelines so may fall afoul of the project altogether.

Expect your code to be modified. We encourage you to use release versioning and to increment versions when modifying other contributor’s gadgets/widgets. This helps to distinguish the many copies of very-similar code that are sometimes floating around.

## AI Assistance Notice

> [!IMPORTANT]
>
> If you are using **any kind of AI assistance** to contribute to BAR,
> it must be disclosed in the pull request.

Disclose the usage, along with the extent to
which AI assistance was used (e.g. docs only vs. code generation).
If PR responses are being generated by an AI, disclose that as well.

An example disclosure:

> This PR was written primarily by Claude Code.

Or a more detailed disclosure:

> I consulted ChatGPT to understand the codebase but the solution
> was fully authored manually by myself.

In a perfect world, AI assistance would produce equal or higher quality
work than any human. That isn't the world we live in today, and in most cases
it's generating slop.

When using AI assistance, we expect contributors to understand the code
that is produced and be able to answer critical questions about it. In the
end, you are responsible for all code you submit.

Please be respectful to maintainers and disclose AI assistance.
