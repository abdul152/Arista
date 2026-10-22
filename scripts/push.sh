#!/usr/bin/env bash
set -uo pipefail
MODE=${1:?usage: push.sh preview|deploy}
LAB=clab-evpn
FAIL=0

for f in configs/*.cfg; do
  node=$(basename "$f" .cfg)
  c="$LAB-$node"

  grep -v '^username admin' "$f" > "/tmp/$node.cand"
  docker cp "/tmp/$node.cand" "$c:/mnt/flash/candidate.cfg"

  if [ "$MODE" = "deploy" ]; then END="commit"; else END="abort"; fi
  printf '%s\n' \
    "configure session ci-$MODE" \
    "copy file:/mnt/flash/candidate.cfg session-config" \
    "show session-config diffs" \
    "$END" > "/tmp/$node.cli"

  echo "===== $node ($MODE) ====="
  OUT=$(docker exec -i "$c" Cli -p 15 < "/tmp/$node.cli" 2>&1)
  echo "$OUT"

  if echo "$OUT" | grep -qE '^% (Invalid|Incomplete|Ambiguous)'; then
    echo "!!! ERROR on $node"; FAIL=1
  fi

  if [ "$MODE" = "deploy" ]; then
    docker exec "$c" Cli -p 15 -c "write memory" > /dev/null
    echo "saved to startup-config on $node"
  fi
done
exit $FAIL
