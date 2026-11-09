#!/usr/bin/env bash
# Parity: fm_proc_info at target via the new /proc route, at target forced onto
# the ps route (FM_PROC_ROOT_OVERRIDE -> empty dir), and at base commit 14d06b04.
WT=$1 BASE=$2 SCR=$3
mkdir -p "$SCR/empty" "$SCR/dir with  space"
cp /usr/bin/sleep.exe "$SCR/dir with  space/sl  eep.exe"
probe() {  # <label> <libdir> <override> <pid>
  bash -c '
    . "$1/fm-session-lock-lib.sh"
    [ -n "$2" ] && export FM_PROC_ROOT_OVERRIDE=$2
    s=$EPOCHREALTIME; fm_proc_info "$3"; rc=$?; e=$EPOCHREALTIME
    printf "rc=%s comm=[%s] args=[%s] ppid=[%s] ms=%d\n" "$rc" "$FM_PROC_COMM" "$FM_PROC_ARGS" "$FM_PROC_PPID" $(( (${e/./}-${s/./})/1000 ))
  ' _ "$2" "$3" "$4"
}
bash -c 'sleep 120; :' "a  b" "   lead" "tab	in" "trail   " & p1=$!
"$SCR/dir with  space/sl  eep.exe" 120 & p2=$!
bash -c 'sleep 120; :' $'first line\nsecond   line' & p3=$!
ping -n 120 127.0.0.1 >/dev/null & p4=$!
sleep 1
fail=0
for spec in "self:$$" "sleep-multispace-args:$p1" "exe-path-with-spaces:$p2" "argv-with-newline:$p3" "native-windows-ping:$p4" "gone-pid:999999"; do
  label=${spec%%:*} pid=${spec#*:}
  a=$(probe target-proc "$WT/bin" "" "$pid"); b=$(probe target-ps "$WT/bin" "$SCR/empty" "$pid"); c=$(probe base "$BASE/bin" "" "$pid")
  echo "== $label (pid=$pid)"; echo "  target /proc : $a"; echo "  target ps    : $b"; echo "  base         : $c"
  if [ "${a% ms=*}" = "${b% ms=*}" ] && [ "${a% ms=*}" = "${c% ms=*}" ]; then echo "  PARITY OK"; else echo "  PARITY MISMATCH"; fail=1; fi
done
kill $p1 $p2 $p3 $p4 2>/dev/null; wait 2>/dev/null
echo "overall: $([ $fail -eq 0 ] && echo PASS || echo FAIL)"
