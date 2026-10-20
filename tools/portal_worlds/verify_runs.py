#!/usr/bin/env python3
"""Verify complete BAR portal fixture assertions and process exit status."""
import argparse
import json
from pathlib import Path
import re

EXPECTED = {'four': {'BAR_PORTAL_TEST': 67, 'BAR_PORTAL_UI': 29, 'BAR_METAL_UI': 25},
            'weapons': {'BAR_WEAPON_TEST': 17}, 'barriers': {'BAR_BARRIER_TEST': 58},
            'baseline': {'BAR_PORTAL_TEST': 2, 'BAR_PORTAL_UI': 1},
            'ai': {'BAR_AI_TEST': 18}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runs', type=Path, nargs='+')
    args = parser.parse_args()
    report = {}
    for run in args.runs:
        text = (run / 'console.log').read_text(errors='replace')
        metadata = json.loads((run / 'command.json').read_text())
        fixture = metadata['options']['test']
        observed = re.findall(r'\[(BAR_PORTAL_TEST|BAR_PORTAL_UI|BAR_METAL_UI|BAR_WEAPON_TEST|BAR_BARRIER_TEST|BAR_AI_TEST)\] ASSERT (\S+) pass=(true|false)', text)
        expected = dict(EXPECTED[fixture])
        counts = {tag: sum(item[0] == tag for item in observed) for tag in expected}
        errors = [line for line in text.splitlines() if 'LUA_ERRRUN' in line or 'Error in ' in line or 'Segmentation fault' in line]
        exit_file = run / 'exit.json'
        exit_status = json.loads(exit_file.read_text()) if exit_file.exists() else None
        if exit_status is None:
            errors.append('Launcher did not record process exit status')
        passed = (counts == expected and not errors and all(value == 'true' for _, _, value in observed)
                  and exit_status is not None and exit_status['exit_code'] == 0)
        result = {'passed': passed, 'fixture': fixture, 'counts': counts,
                  'errors': errors, 'assertions': observed, 'source': metadata}
        (run / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        report[str(run)] = result
    print(json.dumps(report, indent=2))
    raise SystemExit(not all(result['passed'] for result in report.values()))


if __name__ == '__main__':
    main()
