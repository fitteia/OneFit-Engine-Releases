# OFE-GUI for macOS, from this repository's suite release: onefite-gui
# built in advance for Apple Silicon or Intel, with its man page and
# licences. scripts/make-suite-release.sh sets the urls, sha256s and
# version at each suite release. The private fitteia/onefite tap builds
# the same release from source instead.
class OnefiteGoGui < Formula
  desc "Browser-based front end for OFE-Go"
  homepage "https://github.com/fitteia/OneFit-Engine-Releases"
  version "0.5.13"
  license "Artistic-2.0"

  on_arm do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.5.13/onefite-go-gui-0.5.13-darwin-arm64.tar.gz"
    sha256 "fa70073e232e769f90b2f2273cc21d6c547c52b2ceecf157176f025904d0e21d"
  end
  on_intel do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.5.13/onefite-go-gui-0.5.13-darwin-amd64.tar.gz"
    sha256 "7e8e0a9218c714e86ae3c086bd8177f859fceb1f8c0783b235a267e076629ffe"
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
