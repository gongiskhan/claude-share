#!/bin/bash
# csg-complete/scripts/finalize.sh — push the verified branch and open the
# Azure DevOps PR. Runs ONLY after the user explicitly confirms (the SKILL.md
# forbids Claude from invoking this unprompted).
#
#   re-verify (cheap) -> git push -u origin <branch> (Windows git / Credential
#   Manager) -> az repos pr create -> print the PR URL.
#
# usage: finalize.sh   (reads csg-state/pending-finalize.env from csg-complete)
set -euo pipefail

CSG_LIB="$HOME/.claude/skills/csg-common/lib"
. "$CSG_LIB/env.sh"
. "$CSG_LIB/log.sh"
. "$CSG_LIB/remote.sh"
. "$CSG_LIB/manifest.sh"

SCRIPTS_DIR=$(cd "$(dirname "$0")" && pwd)

ensure_state_dir
[ -f "$PENDING_FINALIZE_ENV" ] || die "nothing pending — run csg-complete first"
# shellcheck disable=SC1090
. "$PENDING_FINALIZE_ENV"
[ -n "${TICKET:-}" ] && [ -n "${BRANCH:-}" ] && [ -n "${COMMIT_MSG:-}" ] \
  || die "pending-finalize.env is incomplete — re-run csg-complete"

backchannel_check

log "finalize: re-verifying corporate tree for ticket #$TICKET (branch $BRANCH)..."
REPORT=$(csg_mktemp)
if ! bash "$SCRIPTS_DIR/verify-tree.sh" --ticket "$TICKET" --branch "$BRANCH" \
      --commit-msg "$COMMIT_MSG" --report "$REPORT"; then
  die "verification no longer passes — the corporate tree changed since csg-complete. Residual:"$'\n'"$(sed 's/^/  /' "$REPORT")"$'\n'"Re-run csg-complete, then finalize again."
fi

log "finalize: pushing $BRANCH to origin (Windows git / Credential Manager)..."
PRC=0
POUT=$(corp_git_win "push -u origin $BRANCH" 2>&1) || PRC=$?
printf '%s\n' "$POUT" | tail -10 >&2
[ "$PRC" -eq 0 ] || die "git push failed (rc=$PRC) — see output above. Nothing further was done."

log "finalize: creating the Azure DevOps PR..."
TITLE_Q=$(ps_squote "$COMMIT_MSG")
DESC_BODY="Recreated from the Mac change set by csg-complete for #$TICKET — ${DESC:-}. Verified byte-exact against the spec manifest before push."
DESC_Q=$(ps_squote "$DESC_BODY")
AZ_PS="az repos pr create --org '$ADO_ORG' --project '$ADO_PROJECT' --repository '$ADO_REPO' --source-branch '$BRANCH' --target-branch main --title '$TITLE_Q' --description '$DESC_Q' --output json --only-show-errors
exit \$LASTEXITCODE"
ARC=0
AOUT=$(win_ps "$AZ_PS") || ARC=$?
if [ "$ARC" -ne 0 ]; then
  printf '%s\n' "$AOUT" | tail -20 >&2
  die "az repos pr create failed (rc=$ARC). The branch IS pushed — you can open the PR manually in Azure DevOps."
fi

PRID=$(printf '%s' "$AOUT" | tr -d '\r' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["pullRequestId"])' 2>/dev/null || true)
PR_URL=""
if [ -n "$PRID" ]; then
  PR_URL="$ADO_ORG/$ADO_PROJECT/_git/$ADO_REPO/pullrequest/$PRID"
else
  warn "could not parse the PR id from az output — raw JSON follows:"
  printf '%s\n' "$AOUT" >&2
fi

mv "$PENDING_FINALIZE_ENV" "$STATE_DIR/finalized-$TICKET-$(date +%Y%m%d-%H%M%S).env"

cat >&2 <<EOF

============================================================
 csg-complete: FINALIZED
   ticket : #$TICKET
   branch : $BRANCH (pushed to origin)
   PR     : ${PR_URL:-<see raw az output above>}
============================================================
EOF
