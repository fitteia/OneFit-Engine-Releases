#!/usr/bin/env bash
# Compare commits, including peeled annotated tags, before any release mutation.
check_release_tag() {
  local remote="$1" tag="$2" expected="$3" missing="${4:-required}" refs actual
  refs=$(git ls-remote --tags "$remote" "refs/tags/$tag" "refs/tags/$tag^{}") || {
    echo "Cannot verify remote tag $tag; publication stopped" >&2; return 1;
  }
  actual=$(printf '%s\n' "$refs" | awk -v tag="refs/tags/$tag" '
    $2 == tag { direct=$1 } $2 == tag "^{}" { peeled=$1 }
    END { if (peeled != "") print peeled; else print direct }')
  if [ -z "$actual" ]; then
    [ "$missing" = allow-missing ] && return 0
    echo "Remote tag $tag is missing; push the intended tag first" >&2; return 1
  fi
  [ "$actual" = "$expected" ] || {
    echo "Remote tag $tag resolves to $actual, expected $expected; publication stopped" >&2
    return 1
  }
}
