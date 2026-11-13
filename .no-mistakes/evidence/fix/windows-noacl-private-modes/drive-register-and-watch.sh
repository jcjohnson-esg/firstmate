#!/usr/bin/env bash
# Live driver: on this Windows 11 host's real Git for Windows noacl NTFS mount
# (no fakes, no PATH shims), register a custom watcher check in a disposable
# lab home with the real bin/fm-check-register.sh, then run the exact watcher
# verdict calls bin/fm-watch.sh makes per *.check.sh (fm_custom_check_registered
# and fm_custom_check_snapshot_prepare + running the snapshot) from that bin/.
# The full fm-watch.sh loop cannot start on this host: its singleton lock needs
# `ln -s`, which MSYS refuses without Windows symlink privilege.
# Usage: drive-register-and-watch.sh <bin-root> <lab-home> <label>
set -u
root=$1 lab=$2 label=$3
state="$lab/state"
rm -rf "$state"/*.check.sh "$state"/*.check-trust "$state"/.watch.lock* 2>/dev/null
printf '#!/usr/bin/env bash\nprintf "demo-custom-check-fired\\n"\n' > "$state/demo.check.sh"
chmod 0700 "$state/demo.check.sh"
echo "== [$label] code: $root/bin"
echo "== [$label] uname -s: $(uname -s)"
mount | grep -E " on /tmp | on /c " | sed 's/^/   mount: /'
echo "== [$label] chmod 0700 demo.check.sh; stat reads back: $(stat -c %a "$state/demo.check.sh")"
echo "== [$label] \$ FM_HOME=lab fm-check-register.sh demo"
FM_HOME="$lab" "$root/bin/fm-check-register.sh" demo; echo "   register exit=$?"
ls -l "$state" | sed 's/^/   /'
[ -f "$state/demo.check-trust" ] && echo "   trust file mode as stat reads it: $(stat -c %a "$state/demo.check-trust")"
echo "== [$label] watcher verdict (fm-watch.sh:4257 path)"
bash -c '
  . "$1/bin/fm-pr-lib.sh"; . "$1/bin/fm-check-lib.sh"
  if fm_custom_check_registered "$2" demo; then echo "   fm_custom_check_registered: trusted"; else echo "   fm_custom_check_registered: REJECTED (unauthenticated)"; fi
  if fm_custom_check_snapshot_prepare "$2" demo; then
    echo "   snapshot_prepare: ok; running snapshot -> $(bash "$FM_CUSTOM_CHECK_SNAPSHOT")"
    fm_custom_check_snapshot_cleanup
  else
    fm_custom_check_snapshot_cleanup
    echo "   snapshot_prepare: REJECTED -> watcher would wake: check: rejected unauthenticated state checks: $2/demo.check.sh"
  fi
' _ "$root" "$state"
leftover=$(ls -A "$state" | grep -E "fm-mode-probe|fm-custom-check\." || true)
echo "== [$label] leftover probe/snapshot files in state: ${leftover:-none}"
