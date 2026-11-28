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
    engine_revision = revision(engine)
    ai_build = output.parent / '.cache/barb-native-build'
    marker = ai_build / 'portal-build-source.json'
    cache_record = {'kind': 'bar-portal-native-ai-build-v1', 'source': str(source),
                    'source_commit': source_revision, 'engine_source': str(engine),
                    'engine_commit': engine_revision}
    if ai_build.exists() and any(ai_build.iterdir()):
        if not marker.is_file() or json.loads(marker.read_text()).get('kind') != cache_record['kind']:
            parser.error(f'Dedicated AI build directory is not owned by this helper: {ai_build}')
        if json.loads(marker.read_text()) != cache_record:
            # Only this helper's generated cache is discarded. Object files from
            # a different source mount must not be reused by timestamp alone.
            shutil.rmtree(ai_build)
    ai_build.mkdir(parents=True, exist_ok=True)
    marker.write_text(json.dumps(cache_record, indent=2) + '\n')
    # Use the engine's Docker toolchain and build scripts, with a dedicated
    # output mount. AI objects from an overridden source must never replace the
    # normal engine build's objects or Ninja configuration.
    digest = subprocess.check_output(['bash', '-c',
        'source "$1"; printf "%s" "${image_version[amd64-linux]}"', 'barb-build',
        str(engine / 'docker-build-v2/images_versions.sh')], text=True).strip()
    image = os.environ.get('CONTAINER_IMAGE') or f'ghcr.io/beyond-all-reason/recoil-build-amd64-linux@{digest}'
    info = json.loads(subprocess.check_output(['docker', 'info', '--format', '{{json .}}'], text=True))
    container = ['docker', 'run', '--rm', f'--cpus={args.jobs}',
                 '-v', f'{engine}:/build/src:ro',
                 '-v', f'{source}:/build/src/AI/Skirmish/BARb:ro',
                 '-v', f'{ai_build}:/build/out:rw',
                 '-v', f'{engine / ".cache/ccache-amd64-linux"}:/build/cache:rw',
                 '-w', '/build/src/docker-build-v2/scripts',
                 '-e', f'CMAKE_BUILD_PARALLEL_LEVEL={args.jobs}']
    rootless = any('rootless' in option for option in info.get('SecurityOptions', []))
    if not rootless and info.get('OperatingSystem') != 'Docker Desktop':
        container += ['--user', f'{os.getuid()}:{os.getgid()}',
                      '-v', '/etc/passwd:/etc/passwd:ro', '-v', '/etc/group:/etc/group:ro']
    git_dir = subprocess.check_output(['git', '-C', str(engine), 'rev-parse', '--absolute-git-dir'], text=True).strip()
    common = subprocess.check_output(['git', '-C', str(engine), 'rev-parse', '--path-format=absolute', '--git-common-dir'], text=True).strip()
    if git_dir != common:
        container += ['-v', f'{common}:{common}:ro']
    if not all((ai_build / name).is_file() for name in ('CMakeCache.txt', 'build.ninja')):
        subprocess.run(container + [image, 'bash', './configure.sh'], check=True)
    subprocess.run(container + [image, 'bash', './compile.sh', '--target', 'BARb'], check=True)
    if revision(source) != source_revision or subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain']):
        parser.error('AI source changed during the build; retry with a stable checkout')
    binary = ai_build / 'AI/Skirmish/BARb/data/libSkirmishAI.so'
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
              'engine_source': str(engine), 'engine_commit': engine_revision, 'build_directory': str(ai_build),
              'library_sha256': hashlib.sha256((target / binary.name).read_bytes()).hexdigest()}
    (output / 'build-info.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'Native portal AI: {output}\nLaunch with --ai-dir {shlex.quote(str(output))}', flush=True)


if __name__ == '__main__':
    main()
