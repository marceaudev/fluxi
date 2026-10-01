# FFmpeg in Fluxi — sources (LGPL 2.1)

*Français plus bas.*

Fluxi (Android / Android TV) uses **FFmpeg 6.0.1** only to decode some audio formats (AC-3, E-AC-3,
DTS, TrueHD, MLP, MP2, ALAC) when the device cannot. FFmpeg is licensed under the
**GNU Lesser General Public License version 2.1 or later** (see `licenses/`). It is built
**without** `--enable-gpl` and `--enable-nonfree`.

This folder gives everything needed to rebuild the FFmpeg library used by Fluxi, modify it and link
it again, as required by the LGPL:

| File | Content |
|---|---|
| `ffmpeg-6.0.1.tar.xz` | Exact, unmodified FFmpeg sources (same file as https://ffmpeg.org/releases/ffmpeg-6.0.1.tar.xz) |
| `build_ffmpeg.sh` | Build script, with the full `configure` options |
| `jni/ffmpeg_jni.cc`, `jni/CMakeLists.txt` | Binding code between FFmpeg and the player (`libffmpegJNI.so`) |
| `java/` | Java side of the decoder (from androidx/media 1.11.1, `decoder_ffmpeg`, Apache 2.0) |
| `licenses/` | LGPL 2.1 (FFmpeg) and Apache 2.0 (binding code) |

## Rebuild and replace the library

1. Install the Android SDK with NDK `28.2.13676358` and CMake `3.22.1`.
2. Run (bash): `./build_ffmpeg.sh <work folder without spaces>` from a copy of the Fluxi Android
   sources, or adapt its paths. It produces `libffmpegJNI.so` for `arm64-v8a`, `armeabi-v7a` and
   `x86_64`, with FFmpeg statically linked into it.
3. To use a modified FFmpeg: change the sources in the work folder and run the script again. The
   resulting `libffmpegJNI.so` replaces the one in the Fluxi APK (`lib/<abi>/libffmpegJNI.so`); the
   APK must then be signed again with your own key to be installed.

Fluxi's terms of use do not restrict the rights given by the LGPL, including modifying the library
and the reverse engineering needed to debug such modifications.

---

# FFmpeg dans Fluxi — sources (LGPL 2.1)

Fluxi utilise **FFmpeg 6.0.1** uniquement pour décoder certains sons (AC-3, E-AC-3, DTS, TrueHD,
MLP, MP2, ALAC) quand l'appareil ne sait pas le faire. FFmpeg est sous **licence publique générale
limitée GNU (LGPL) version 2.1 ou ultérieure** (voir `licenses/`), compilé **sans** `--enable-gpl` ni
`--enable-nonfree`.

Ce dossier contient tout ce qu'il faut pour recompiler la bibliothèque FFmpeg de Fluxi, la modifier
et la relier à nouveau, comme l'exige la LGPL : sources exactes de FFmpeg (`ffmpeg-6.0.1.tar.xz`),
script de compilation et options de `configure` (`build_ffmpeg.sh`), code de liaison (`jni/`), partie
Java du décodeur (`java/`) et textes des licences (`licenses/`). Mode d'emploi : voir ci-dessus.

Les conditions d'utilisation de Fluxi ne restreignent aucun des droits accordés par la LGPL,
notamment la modification de la bibliothèque et l'ingénierie inverse nécessaire pour la mettre au point.
