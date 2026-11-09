#!/usr/bin/env bash
# Drive fm_harness_ancestry_pids / fm_harness_ancestry_pid from inside real
# Cygwin process chains whose executables are harness-named copies of bash.exe,
# at the target worktree and at base commit 14d06b04, and compare.
WT=$1 BASE=$2 SCR=$3
H=$SCR/h; mkdir -p "$H/codex"
cp /usr/bin/bash.exe "$H/claude.exe"; cp /usr/bin/bash.exe "$H/codex/bash.exe"
cat > "$SCR/walker.sh" <<'W'
. "$1/fm-session-lock-lib.sh"
s=$EPOCHREALTIME; pids=$(fm_harness_ancestry_pids); rc=$?; e=$EPOCHREALTIME
outer=$(fm_harness_ancestry_pid)
chain=""; for p in $pids; do chain="$chain $p:$(tr '\0' ' ' </proc/$p/exename 2>/dev/null)"; done
printf 'rc=%s pids=[%s] outermost=[%s] walk_ms=%d\n' "$rc" "$(echo $pids)" "$outer" $(( (${e/./}-${s/./})/1000 ))
printf '   matched:%s\n' "$chain"
W
run() {  # <label> <libdir>
  local L=$2 W=$SCR/walker.sh C=$H/claude.exe X=$H/codex/bash.exe
  case $1 in
    claude-run) "$C" -c "\"$C\" -c 'bash \"$W\" \"$L\"; :'; :" ;;
    claude-gap) "$C" -c "bash -c '\"$C\" -c \"bash $W $L; :\"; :'; :" ;;
    codex-path) "$X" -c "bash '$W' '$L'; :" ;;
    no-harness) bash -c "bash '$W' '$L'; :" ;;
  esac
}
for sc in claude-run claude-gap codex-path no-harness; do
  echo "== $sc"
  t=$(run $sc "$WT/bin"); b=$(run $sc "$BASE/bin")
  echo " target: $t"; echo " base  : $b"
  # pids differ per run; compare shape: count of matched pids and matched exenames
  ts=$(printf '%s\n' "$t" | sed -n 's/.*matched://p' | sed 's/[0-9]*://g'); bs=$(printf '%s\n' "$b" | sed -n 's/.*matched://p' | sed 's/[0-9]*://g')
  trc=${t%% *}; brc=${b%% *}
  [ "$ts" = "$bs" ] && [ "$trc" = "$brc" ] && echo " SAME VERDICT: rc ${trc#rc=}, matched [$ts]" || echo " VERDICT MISMATCH"
done
