#!/usr/bin/env bash
set -uo pipefail
MODE=${1:?usage: push.sh preview|deploy}
LAB=clab-evpn
FAIL=0
STAMP=$(date +%Y%m%d%H%M%S)

for f in configs/*.cfg; do
  node=$(basename "$f" .cfg)
  c="$LAB-$node"
  SESSION="ci-$MODE-$STAMP"

  grep -v '^username admin' "$f" > "/tmp/$node.cand"
  docker cp "/tmp/$node.cand" "$c:/mnt/flash/candidate.cfg"

  if [ "$MODE" = "deploy" ]; then END="commit"; else END="abort"; fi
  printf '%s\n' \
    "configure session $SESSION" \
    "copy file:/mnt/flash/candidate.cfg session-config" \
    "show session-config diffs" \
    "$END" > "/tmp/$node.cli"

  echo "===== $node ($MODE) ====="
  OUT=$(docker exec -i "$c" Cli -p 15 < "/tmp/$node.cli" 2>&1)
  echo "$OUT"

  NODE_FAIL=0
  if echo "$OUT" | grep -qE '^% '; then
    echo "!!! ERROR on $node"; NODE_FAIL=1; FAIL=1
  fi

  if [ "$MODE" = "deploy" ] && [ "$NODE_FAIL" = "0" ]; then
    docker exec "$c" Cli -p 15 -c "write memory" > /dev/null
    echo "saved to startup-config on $node"
  fi
done
exit $FAIL
