#!/usr/bin/env bash
# The linked Substrait app's Dev security findings — what /substrait:fix reads and files.
#
#   findings              the Dev blocking set as JSON, verbatim (every finding the Go live
#                         gate counts, per scanner, with its Infosec false-positive state)
#   status                the same read, summarised one key=value per line:
#                         blocking_total, scans_running, scans_errored (comma lists),
#                         governance_run_id, deploy_run_id, commit_sha, source_hash
#   submit-fp --file F    file false-positive claims with Infosec. F is a JSON file:
#                         {"items":[{"finding_id":N,"agent_reason":"…"}],"user_note":null}
#                         Needs the ACCOUNT link (/substrait:login): a claim is filed by a
#                         person, and an app deploy token isn't one.
#   source-hash [DIR]     the source fingerprint of what a deploy of DIR (default: .) would
#                         ship right now — the value the server stores for an uploaded zip
#                         (status's source_hash), so equal = this tree is what's deployed
#
# "Dev" is the app's sandbox scans — the set the Go live gate checks — whatever --env or
# pinned environment the project uses; the server ignores X-Substrait-Env here.
#
# Not synced into the Cursor plugin (Cursor has no /substrait:fix), so nothing synced may
# depend on this script — substrait-deploy.sh's --watch verdict reads the endpoint itself.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=substrait-common.sh
. "$DIR/substrait-common.sh"

die() { echo "Error: $*" >&2; exit 1; }

# `shift 2` with only the flag left is a no-op, so a bare `--file` would spin the loop
# forever; an agent drives this script and can plausibly emit one.
need_value() { [ "$1" -ge 2 ] || die "$2 needs a value"; }

# detail_or_body — the server's `detail` message, else the raw body.
detail_or_body() {
  local d
  if d="$(printf '%s' "$SUBSTRAIT_BODY" | _json_field detail)" && [ -n "$d" ]; then printf '%s' "$d"
  else printf '%s' "$SUBSTRAIT_BODY"; fi
}

# read_findings — GET the Dev blocking set into SUBSTRAIT_BODY, or exit with the reason.
read_findings() {
  substrait_call GET /api/deploy/security/findings || exit $?
  case "${SUBSTRAIT_STATUS:-}" in
    200) ;;
    401) die "the app's credential was rejected — re-run /substrait:link (or /substrait:login)." ;;
    403) die "not allowed: $(detail_or_body)" ;;
    404) die "no Dev findings for this app: $(detail_or_body) (an older Substrait portal has no such endpoint yet — use the app's Security tab)." ;;
    409) die "$(detail_or_body)" ;;
    *)   die "could not read the Dev findings (HTTP ${SUBSTRAIT_STATUS:-?}): $SUBSTRAIT_BODY" ;;
  esac
}

cmd_findings() {
  read_findings
  printf '%s\n' "$SUBSTRAIT_BODY"
}

cmd_status() {
  read_findings
  # The summary fields all come before "scanners" (FastAPI keeps declaration order), so
  # parse only that head: a finding's free text can then never be mistaken for one.
  local head v k
  head="${SUBSTRAIT_BODY%%\"scanners\"*}"
  printf '%s' "$head" | grep -q '"blocking_total"' || head="$SUBSTRAIT_BODY"
  v="$(printf '%s' "$head" | _json_field blocking_total)" || v=""
  echo "blocking_total=$v"
  for k in scans_running scans_errored; do
    v="$(printf '%s' "$head" | _json_str_array "$k")" || v=""
    echo "$k=$v"
  done
  for k in governance_run_id deploy_run_id commit_sha source_hash scanned_at; do
    v="$(printf '%s' "$head" | _json_field "$k")" || v=""
    echo "$k=$v"
  done
}

cmd_submit_fp() {
  local file=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --file) need_value $# --file; file="$2"; shift 2 ;;
      --file=*) file="${1#*=}"; shift ;;
      *) die "unknown option for submit-fp: $1" ;;
    esac
  done
  [ -n "$file" ] || die "usage: substrait-security.sh submit-fp --file <claims.json>"
  [ -f "$file" ] && [ -r "$file" ] || die "no readable file: $file"
  grep -q '"items"' "$file" || die "$file has no \"items\" — expected {\"items\":[{\"finding_id\":N,\"agent_reason\":\"…\"}],\"user_note\":null}"
  # A claim is filed by a PERSON: resolve the account token and skip the project config,
  # whose sbd_ deploy token the server refuses here (see SUBSTRAIT_REQUIRE_ACCOUNT).
  export SUBSTRAIT_REQUIRE_ACCOUNT=1
  substrait_call POST /api/deploy/security/false-positives \
    -H "Content-Type: application/json" --data-binary "@$file" || exit $?
  case "${SUBSTRAIT_STATUS:-}" in
    200|201) printf '%s\n' "$SUBSTRAIT_BODY" ;;
    401)
      echo "Not signed in to an account — run /substrait:login (a deploy token can't file a claim: it isn't tied to a person)." >&2
      exit 1 ;;
    400) die "claim not filed: $(detail_or_body)" ;;
    403) die "not allowed to file claims for this app: $(detail_or_body)" ;;
    404) die "claim not filed: $(detail_or_body)" ;;
    409) die "claim not filed: $(detail_or_body)" ;;
    422) die "the claims file was rejected (each item needs finding_id and a non-empty agent_reason): $(detail_or_body)" ;;
    *)   die "claim not filed (HTTP ${SUBSTRAIT_STATUS:-?}): $SUBSTRAIT_BODY" ;;
  esac
}

cmd_source_hash() {
  local dir="${1:-.}" fp rc
  fp="$(substrait_source_fingerprint "$dir")"; rc=$?
  case "$rc" in
    0) printf '%s\n' "$fp" ;;
    2) exit 2 ;;   # no sha256 tool — the helper already said which to install
    *) die "could not fingerprint $dir" ;;
  esac
}

case "${1:-}" in
  findings)    shift; cmd_findings "$@" ;;
  status)      shift; cmd_status "$@" ;;
  submit-fp)   shift; cmd_submit_fp "$@" ;;
  source-hash) shift; cmd_source_hash "$@" ;;
  -h|--help|help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") die "usage: substrait-security.sh findings|status|submit-fp --file F|source-hash [DIR]   (-h for help)" ;;
  *) die "unknown command: $1. Use findings|status|submit-fp|source-hash (-h for help)." ;;
esac
