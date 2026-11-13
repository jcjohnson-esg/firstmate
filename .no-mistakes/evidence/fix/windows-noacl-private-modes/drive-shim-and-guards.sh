#!/usr/bin/env bash
# Live driver on this host's real Git for Windows noacl NTFS mount (no fakes).
# Part 1: arm a real check-shim writer (fm-tool-update-check.sh arm), which
#   writes state/tool-updates.check.sh through shim_write and registers it.
# Part 2 (head only): adversarial guards that must stay strict on Windows.
# Usage: drive-shim-and-guards.sh <bin-root> <lab-home> <label> [guards]
set -u
root=$1 lab=$2 label=$3 guards=${4:-}
state="$lab/state"
rm -rf "$state"/* "$state"/.[!.]* 2>/dev/null
printf '%s\n' '{"tools":[{"name":"git","command":"git"}]}' > "$lab/config/watched-tools.json"
echo "== [$label] \$ FM_HOME=lab $root/bin/fm-tool-update-check.sh arm"
FM_HOME="$lab" "$root/bin/fm-tool-update-check.sh" arm; echo "   arm exit=$?"
ls -l "$state" | sed 's/^/   /'
bash -c '. "$1/bin/fm-pr-lib.sh"; . "$1/bin/fm-check-lib.sh"
  if fm_custom_check_registered "$2" tool-updates; then echo "   watcher verdict for tool-updates shim: trusted"; else echo "   watcher verdict for tool-updates shim: REJECTED"; fi' _ "$root" "$state"
echo "== [$label] re-arm (shim_write fast path compares existing shim to mode 700)"
FM_HOME="$lab" "$root/bin/fm-tool-update-check.sh" arm; echo "   re-arm exit=$?"

[ "$guards" = guards ] || exit 0
verdict() { bash -c '. "$1/bin/fm-pr-lib.sh"; . "$1/bin/fm-check-lib.sh"; fm_custom_check_registered "$2" "$3" && echo trusted || echo REJECTED' _ "$root" "$state" "$1"; }

echo "== [$label] guard A: bytes changed after registration"
printf '#!/usr/bin/env bash\nprintf ok\n' > "$state/demo.check.sh"; chmod 0700 "$state/demo.check.sh"
FM_HOME="$lab" "$root/bin/fm-check-register.sh" demo
echo "   before tamper: $(verdict demo)"
printf '#!/usr/bin/env bash\nprintf evil\n' > "$state/demo.check.sh"
echo "   after tamper (expect REJECTED): $(verdict demo)"

echo "== [$label] guard B: hard-linked check (link count 2) is refused"
rm -f "$state/demo.check-trust"
printf '#!/usr/bin/env bash\nprintf ok\n' > "$state/hl.check.sh"
ln "$state/hl.check.sh" "$lab/hl-alias"
echo "   link count: $(stat -c %h "$state/hl.check.sh")"
FM_HOME="$lab" "$root/bin/fm-check-register.sh" hl; echo "   register exit=$? (expect 1)"
rm -f "$lab/hl-alias" "$state/hl.check.sh"

echo "== [$label] guard C: probe cannot be created (state dir denies file creation) keeps strict"
printf '#!/usr/bin/env bash\nprintf ok\n' > "$state/ro.check.sh"
FM_HOME="$lab" "$root/bin/fm-check-register.sh" ro >/dev/null && echo "   pre-registered ro while writable: $(verdict ro)"
winstate=$(cygpath -w "$state")
MSYS2_ARG_CONV_EXCL="*" icacls "$winstate" /deny "$USERNAME:(AD,WD)" >/dev/null && echo "   icacls: denied add-file/add-subdir on state for $USERNAME"
if ( : > "$state/.write-test" ) 2>/dev/null; then echo "   WARNING: deny did not take effect"; rm -f "$state/.write-test"; fi
echo "   watcher verdict with unwritable state (expect REJECTED, probe cannot run): $(verdict ro)"
MSYS2_ARG_CONV_EXCL="*" icacls "$winstate" /remove:d "$USERNAME" >/dev/null && echo "   icacls: deny removed"
echo "   watcher verdict after restoring write (expect trusted): $(verdict ro)"
leftover=$(ls -A "$state" | grep -E "fm-mode-probe" || true)
echo "== [$label] leftover probe files: ${leftover:-none}"
