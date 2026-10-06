# voidlinux-pkgs-debloated

Debloated builds of common Void Linux packages, intended for **AppImages** and
other size-constrained bundles where a full-featured graphics/ML stack is dead
weight.

Originally the [archlinux-pkgs-debloated](https://github.com/pkgforge-dev/archlinux-pkgs-debloated)
project (`llvm-libs-debloated` before that). This repository is the Void Linux
port: [`xbps-src`](https://github.com/void-linux/void-packages) templates under
[`srcpkgs/`](srcpkgs/), built by [GitHub Actions](.github/workflows/void.yml) into
`.xbps` packages on every push to `main` via the rolling `continuous` release.

---

## Size comparison

Measured from the packages in the [`continuous` release](https://github.com/kazam0180/voidlinux-pkgs-debloated/releases),
against [`repo-default.voidlinux.org/current`](https://repo-default.voidlinux.org/current)
`installed_size` for the equivalent stock packages. Where Void splits a library
into `foo` + `foo-devel`, the stock column sums both, since the mini packages are
monolithic.

| mini package | size | stock Void equivalent | size | change |
|---|---:|---|---:|---:|
| `icu-mini` | 2.9 MB | `libicu78` + `icu` | 38.4 MB | **−92%** |
| `llvm21-mini` | 14.7 MB | `libllvm21` | 130.8 MB | **−89%** |
| `llvm21-nano` | 17.9 MB | `libllvm21` | 130.8 MB | **−86%** |
| `x265-mini` | 2.3 MB | `x265` | 16.4 MB | **−86%** |
| `gtk2-mini` | 4.2 MB | `gtk+` + `gtk+-devel` | 32.8 MB | **−87%** |
| `gtk3-mini` | 11.4 MB | `gtk+3` + `gtk+3-devel` | 75.8 MB | **−85%** |
| `gdk-pixbuf2-mini` | 0.5 MB | `gdk-pixbuf` + `-devel` | 3.1 MB | **−84%** |
| `mangohud-mini` | 1.7 MB | `MangoHud` + `mangoapp` | 9.8 MB | **−83%** |
| `webkit2gtk-4.1-mini` | 34.5 MB | `libwebkit2gtk41` + `-devel` | 162.3 MB | **−79%** |
| `intel-media-driver-mini` | 4.7 MB | `intel-media-driver` | 19.9 MB | **−76%** |
| `mesa-mini` / `mesa-nano` | 25.5 MB | `mesa` + `mesa-libgallium` + `mesa-opencl` + `mesa-libclc` | 98.4 MB | **−74%** |
| ffmpeg family (12 pkgs) | 16.7 MB | same family, stock | 71.7 MB | **−77%** |
| `sdl2_image-mini` | 0.1 MB | `SDL2_image` + `-devel` | 0.3 MB | **−63%** |
| `glycin-mini` | 2.0 MB | `glycin` | 5.0 MB | **−60%** |
| `gtk4-mini` | 23.9 MB | `gtk4` + `gtk4-devel` | 51.7 MB | **−54%** |
| `kiconthemes-mini` | 0.2 MB | `kiconthemes` | 0.4 MB | **−50%** |
| `qt6-base-mini` | 15.1 MB | `qt6-base` + `qt6-base-devel` | 24.4 MB | **−38%** |
| `librsvg-mini` | 4.5 MB | `librsvg` | 6.7 MB | **−33%** |
| `opus-mini` | 0.3 MB | `opus` | 4.7 MB | **−94%** |
| `libxml2-mini` | 1.5 MB | `libxml2` | 1.5 MB | ±0% |
| `libdecor-mini` | 0.4 MB | `libdecor` + `-devel` | 0.2 MB | **+125%** |

`mesa-zink-mini` (4.4 MB) has no clean 1:1 comparison: Void ships zink inside
`mesa-libgallium` (43.7 MB) alongside every other Gallium driver, whereas this
package is zink + softpipe + virgl only.

Two rows are not wins, and it is worth being explicit about them:

* **`libxml2-mini` is the same size.** The package drops the `libicu78`
  dependency, which is the entire point — the win is in the transitive closure,
  not the archive.
* **`libdecor-mini` is about 2× larger** than Void's C `libdecor`. There is no
  size argument for it here; the reason to use it is that it is a pure-Rust
  implementation with no GTK or D-Bus dependency.

---

## What each package drops

* **`mesa-mini`** — compiled with LLVM enabled for the build but with
  `-Ddraw-use-llvm=false -Damd-use-llvm=false`, so the result does **not** link
  `libLLVM.so.1` at runtime. Verified: `libLLVM.so.1` is absent from the
  package's `shlib-requires`. OpenGL, Vulkan and VA-API still work.
* **`mesa-nano`** — same as `mini` but built with `-Os`. Roughly 30% smaller
  again. `-Os` can cost performance and, in rare cases, stability, so avoid it
  for emulators and other latency-critical code.
* **`llvm21-mini` / `llvm21-nano`** — `MinSizeRel`, no assertions, no unwind
  tables, no zlib/zstd/libxml2/curl/terminfo, no docs, tests, benchmarks or
  examples. Ships only `libLLVM` shared libraries plus `llvm-config`; no
  headers, static archives or tools. `mini` builds just the `X86` codegen
  backend, `nano` builds `X86;AMDGPU`.
* **`icu-mini`** — builds `icudt78l.dat` from ICU's source data using
  [`files/filter.json`](srcpkgs/icu-mini/files/filter.json), keeping only
  `en_US`/`en_GB`, 23 collation languages, dropping brkitr and conversion data
  and reducing transliteration to script conversion. The generated data file is
  3.0 MB against roughly 30 MB unfiltered.
* **`webkit2gtk-4.1-mini`** — no AVIF, no sysprof capture, and trimmed
  WebKit features. Needs ~12 GB RAM to compile; that is why CI runs on
  GitHub's 16 GB runners.
* **`gtk4-mini`** — no Vulkan, broadway, cloudproviders, colord, CUPS, tracker
  or media-gstreamer.
* **`gtk3-mini`** — no broadway, cloudproviders or man pages.
* **`gtk2-mini`** — stock GTK+ 2.24.33 from GNOME upstream, no GObject
  introspection, no CUPS, built with `-Os`.
* **`gdk-pixbuf2-mini`**, **`librsvg-mini`** — remove the `glycin` dependency
  (which pulls `bwrap` and is troublesome on old kernels for AppImages).
  `librsvg-mini` ships only the pixbuf loader.
* **`qt6-base-mini`** — no ICU, no journald, no VNC.
* **`libxml2-mini`** — no ICU.
* **`ffmpeg` family** — removes libx265 (and therefore ~16 MB of transitive
  deps), plus AV1 encoding via libaom / SVT-AV1 / rav1e. AV1 **decoding** still
  works. Also drops OpenCL, libplacebo, frei0r, gsm, opencore-amr, libjxl,
  librsvg, openjpeg and vapoursynth.
* **`ffmpeg-nano`** — a much smaller ffmpeg that only decodes
  `mp3, opus, vorbis, flac, aac, png, mjpeg, h264, vp8, vp9, theora` and raw
  PCM. All encoders are disabled.
* **`sdl2_image-mini`** — no AVIF, no JPEG-XL. AVIF alone pulls `libavif` plus
  the whole AV1 family (`libaom`, `SvtAv1Enc`, `rav1e`, `dav1d`). PNG/JPG/TIFF/WEBP
  still work.
* **`glycin-mini`** — builds [`glycin-ng`](https://github.com/QaidVoid/glycin-ng),
  an alternative that avoids the problems GNOME's glycin has.
* **`libdecor-mini`** — builds [`libdecor-rs`](https://github.com/QaidVoid/libdecor-rs),
  a pure-Rust libdecor without GTK/D-Bus (good for SDL apps).
* **`mangohud-mini`** — no `mangoapp`, no Python.
* **`intel-media-driver-mini`** — `MinSizeRel`.
* **`opus-mini`** — a 0.3 MB library against Void's stock 4.7 MB.
* **`kiconthemes-mini`** — drops the Breeze icon theme.

---

## Building

```sh
./bin/build-void-ci <template> [output-dir]   # one package in a Void container
./build-void.sh <template>                    # disposable container
./build-void-keep.sh <template>               # resumable: keeps the builddir
```

All three run `xbps-src` inside a Void container in *ethereal* chroot mode,
where the container root filesystem **is** the masterdir. `build-void-keep.sh`
uses a persistent container plus `XBPS_KEEP_BUILD_DIR=yes`, so a packaging-only
failure reuses compiled objects instead of forcing a full recompile — worth it
for LLVM, which takes hours.

To use the packages, add the `continuous` release as a repository. The release
ships an `x86_64-repodata` index alongside the `.xbps` files, which xbps
requires before it will install from a directory or a URL:

```sh
sudo xbps-install -R https://github.com/kazam0180/voidlinux-pkgs-debloated/releases/download/continuous
sudo xbps-install -y mesa-mini
```

Building that index locally works too, if you have a directory of `.xbps`
files:

```sh
cd /path/to/packages
xbps-rindex -a *.xbps          # writes x86_64-repodata
sudo xbps-install -R "$PWD" -y mesa-mini
```

Note that `llvm21-mini`/`llvm21-nano` are runtime-only replacements for
`libllvm21`; they carry no headers, static archives or CMake files, so keep the
stock `llvm21-devel` when *building* against LLVM.

---

## Projects using these packages

* [Anylinux-AppImages](https://github.com/pkgforge-dev/Anylinux-AppImages) — [ghostty](https://github.com/pkgforge-dev/ghostty-appimage), [citron](https://github.com/pkgforge-dev/Citron-appimage) and many more
* [goverlay](https://github.com/benjamimgois/goverlay)
* [Steam-appimage](https://github.com/ivan-hc/Steam-appimage)
* [interstellar](https://github.com/interstellar-app/interstellar)
* [QDiskInfo](https://github.com/edisionnano/QDiskInfo)
* [mangojuice](https://github.com/radiolamp/mangojuice)
* [CPU-X](https://github.com/TheTumultuousUnicornOfDarkness/CPU-X)
* [ppsspp](https://github.com/hrydgard/ppsspp)
* [Eden](https://github.com/eden-emulator/Releases)