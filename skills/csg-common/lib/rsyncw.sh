#!/bin/bash
# csg-common/lib/rsyncw.sh — openrsync pull/push wrappers + explicit rm-by-list.
#
# Mac ships Apple openrsync (protocol 29); --files-from is verified OK against
# WSL rsync 3.2.7. Flags are -rltz, never -a (perms/owner are meaningless on
# DrvFs) and NEVER --delete: deletions are computed from manifests and applied
# as explicit, printed rm lists so excluded files (cookies.txt, the findings
# doc, corp-side untracked junk) can never be collateral damage.
#
# Requires env.sh + log.sh sourced first.

RSYNC_SSH="ssh -p $BACKCHANNEL_PORT $SSH_OPTS_STR"

# rsync_pull <files-from> — corp -> Mac for the listed repo-relative paths.
rsync_pull() {
  rsync -rltz --files-from="$1" -e "$RSYNC_SSH" \
    "$BACKCHANNEL_USER@localhost:$CORP_REPO_WSL/" "$MAC_REPO/"
}

# rsync_push <files-from> — Mac -> corp for the listed repo-relative paths.
rsync_push() {
  rsync -rltz --files-from="$1" -e "$RSYNC_SSH" \
    "$MAC_REPO/" "$BACKCHANNEL_USER@localhost:$CORP_REPO_WSL/"
}

# scp a single file to a WSL-side path.
scp_to_wsl() {
  # shellcheck disable=SC2086
  scp -P "$BACKCHANNEL_PORT" $SSH_OPTS_STR -q "$1" "$BACKCHANNEL_USER@localhost:$2"
}

# rm_by_list_mac <path-list> — delete listed paths under MAC_REPO. NUL-safe.
rm_by_list_mac() {
  [ -s "$1" ] || return 0
  ( cd "$MAC_REPO" && tr '\n' '\0' < "$1" | xargs -0 rm -f -- )
}

# rm_by_list_corp <path-list> — delete listed paths under CORP_REPO_WSL. NUL-safe.
rm_by_list_corp() {
  [ -s "$1" ] || return 0
  wsl_exec "cd \"$CORP_REPO_WSL\" && tr '\n' '\0' | xargs -0 -r rm -f --" < "$1"
}
