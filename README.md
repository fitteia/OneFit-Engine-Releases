# OneFit Engine releases

Ready-to-install builds of the OneFit Engine suite: **OFE-Go** (`onefite`,
the non-linear fitting command line), **OFE-GUI** (`onefite-gui`, its
browser interface) and **plot-go** (the plots). Every
[release](https://github.com/fitteia/OneFit-Engine-Releases/releases) names
the versions it holds; the [latest one](https://github.com/fitteia/OneFit-Engine-Releases/releases/latest)
is the current suite.

Videos (introduction, remote hosts, fits and batches):
[OneFit-Engine-Videos](https://github.com/fitteia/OneFit-Engine-Videos).
OFE-Raku, the reference engine, is installed from its own repository,
[OneFit-Engine](https://github.com/fitteia/OneFit-Engine); each release
names the OFE-Raku version it goes with.

## What each release holds

| File | For |
| --- | --- |
| `onefite-go_VERSION_amd64.deb`, `_arm64.deb` | OFE-Go on Debian, Ubuntu, Raspberry Pi OS and WSL |
| `onefite-go-gui_VERSION_amd64.deb`, `_arm64.deb` | OFE-GUI on the same systems |
| `onefite-go-VERSION-darwin-ARCH.tar.gz`, `onefite-go-gui-VERSION-darwin-ARCH.tar.gz` | macOS, installed by the Homebrew formulas in this repository |
| `onefite-gui-VERSION-OS-ARCH.zip` | OFE-GUI on its own, for Linux, macOS and Windows |
| `plot-go-VERSION-OS-ARCH.zip` | plot-go on its own, for Linux, macOS and Windows |
| `SHA256SUMS` | the checksums of all of them |

`amd64` is Intel and AMD; `arm64` is Apple Silicon, Raspberry Pi and other
ARM machines. Each zip holds the program with its licences.

## Linux (Debian, Ubuntu, Raspberry Pi OS) and WSL

Download the two `.deb` files for your machine (`dpkg --print-architecture`
says which), then:

```sh
sudo apt install ./onefite-go_0.5.0_arm64.deb ./onefite-go-gui_0.5.0_arm64.deb
onefite doctor
```

The OFE-Go package builds the fitting engine (C and Fortran) on your machine
while it installs, from the engine sources it carries, so it needs a few
minutes and installs the compilers it uses. Then start the GUI and open
<http://127.0.0.1:8143> in a browser:

```sh
onefite-gui
```

On Windows, install Debian or Ubuntu in WSL (`wsl --install -d Debian` in
PowerShell) and use these packages inside it.

## macOS (Homebrew)

```sh
brew tap fitteia/ofe https://github.com/fitteia/OneFit-Engine-Releases
brew trust fitteia/ofe
brew install fitteia/ofe/onefite-go fitteia/ofe/onefite-go-gui
```

The formulas install the prebuilt programs for Apple Silicon or Intel and
then build the fitting engine on your Mac (Homebrew's `gcc` provides the
Fortran compiler). Follow what `brew info fitteia/ofe/onefite-go` says
about `OFE_PATH`, then check with `onefite doctor`. `brew upgrade` moves to
the next suite release.

## The zips: OFE-GUI or plot-go on their own

Unzip, and put the program on your PATH. On macOS, a program downloaded
with a browser is quarantined; allow it once with:

```sh
xattr -d com.apple.quarantine onefite-gui
```

OFE-GUI needs OFE-Go to fit. On a machine without it (Windows, for
example), the GUI can run its fits on another machine that has it, over
SSH: see the "remote hosts" video.

## Checking a download

```sh
sha256sum -c --ignore-missing SHA256SUMS
```

(`shasum -a 256 -c --ignore-missing SHA256SUMS` on macOS.)

## Source code and licences

All of the suite is distributed under the Artistic License 2.0 (see
[LICENSE](LICENSE)); every package and zip carries its licence and the
licences of the components it contains.

**Commercial licence (OFE-Go and OFE-GUI).** A separate commercial
licence for OFE-Go and OFE-GUI is in preparation (dual licensing); to be
told when it is available, write to pj.sebastiao@gmail.com. The downloads here
are provided under the Artistic License 2.0, and third-party components
keep their own licences; the NOTICE in each package has the details.

- plot-go: [OneFit-Engine-plot](https://github.com/fitteia/OneFit-Engine-plot), public.
- OFE-Raku, the reference engine: [OneFit-Engine](https://github.com/fitteia/OneFit-Engine), public.
- The engine libraries the OFE-Go packages build:
  [OneFit-Engine-C](https://github.com/fitteia/OneFit-Engine-C),
  [OneFit-Engine-minuit](https://github.com/fitteia/OneFit-Engine-minuit) and
  [OneFit-Engine-ext-florence](https://github.com/fitteia/OneFit-Engine-ext-florence), public.
- **OFE-Go and OFE-GUI: the complete source of every release published here
  is available on request.** Write to pj.sebastiao@gmail.com, naming the
  release (for example `suite-0.5.0`).

## Making a release (maintainers)

```sh
scripts/make-suite-release.sh suite-0.5.0 v0.5.0 v0.5.0 v1.2.0 1.1.0
scripts/make-suite-release.sh --publish suite-0.5.0 v0.5.0 v0.5.0 v1.2.0 1.1.0
git add Formula && git commit -m "Formulas: suite-0.5.0" && git push origin main
```

The arguments are the suite tag, then the OFE-Go, OFE-GUI, plot-go and
OFE-Raku versions. The script gathers the files from the components' own
releases into `build/SUITE/` (`gh` must have access to the private ones),
checks them, writes `SHA256SUMS` and the release notes, and points the
formulas at the new archives; `--publish` creates the release.
