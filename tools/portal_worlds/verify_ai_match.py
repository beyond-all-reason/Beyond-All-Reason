#!/usr/bin/env python3
"""Report unassisted AI outcomes without mistaking a timed run for a win."""
import argparse
from collections import Counter
import json
from pathlib import Path


def inspect(run):
    lines = (run / 'console.log').read_text(errors='replace').splitlines()
    metadata = json.loads((run / 'command.json').read_text())
    events = [json.loads(line.split('[BAR_AI_MATCH] ', 1)[1])
              for line in lines if '[BAR_AI_MATCH] ' in line]
    results = [event for event in events if event['event'] == 'result']
    result = results[-1] if results else None
    deaths = [event for event in events if event['event'] == 'commander_destroyed']
    openings = [event for event in events if event['event'] == 'portal_opened']
    verified = [event for event in events if event['event'] == 'death_portal_verified']
    transits = [event for event in events if event['event'] == 'physical_transit']
    errors = [line for line in lines if any(key in line for key in
              ('LUA_ERRRUN', 'Error in ', 'Segmentation fault'))]
    exit_path = run / 'exit.json'
    exit_status = json.loads(exit_path.read_text()) if exit_path.exists() else None
    normal = metadata['options']['normal']
    finished_cleanly = bool(result and exit_status and exit_status['exit_code'] == 0 and not errors)
    won = bool(result and result['outcome'] == 'game_over' and len(result['winners']) == 1)
    winners = set(result['winners']) if result else set()
    team_homes = {team['team']: team.get('home') for team in result['teams']} if result else {}
    winner_transits = [event for event in transits if event['team'] in winners]
    winner_foreign_kills = [event for event in deaths if event.get('attackerTeam') in winners
                            and event.get('attackerTeam') != event['team']
                            and event.get('region') is not None
                            and team_homes.get(event['attackerTeam']) != event['region']]
    campaign = bool(won and winner_transits and verified and winner_foreign_kills)
    return {
        'passed': finished_cleanly and (won if normal else campaign),
        'normal_game': normal,
        'finished_cleanly': finished_cleanly,
        'native_game_over_with_one_winner': won,
        'portal_campaign_completed': campaign,
        'commander_deaths': deaths,
        'portal_openings': openings,
        'death_site_portals_verified': verified,
        'physical_transits': len(transits),
        'unique_travelling_units': len({event['id'] for event in transits}),
        'transits_by_team': dict(Counter(event['team'] for event in transits)),
        'transit_unit_types': dict(Counter(event.get('unit', 'unrecorded') for event in transits)),
        'routes': [{'from': source, 'to': destination, 'count': count}
                   for (source, destination), count in sorted(
                       Counter((event['from'], event['to']) for event in transits).items())],
        'winner_transits': len(winner_transits),
        'winner_foreign_commander_kills': winner_foreign_kills,
        'result': result,
        'errors': errors,
        'exit': exit_status,
        'source': metadata,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runs', type=Path, nargs='+')
    args = parser.parse_args()
    reports = {}
    for run in args.runs:
        report = inspect(run)
        (run / 'ai-match-result.json').write_text(json.dumps(report, indent=2) + '\n')
        reports[str(run)] = report
    print(json.dumps(reports, indent=2))
    raise SystemExit(not all(report['passed'] for report in reports.values()))


if __name__ == '__main__':
    main()
