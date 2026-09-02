#!/usr/bin/env bash
#
# Synthetic smoke test against a deployed Next service.
#
#   scripts/smoke-next.sh https://fluid-droplet-name-next-xxxx.a.run.app
#
# Sends no valid signatures, so it needs no secrets and is safe against
# production. Read the limits below before trusting a pass.
#
# WHAT THIS CAN AND CANNOT SHOW
#
# The webhook route fails CLOSED, so an unsigned request must be refused with a
# 401. That is a real assertion: if verification were broken or the route were
# unwrapped, this would come back 200.
#
# The callback route fails OPEN by design — `onAuthFailure: ok` answers 200
# `{"success":true}`, because Fluid blocks a live cart on this response and a
# 401 would break checkout rather than protect it. So an unauthenticated probe
# CANNOT distinguish "verifying correctly and refusing me" from "cannot verify
# anything and refusing everyone". Both look identical from outside. That is
# the point of the design and the blind spot of this script.
#
# What that means in practice: a pass here says the service is up, routed, and
# refusing unsigned webhooks. It does NOT say a genuine Fluid callback would be
# accepted. Only real traffic — or a request signed with a real registration
# token — shows that, which is why the first cutover is an internal
# installation and not a client.
set -uo pipefail

BASE="${1:-}"
[ -n "$BASE" ] || { echo "usage: $0 <base-url>"; exit 2; }
BASE="${BASE%/}"

fail=0
check () {
  local name="$1" expected="$2" got="$3"
  if [ "$got" = "$expected" ]; then
    printf '  ok    %-48s %s\n' "$name" "$got"
  else
    printf '  FAIL  %-48s got %s, want %s\n' "$name" "$got" "$expected"
    fail=$((fail + 1))
  fi
}

code () { curl -s -o /dev/null -m 20 -w '%{http_code}' "$@" 2>/dev/null || echo 000; }
body () { curl -s -m 20 "$@" 2>/dev/null || echo ""; }

echo "Smoke testing $BASE"

check "health" 200 "$(code "$BASE/api/health")"

# Fails closed. This is the assertion that carries weight.
check "webhook without a signature is refused" 401 \
  "$(code -X POST "$BASE/api/webhooks" \
      -H 'content-type: application/json' \
      -d '{"resource":"order","event":"created","company":{"fluid_shop":"smoke"}}')"

# Still an auth failure, not a 400: the wrapper authenticates before it parses,
# so a malformed body behind a missing signature must never reach the parser.
check "unsigned webhook with a malformed body is refused as auth" 401 \
  "$(code -X POST "$BASE/api/webhooks" \
      -H 'content-type: application/json' -d 'not json')"

# A bootstrap-eligible event with no signature must also be refused. The shared
# secret is a candidate for these events, not a bypass of verification.
check "unsigned install event is refused" 401 \
  "$(code -X POST "$BASE/api/webhooks" \
      -H 'content-type: application/json' \
      -d '{"name":"droplet_installed","payload":{"company":{"fluid_shop":"smoke"}}}')"

# Fails open, so the 200 proves routing and that the route is deployed —
# nothing about verification. Asserted anyway because a 404 or a 500 here is a
# genuine finding: it means the route is missing or throwing.
CB=$(code -X POST "$BASE/api/callbacks/cart-item-added" \
      -H 'content-type: application/json' -d '{"cart":{"id":1}}')
check "callback route answers (fail-open, proves routing only)" 200 "$CB"

CB_BODY=$(body -X POST "$BASE/api/callbacks/cart-item-added" \
      -H 'content-type: application/json' -d '{"cart":{"id":1}}')
case "$CB_BODY" in
  *success*) printf '  ok    %-48s %s\n' "callback returns the neutral body" "$CB_BODY" ;;
  *) printf '  FAIL  %-48s %s\n' "callback returns the neutral body" "$CB_BODY"; fail=$((fail + 1)) ;;
esac

echo
if [ "$fail" -gt 0 ]; then
  echo "$fail check(s) failed — do not repoint any installation at this service."
  exit 1
fi
echo "Passed. The service is up and refusing unsigned webhooks."
echo "This does NOT establish that a signed callback would be accepted;"
echo "cut an internal installation over first and watch it."
