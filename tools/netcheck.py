"""Network check: a headless host + client (--netcheck), prints their [NetCheck] lines.

    python tools/netcheck.py [port] [--all]

Kills both process trees afterwards (the console exe starts the real Godot as a child,
so a plain timeout would leave it running and holding the port).
--all prints every log line except engine noise.
"""
import os
import subprocess
import sys
import threading
import time

G = os.environ.get("GODOT", r"C:\Users\alexc\AppData\Local\Microsoft\WinGet\Packages"
                   r"\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
port = next((a for a in sys.argv[1:] if a.isdigit()), "7792")
show_all = "--all" in sys.argv
NOISE = ("Unreferenced static", "string_name.cpp", "leaked at exit", "PagedAllocator", "XR:")


EXTRA = ["--verbose"] if "--verbose" in sys.argv else []


def start(args):
    return subprocess.Popen([G, "--headless", "--path", ROOT] + EXTRA + ["--"] + args, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")


def kill_tree(p):
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)


all_host = []


def collect(p, name, out, t0):
    for line in p.stdout:
        line = line.rstrip()
        if name == "host":
            all_host.append(line)
        if any(n in line for n in NOISE):
            continue
        if show_all or "[NetCheck]" in line or "SCRIPT ERROR" in line or "ERROR:" in line or "[Net]" in line:
            out.append(f"{time.time() - t0:6.1f}s {name}: {line[:220]}")


t0 = time.time()
lines = []
host = start(["--host", f"--port={port}", "--netcheck", "--name=Host"])
threading.Thread(target=collect, args=(host, "host", lines, t0), daemon=True).start()
# Start the client once the host has its world loaded + baked (point 47: the bigger map loads for ~20 s under load).
for _ in range(240):
    if any("Navigation mesh baked" in l for l in all_host):
        break
    time.sleep(0.5)
time.sleep(1)
client = start([f"--join=127.0.0.1", f"--port={port}", "--netcheck", "--name=B"])
threading.Thread(target=collect, args=(client, "client", lines, t0), daemon=True).start()
try:
    client.wait(timeout=150)
    host.wait(timeout=150)
except subprocess.TimeoutExpired:
    lines.append("TIMEOUT")
finally:
    lines.append(f"client exit code {client.poll()}, host exit code {host.poll()}")
    kill_tree(client)
    kill_tree(host)
time.sleep(0.5)
print("\n".join(lines))
