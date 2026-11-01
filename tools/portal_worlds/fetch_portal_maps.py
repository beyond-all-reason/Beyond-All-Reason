#!/usr/bin/env python3
"""Fetch original maps named by a composition manifest, with archive checksums."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import urllib.parse
import urllib.request
from portal_paths import ROOT, WORKSPACE


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--manifest',type=Path,default=ROOT/'portal_maps.json')
    args=parser.parse_args()
    manifest=json.loads(args.manifest.read_text())
    (WORKSPACE/'content').mkdir(parents=True,exist_ok=True)
    for entry in manifest['maps']:
        source=WORKSPACE/entry['source']
        if list((source/'maps').glob('*.smf')):
            print(entry['name']+': original source is present')
            continue
        record=entry.get('archive')
        if record is None:
            query=urllib.parse.urlencode({'category':'map','springname':entry['name']})
            with urllib.request.urlopen('https://springfiles.springrts.com/json.php?'+query,timeout=45) as response:
                records=json.load(response)
            assert len(records)==1, 'Ambiguous or missing map: '+entry['name']
            record=records[0]
        record=dict(record, springname=entry['name'])
        filename=record['filename']
        assert Path(filename).name==filename and Path(filename).suffix in ('.sd7','.sdz')
        archive=WORKSPACE/'content'/filename
        if not archive.exists():
            temporary=archive.with_suffix('.download')
            print(entry['name']+': downloading '+filename, flush=True)
            with urllib.request.urlopen(record['mirrors'][0], timeout=45) as response, temporary.open('wb') as output:
                shutil.copyfileobj(response, output)
            assert hashlib.md5(temporary.read_bytes()).hexdigest()==record['md5'], 'Archive checksum mismatch: '+filename
            temporary.rename(archive)
        assert hashlib.md5(archive.read_bytes()).hexdigest()==record['md5'], 'Archive checksum mismatch: '+filename
        archive.with_suffix('.provenance.json').write_text(json.dumps(record,indent=2))
        subprocess.run(['7z','x','-y','-mmt=2','-o'+str(source),str(archive)],check=True)
        print(entry['name']+': downloaded and verified '+record['md5'], flush=True)


if __name__=='__main__':main()
