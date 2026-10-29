#!/usr/bin/env bash
# Assembles an OFE suite release from the components' own releases:
#
#   scripts/make-suite-release.sh SUITE GO GUI PLOT RAKU            prepare
#   scripts/make-suite-release.sh --publish SUITE GO GUI PLOT RAKU  and publish
#
#   e.g. scripts/make-suite-release.sh suite-0.4.0 v0.4.0 v0.4.0 v1.2.0 1.1.0
#
# It fetches into build/SUITE/ (a file already there is kept, so one built
# by hand can stand in for a missing release asset):
#   from fitteia/OneFit-Engine-go   (private: gh must be logged in with access)
#     onefite-go_V_amd64.deb, onefite-go_V_arm64.deb
#     onefite-go-V-darwin-arm64.tar.gz, onefite-go-V-darwin-amd64.tar.gz
#   from fitteia/OneFit-Engine-GUI  (private)
#     onefite-go-gui_V_amd64.deb, onefite-go-gui_V_arm64.deb
#     onefite-gui-V-OS-ARCH.zip (six), onefite-go-gui-V-darwin-ARCH.tar.gz (two)
#   from fitteia/OneFit-Engine-plot (public)
#     plot-go-V-OS-ARCH.zip (six)
# checks the zips against their release's SHA256SUMS, writes SHA256SUMS and
# the release notes, and sets Formula/*.rb to this suite's archives (url,
# sha256, version). --publish then creates the GitHub release SUITE here
# (or adds the files to it, if it exists); commit and push Formula/ after.
# Runs on macOS (bash 3.2, BSD tools) and Linux.
set -euo pipefail

publish=""
if [ "${1:-}" = "--publish" ]; then publish=1; shift; fi
[ $# -eq 5 ] || { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
suite="$1" go_tag="$2" gui_tag="$3" plot_tag="$4" raku_version="${5#v}"
go_v="${go_tag#v}" gui_v="${gui_tag#v}" plot_v="${plot_tag#v}"
here_repo=fitteia/OneFit-Engine-Releases
go_repo=fitteia/OneFit-Engine-go
gui_repo=fitteia/OneFit-Engine-GUI
plot_repo=fitteia/OneFit-Engine-plot

cd "$(dirname "$0")/.."
stage="build/$suite"
mkdir -p "$stage"
sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'; }

platforms="linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64 windows-arm64"
go_files="onefite-go_${go_v//-/\~}_amd64.deb onefite-go_${go_v//-/\~}_arm64.deb onefite-go-$go_v-darwin-arm64.tar.gz onefite-go-$go_v-darwin-amd64.tar.gz"
gui_files="onefite-go-gui_${gui_v//-/\~}_amd64.deb onefite-go-gui_${gui_v//-/\~}_arm64.deb onefite-go-gui-$gui_v-darwin-arm64.tar.gz onefite-go-gui-$gui_v-darwin-amd64.tar.gz"
plot_files=""
for p in $platforms; do
  gui_files="$gui_files onefite-gui-$gui_v-$p.zip"
  plot_files="$plot_files plot-go-$plot_v-$p.zip"
done

# fetch REPO TAG FILE...: each FILE not yet in the stage, from REPO's TAG release
fetch() {
  repo="$1" tag="$2"; shift 2
  for f in "$@"; do
    if [ -f "$stage/$f" ]; then
      echo "    have  $f"
    else
      echo "    fetch $f ($repo $tag)"
      gh release download "$tag" -R "$repo" -p "$f" -D "$stage"
    fi
  done
}
# verify REPO TAG FILE...: FILE against REPO's TAG release SHA256SUMS
verify() {
  repo="$1" tag="$2"; shift 2
  sums="$(mktemp)"
  gh release download "$tag" -R "$repo" -p SHA256SUMS -O "$sums" --clobber
  for f in "$@"; do
    want="$(awk -v f="$f" '$2 == f {print $1}' "$sums")"
    [ -n "$want" ] || { echo "$f is not in $repo $tag's SHA256SUMS" >&2; rm -f "$sums"; exit 1; }
    [ "$(sha256 "$stage/$f")" = "$want" ] || { echo "$f does not match $repo $tag's SHA256SUMS" >&2; rm -f "$sums"; exit 1; }
  done
  rm -f "$sums"
  echo "    $repo $tag: SHA256SUMS match"
}

echo "==> $suite in $stage"
# shellcheck disable=SC2086
fetch "$go_repo" "$go_tag" $go_files
# shellcheck disable=SC2086
fetch "$gui_repo" "$gui_tag" $gui_files
# shellcheck disable=SC2086
fetch "$plot_repo" "$plot_tag" $plot_files
# shellcheck disable=SC2086
verify "$gui_repo" "$gui_tag" $(for p in $platforms; do echo "onefite-gui-$gui_v-$p.zip"; done)
# shellcheck disable=SC2086
verify "$plot_repo" "$plot_tag" $plot_files

all="$go_files $gui_files $plot_files"
# shellcheck disable=SC2086
(cd "$stage" && for f in $all; do printf '%s  %s\n' "$(sha256 "$f")" "$f"; done) > "$stage/SHA256SUMS"

cat > "$stage/NOTES.md" <<EOF
OneFit Engine suite **${suite#suite-}**:

| Component | Version | Source |
| --- | --- | --- |
| OFE-Go (\`onefite\`, the command line) | $go_v | on request: pj.sebastiao@gmail.com |
| OFE-GUI (\`onefite-gui\`, in the browser) | $gui_v | on request: pj.sebastiao@gmail.com |
| plot-go (the plots) | $plot_v | [OneFit-Engine-plot $plot_tag](https://github.com/$plot_repo/tree/$plot_tag) |
| OFE-Raku (the reference engine, installed from source) | $raku_version | [OneFit-Engine $raku_version](https://github.com/fitteia/OneFit-Engine/tree/$raku_version) |

The engine libraries the OFE-Go packages build on install (OneFit-Engine-C, OneFit-Engine-minuit, OneFit-Engine-ext-florence) are public; the packages carry their pinned sources.

How to install on Linux, macOS (Homebrew) and Windows: see the [README](https://github.com/$here_repo#readme). Check downloads against \`SHA256SUMS\`.
EOF

# Formula FILE ARCHIVE_PREFIX VERSION: urls, sha256s and version for this suite
set_formula() {
  file="$1" prefix="$2" version="$3"
  arm="$(sha256 "$stage/$prefix-$version-darwin-arm64.tar.gz")"
  intel="$(sha256 "$stage/$prefix-$version-darwin-amd64.tar.gz")"
  base="https://github.com/$here_repo/releases/download/$suite"
  SUITE_ARM_URL="$base/$prefix-$version-darwin-arm64.tar.gz" SUITE_ARM_SHA="$arm" \
  SUITE_INTEL_URL="$base/$prefix-$version-darwin-amd64.tar.gz" SUITE_INTEL_SHA="$intel" \
  SUITE_VERSION="$version" perl -0pi -e '
    s{(on_arm do\s*\n\s*url ")[^"]*("\s*\n\s*sha256 ")[^"]*}{$1$ENV{SUITE_ARM_URL}$2$ENV{SUITE_ARM_SHA}};
    s{(on_intel do\s*\n\s*url ")[^"]*("\s*\n\s*sha256 ")[^"]*}{$1$ENV{SUITE_INTEL_URL}$2$ENV{SUITE_INTEL_SHA}};
    s{(\n  version ")[^"]*}{$1$ENV{SUITE_VERSION}};
  ' "$file"
  echo "    $file: $version"
}
set_formula Formula/onefite-go.rb onefite-go "$go_v"
set_formula Formula/onefite-go-gui.rb onefite-go-gui "$gui_v"

echo "==> Ready: $(echo $all | wc -w | tr -d ' ') files, SHA256SUMS and NOTES.md in $stage"
if [ -z "$publish" ]; then
  echo "    Check them, then rerun with --publish."
  exit 0
fi

echo "==> Publishing $suite on $here_repo"
# shellcheck disable=SC2086
if gh release view "$suite" -R "$here_repo" >/dev/null 2>&1; then
  (cd "$stage" && gh release upload "$suite" $all SHA256SUMS --clobber -R "$here_repo")
  gh release edit "$suite" -R "$here_repo" --notes-file "$stage/NOTES.md"
else
  (cd "$stage" && gh release create "$suite" $all SHA256SUMS -R "$here_repo" \
    --title "OneFit Engine suite ${suite#suite-}" --notes-file NOTES.md)
fi
echo "==> Published. Now commit and push the formulas:"
echo "    git add Formula && git commit -m \"Formulas: $suite\" && git push origin main"
