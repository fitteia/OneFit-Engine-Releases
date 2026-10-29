# OFE-Go for macOS, from this repository's suite release: onefite and
# plot-go built in advance for Apple Silicon or Intel, with the pinned
# engine sources, which the post-install builds on this Mac (gcc for the
# Fortran compiler). scripts/make-suite-release.sh sets the urls, sha256s
# and version at each suite release. The private fitteia/onefite tap
# builds the same release from source instead.
class OnefiteGo < Formula
  desc "OneFit-Engine non-linear fitting CLI (OFE-Go)"
  homepage "https://github.com/fitteia/OneFit-Engine-Releases"
  version "0.4.0"
  license "Artistic-2.0"

  on_arm do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.4.0/onefite-go-0.4.0-darwin-arm64.tar.gz"
    sha256 "450e691ad66a9ad4e042ab2b58f21aa3c322938e5888b5d9c3e7abbcd8446b65"
  end
  on_intel do
    url "https://github.com/fitteia/OneFit-Engine-Releases/releases/download/suite-0.4.0/onefite-go-0.4.0-darwin-amd64.tar.gz"
    sha256 "455e848ca12a3c58b34af23a987120565219f9ac40db016f34290649a43c5f20"
  end

  depends_on "gcc"
  depends_on :macos

  # Optional at run time: ffmpeg for MP4s, Grace as the legacy plotter
  # (OFE_PLOTTER=grace), hdf5 for HDF5 import, poppler for PDF to raster.
  depends_on "ffmpeg" => :optional
  depends_on "grace" => :optional
  depends_on "hdf5" => :optional
  depends_on "poppler" => :optional

  # The URW base-35 fonts plot-go measures and draws text with, as Grace and
  # Ghostscript do (a formula cannot depend on Homebrew's font-urw-base35
  # cask). Their own license: AGPL-3.0 with a font exception - separate files
  # plot-go only reads, installed with that license (COPYING, LICENSE).
  resource "urw-base35-fonts" do
    url "https://github.com/ArtifexSoftware/urw-base35-fonts/archive/refs/tags/20200910.tar.gz"
    sha256 "e0d9b7f11885fdfdc4987f06b2aa0565ad2a4af52b22e5ebf79e1a98abd0ae2f"
  end

  def install
    # bin/onefite and bin/plot-go, the man page, the engine sources
    # (share/onefite-go/engine-sources) and every licence (share/doc/onefite-go)
    prefix.install "bin", "share"
    bin.install_symlink "onefite" => "onefite-go"
    man1.install_symlink "onefite.1" => "onefite-go.1"

    # the 13 URW fonts plot-go uses, where it looks for them
    resource("urw-base35-fonts").stage do
      (share/"fonts/urw-base35").install %w[
        NimbusSans-Regular NimbusSans-Bold NimbusSans-Italic NimbusSans-BoldItalic
        NimbusRoman-Regular NimbusRoman-Bold NimbusRoman-Italic NimbusRoman-BoldItalic
        NimbusMonoPS-Regular NimbusMonoPS-Bold NimbusMonoPS-Italic NimbusMonoPS-BoldItalic
        StandardSymbolsPS
      ].map { |f| "fonts/#{f}.otf" }
      (doc/"third-party/urw-base35-fonts").install "COPYING", "LICENSE", "README.md"
    end
  end

  # builds the engine from the bundled sources into var/onefite-go; an
  # upgrade rebuilds it only when the bundled pins changed
  post_install_steps do
    if_path_exists "onefite-go/lib/libminuit.a", base: :var do
      run "{{bin}}/onefite",
          args: ["doctor", "--install", "--keep-minuit", "--if-changed",
                 "--sources", "{{bin}}/../share/onefite-go/engine-sources",
                 "--ofe-path", "{{var}}/onefite-go"],
          network_access: true
    end

    unless_path_exists "onefite-go/lib/libminuit.a", base: :var do
      run "{{bin}}/onefite",
          args: ["doctor", "--install",
                 "--sources", "{{bin}}/../share/onefite-go/engine-sources",
                 "--ofe-path", "{{var}}/onefite-go"],
          network_access: true
    end
  end

  def caveats
    <<~EOS
      onefite needs OFE_PATH set to the engine root the install built:
        export OFE_PATH="#{var}/onefite-go"
      Add that to your shell profile. Then check everything is in place:
        onefite doctor

      bin/ has both "onefite" and "onefite-go"; use onefite-go if OFE-Raku's
      onefite is also on your PATH.

      For the browser GUI: brew install fitteia/ofe/onefite-go-gui
      Videos: https://github.com/fitteia/OneFit-Engine-Videos
    EOS
  end

  test do
    system bin/"onefite", "parse-function", "y(x,a,b)=a+b*x"
  end
end
