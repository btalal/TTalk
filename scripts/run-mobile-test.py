"""Run a native Flutter smoke test with a bounded VM/simulator startup time."""
import subprocess
import sys

command = ["flutter", "test", "integration_test/mobile_smoke_test.dart", "-d", sys.argv[1], "--no-pub"]
try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=600)
    output = result.stdout
    code = result.returncode
except subprocess.TimeoutExpired as error:
    output = error.stdout or b""
    if isinstance(output, bytes):
        output = output.decode(errors="replace")
    output += "\nNative test did not finish within 10 minutes.\n"
    code = 1
print(output, flush=True)
if code:
    detail = "\n".join(output.splitlines()[-60:])
    detail = detail.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::error::{detail}", flush=True)
sys.exit(code)
