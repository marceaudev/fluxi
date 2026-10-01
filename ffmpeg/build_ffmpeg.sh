#!/usr/bin/env bash
#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Modifié pour Fluxi (d'après androidx/media 1.11.1,
# libraries/decoder_ffmpeg/src/main/jni/build_ffmpeg.sh) : fonctionne aussi sous
# Windows (Git Bash), télécharge FFmpeg, compile la bibliothèque JNI et la copie dans
# android/app/src/main/jniLibs.
#
# Compile le décodeur audio FFmpeg utilisé par ExoPlayer (libffmpegJNI.so) pour
# arm64-v8a, armeabi-v7a et x86_64. FFmpeg est compilé en LGPL : aucune option
# --enable-gpl ni --enable-nonfree, uniquement des décodeurs audio. Le script
# s'arrête si FFmpeg ne se déclare pas sous licence LGPL.
#
# Usage : android/ffmpeg/build_ffmpeg.sh <dossier de travail, sans espace>
set -euo pipefail

FFMPEG_VERSION="6.0.1"          # Version recommandée par le module ExoPlayer.
NDK_VERSION="28.2.13676358"     # Doit correspondre à flutter.ndkVersion.
CMAKE_VERSION="3.22.1"
MIN_SDK=24                      # minSdk de l'app.
DECODERS=(ac3 eac3 dca truehd mlp mp2 alac)
ABIS=(arm64-v8a armeabi-v7a x86_64)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JNI_LIBS="$SCRIPT_DIR/../app/src/main/jniLibs"
WORK="${1:?Indiquez un dossier de travail (sans espace dans le chemin)}"
case "$WORK" in *" "*) echo "Le dossier de travail ne doit pas contenir d'espace."; exit 1 ;; esac
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"

# Outils du SDK Android (NDK, CMake), selon le système.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    HOST=windows-x86_64
    EXE=.exe
    SDK="$(cygpath -u "${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}")"
    native_path() { cygpath -m "$1"; } # Chemin lisible par les outils Windows.
    ;;
  Linux | Darwin)
    [ "$(uname -s)" = Linux ] && HOST=linux-x86_64 || HOST=darwin-x86_64
    EXE=
    SDK="${ANDROID_HOME:?Définissez ANDROID_HOME (dossier du SDK Android)}"
    native_path() { echo "$1"; }
    ;;
  *) echo "Système non pris en charge."; exit 1 ;;
esac
NDK="$SDK/ndk/$NDK_VERSION"
TC="$NDK/toolchains/llvm/prebuilt/$HOST/bin"
CMAKE="$SDK/cmake/$CMAKE_VERSION/bin/cmake$EXE"
NINJA="$SDK/cmake/$CMAKE_VERSION/bin/ninja$EXE"
[ -d "$TC" ] || { echo "NDK $NDK_VERSION introuvable : $NDK"; exit 1; }
[ -x "$CMAKE" ] || { echo "CMake $CMAKE_VERSION introuvable : $CMAKE"; exit 1; }
# Sous Windows, « make » est fourni avec le NDK.
if [ -d "$NDK/prebuilt/$HOST/bin" ]; then export PATH="$NDK/prebuilt/$HOST/bin:$PATH"; fi
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"
JOBS="$(nproc 2> /dev/null || echo 4)"

# Sources de FFmpeg, téléchargées une seule fois.
SRC="$WORK/ffmpeg-$FFMPEG_VERSION"
if [ ! -d "$SRC" ]; then
  curl -fL -o "$WORK/ffmpeg-$FFMPEG_VERSION.tar.xz" \
    "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz"
  tar -xf "$WORK/ffmpeg-$FFMPEG_VERSION.tar.xz" -C "$WORK"
fi

COMMON=(
  --target-os=android --enable-cross-compile --disable-autodetect
  --enable-static --disable-shared --disable-doc --disable-programs --disable-everything
  --disable-avdevice --disable-avformat --disable-swscale --disable-postproc
  --disable-avfilter --disable-symver --enable-swresample --disable-v4l2-m2m --disable-vulkan
  --nm="$TC/llvm-nm$EXE" --ar="$TC/llvm-ar$EXE" --ranlib="$TC/llvm-ranlib$EXE"
  --strip="$TC/llvm-strip$EXE"
)
for decoder in "${DECODERS[@]}"; do COMMON+=(--enable-decoder="$decoder"); done

# build_abi <abi> <arch> <cpu> <préfixe du compilateur> [options FFmpeg en plus]
build_abi() {
  local abi=$1 arch=$2 cpu=$3 triple=$4
  shift 4
  local prefix="$WORK/out/$abi"
  local jni_build="$WORK/jni-$abi"

  echo "=== $abi : FFmpeg"
  (
    cd "$SRC"
    make distclean > /dev/null 2>&1 || true
    ./configure --prefix="$prefix" --arch="$arch" --cpu="$cpu" \
      --cc="$TC/$triple$MIN_SDK-clang" --cxx="$TC/$triple$MIN_SDK-clang++" \
      "${COMMON[@]}" "$@" > "$WORK/configure-$abi.log"
    grep -q "^License: LGPL" "$WORK/configure-$abi.log" \
      || { echo "FFmpeg n'est pas sous LGPL : arrêt."; exit 1; }
    make -j"$JOBS" > "$WORK/make-$abi.log" 2>&1
    make install-libs install-headers >> "$WORK/make-$abi.log" 2>&1
  )

  echo "=== $abi : libffmpegJNI.so"
  rm -rf "$jni_build"
  "$CMAKE" -G Ninja -S "$(native_path "$SCRIPT_DIR/jni")" -B "$(native_path "$jni_build")" \
    -DCMAKE_MAKE_PROGRAM="$(native_path "$NINJA")" \
    -DCMAKE_TOOLCHAIN_FILE="$(native_path "$NDK/build/cmake/android.toolchain.cmake")" \
    -DANDROID_ABI="$abi" -DANDROID_PLATFORM="android-$MIN_SDK" -DCMAKE_BUILD_TYPE=Release \
    -DFFMPEG_PREFIX="$(native_path "$prefix")" > "$WORK/cmake-$abi.log"
  "$CMAKE" --build "$(native_path "$jni_build")" >> "$WORK/cmake-$abi.log"
  mkdir -p "$JNI_LIBS/$abi"
  "$TC/llvm-strip$EXE" --strip-unneeded -o "$(native_path "$JNI_LIBS/$abi/libffmpegJNI.so")" \
    "$(native_path "$jni_build/libffmpegJNI.so")"
}

for abi in "${ABIS[@]}"; do
  case "$abi" in
    arm64-v8a) build_abi arm64-v8a aarch64 armv8-a aarch64-linux-android ;;
    armeabi-v7a)
      build_abi armeabi-v7a arm armv7-a armv7a-linux-androideabi \
        --extra-cflags="-march=armv7-a -mfloat-abi=softfp" --extra-ldflags="-Wl,--fix-cortex-a8"
      ;;
    x86_64) build_abi x86_64 x86_64 x86-64 x86_64-linux-android --disable-asm ;;
  esac
done

echo "=== Terminé :"
ls -l "$JNI_LIBS"/*/libffmpegJNI.so
