# Beyond All Reason - Copilot Instructions

This repository contains mixed script types (LuaUI, LuaRules, BOS animation scripts, shaders, etc.).

## Model Context Policy

- Assume local agents may not have prior BAR/Recoil domain knowledge oposed to frontier models.
- For local agents, include enough repository-specific context in prompts to avoid incorrect assumptions.
- Prefer retrieval-first behavior: inspect nearby files and anchors before proposing architecture-level changes.

## Local-Agent Bootstrap Workflow

Before editing code, local agents should:

1. Identify subsystem: LuaUI widget, LuaRules gadget, AI script, shader, or BOS.
2. Identify execution domain: synced vs unsynced (if applicable).
3. Read 2-4 relevant nearby files to match local conventions.
4. Reuse canonical constants/options instead of re-defining values.
5. Make minimal changes first, then expand only if required.

## LUA 5.1

- Use Lua 5.1 syntax and semantics for all Lua files.
- The game runs on the Recoil engine (which is a fork of SpringRTS engine).
- The engine Lua API can be found at https://recoilengine.org/docs/lua-api
- Performance is really important for us, so avoid unnecessary table allocations, excessive function calls, and other performance pitfalls. Use local variables and functions where appropriate to reduce global lookups.
- 200 local variables is the maximum number of local variables allowed in a single function. If you start approaching this limit, consider refactoring your code into smaller functions or using tables to group related data.
- 60 upvalues is the maximum number of upvalues allowed in a single function. If you start approaching this limit, consider refactoring your code into smaller functions or using tables to group related data.

## Lua Runtime and Safety

- Be explicit about synced vs unsynced behavior and avoid cross-domain assumptions.
- Preserve deterministic behavior in synced code; avoid non-deterministic sources there.
- Treat per-frame callins as hot paths; optimize for low allocation and low overhead.
- Avoid changing networked/game-state semantics unless explicitly requested.

## Performance Checklist (Lua/UI/Gadgets)

Before finalizing:

- Avoid per-frame table allocations where feasible.
- Cache frequent global and API lookups in locals.
- Prefer incremental updates over full scans each frame.
- Avoid unnecessary string processing in hot loops.
- Keep function boundaries clear if approaching local/upvalue limits.
- Keep changes simple and measurable rather than broad refactors.

## OpenGL

- Where possible use gl 4.5+ features and avoid deprecated functionality. Use modern OpenGL practices, such as buffer objects, vertex array objects, and shaders, to improve performance and maintainability. Regarding shaders try using "#version 420" or higher
- When using geometry shaders, ensure that they are used appropriately and efficiently, as they can introduce performance overhead if not used correctly. Avoid excessive use of geometry shaders for simple tasks that can be accomplished with vertex or fragment shaders. Also use a no geometry shader fallback path for hardware/software that does not support geometry shaders, try and test compile first before using the fallback path.

## Tooling Scope Rules

- Use `BARScriptCompiler.exe` only for BOS animation scripts (for example `.bos` sources).
- Do not use `BARScriptCompiler.exe` for `.lua` files.
- For Lua changes, validate with Lua-appropriate checks and in-engine behavior (LuaUI reload/runtime), not BOS tooling.

## Validation Matrix

- `.lua` (LuaUI/LuaRules/AI): validate with Lua-appropriate checks and in-engine runtime behavior.
- `.bos`: validate with `BARScriptCompiler.exe`.
- Shader files: validate compile path and runtime fallback behavior when applicable.
- RmlUi files (`.rml`, `.rcss`): validate in-engine UI behavior and performance-sensitive interactions.

## Validation Expectations

- Match validator to file type before running any command.
- If uncertain about a tool's scope, ask or inspect existing project docs/workflows first.
- Prefer minimal, low-risk changes and preserve backward compatibility for saved config formats.

## Compatibility and Data Ownership

- Preserve backward compatibility for saved config formats and widget options.
- Prefer canonical shared sources (for example constants/options) over local duplication.
- Do not silently change serialization or persistent data shapes.
- If a behavior change is required, document it in the change summary.

## Modifying local or repo equivalent copies

- Unless specifically instructed, do not also update repo equivalent or local widget copies. Keep working with the file we started prompting with.

## Preferred and Avoided Patterns

Preferred:

- Follow nearby style and naming in the same subsystem.
- Keep patches narrowly scoped and easy to review.
- Reuse existing utilities before introducing new abstractions.

Avoid:

- Large cross-subsystem refactors without explicit request.
- Re-implementing existing helpers/constants locally.
- Adding expensive per-frame work in render/update callins.

## RmlUi interface framework

- When working with the RmlUi interface framework, follow the RmlUi syntax and semantics, but always optimize for performance, meaning avoid unnecessary DOM updates, reflows, and excessive event handling and shadow DOM usage. Use the RmlUi API for all interface interactions. Where possible use absolute positioning and fixed layouts to reduce layout recalculations. Avoid using complex CSS selectors and prefer class-based styling for better performance. Use RmlUi's built-in event handling system instead of relying on external libraries or custom event handling code.
- RmlUi practices and instructions for this repository: luaui/RmlWidgets/agents.md
- Engine implemented RmlUi Lua documentation: https://recoilengine.org/docs/lua-api/#RmlUi
- RmlUi official documentation (might be ahead): https://github.com/mikke89/RmlUiDoc/tree/master/pages/rml
