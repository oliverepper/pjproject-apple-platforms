#!/bin/bash
# Oliver Epper <oliver.epper@gmail.com>

set -e
env -i

if [ $# -eq 0 ]
then
    echo "sh ./start.sh <absolute path>"
    exit 1
fi

PREFIX=$1
PJPROJECT_VERSION=2.12.1
IOS_ARM64_INSTALL_PREFIX="${PREFIX}/ios-arm64"
IOS_ARM64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-arm64-simulator"
IOS_X86_64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-x86_64-simulator"
IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-arm64_x86_64-simulator"
IOS_ARM64_MACCATALYST_INSTALL_PREFIX="${PREFIX}/ios-arm64-maccatalyst"
IOS_X86_64_MACCATALYST_INSTALL_PREFIX="${PREFIX}/ios-x86_64-maccatalyst"
IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX="${PREFIX}/ios-arm64_x86_64-maccatalyst"
MACOS_ARM64_INSTALL_PREFIX="${PREFIX}/macos-arm64"
MACOS_X86_64_INSTALL_PREFIX="${PREFIX}/macos-x86_64"
MACOS_ARM64_X86_64_INSTALL_PREFIX="${PREFIX}/macos-arm64_x86_64"

if [ -d pjproject ]
then
    pushd pjproject
    git reset --hard $PJPROJECT_VERSION
    popd
else
    git -c advice.detachedHead=false clone --depth 1 --branch $PJPROJECT_VERSION https://github.com/pjsip/pjproject # > /dev/null 2>&1
fi

#
# helper function
#
function createLib {
    pushd "$1"
    if [ -d "${OPUS[@]: -1}" ]; then
        libtool -static -o libpjproject.a ./*.a "${OPUS[@] -1}"/lib/libopus.a
    else
        libtool -static -o libpjproject.a ./*.a
    fi
    ranlib libpjproject.a
    popd
}

#
# create base configuration for pjproject build
#
pushd pjproject
cat << EOF > pjlib/include/pj/config_site.h
#define PJ_HAS_SSL_SOCK 1
#undef PJ_SSL_SOCK_IMP
#define PJ_SSL_SOCK_IMP PJ_SSL_SOCK_IMP_APPLE
#include <pj/config_site_sample.h>
EOF
popd

function prepare {
    local WANTS_IPHONE=$1

    git reset --hard
    git clean -fxd

    cat << EOF > pjlib/include/pj/config_site.h
#define PJ_HAS_SSL_SOCK 1
#undef PJ_SSL_SOCK_IMP
#define PJ_SSL_SOCK_IMP PJ_SSL_SOCK_IMP_APPLE
#include <pj/config_site_sample.h>
EOF

    if [[ WANTS_IPHONE="YES" ]]; then
        sed -i '' -e '1i\
#define PJ_CONFIG_IPHONE 1
' pjlib/include/pj/config_site.h
    fi
}


#
# build for iOS on arm64
#
rm -rf "${IOS_ARM64_INSTALL_PREFIX}"
pushd pjproject
prepare YES

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/ios-arm64)
if [[ -d "${OPUS[@]: -1}" ]]
then
    CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
fi

SDKPATH=$(xcrun -sdk iphoneos --show-sdk-path)
ARCH="arm64"
CFLAGS="-isysroot $SDKPATH -miphoneos-version-min=13 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" -arch $ARCH" \
LDFLAGS="-isysroot $SDKPATH -framework AudioToolbox -framework Foundation -framework Network -framework Security -arch $ARCH" \
./aconfigure --prefix="$IOS_ARM64_INSTALL_PREFIX" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

make dep && make clean
make
make install

createLib "$IOS_ARM64_INSTALL_PREFIX"/lib
popd


#
# build for iOS simulator on arm64
#
rm -rf "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}"
pushd pjproject
prepare YES

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/ios-arm64-simulator)
if [[ -d "${OPUS[@]: -1}" ]]
then
    CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
fi

SDKPATH=$(xcrun -sdk iphonesimulator --show-sdk-path)
ARCH="arm64"
CFLAGS="-isysroot $SDKPATH -miphonesimulator-version-min=13 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" -arch $ARCH" \
LDFLAGS="-isysroot $SDKPATH -framework AudioToolbox -framework Foundation -framework Network -framework Security -arch $ARCH" \
./aconfigure --prefix="$IOS_ARM64_SIMULATOR_INSTALL_PREFIX" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

make dep && make clean
make
make install

createLib "$IOS_ARM64_SIMULATOR_INSTALL_PREFIX"/lib
popd


#
# build for iOS simulator on x86_64
#
rm -rf "${IOS_X86_64_SIMULATOR_INSTALL_PREFIX}"
pushd pjproject
prepare YES

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/ios-x86_64-simulator)
if [[ -d "${OPUS[@]: -1}" ]]
then
    CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
fi

SDKPATH=$(xcrun -sdk iphonesimulator --show-sdk-path)
ARCH="x86_64"
CFLAGS="-isysroot $SDKPATH -miphonesimulator-version-min=13 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" -arch $ARCH" \
LDFLAGS="-isysroot $SDKPATH -framework AudioToolbox -framework Foundation -framework Network -framework Security -arch $ARCH" \
./aconfigure --prefix="$IOS_X86_64_SIMULATOR_INSTALL_PREFIX" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

make dep && make clean
make
make install

createLib "$IOS_X86_64_SIMULATOR_INSTALL_PREFIX"/lib
popd


#
# build fat lib for simulator
#
mkdir -p "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib"
lipo -create \
    "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}/lib/libpjproject.a" \
    "${IOS_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libpjproject.a" \
    -output \
    "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libpjproject.a"


#
# build for Catalyst on arm64
#
rm -rf "${IOS_ARM64_MACCATALYST_INSTALL_PREFIX}"
pushd pjproject
prepare YES

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/ios-arm64-maccatalyst)
if [[ -d "${OPUS[@]: -1}" ]]
then
    CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
fi

SDKPATH=$(xcrun -sdk macosx --show-sdk-path)
ARCH="arm64"
CFLAGS="-isysroot $SDKPATH -isystem ${SDKPATH}/System/iOSSupport/usr/include -iframework ${SDKPATH}/System/iOSSupport/System/Library/Frameworks -miphoneos-version-min=13.1 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" -arch $ARCH -target ${ARCH}-apple-ios-macabi" \
LDFLAGS="-isysroot $SDKPATH -isystem ${SDKPATH}/System/iOSSupport/usr/include -iframework ${SDKPATH}/System/iOSSupport/System/Library/Frameworks -framework Network -framework Security -framework Foundation -arch $ARCH -target ${ARCH}-apple-ios-macabi" \
./aconfigure --prefix="$IOS_ARM64_MACCATALYST_INSTALL_PREFIX" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

make dep && make clean
make VERBOSE=1
make install

createLib "$IOS_ARM64_MACCATALYST_INSTALL_PREFIX"/lib
popd


# build for Catalyst on x86_64
rm -rf "${IOS_X86_64_MACCATALYST_INSTALL_PREFIX}"
pushd pjproject
prepare YES

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/ios-x86_64-maccatalyst)
if [[ -d "${OPUS[@]: -1}" ]]
then
    CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
fi

SDKPATH=$(xcrun -sdk macosx --show-sdk-path)
ARCH="x86_64"
CFLAGS="-isysroot $SDKPATH -isystem ${SDKPATH}/System/iOSSupport/usr/include -iframework ${SDKPATH}/System/iOSSupport/System/Library/Frameworks -miphoneos-version-min=13.1 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" -arch $ARCH -target ${ARCH}-apple-ios-macabi" \
LDFLAGS="-isysroot $SDKPATH -isystem ${SDKPATH}/System/iOSSupport/usr/include -iframework ${SDKPATH}/System/iOSSupport/System/Library/Frameworks -framework Network -framework Security -framework Foundation -arch $ARCH -target ${ARCH}-apple-ios-macabi" \
./aconfigure --prefix="$IOS_X86_64_MACCATALYST_INSTALL_PREFIX" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

make dep && make clean
make VERBOSE=1
make install

createLib "$IOS_X86_64_MACCATALYST_INSTALL_PREFIX"/lib
popd


#
# build fat lib for catalyst
#
mkdir -p "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}/lib"
lipo -create \
    "${IOS_ARM64_MACCATALYST_INSTALL_PREFIX}/lib/libpjproject.a" \
    "${IOS_X86_64_MACCATALYST_INSTALL_PREFIX}/lib/libpjproject.a" \
    -output \
    "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}/lib/libpjproject.a"



#
# build for macOS on arm64
#
rm -rf "${MACOS_ARM64_INSTALL_PREFIX}"
pushd pjproject
prepare NO

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/macos-arm64)
if [[ -d "${OPUS[@]: -1}" ]]
then
    CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
fi

SDKPATH=$(xcrun -sdk macosx --show-sdk-path)
ARCH="arm"
CFLAGS="-isysroot $SDKPATH -mmacosx-version-min=11 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\"" \
LDFLAGS="-isysroot $SDKPATH -framework AudioToolbox -framework Foundation -framework Network -framework Security" \
./aconfigure --prefix="$MACOS_ARM64_INSTALL_PREFIX" --host="${ARCH}"-apple-darwin "$CONFIGURE_EXTRA_PARAMS"

make dep && make clean
make
make install

createLib "$MACOS_ARM64_INSTALL_PREFIX"/lib
popd


#
# build for macOS on x86_64
#
rm -rf "${MACOS_X86_64_INSTALL_PREFIX}"
pushd pjproject
prepare NO

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/macos-x86_64)
if [[ -d "${OPUS[@]: -1}" ]]
then
    CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
fi

SDKPATH=$(xcrun -sdk macosx --show-sdk-path)
ARCH="x86_64"
CFLAGS="-isysroot $SDKPATH -mmacosx-version-min=11 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" -arch ${ARCH}" \
LDFLAGS="-isysroot $SDKPATH -framework AudioToolbox -framework Foundation -framework Network -framework Security -arch ${ARCH}" \
./aconfigure --prefix="$MACOS_X86_64_INSTALL_PREFIX" --host="${ARCH}"-apple-darwin "$CONFIGURE_EXTRA_PARAMS"

make dep && make clean
arch -arch x86_64 make
make install

createLib "$MACOS_X86_64_INSTALL_PREFIX"/lib
popd


#
# build fat lib for macos
#
mkdir -p "${MACOS_ARM64_X86_64_INSTALL_PREFIX}/lib"
lipo -create \
    "${MACOS_ARM64_INSTALL_PREFIX}/lib/libpjproject.a" \
    "${MACOS_X86_64_INSTALL_PREFIX}/lib/libpjproject.a" \
    -output \
    "${MACOS_ARM64_X86_64_INSTALL_PREFIX}/lib/libpjproject.a"


#
# create xcframework
#
mkdir -p "$PREFIX"/lib
XCFRAMEWORK="$PREFIX/lib/libpjproject.xcframework"
rm -rf "$XCFRAMEWORK"
xcodebuild -create-xcframework \
-library "${IOS_ARM64_INSTALL_PREFIX}/lib/libpjproject.a" \
-headers "${IOS_ARM64_INSTALL_PREFIX}/include" \
-library "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libpjproject.a" \
-headers "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}/include" \
-library "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}/lib/libpjproject.a" \
-headers "${IOS_ARM64_MACCATALYST_INSTALL_PREFIX}/include" \
-library "${MACOS_ARM64_X86_64_INSTALL_PREFIX}/lib/libpjproject.a" \
-headers "${MACOS_ARM64_INSTALL_PREFIX}/include" \
-output "${XCFRAMEWORK}"

#
# install the system version
#
cp -a "${PREFIX}/macOS-$(arch)/include" "${PREFIX}"
cp -a "${PREFIX}/macOS-$(arch)/lib" "${PREFIX}"

#
# clean-up for now
#
rm -rf "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}"
rm -rf "${IOS_ARM64_X86_64_MACCATALYST_INSTALL_PREFIX}"
rm -rf "${MACOS_ARM64_X86_64_INSTALL_PREFIX}"
