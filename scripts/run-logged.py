"""Keep complete CI logs and expose a short, useful failure annotation."""
from collections import deque
import re
import subprocess
import sys

lines = deque(maxlen=400)
process = subprocess.Popen(sys.argv[1:], stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True)
for line in process.stdout:
    print(line, end="", flush=True)
    # SDK manager writes hundreds of progress updates; keep diagnostics instead.
    if not re.match(r"^\[[ =-]+\]\s+\d+%", line):
        lines.append(line)
code = process.wait()
if code:
    detail = "".join(lines)[-3500:]
    detail = detail.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::error::{detail}", flush=True)
sys.exit(code)
