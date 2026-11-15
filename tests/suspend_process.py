from pathlib import Path
import os, signal, subprocess, time
root=Path(__file__).resolve().parents[1]
child=subprocess.Popen([str(root/'tools/Godot.app/Contents/MacOS/Godot'),'--headless','--path',str(root/'project'),'--script','res://tests/suspend_probe.gd','--','--suspend-test'], stdout=subprocess.PIPE, stderr=subprocess.PIPE,text=True)
try:
    time.sleep(1)
    os.kill(child.pid,signal.SIGSTOP)
    time.sleep(5)
    os.kill(child.pid,signal.SIGCONT)
    out,err=child.communicate(timeout=10)
    print(out.strip())
    if child.returncode: print(err[-1600:])
    raise SystemExit(child.returncode)
finally:
    if child.poll() is None:
        os.kill(child.pid,signal.SIGCONT)
        child.terminate()
        child.wait()
