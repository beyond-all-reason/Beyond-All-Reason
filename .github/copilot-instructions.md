# Beyond All Reason - Copilot Instructions

This repository contains mixed script types (LuaUI, LuaRules, BOS animation scripts, shaders, etc.).

## LUA 5.1

- Use Lua 5.1 syntax and semantics for all Lua files.

## Tooling Scope Rules

- Use `BARScriptCompiler.exe` only for BOS animation scripts (for example `.bos` sources).
- Do not use `BARScriptCompiler.exe` for `.lua` files.
- For Lua changes, validate with Lua-appropriate checks and in-engine behavior (LuaUI reload/runtime), not BOS tooling.

## Validation Expectations

- Match validator to file type before running any command.
- If uncertain about a tool's scope, ask or inspect existing project docs/workflows first.
- Prefer minimal, low-risk changes and preserve backward compatibility for saved config formats.

## Modifying local or repo equivalent copies

- Unless specifically instructed, do not also update repo equivalent or local widget copies. Keep working with the file we started prompted with.
