# BAR portal launcher

See [setup and mechanics](../../docs/portal-worlds.md). The launcher consumes a
composed `.sdd` map and this checkout. Downloads and generated media remain in a
separate workspace. Use `--play` for an interactive match; automated runs stay
offscreen. The small `limit_swap.c` helper is compiled into the workspace for
15 FPS offscreen rendering and is unused for visible play.

```sh
python3 play_portals.py --help
python3 verify_runs.py /path/workspace/runs/portal-test
```

AI assistance: OpenAI Codex prepared these prototype tools and their checks.

Automated BAR checks default to the graphical engine with SDL offscreen.
`--headless` uses the native headless executable. The `ai_match` observer and
`verify_ai_match.py` distinguish an unassisted native victory from a timed run;
see the gameplay document for a complete invocation.
