#!/usr/bin/env bash
# Bring an account's repositories to the labels in labels.json.
#
# A label is created, or updated when its color or description differs. A label
# with "replaces" takes over the label of that name, by renaming it, so issues
# keep it. A "retired" label, or a replaced one left beside its successor, is
# deleted only when no issue or pull request carries it. Any other label is
# left alone.
#
# Usage: tools/sync-labels.sh [--dry-run] <owner> [repository ...]
#   <owner> is a user or an organization. With no repositories named, every
#   repository of the owner that is neither a fork nor archived.
#   --dry-run prints what would change and changes nothing.
#
# Needs the GitHub CLI (gh), signed in, and jq.
set -euo pipefail

usage="usage: tools/sync-labels.sh [--dry-run] <owner> [repository ...]"
dry_run=false
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=true
  shift
fi
owner="${1:?$usage}"
shift
labels="$(cd "$(dirname "$0")/.." && pwd)/labels.json"
errors="$(mktemp)"
trap 'rm -f "$errors"' EXIT

# Run a command and print its output, waiting and trying again when GitHub
# rate-limits it.
call() {
  local out attempt=0
  while :; do
    if out="$("$@" 2> "$errors" < /dev/null)"; then
      printf '%s' "$out"
      return 0
    fi
    if { printf '%s\n' "$out" | cat - "$errors" | grep -qi -e 'rate limit' -e 'abuse detection'; } &&
      [ "$attempt" -lt 8 ]; then
      attempt=$((attempt + 1))
      echo "  rate limited, waiting $((attempt * 60)) seconds" >&2
      sleep $((attempt * 60))
    else
      printf '%s' "$out"
      return 1
    fi
  done
}

if [ "$#" -gt 0 ]; then
  repos="$*"
else
  repos="$(gh repo list "$owner" --source --no-archived --limit 1000 --json name --jq '.[].name')"
fi

state_query='
query($owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {
    id
    labels(first: 100) {
      nodes { id name color description issues { totalCount } pullRequests { totalCount } }
    }
  }
}'

# The steps a repository needs: what to say about each, and the GraphQL call
# that carries it out, when there is one.
plan='
  $want[0] as $want
  | .data.repository as $repo
  | ($repo.labels.nodes | map({key: .name, value: .}) | from_entries) as $have
  | def fields($l):
      "name: \($l.name | @json), color: \($l.color | @json), description: \($l.description | @json)";
    def retire($h):
      if ($h.issues.totalCount + $h.pullRequests.totalCount) == 0
      then {say: "deleted: \($h.name)", call: "deleteLabel(input: {id: \($h.id | @json)})"}
      else {say: "kept: \($h.name) (an issue or pull request carries it)"}
      end;
    [ $want.labels[]
      | . as $l
      | ($l.replaces // "") as $old
      | if $have[$l.name] then
          ( $have[$l.name]
            | select((.color | ascii_downcase) != ($l.color | ascii_downcase)
                     or (.description // "") != $l.description)
            | {say: "updated: \($l.name)",
               call: "updateLabel(input: {id: \(.id | @json), \(fields($l))})"} ),
          ( select($old != "" and $have[$old] != null) | retire($have[$old]) )
        elif $old != "" and $have[$old] != null then
          {say: "renamed: \($old) -> \($l.name)",
           call: "updateLabel(input: {id: \($have[$old].id | @json), \(fields($l))})"}
        else
          {say: "created: \($l.name)",
           call: "createLabel(input: {repositoryId: \($repo.id | @json), \(fields($l))})"}
        end
    ]
    + [ $want.retired[] | select($have[.] != null) | retire($have[.]) ]
'

mutation='
  [.[] | select(.call) | .call]
  | to_entries
  | map("  m\(.key): \(.value) { clientMutationId }")
  | if length == 0 then "" else "mutation {\n" + join("\n") + "\n}" end
'

for repo in $repos; do
  echo "$owner/$repo"
  if ! state="$(call gh api graphql -f query="$state_query" -f owner="$owner" -f repo="$repo")"; then
    echo "  failed to read the labels: $(head -n 1 "$errors")"
    continue
  fi
  steps="$(printf '%s' "$state" | jq -c --slurpfile want "$labels" "$plan")"
  if [ "$steps" = "[]" ]; then
    echo "  up to date"
    continue
  fi
  if [ "$dry_run" = true ]; then
    printf '%s' "$steps" | jq -r '.[] | "  would have " + .say'
    continue
  fi
  calls="$(printf '%s' "$steps" | jq -r "$mutation")"
  if [ -z "$calls" ] || call gh api graphql -f query="$calls" > /dev/null; then
    printf '%s' "$steps" | jq -r '.[] | "  " + .say'
  else
    echo "  failed part way, run it again: $(head -n 1 "$errors")"
  fi
  # GitHub allows about 2,000 points a minute, and each change costs 5.
  if [ -n "$calls" ]; then sleep "${SYNC_LABELS_PAUSE:-4}"; fi
done
