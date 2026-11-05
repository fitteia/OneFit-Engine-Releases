# OFE-GUI for macOS, from this repository's suite release: onefite-gui
# built in advance for Apple Silicon or Intel, with its man page and
# licences. scripts/make-suite-release.sh sets the urls, sha256s and
# version at each suite release. The private fitteia/onefite tap builds
# the same release from source instead.
class OnefiteGoGui < Formula
  desc "Browser-based front end for OFE-Go"
  homepage "https://github.com/fitteia/OneFit-Engine-Releases"
  version "0.5.11"
  license "Artistic-2.0"

  on_arm do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.5.11/onefite-go-gui-0.5.11-darwin-arm64.tar.gz"
    sha256 "517c010edf2040027e0f2fac9abdbb9f1fb3320f1b4f846bfecd5bb673b57d95"
  end
  on_intel do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.5.11/onefite-go-gui-0.5.11-darwin-amd64.tar.gz"
    sha256 "e042b5d13488765e883cb9b7691c8d8a1b061294757c7e1ad538bf0ce078aa8b"
  end

  depends_on "fitteia/ofe/onefite-go"
  depends_on :macos

  def install
    # bin/onefite-gui, the man page and every licence (share/doc/onefite-go-gui)
    prefix.install "bin", "share"
  end

  def caveats
    <<~EOS
      Run it with:
        onefite-gui -onefite="#{formula_opt_bin("onefite-go")}/onefite"
      and open http://127.0.0.1:8143 in a browser. From another machine,
      reach it through an SSH tunnel:
        ssh -N -L 8143:127.0.0.1:8143 user@this-mac

      Local runs are not sandboxed on macOS (bubblewrap is Linux-only): the
      same trust as running onefite fit yourself in a terminal.
    EOS
  end

  test do
    system bin/"onefite-gui", "-h"
  end
end
