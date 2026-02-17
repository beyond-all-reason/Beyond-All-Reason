# Raptor Hive Standoff Validation

Date run: 2026-02-17

## Goal

Validate that `cmd_ai_raptor_hive_standoff.lua`:

1. rewrites AI attack orders against `raptor_hive` into stand-off behavior,
2. does not alter unrelated gameplay command paths.

## Test assets

- Test: `luaui/Tests/cmd_ai_raptor_hive_standoff/test_cmd_ai_raptor_hive_standoff.lua`
- Headless startscript: `tools/headless_testing/startscript_raptor_hive_standoff.txt`

## Execution

From repo root:

```bash
docker compose -f tools/headless_testing/docker-compose.yml run --rm --entrypoint ./start.sh bar /bar /bar/games/BAR.sdd/tools/headless_testing/startscript_raptor_hive_standoff.txt
```

## Result

Output file: `tools/headless_testing/testlog/results.json`

- `passes`: 1
- `failures`: 0
- `tests`: 2 (`cmd_ai_raptor_hive_standoff` + `infolog`)

Recorded JSON stats:

```json
{
  "passes": 1,
  "failures": 0,
  "tests": 2
}
```

## What was validated

The automated test contains three assertions:

1. `AI -> raptor_hive` is rewritten to `MOVE` then queued `ATTACK` at a safe stand-off distance.
2. `Human -> raptor_hive` remains direct `ATTACK` (no rewrite).
3. `AI -> non-hive target` remains direct `ATTACK` (no rewrite).

These checks demonstrate the fix is active only on the intended command path, while human control and non-hive AI command behavior remain unchanged.

## CI compatibility note

The test now self-skips when the runtime does not include the required team composition
(human + non-raptor AI + Raptors team). This prevents false negatives in generic headless runs
that do not start a Raptors-mode match.
