"""Read-only, resumable resource observations of the existing world process."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--seconds', type=float, default=3600)
parser.add_argument('--interval', type=float, default=30)
parser.add_argument('--output', type=Path, default=Path('docs/performance-observation.json'))
parser.add_argument('--app', type=Path, default=Path('build/温馨小世界.app'))
args = parser.parse_args()
root = Path.home()/'Library/Application Support/Godot/app_userdata/温馨小世界'
app = args.app.expanduser().resolve()
if not (app/'Contents/Info.plist').is_file():
    parser.error('--app must identify the application being observed')

def size(path):
    return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())

start = time.monotonic()
rows = []
initial_pid = None
try:
    while True:
        life = json.loads((root/'lifecycle.json').read_text())
        if initial_pid is None:
            initial_pid = life['pid']
        if life['pid'] != initial_pid:
            raise RuntimeError('Process changed; end this observation instead of mixing sessions.')
        envelope = json.loads((root/'saves/world.json').read_text())
        payload = envelope['payload_json']
        if hashlib.sha256(payload.encode()).hexdigest() != envelope['sha256']:
            raise RuntimeError('Save checksum mismatch')
        state = json.loads(payload)
        process = subprocess.run(['ps','-p',str(initial_pid),'-o','rss=,%cpu=,time='], capture_output=True,text=True,check=True)
        fields = process.stdout.split()
        if len(fields) != 3:
            raise RuntimeError('Unable to read process resource metrics')
        row = dict(elapsed=round(time.monotonic()-start,3),pid=initial_pid,
                   background=life['background'],sleeping=life['sleeping'],wake_sequence=life['wake_sequence'],
                   rss_kib=int(fields[0]),cpu_percent=float(fields[1]),cpu_time=fields[2],
                   save_sequence=state['save_sequence'],simulation_seconds=state['simulation_seconds'],
                   data_bytes=size(root),app_bytes=size(app))
        rows.append(row)
        args.output.write_text(json.dumps({'complete':False,'samples':rows},ensure_ascii=False,indent=2)+'\n')
        print(json.dumps(row),flush=True)
        if row['elapsed'] >= args.seconds:
            break
        time.sleep(min(args.interval,args.seconds-row['elapsed']))
except Exception as exc:
    args.output.write_text(json.dumps({'complete':False,'error':str(exc),'samples':rows},ensure_ascii=False,indent=2)+'\n')
    raise
args.output.write_text(json.dumps({'complete':True,'samples':rows},ensure_ascii=False,indent=2)+'\n')
