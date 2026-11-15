from pathlib import Path
import json, time, subprocess
root = Path.home()/'Library/Application Support/Godot/app_userdata/温馨小世界'
start = time.monotonic()
rows = []
while True:
    elapsed = time.monotonic()-start
    life = json.loads((root/'lifecycle.json').read_text())
    envelope = json.loads((root/'saves/world.json').read_text())
    state = json.loads(envelope['payload_json'])
    result = subprocess.run(['ps','-p',str(life['pid']),'-o','rss=,%cpu='], capture_output=True,text=True)
    fields = result.stdout.split()
    row = {'elapsed':round(elapsed,1),'background':life['background'],
           'save_sequence':state['save_sequence'],'simulation_seconds':state['simulation_seconds'],
           'mode':state['resident']['mode'],'location':state['resident']['current_location'],
           'event_count':len(state['resident']['recent_events']),
           'rss_kib':int(fields[0]) if fields else None,'cpu_percent':float(fields[1]) if fields else None}
    rows.append(row)
    Path('docs/background-observation.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(row,ensure_ascii=False),flush=True)
    if elapsed>=600: break
    time.sleep(min(30,600-elapsed))
