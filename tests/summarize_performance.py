"""Summarize a resource observation without claiming an unfinished run passed."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('input', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
data = json.loads(args.input.read_text())
rows = data['samples']
if not rows:
    raise SystemExit('No samples')
first, last = rows[0], rows[-1]
elapsed = last['elapsed']-first['elapsed']
summary = {'complete':data['complete'],'seconds_observed':round(elapsed,3),
           'sample_count':len(rows),'same_process':len({r['pid'] for r in rows})==1,
           'simulation_seconds_advanced':round(last['simulation_seconds']-first['simulation_seconds'],3),
           'new_saves':last['save_sequence']-first['save_sequence'],
           'data_growth_bytes':last['data_bytes']-first['data_bytes'],
           'wake_events':last['wake_sequence']-first['wake_sequence'],
           'app_bytes':last['app_bytes'],'data_bytes':last['data_bytes'],
           'app_and_data_below_5gb':max(r['app_bytes']+r['data_bytes'] for r in rows)<5_000_000_000,
           'rss_below_3_2gb':max(r['rss_kib']*1024 for r in rows)<3_200_000_000,
           'hour_completed':bool(data['complete'] and elapsed>=3599),
           'phases':{}}
def cpu_seconds(value):
    minutes, seconds = value.split(':')
    if '-' in minutes:
        days, minutes = minutes.split('-')
        return int(days)*86400+int(minutes)*60+float(seconds)
    return int(minutes)*60+float(seconds)

for name, background in [('foreground',False),('background',True)]:
    phase = [r for r in rows if bool(r['background'])==background]
    if not phase:
        continue
    intervals = [(b['elapsed']-a['elapsed'],cpu_seconds(b['cpu_time'])-cpu_seconds(a['cpu_time']))
                 for a,b in zip(rows,rows[1:])
                 if bool(a['background'])==background and bool(b['background'])==background
                 and a['wake_sequence']==b['wake_sequence']
                 and not a['sleeping'] and not b['sleeping'] and b['elapsed']>a['elapsed']]
    average_cpu = round(100*sum(c for _,c in intervals)/sum(t for t,_ in intervals),3) if intervals else None
    summary['phases'][name] = {'sample_count':len(phase),'average_cpu_from_time_percent':average_cpu,
        'rss_mib_range':[round(f(r['rss_kib'] for r in phase)/1024,2) for f in (min,max)],
        'cpu_percent_range':[f(r['cpu_percent'] for r in phase) for f in (min,max)],
        'first_elapsed':phase[0]['elapsed'],'last_elapsed':phase[-1]['elapsed']}
if 'error' in data:
    summary['error'] = data['error']
output = json.dumps(summary,ensure_ascii=False,indent=2)+'\n'
if args.output:
    args.output.write_text(output)
print(output,end='')
