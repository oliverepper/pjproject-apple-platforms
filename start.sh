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

if [ -d pjproject ]
then
    pushd pjproject
    git reset --hard $PJPROJECT_VERSION
    popd
else
    git -c advice.detachedHead=false clone --depth 1 --branch $PJPROJECT_VERSION https://github.com/pjsip/pjproject # > /dev/null 2>&1
fi

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

# build for iOS on arm64
IOS_ARM64_INSTALL_PREFIX="${PREFIX}/ios-arm64"
rm -rf "${IOS_ARM64_INSTALL_PREFIX}"
pushd pjproject
sed -i '' -e '1i\
#define PJ_CONFIG_IPHONE 1
' pjlib/include/pj/config_site.h

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
sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib "$IOS_ARM64_INSTALL_PREFIX"/lib
popd


# build for iOS simulator on arm64
IOS_ARM64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-arm64-simulator"
rm -rf "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}"
pushd pjproject
sed -i '' -e '1i\
#define PJ_CONFIG_IPHONE 1
' pjlib/include/pj/config_site.h

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
sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib "$IOS_ARM64_SIMULATOR_INSTALL_PREFIX"/lib
popd


# build for iOS simulator on x86_64
IOS_X86_64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-x86_64-simulator"
rm -rf "${IOS_X86_64_SIMULATOR_INSTALL_PREFIX}"
pushd pjproject
sed -i '' -e '1i\
#define PJ_CONFIG_IPHONE 1
' pjlib/include/pj/config_site.h

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
sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib "$IOS_X86_64_SIMULATOR_INSTALL_PREFIX"/lib
popd


# build fat lib for simulator
IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX="${PREFIX}/ios-arm64_x86_64-simulator"
mkdir -p "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib"
lipo -create \
    "${IOS_ARM64_SIMULATOR_INSTALL_PREFIX}/lib/libpjproject.a" \
    "${IOS_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libpjproject.a" \
    -output \
    "${IOS_ARM64_X86_64_SIMULATOR_INSTALL_PREFIX}/lib/libpjproject.a"



# #
# # build for iOS simulator running on arm64
# #
# OUT_IOS_SIM_ARM64=$PREFIX/iOS_simulator_arm64
# if [[ $TARGETS =~ "IOS_SIM_ARM64" ]]; then
# rm -rf "$OUT_IOS_SIM_ARM64"
# pushd pjproject

# sed -i '' -e '1i\
# #define PJ_CONFIG_IPHONE 1
# ' pjlib/include/pj/config_site.h

# OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/ios-arm64-simulator)
# if [[ -d "${OPUS[@]: -1}" ]]
# then
# 	CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
# fi

# SDKPATH=$(xcrun -sdk iphonesimulator --show-sdk-path)
# ARCH="arm64"
# export CFLAGS="-isysroot "$SDKPATH" -miphonesimulator-version-min=13 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" $GENERAL_CFLAGS -arch "$ARCH""
# export LDFLAGS="-isysroot "$SDKPATH" -framework AudioToolbox -framework Foundation -arch "$ARCH""
# ./aconfigure --prefix="$OUT_IOS_SIM_ARM64" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

# make dep && make clean
# CFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable" make
# make install
# sed -i '' -e '1d' pjlib/include/pj/config_site.h

# createLib "$OUT_IOS_SIM_ARM64"/lib
# popd
# fi

# #
# # build for iOS simulator running on x86_64
# #
# OUT_IOS_SIM_X86_64=$PREFIX/iOS_simulator_x86_64
# if [[ $TARGETS =~ "IOS_SIM_X86_64" ]]; then
# rm -rf "$OUT_IOS_SIM_X86_64"
# pushd pjproject

# sed -i '' -e '1i\
# #define PJ_CONFIG_IPHONE 1
# ' pjlib/include/pj/config_site.h

# OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/ios-x86_64-simulator)
# if [[ -d "${OPUS[@]: -1}" ]]
# then
# 	echo "@@@@@@@@@@@@@@@@@@@@@@@@ FOUND OPUS"
# 	CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
# fi

# SDKPATH=$(xcrun -sdk iphonesimulator --show-sdk-path)
# ARCH="x86_64"
# export CFLAGS="-isysroot "$SDKPATH" -miphonesimulator-version-min=13 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" $GENERAL_CFLAGS -arch "$ARCH""
# export LDFLAGS="-isysroot "$SDKPATH" -framework AudioToolbox -framework Foundation -arch "$ARCH""
# ./aconfigure --prefix="$OUT_IOS_SIM_X86_64" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

# make dep && make clean
# CFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable" make
# make install

# sed -i '' -e '1d' pjlib/include/pj/config_site.h

# createLib "$OUT_IOS_SIM_X86_64"/lib
# popd
# fi

# #
# # build for iOS arm64
# #
# OUT_IOS_ARM64=$PREFIX/iOS_arm64
# if [[ $TARGETS =~ "IOS_ARM64" ]]; then
# rm -rf "$OUT_IOS_ARM64"
# pushd pjproject

# sed -i '' -e '1i\
# #define PJ_CONFIG_IPHONE 1
# ' pjlib/include/pj/config_site.h

# OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/iOS_arm64)
# if [[ -d "${OPUS[@]: -1}" ]]
# then
# 	CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
# fi

# SDKPATH=$(xcrun -sdk iphoneos --show-sdk-path)
# ARCH="arm64"
# export CFLAGS="-isysroot "$SDKPATH" -miphoneos-version-min=13 -DPJ_SDK_NAME=\"\\\"$(basename "$SDKPATH")\\\"\" $GENERAL_CFLAGS -arch "$ARCH""
# export LDFLAGS="-isysroot "$SDKPATH" -framework AudioToolbox -framework Foundation -arch "$ARCH""
# ./aconfigure --prefix="$OUT_IOS_ARM64" --host="${ARCH}"-apple-darwin_ios "$CONFIGURE_EXTRA_PARAMS" --disable-sdl

# make dep && make clean
# CFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable" make
# make install

# sed -i '' -e '1d' pjlib/include/pj/config_site.h

# createLib "$OUT_IOS_ARM64"/lib
# popd
# fi

# #
# # build for macOS arm64
# #
# OUT_MACOS_ARM64=$PREFIX/macOS_arm64
# if [[ $TARGETS =~ "MACOS_ARM64" ]]; then
# rm -rf "$OUT_MACOS_ARM64"
# pushd pjproject

# sed -i '' -e '/PJ_CONFIG_IPHONE/d' pjlib/include/pj/config_site.h

# OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/macOS_arm64)
# if [[ -d "${OPUS[@]: -1}" ]]
# then
# 	CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
# fi

# SDKPATH=$(xcrun -sdk macosx --show-sdk-path)
# ARCH="arm"
# export CFLAGS="-isysroot "$SDKPATH" -mmacosx-version-min=11 $GENERAL_CFLAGS"
# export LDFLAGS="-isysroot "$SDKPATH""
# ./aconfigure --prefix="$OUT_MACOS_ARM64" --host="${ARCH}"-apple-darwin "$CONFIGURE_EXTRA_PARAMS"

# make dep && make clean
# CFLAGS="-Wno-unused-but-set-variable" make
# make install

# sed -i '' -e '1d' pjlib/include/pj/config_site.h

# createLib "$OUT_MACOS_ARM64"/lib
# popd
# fi

# #
# # build for macOS x86_64
# #
# OUT_MACOS_X86_64=$PREFIX/macOS_x86_64
# if [[ $TARGETS =~ "MACOS_X86_64" ]]; then
# rm -rf "$OUT_MACOS_X86_64"
# pushd pjproject

# sed -i '' -e '/PJ_CONFIG_IPHONE/d' pjlib/include/pj/config_site.h

# OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/macOS_x86_64)
# if [[ -d "${OPUS[@]: -1}" ]]
# then
# 	CONFIGURE_EXTRA_PARAMS="--with-opus=${OPUS[@]: -1}"
# fi

# SDKPATH=$(xcrun -sdk macosx --show-sdk-path)
# ARCH="x86_64"
# export CFLAGS="-isysroot "$SDKPATH" -mmacosx-version-min=11 $GENERAL_CFLAGS -arch "$ARCH""
# export LDFLAGS="-isysroot "$SDKPATH" -arch "$ARCH""
# arch -arch "${ARCH}" ./aconfigure --prefix="$OUT_MACOS_X86_64" --host="${ARCH}"-apple-darwin "$CONFIGURE_EXTRA_PARAMS"

# make dep && make clean
# CFLAGS="-Wno-unused-but-set-variable" arch -arch x86_64 make
# make install

# sed -i '' -e '1d' pjlib/include/pj/config_site.h

# createLib "$OUT_MACOS_X86_64"/lib
# popd
# fi

# #
# # create fat lib for the mac
# #
# if [ -f "$OUT_MACOS_ARM64"/lib/libpjproject.a ] && [ -f "$OUT_MACOS_X86_64"/lib/libpjproject.a ]; then
# OUT_MACOS="$PREFIX/macOS_arm64_x86_64"
# mkdir -p "$OUT_MACOS"/lib
# lipo -create "$OUT_MACOS_ARM64"/lib/libpjproject.a "$OUT_MACOS_X86_64"/lib/libpjproject.a -output "$OUT_MACOS"/lib/libpjproject.a
# fi

# #
# # create fat lib for the simulator
# #
# if [ -f "$OUT_IOS_SIM_ARM64"/lib/libpjproject.a ] && [ -f "$OUT_IOS_SIM_X86_64"/lib/libpjproject.a ]; then
# OUT_IOS_SIM="$PREFIX/iOS_simulator_arm64_x86_64"
# mkdir -p "$OUT_IOS_SIM"/lib
# lipo -create "$OUT_IOS_SIM_ARM64"/lib/libpjproject.a "$OUT_IOS_SIM_X86_64"/lib/libpjproject.a -output "$OUT_IOS_SIM"/lib/libpjproject.a
# fi

# #
# # create xcframework
# #
# mkdir -p "$PREFIX"/lib
# XCFRAMEWORK="$PREFIX/lib/libpjproject.xcframework"
# rm -rf "$XCFRAMEWORK"
# xcodebuild -create-xcframework \
# -library "$OUT_IOS_SIM"/lib/libpjproject.a \
# -headers "$OUT_IOS_SIM_ARM64"/include \
# -library "$OUT_IOS_ARM64"/lib/libpjproject.a \
# -headers "$OUT_IOS_ARM64"/include \
# -library "$OUT_MACOS"/lib/libpjproject.a \
# -headers "$OUT_MACOS_ARM64"/include \
# -output "$XCFRAMEWORK"

# rm -rf "$OUT_IOS_SIM"
# rm -rf "$OUT_MACOS"

# #
# # don't just link lib & include
# #
# mkdir -p "$PREFIX"/{"lib/pkgconfig",include}
# cp -a "$PREFIX"/"macOS_$(arch)"/include/* "$PREFIX"/include

# #
# # create pkg-config for system
# #
# pushd "$PREFIX"/lib/pkgconfig
# ln -sf ../../macOS_"$(arch)"/lib/pkgconfig/libpjproject.pc .
# popd
