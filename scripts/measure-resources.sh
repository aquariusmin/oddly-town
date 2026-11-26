#!/usr/bin/env bash
# Samples CPU and memory of a running Oddly Town process and prints a summary.
#
#   scripts/measure-resources.sh                      # OddlyTown, 5 min, every 5 s
#   scripts/measure-resources.sh -d 1800 -i 10 -o ambient.csv
#   scripts/measure-resources.sh -p 12345 -d 60
#   scripts/measure-resources.sh --max-cpu 1 --max-mem 150   # exit 2 if a target is missed
#
# CPU % is the change in the process's total CPU time divided by wall time between
# samples (not ps's decaying %cpu), so the average is the real average.
# Memory is RSS from ps and, on macOS, the physical footprint from `vmmap --summary`
# (the number Activity Monitor shows as "Memory"). The 150 MB target is checked
# against the footprint when it is available, otherwise against RSS.
#
# Exit codes: 0 ok, 1 usage / process not found / process exited while sampling,
#             2 a --max-cpu / --max-mem target was missed.
# Works with macOS's bash 3.2 and on Linux (RSS only there).
set -euo pipefail

NAME="OddlyTown"
PID=""
DURATION=300
INTERVAL=5
OUT=""
MAX_CPU=""
MAX_MEM=""
USE_VMMAP=1

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p) PID="$2"; shift 2 ;;
    -n) NAME="$2"; shift 2 ;;
    -d) DURATION="$2"; shift 2 ;;
    -i) INTERVAL="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    --max-cpu) MAX_CPU="$2"; shift 2 ;;
    --max-mem) MAX_MEM="$2"; shift 2 ;;
    --no-footprint) USE_VMMAP=0; shift ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "$PID" ]]; then
  PID="$(pgrep -x "$NAME" | head -n 1 || true)"
  if [[ -z "$PID" ]]; then
    echo "No running process named '$NAME'. Start the app first or pass -p <pid>." >&2
    exit 1
  fi
fi
if ! kill -0 "$PID" 2>/dev/null; then
  echo "Process $PID is not running." >&2
  exit 1
fi
NAME="$(basename "$(ps -o comm= -p "$PID" 2>/dev/null || echo "$NAME")")"
if ! command -v vmmap >/dev/null 2>&1; then USE_VMMAP=0; fi

# Total CPU seconds of a process, from ps's [[dd-]hh:]mm:ss[.ss] time column.
cpu_seconds() {
  ps -o time= -p "$1" 2>/dev/null | awk '{
    t = $1; days = 0
    if (index(t, "-") > 0) { split(t, d, "-"); days = d[1]; t = d[2] }
    n = split(t, p, ":"); s = 0
    for (i = 1; i <= n; i++) s = s * 60 + p[i]
    printf "%.3f\n", s + days * 86400
  }'
}

rss_mb() { ps -o rss= -p "$1" 2>/dev/null | awk '{ printf "%.1f\n", $1 / 1024 }'; }

# "Physical footprint:  12.3M" → 12.3 (MB). Empty when vmmap is unavailable or fails.
footprint_mb() {
  [[ "$USE_VMMAP" == "1" ]] || return 0
  vmmap --summary "$1" 2>/dev/null | awk '/^Physical footprint:/ {
    v = $3; unit = substr(v, length(v)); num = substr(v, 1, length(v) - 1) + 0
    if (unit == "K") num /= 1024; else if (unit == "G") num *= 1024; else if (unit != "M") num = v / 1048576
    printf "%.1f\n", num; exit
  }' || true
}

now() { perl -MTime::HiRes=time -e 'printf "%.3f\n", time' 2>/dev/null || date +%s; }

CSV="$(mktemp)"
trap 'rm -f "$CSV"' EXIT
echo "elapsed_s,cpu_pct,rss_mb,footprint_mb" > "$CSV"

echo "Sampling PID $PID ($NAME) every ${INTERVAL}s for ${DURATION}s…" >&2
start="$(now)"
prev_t="$start"
prev_cpu="$(cpu_seconds "$PID")"
died=0

while :; do
  sleep "$INTERVAL"
  if ! kill -0 "$PID" 2>/dev/null; then died=1; break; fi
  t="$(now)"
  cpu="$(cpu_seconds "$PID")"
  rss="$(rss_mb "$PID")"
  fp="$(footprint_mb "$PID")"
  awk -v t="$t" -v pt="$prev_t" -v c="$cpu" -v pc="$prev_cpu" -v s="$start" -v r="$rss" -v f="$fp" \
    'BEGIN { dt = t - pt; pct = dt > 0 ? (c - pc) / dt * 100 : 0
             printf "%.0f,%.2f,%s,%s\n", t - s, pct, r, f }' >> "$CSV"
  prev_t="$t"; prev_cpu="$cpu"
  awk -v t="$t" -v s="$start" -v d="$DURATION" 'BEGIN { exit (t - s >= d) ? 0 : 1 }' && break
done

if [[ -n "$OUT" ]]; then cp "$CSV" "$OUT"; echo "Samples written to $OUT" >&2; fi

# Summary. The memory target uses the footprint column when every sample has one.
summary="$(awk -F, -v maxcpu="$MAX_CPU" -v maxmem="$MAX_MEM" 'NR > 1 {
    n++; c += $2; if ($2 > cpk) cpk = $2
    if (n == 1) { r1 = $3; f1 = $4 }
    rl = $3; fl = $4; if ($3 > rpk) rpk = $3
    if ($4 != "") { nf++; if ($4 > fpk) fpk = $4 }
  }
  END {
    if (n == 0) { print "No samples (duration shorter than one interval?)"; exit 3 }
    avg = c / n
    printf "samples        %d\n", n
    printf "CPU            avg %.2f%%  peak %.2f%%\n", avg, cpk
    printf "RSS            start %.1f MB  end %.1f MB  peak %.1f MB  change %+.1f MB\n", r1, rl, rpk, rl - r1
    usefp = (nf == n)
    if (usefp) printf "Footprint      start %.1f MB  end %.1f MB  peak %.1f MB  change %+.1f MB\n", f1, fl, fpk, fl - f1
    mem = usefp ? fpk : rpk; memname = usefp ? "footprint" : "RSS"
    miss = 0
    if (maxcpu != "" && avg > maxcpu + 0) { printf "MISSED         avg CPU %.2f%% > %s%%\n", avg, maxcpu; miss = 1 }
    if (maxmem != "" && mem > maxmem + 0) { printf "MISSED         peak %s %.1f MB > %s MB\n", memname, mem, maxmem; miss = 1 }
    exit miss ? 2 : 0
  }' "$CSV")" && status=0 || status=$?

echo "$summary"
if [[ "$died" == "1" ]]; then
  echo "Process $PID exited while being sampled." >&2
  exit 1
fi
exit "$status"
