#
# Copyright 2021 The Android Open Source Project
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
# Modifié pour Fluxi (d'après androidx/media 1.11.1, libraries/decoder_ffmpeg) :
# les bibliothèques et en-têtes FFmpeg sont lus dans FFMPEG_PREFIX (compilés par
# ../build_ffmpeg.sh), et les pages mémoire de 16 Ko sont exigées au lien.

cmake_minimum_required(VERSION 3.21.0 FATAL_ERROR)

set(CMAKE_CXX_STANDARD 11)

project(libffmpegJNI C CXX)

if(NOT FFMPEG_PREFIX)
    message(FATAL_ERROR "FFMPEG_PREFIX manquant : dossier où FFmpeg a été installé.")
endif()

foreach(ffmpeg_lib avutil swresample avcodec)
    add_library(${ffmpeg_lib} STATIC IMPORTED)
    set_target_properties(${ffmpeg_lib} PROPERTIES
                          IMPORTED_LOCATION ${FFMPEG_PREFIX}/lib/lib${ffmpeg_lib}.a)
endforeach()

include_directories(${FFMPEG_PREFIX}/include)
find_library(android_log_lib log)

add_library(ffmpegJNI
            SHARED
            ffmpeg_jni.cc)

set_target_properties(ffmpegJNI PROPERTIES
                      CXX_VISIBILITY_PRESET hidden
                      VISIBILITY_INLINES_HIDDEN ON)

target_link_libraries(ffmpegJNI
                      PRIVATE android
                      PRIVATE swresample
                      PRIVATE avcodec
                      PRIVATE avutil
                      PRIVATE ${android_log_lib})

# Additional flags needed for "arm64-v8a" from NDK 23.1.7779620 and above.
# See https://github.com/google/ExoPlayer/issues/9933#issuecomment-1029775358.
if(ANDROID_ABI STREQUAL "arm64-v8a")
    target_link_options(ffmpegJNI PRIVATE "-Wl,-Bsymbolic")
endif()

# Pages mémoire de 16 Ko : exigé par Google Play pour les bibliothèques natives.
target_link_options(ffmpegJNI PRIVATE "-Wl,-z,max-page-size=16384")
