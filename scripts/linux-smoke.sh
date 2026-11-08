#!/usr/bin/env bash
set -euo pipefail
# Run in an isolated desktop session, never in an end-user account.
export XDG_DATA_HOME="$(mktemp -d)"
export XDG_CONFIG_HOME="$(mktemp -d)"
export XDG_RUNTIME_DIR="$(mktemp -d)"
chmod 700 "$XDG_RUNTIME_DIR"
export LIBGL_ALWAYS_SOFTWARE=1
export GDK_BACKEND=x11
printf '%s' 'ci-ephemeral-keyring' | gnome-keyring-daemon --unlock --components=secrets
mkdir -p "${TTALK_SMOKE_OUTPUT:-/tmp/ttalk-smoke}"
log="${TTALK_SMOKE_OUTPUT:-/tmp/ttalk-smoke}/startup.log"
ttalk > "$log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 45); do
  kill -0 "$pid" 2>/dev/null || { cat "$log"; exit 1; }
  if xdotool search --onlyvisible --name 'Messagerie chiffrée' > /tmp/ttalk-window-id 2>/dev/null; then
    break
  fi
  sleep 1
done
test -s /tmp/ttalk-window-id
# Only one real window may exist after activating a second process.
ttalk >> "$log" 2>&1 &
second=$!
sleep 3
if kill -0 "$second" 2>/dev/null; then
  echo 'Second application process stayed alive'; kill "$second"; exit 1
fi
wait "$second"
test "$(xdotool search --onlyvisible --name 'Messagerie chiffrée' | wc -l)" -eq 1
if command -v import >/dev/null; then
  import -window root "${TTALK_SMOKE_OUTPUT:-/tmp/ttalk-smoke}/desktop.png"
fi
kill -0 "$pid"
cat "$log"
