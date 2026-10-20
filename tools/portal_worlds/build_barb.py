#!/usr/bin/env python3
"""Build native BARb portal missions into a new isolated AI installation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine-source', type=Path, required=True, help='Configured RecoilEngine checkout')
    parser.add_argument('--ai-source', type=Path, required=True, help='Clean BARb checkout with portal missions')
    parser.add_argument('--output', type=Path, required=True, help='New AI root; existing installations are never overwritten')
    parser.add_argument('--jobs', type=int, default=2, help='Build jobs and container CPU limit (default: 2)')
    args = parser.parse_args()
    engine, source, output = args.engine_source.resolve(), args.ai_source.resolve(), args.output.resolve()
    if args.jobs < 1:
        parser.error('--jobs must be positive')
    if output.exists():
        parser.error('--output must not exist; choose a new directory to preserve any running games')
    if not (source / 'src/circuit/setup/PortalWorld.cpp').is_file():
        parser.error('--ai-source does not contain native portal missions')
    if subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain']):
        parser.error('Commit local AI source changes before building, so the installation has an exact source revision')
    build = engine / 'build-amd64-linux'
    installed = build / 'install/AI'
    if not (installed / 'Skirmish/BARb/stable/AIInfo.lua').is_file():
        parser.error('Build and install the Linux engine first; its AI interface and assets are required')
    source_revision = revision(source)
    # The engine source and its stock AI remain unchanged. Override only the
    # read-only source mount used to compile the separate native AI target.
    extra = shlex.join(['-v', f'{source}:/build/src/AI/Skirmish/BARb:ro', f'--cpus={args.jobs}'])
    env = dict(os.environ)
    env['CONTAINER_RUNTIME_EXTRA_ARGS'] = ' '.join(filter(None, [env.get('CONTAINER_RUNTIME_EXTRA_ARGS'), extra]))
    subprocess.run([str(engine / 'docker-build-v2/build.sh'), '--compile', '-j', str(args.jobs),
                    'linux', '--target', 'BARb'], cwd=engine, env=env, check=True)
    if revision(source) != source_revision or subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain']):
        parser.error('AI source changed during the build; retry with a stable checkout')
    binary = build / 'AI/Skirmish/BARb/data/libSkirmishAI.so'
    (output / 'Skirmish').mkdir(parents=True)
    (output / 'Interfaces').symlink_to(installed / 'Interfaces', target_is_directory=True)
    for other in (installed / 'Skirmish').iterdir():
        if other.name != 'BARb':
            (output / 'Skirmish' / other.name).symlink_to(other, target_is_directory=True)
    target = output / 'Skirmish/BARb/stable'
    shutil.copytree(installed / 'Skirmish/BARb/stable', target)
    shutil.copytree(source / 'data', target, dirs_exist_ok=True)
    shutil.copy2(binary, target / binary.name)
    record = {'source': str(source), 'source_commit': source_revision,
              'engine_source': str(engine), 'engine_commit': revision(engine),
              'library_sha256': hashlib.sha256((target / binary.name).read_bytes()).hexdigest()}
    (output / 'build-info.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'Native portal AI: {output}\nLaunch with --ai-dir {shlex.quote(str(output))}', flush=True)


if __name__ == '__main__':
    main()
