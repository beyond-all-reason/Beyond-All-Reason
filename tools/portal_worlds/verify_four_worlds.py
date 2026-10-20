#!/usr/bin/env python3
"""Validate authored map data and observed engine assertions, not just successful startup."""
import argparse
import array
import json
from pathlib import Path
import re
import struct
from map_sources import map_info
from portal_paths import ROOT, WORKSPACE
from build_portal_worlds import read_tiles, FMT


def terrain_checks():
    target = WORKSPACE/'content/maps/portal_worlds_v3.sdd'
    world = json.loads((target/'composition.json').read_text())
    manifest = json.loads((ROOT/'portal_maps.json').read_text())
    raw = (target/'maps/worlds.smf').read_bytes()
    h = struct.unpack_from(FMT,raw)
    heights = array.array('H')
    heights.frombytes(raw[h[10]:h[10]+(h[3]+1)*(h[4]+1)*2])
    smt, count, indices = read_tiles(target,raw,h)
    checks = {'world_dimensions': world['size']==[h[3]*8,h[4]*8], 'four_native_maps': len(world['regions'])==4}
    for region, entry in zip(world['regions'],manifest['maps']):
        source = WORKSPACE/entry['source']
        native = next((source/'maps').glob('*.smf')).read_bytes()
        nh = struct.unpack_from(FMT,native)
        info = map_info(source)
        low, high = info.get('smf',{}).get('minheight',nh[8]),info.get('smf',{}).get('maxheight',nh[9])
        values = array.array('H')
        values.frombytes(native[nh[10]:nh[10]+(nh[3]+1)*(nh[4]+1)*2])
        error = 0
        for z in range(nh[4]+1):
            for x in range(nh[3]+1):
                old = low+values[z*(nh[3]+1)+x]*(high-low)/65535
                new = h[8]+heights[(region['z0']//8+z)*(h[3]+1)+region['x0']//8+x]*(h[9]-h[8])/65535
                error = max(error,abs(old-new))
        checks[region['id']+'_native_8x8'] = nh[3:5]==(512,512)
        checks[region['id']+'_height_preserved'] = error<.01
        original_tiles, _, native_indices = read_tiles(source,native,nh)
        equal=True
        for z in range(nh[4]//4):
            for x in range(nh[3]//4):
                a=native_indices[z*(nh[3]//4)+x]
                b=indices[(region['z0']//32+z)*(h[3]//4)+region['x0']//32+x]
                if original_tiles[a*680:(a+1)*680]!=smt[b*680:(b+1)*680]: equal=False;break
        checks[region['id']+'_tiles_and_mips_preserved'] = equal
    checks['start_positions_in_assigned_regions'] = all(any(r['x0']<=t['start'][0]<=r['x1'] and r['z0']<=t['start'][1]<=r['z1'] for i,r in enumerate(world['regions'],1) if i==t['region']) for t in world['teams'])
    return checks


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('runs',nargs='*')
    parser.add_argument('--output',type=Path,default=WORKSPACE/'four-worlds-validation.json')
    args=parser.parse_args()
    checks=terrain_checks()
    results={}
    for name in args.runs:
        run=WORKSPACE/'runs'/name
        log=(run/'console.log').read_text(errors='replace')
        observed=re.findall(r'\[(FOUR_TEST|FOUR_UI|WEAPON_TEST|COMBAT_TEST|COMBAT_UI|LAYOUT_TEST|LAYOUT_UI|ISOLATION_TEST|MECHANICS_TEST|FULL_MECHANICS|BARRIER_TEST|REPLACEMENTS_TEST|ORDERS_TEST)\] ASSERT (\S+) pass=(true|false)',log)
        passed={tag+':'+key:value=='true' for tag,key,value in observed}
        errors=[line for line in log.splitlines() if 'LUA_ERRRUN' in line or ('Error in ' in line and 'f=-000001' not in line)]
        passed['no_failed_assertion']=all(value=='true' for _,_,value in observed)
        passed['clean_exit']=json.loads((run/'exit.json').read_text())['exit_code']==0
        passed['no_runtime_errors']=not errors
        if '[FOUR_TEST]' in log:
            passed['five_command_transits']=sum(key.startswith('explicit_transit_') for tag,key,_ in observed if tag=='FOUR_TEST')==5
            passed['sixteen_bidirectional_transits']=sum(key.startswith('bidirectional_edge_') for tag,key,_ in observed if tag=='FOUR_TEST')==16
            passed['all_eight_views_captured']=sum(key.startswith('capture_saved_') for tag,key,_ in observed if tag=='FOUR_UI')==8
        if '[BARRIER_TEST]' in log:
            passed['barrier_checks_complete']=sum(tag=='BARRIER_TEST' for tag,_,_ in observed)==58
        if '[WEAPON_TEST]' in log:
            passed['seventeen_strategic_checks']=len(observed)==17
        if '[MECHANICS_TEST]' in log:
            options=json.loads((run/'command.json').read_text())['options']
            expected=7 if options['test']=='mechanics-baseline' else 30
            passed['mechanics_checks_complete']=sum(tag=='MECHANICS_TEST' for tag,_,_ in observed)==expected
        if '[FULL_MECHANICS]' in log:
            completed = re.search(r'\[FULL_MECHANICS\] DONE checks=(\d+) failures=(\d+)', log)
            passed['extended_mechanics_complete'] = bool(completed and int(completed[1]) == sum(tag == 'FULL_MECHANICS' for tag, _, _ in observed) and int(completed[2]) == 0)
        if '[REPLACEMENTS_TEST]' in log:
            completed = re.search(r'\[REPLACEMENTS_TEST\] DONE checks=(\d+) failures=(\d+)', log)
            passed['replacements_complete'] = bool(completed and int(completed[1]) == sum(tag == 'REPLACEMENTS_TEST' for tag, _, _ in observed) and int(completed[2]) == 0)
        if '[ORDERS_TEST]' in log:
            completed = re.search(r'\[ORDERS_TEST\] DONE checks=(\d+) failures=(\d+)', log)
            passed['orders_complete'] = bool(completed and int(completed[1]) == sum(tag == 'ORDERS_TEST' for tag, _, _ in observed) and int(completed[2]) == 0)
        if '[ISOLATION_TEST]' in log:
            passed['isolation_checks_complete']=sum(tag=='ISOLATION_TEST' for tag,_,_ in observed)==104
        if '[COMBAT_TEST]' in log:
            passed['sixteen_weapon_damage_checks']=sum(tag=='COMBAT_TEST' for tag,_,_ in observed)==16
            passed['twelve_combat_views']=sum(tag=='COMBAT_UI' for tag,_,_ in observed)==12
        if '[LAYOUT_TEST]' in log:
            passed['three_alternate_layout_views']=sum(key.startswith('capture_') for tag,key,_ in observed if tag=='LAYOUT_UI')==3
            passed['six_alternate_layout_routes']=sum(key.startswith('route_') for tag,key,_ in observed if tag=='LAYOUT_TEST')==6
        if any(tag.endswith('_UI') or tag=='MECHANICS_TEST' for tag,_,_ in observed):
            renderer=re.search(r'GL renderer\s*:\s*([^\n]+)',log)
            passed['gpu_renderer']=bool(renderer and not re.search(r'llvmpipe|softpipe|swrast|software rasterizer',renderer.group(1),re.I))
        if not observed:
            stats=re.findall(r'\[ZKDUELS\] TEAM frame=(\d+) team=(\d+) region=(\d+) units=(\d+) created=(\d+) factories=(\d+) here=(\d+) away=(\d+) damage=([\d.]+)',log)
            passed['ten_minutes_of_simulation']=bool(stats) and max(int(row[0]) for row in stats)>=18000
            for team in range(8):
                rows=[row for row in stats if int(row[1])==team]
                passed['team_'+str(team)+'_built_factory']=bool(rows) and max(int(row[5]) for row in rows)>0
                passed['team_'+str(team)+'_fought']=bool(rows) and max(float(row[8]) for row in rows)>1000
            if name=='four-circuit-final-long':
                passed['thirty_minutes_of_simulation']=bool(stats) and max(int(row[0]) for row in stats)>=54000
                passed['natural_commander_death_opened_portal']='[ZKDUELS] OPEN ' in log
                passed['circuit_used_portal']='[ZKDUELS] TRANSIT ' in log
        checks[name]=all(passed.values())
        results[name]={'checks':passed,'errors':errors}
    report={'passed':all(checks.values()),'checks':checks,'runs':results}
    args.output.write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
    raise SystemExit(not report['passed'])


if __name__=='__main__': main()
