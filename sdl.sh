#!/bin/bash
# Oliver Epper <oliver.epper@gmail.com>

set -e

if [ $# -eq 0 ]
then
    echo "sh ./sdl.sh <absolute path>"
    exit 1
fi

PREFIX=$1
SDL_VERSION=release-2.26.2
IOS_TOOLCHAIN_VERSION=4.3.0

if [ -d SDL ]
then
    pushd SDL
    git clean -fxd
    git reset --hard $SDL_VERSION
    popd
else
    git -c advice.detachedHead=false clone --depth 1 --branch $SDL_VERSION https://github.com/libsdl-org/SDL.git
fi

if [ -d ios-cmake ]
then
    pushd ios-cmake
    git clean -fxd
    git reset --hard $IOS_TOOLCHAIN_VERSION
    popd
else
    git -c advice.detachedHead=false clone --depth 1 --branch $IOS_TOOLCHAIN_VERSION https://github.com/leetal/ios-cmake.git
fi

function build {
    local TOOLCHAIN_PLATFORM_NAME=$1
    local INSTALL_PREFIX=$2
    local DEPLOYMENT_TARGET=$3

    echo "Building for platform ${TOOLCHAIN_PLATFORM_NAME} with deployment target ${DEPLOYMENT_TARGET}"
    echo "Installing to: ${INSTALL_PREFIX}"

    cmake -Bbuild/"${TOOLCHAIN_PLATFORM_NAME}" \
        -SSDL \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DCMAKE_TOOLCHAIN_FILE=../ios-cmake/ios.toolchain.cmake \
        -DPLATFORM="${TOOLCHAIN_PLATFORM_NAME}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
        -DENABLE_BITCODE=OFF \
        -DSDL_HAPTIC=OFF \
        -DSDL_HIDAPI_JOYSTICK=OFF \
        -DSDL_SYSTEM_ICONV=OFF \
        -DSDL_JOYSTICK=OFF &&

    cmake --build build/"${TOOLCHAIN_PLATFORM_NAME}" \
        --config Release \
        --target install
}

# build for macOS on arm64
MACOS_ARM64_INSTALL_PREFIX="${PREFIX}/macos-arm64"
build MAC_ARM64 "${MACOS_ARM64_INSTALL_PREFIX}" 11.0

# build for macOS on x86_64
MACOS_X86_64_INSTALL_PREFIX="${PREFIX}/macos-x86_64"
build MAC "${MACOS_X86_64_INSTALL_PREFIX}" 11.0
