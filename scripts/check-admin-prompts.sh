#!/bin/bash
# Fail if any code outside the one prompter builds an administrator prompt.
#
# Every password dialog must go through `AdminPrompting`
# (Sources/PervigilCore/AdminPrompting.swift), which refuses background
# automation outright. A new `do shell script ... with administrator
# privileges` anywhere else would bring back the unattended "osascript wants
# to make changes" dialog this check exists to prevent. Comments may mention
# the phrase; code may not.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

allowed="Sources/PervigilCore/AdminPrompting.swift"

# Non-comment Swift lines that mention the AppleScript admin clause.
hits="$(grep -rn --include='*.swift' -i 'administrator privileges' Sources \
  | grep -v "^${allowed}:" \
  | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*//' || true)"

if [ -n "$hits" ]; then
  echo "error: administrator prompt built outside ${allowed}:" >&2
  printf '%s\n' "$hits" >&2
  echo "Route it through AdminPrompting.runAsRoot(_:feature:origin:) so automation can't prompt." >&2
  exit 1
fi

echo "admin prompts: OK (only ${allowed} builds them)"
