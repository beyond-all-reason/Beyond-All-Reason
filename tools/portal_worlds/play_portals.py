#!/usr/bin/env python3
"""Launch BAR portal worlds in isolated data, with an explicit visible-play option."""
import argparse
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name', nargs='?', default=time.strftime('portals-%Y%m%d-%H%M%S'))
    parser.add_argument('--game-dir', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--engine-dir', type=Path, required=True)
    parser.add_argument('--map-dir', type=Path, required=True, help='Composed map .sdd containing composition.json')
    parser.add_argument('--workspace', type=Path, required=True, help='Downloads and run output outside the game checkout')
    parser.add_argument('--normal', action='store_true', help='Ordinary BAR on the first original source map')
    parser.add_argument('--original-map-dir', type=Path, help='Original map archive directory for --normal')
    display = parser.add_mutually_exclusive_group()
    display.add_argument('--play', action='store_true', help='Open a human-vs-AI game; runs until closed')
    display.add_argument('--watch', action='store_true', help='Open an AI game; runs until closed')
    display.add_argument('--headless', action='store_true', help='Run the native headless engine without rendering')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--ai', help='BARb for ordinary play; NullAI for scripted tests')
    parser.add_argument('--ai-profile', choices=['easy', 'medium', 'hard', 'hard_aggressive'], help='Stock BARb profile for team 0')
    parser.add_argument('--opponent-profile', choices=['easy', 'medium', 'hard', 'hard_aggressive'], help='Stock BARb profile for the other teams')
    parser.add_argument('--duel-income-multiplier', type=float, default=1,
                        help='Metal and energy income factor for the first team in each region (default: 1)')
    parser.add_argument('--ai-seed', type=int, help='Reproducible stock BARb random seed')
    parser.add_argument('--test', default='none')
    parser.add_argument('--human', action='store_true', help='Use a local player offscreen for input fixtures')
    parser.add_argument('--side', choices=['Armada', 'Cortex', 'Legion'], default='Armada')
    parser.add_argument('--frames', type=int, default=18000)
    parser.add_argument('--speed', type=float, default=3)
    parser.add_argument('--seconds', type=int, default=240)
    args = parser.parse_args()
    if not math.isfinite(args.duel_income_multiplier) or args.duel_income_multiplier < 1:
        parser.error('--duel-income-multiplier must be finite and at least 1')
    game, engine, map_dir = args.game_dir.resolve(), args.engine_dir.resolve(), args.map_dir.resolve()
    layout = json.loads((map_dir / 'composition.json').read_text())
    visible = args.play or args.watch
    human = args.play or args.human or args.test == 'four'
    ai = args.ai or ('BARb' if args.test in ('none', 'ai', 'ai_match') else 'NullAI')
    if args.normal:
        region = layout['regions'][0]
        map_dir = (args.original_map_dir or map_dir.parent.parent / (region['id'] + '-source')).resolve()
        if not (map_dir / 'maps').is_dir():
            parser.error('--normal needs the first original source map; pass --original-map-dir')
        layout = dict(layout, name=region['name'], size=[region['width'], region['height']],
                      teams=[t for t in layout['teams'] if t['region'] == 1])
    run = args.workspace.resolve() / 'runs' / args.name
    run.mkdir(parents=True, exist_ok=False)
    isolation, write = run / 'isolation', run / 'write'
    for path in (isolation / 'games', isolation / 'maps', write / 'screenshots'):
        path.mkdir(parents=True)
    (isolation / 'games/BAR.sdd').symlink_to(game)
    (isolation / 'maps/worlds.sdd').symlink_to(map_dir)
    for name in ('base', 'fonts', 'AI'):
        (isolation / name).symlink_to(engine / name)
    ai_root = engine / 'AI/Skirmish' / ai
    versions = sorted(p.name for p in ai_root.iterdir() if p.is_dir())
    version = 'stable' if 'stable' in versions else versions[-1]
    options = {
        'Fullscreen': 0, 'XResolutionWindowed': 1280, 'YResolutionWindowed': 720,
        'VSync': 0 if visible else 2, 'WorkerThreadCount': 2,
        'Sound': 1 if visible else 0, 'snd_volmaster': 50 if visible else 0,
        'HangTimeout': 60, 'UseLuaMemPools': 0, 'LuaSocketEnabled': 0,
        'GroundDetail': 100, 'Shadows': 1, 'ShadowMapSize': 2048,
        'MaxParticles': 20000, 'MaxNanoParticles': 5000, 'Water': 0,
        'AdvUnitShading': 1, 'AdvMapShading': 1, 'ROAM': 1,
    }
    config = run / 'spring.conf'
    config.write_text(''.join(f'{key} = {value}\n' for key, value in options.items()))
    script = run / 'start.txt'
    port = 21000 + os.getpid() % 20000
    mode = 'off' if args.normal else 'portals'
    legion = 'experimentallegionfaction=1;' if args.side == 'Legion' or args.test == 'four' else ''
    duration = 0 if visible else args.frames
    parts = [f'''[GAME] {{
GameType=Beyond All Reason $VERSION;
MapName={layout['name']};
IsHost=1; HostIP=127.0.0.1; HostPort={port};
GameStartDelay=0; StartPosType=3; MyPlayerName=Player;
[MODOPTIONS] {{ portal_worlds={mode}; portal_worlds_test={args.test}; portal_worlds_end={duration};
portal_worlds_speed={1 if visible else args.speed}; {legion} deathmode=com; startmetal=1000; startenergy=1000;
maxspeed=100; minspeed=0.1; }}
[PLAYER0] {{ Name=Player; Spectator={0 if human else 1}; Team=0; }}
''']
    colors = ['0.2 0.6 1', '1 0.25 0.2', '0.2 1 0.65', '1 0.7 0.15',
              '0.7 0.4 1', '1 0.4 0.75', '0.2 0.9 1', '0.8 0.9 0.2']
    champions = {}
    for team, entry in enumerate(layout['teams']):
        champions.setdefault(entry['region'], team)
    income_multipliers = {team: args.duel_income_multiplier if champions[entry['region']] == team else 1
                          for team, entry in enumerate(layout['teams'])}
    for team, entry in enumerate(layout['teams']):
        x, z = entry['start']
        if not (human and team == 0):
            profile = args.ai_profile if team == 0 else args.opponent_profile
            option_values = [f'profile={profile};'] if profile else []
            if args.ai_seed is not None:
                option_values.append(f'random_seed={args.ai_seed};')
            ai_options = '[OPTIONS] { ' + ' '.join(option_values) + ' }' if option_values else ''
            parts.append(f'[AI{team}] {{ Name=Opponent{team}; ShortName={ai}; Version={version}; Team={team}; Host=0; {ai_options} }}')
        parts.append(f'[TEAM{team}] {{ TeamLeader=0; AllyTeam={team}; Side={args.side}; IncomeMultiplier={income_multipliers[team]}; RgbColor={colors[team % len(colors)]}; StartPosX={x}; StartPosZ={z}; }}')
        box = entry['boxes'][0]
        left, right = min(p[0] for p in box) / layout['size'][0], max(p[0] for p in box) / layout['size'][0]
        top, bottom = min(p[1] for p in box) / layout['size'][1], max(p[1] for p in box) / layout['size'][1]
        parts.append(f'[ALLYTEAM{team}] {{ NumAllies=0; StartRectLeft={left}; StartRectTop={top}; StartRectRight={right}; StartRectBottom={bottom}; }}')
    script.write_text('\n'.join(parts) + '\n}\n')
    command = [str(engine / ('spring-headless' if args.headless else 'spring')),
               '--isolation', '--isolation-dir', str(isolation), '--write-dir', str(write),
               '--config', str(config), '--nocolor', str(script)]
    fontconfig = run / 'fonts.conf'
    fontconfig.write_text(f'<fontconfig><dir>{engine / "fonts"}</dir><cachedir>{run / "fontcache"}</cachedir></fontconfig>')
    env = dict(os.environ, FONTCONFIG_FILE=str(fontconfig))
    if not visible:
        env.update(DISPLAY='', WAYLAND_DISPLAY='', SDL_VIDEODRIVER='offscreen', SDL_AUDIODRIVER='dummy')
    if not visible and not args.headless:
        helper = Path(__file__).parent / 'limit_swap.c'
        limiter = args.workspace.resolve() / 'limit_swap.so'
        if not limiter.exists() or limiter.stat().st_mtime < helper.stat().st_mtime:
            subprocess.run(['cc', '-O2', '-shared', '-fPIC', str(helper), '-ldl', '-o', str(limiter)], check=True)
        env.update(LD_PRELOAD=str(limiter), SPRING_PROBE_FPS='15')
    metadata = {'command': command, 'team_income_multipliers': income_multipliers, 'game_commit': subprocess.check_output(['git', '-C', str(game), 'rev-parse', 'HEAD'], text=True).strip(),
                'engine_version': subprocess.check_output([command[0], '--sync-version'], text=True).strip(),
                'options': {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()}}
    (run / 'command.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Run: {run}\nLog: {run / "console.log"}\nEngine log: {write / "infolog.txt"}\nScreenshots: {write / "screenshots"}', flush=True)
    if args.prepare_only:
        return
    with (run / 'console.log').open('w') as log:
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        timed_out = False
        try:
            code = process.wait(timeout=None if visible else args.seconds)
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            timed_out = True
            code = -1
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
        (run / 'exit.json').write_text(json.dumps({'exit_code': code, 'timed_out': timed_out}, indent=2))
    raise SystemExit(code)


if __name__ == '__main__':
    main()
