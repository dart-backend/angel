#!/usr/bin/env bash
# Benchmarks the servers of issue 2 with bin/load.dart.
#
# The servers run on SERVER_CPUS with ISOLATES isolates, and the load
# generator on LOAD_CPUS, so that the two do not compete for a core.
#
#   ./run.sh                  # every server
#   ./run.sh angel shelf      # only these
set -euo pipefail
cd "$(dirname "$0")"

SERVER_CPUS=${SERVER_CPUS:-0,1}
LOAD_CPUS=${LOAD_CPUS:-2,3}
ISOLATES=${ISOLATES:-2}
LOAD_ISOLATES=${LOAD_ISOLATES:-2}
CONNECTIONS=${CONNECTIONS:-64}
DURATION=${DURATION:-10}
WARMUP=${WARMUP:-3}
TRIALS=${TRIALS:-2}
PORT=${PORT:-3000}

servers=("$@")
[ ${#servers[@]} -eq 0 ] && servers=(raw angel shelf relic)
targets=('GET /' 'GET /user/42' 'GET /user/*' 'POST /user')

for s in "${servers[@]}" load; do
  if [ ! -x "build/$s/bundle/bin/$s" ]; then
    dart build cli -t "bin/$s.dart" -o "build/$s" --verbosity=error
  fi
done

load() {
  taskset -c "$LOAD_CPUS" build/load/bundle/bin/load \
    -p "$PORT" -c "$CONNECTIONS" -i "$LOAD_ISOLATES" "$@"
}

echo "# $(date -Iseconds)  dart $(dart --version 2>&1 | cut -d' ' -f4)  $(nproc) cpus"
echo "# server cpus=$SERVER_CPUS isolates=$ISOLATES; load cpus=$LOAD_CPUS" \
  "isolates=$LOAD_ISOLATES connections=$CONNECTIONS duration=${DURATION}s"

for s in "${servers[@]}"; do
  ISOLATES=$ISOLATES PORT=$PORT taskset -c "$SERVER_CPUS" \
    "build/$s/bundle/bin/$s" > /dev/null 2>&1 &
  pid=$!
  for _ in $(seq 100); do
    curl -s -o /dev/null "localhost:$PORT/" && break
    sleep 0.1
  done

  for t in "${targets[@]}"; do
    load -d "$WARMUP" "$t" > /dev/null
    for trial in $(seq "$TRIALS"); do
      echo "$s  $(load -d "$DURATION" "$t")"
    done
  done

  kill "$pid"
  wait "$pid" 2> /dev/null || true
done
