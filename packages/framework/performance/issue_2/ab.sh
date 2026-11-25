#!/usr/bin/env bash
# Compares builds of the servers, alternating them ROUNDS times per route so
# that a busy machine affects them alike, and prints the mean req/s of each.
#
#   ./ab.sh build/angel-old/bundle/bin/angel build/angel/bundle/bin/angel
#   TARGETS='GET /' ROUNDS=5 ./ab.sh ...
set -euo pipefail
cd "$(dirname "$0")"

SERVER_CPUS=${SERVER_CPUS:-0,1}
LOAD_CPUS=${LOAD_CPUS:-2,3}
ISOLATES=${ISOLATES:-2}
CONNECTIONS=${CONNECTIONS:-64}
DURATION=${DURATION:-8}
WARMUP=${WARMUP:-3}
ROUNDS=${ROUNDS:-3}
PORT=${PORT:-3000}
LOAD=build/load/bundle/bin/load
# TARGETS, separated by commas, picks the routes, e.g. TARGETS='GET /,POST /user'.
IFS=',' read -r -a targets <<< "${TARGETS:-GET /,GET /user/42,GET /user/*,POST /user}"

echo "# $(date -Iseconds) load average $(cut -d' ' -f1-3 /proc/loadavg)"
results=$(mktemp)
for t in "${targets[@]}"; do
  for _ in $(seq "$ROUNDS"); do
    for server in "$@"; do
      ISOLATES=$ISOLATES PORT=$PORT taskset -c "$SERVER_CPUS" "$server" \
        > /dev/null 2>&1 &
      pid=$!
      for _ in $(seq 100); do
        curl -s -o /dev/null "localhost:$PORT/" && break
        sleep 0.1
      done
      taskset -c "$LOAD_CPUS" $LOAD -p "$PORT" -c "$CONNECTIONS" \
        -d "$WARMUP" "$t" > /dev/null
      line=$(taskset -c "$LOAD_CPUS" $LOAD -p "$PORT" -c "$CONNECTIONS" \
        -d "$DURATION" "$t")
      echo "$server  $line" | tee -a "$results"
      kill "$pid"
      wait "$pid" 2> /dev/null || true
    done
  done
done
echo "# load average $(cut -d' ' -f1-3 /proc/loadavg)"
echo "# mean req/s"
awk '{split($4, a, "="); k = $2 " " $3 "\t" $1; s[k] += a[2]; n[k]++}
  END {for (k in s) printf "%s\t%.0f\n", k, s[k] / n[k]}' "$results" | sort
rm -f "$results"
