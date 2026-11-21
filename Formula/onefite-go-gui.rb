# OFE-GUI for macOS, from this repository's suite release: onefite-gui
# built in advance for Apple Silicon or Intel, with its man page and
# licences. scripts/make-suite-release.sh sets the urls, sha256s and
# version at each suite release. The private fitteia/onefite tap builds
# the same release from source instead.
class OnefiteGoGui < Formula
  desc "Browser-based front end for OFE-Go"
  homepage "https://github.com/fitteia/OneFit-Engine-Releases"
  version "0.6.1"
  license "Artistic-2.0"

  on_arm do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.6.1/onefite-go-gui-0.6.1-darwin-arm64.tar.gz"
    sha256 "cecab0070e1190043f8dcefe143b403d3389154b23f5dcf730e6d1ab8b7aa9a2"
  end
  on_intel do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.6.1/onefite-go-gui-0.6.1-darwin-amd64.tar.gz"
    sha256 "009a3fb9210e3b4d307c2a7d39cebd2a25f7ed8595f747d0f864a4caa80f79a7"
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
