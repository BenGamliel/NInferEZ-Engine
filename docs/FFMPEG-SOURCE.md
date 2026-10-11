FFmpeg 8.1.2 corresponding source for NInferEZ Engine 1.0.0 (all Windows GPU targets)

FFmpeg is Copyright (c) the FFmpeg developers and licensed under LGPL 2.1 or later
for this build. NInferEZ does not claim authorship of FFmpeg. Dynamic shared
libraries were built without --enable-gpl or --enable-nonfree.

Contents
- upstream/ffmpeg-ffmpeg-n8.1.2.tar.gz: original source, verified against the exact
  SHA512 recorded by the dependency build.
- ffmpeg/: complete patched source used to compile the shipped libraries.
- vcpkg/ports/ffmpeg/: exact port and all patches, checked against build ABI hashes.
- vcpkg/scripts/, vcpkg/triplets/: helper scripts and triplet definitions.
- build-records/: configure scripts, response files, generated configuration and
  config.mak recording the actual Release build. The build used an N: build drive;
  adapt those paths to your own extraction directory and dependency/tool paths.
- upstream/madler-zlib-v1.3.2.tar.gz: source of the selected zlib dependency.
- binary-provenance.json: hashes connecting this source to the shipped DLLs.

Rebuilding
Use a Visual Studio 2022 x64 Native Tools environment with MSVC 14.44, the Windows
SDK, MSYS2 bash/make/pkg-config, and NASM. The exact configure command and compiler
flags are in build-records/build.sh and ffbuild/config.mak. Extract the zlib source
and build its x64 MSVC Release library first, or use vcpkg's zlib port. Adapt the
source/package/pkg-config/zlib paths in build.sh and run it from an empty build
folder. The included portfile.cmake is the authoritative patch order and build
recipe. An alternative is vcpkg install with the preserved port/helper scripts,
x64-windows triplet, and the features listed in vcpkg_abi_info.txt. FFmpeg programs
are disabled; avcodec, avdevice, avfilter, avformat, swresample, swscale and zlib
are enabled. Keep the shared libraries replaceable when redistributing.

There are no additional NInferEZ source edits to FFmpeg beyond the included vcpkg
patches. The complete LGPL text and original source copyright notices are retained.
This archive is publicly available next to the Engine binary downloads:
https://github.com/BenGamliel/NInferEZ-Engine/releases/download/v1.0.0/FFmpeg-8.1.2-Corresponding-Source.zip
