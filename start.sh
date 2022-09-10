#!/bin/sh
# Oliver Epper <oliver.epper@gmail.com>

set -e

if [ $# -eq 0 ]
then
    echo "sh ./start.sh <absolute path>"
    exit 1
fi

PREFIX=$1
PJPROJECT_VERSION=2.12.1
CFLAGS="-O2 -fembed-bitcode -fpic"
TARGETS="IOS_SIM_ARM64 IOS_SIM_X86_64 IOS_ARM64 MACOS_ARM64 MACOS_X86_64"
TARGETS=""

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

cat << EOF > user.mak
export CFLAGS += -Wno-unused-label -Werror
export LDFLAGS += -framework Network -framework Security
EOF
popd

function createLib {
	pushd $1
	mkdir tmp && cd tmp
	find ../ -name "*.a" -exec ar x {} \;
	libtool -static -o ../libpjproject.a *.o
	ranlib ../libpjproject.a
	cd .. && rm -rf tmp
	popd
}

#
# build for iOS simulator running on arm64
#
OUT_IOS_SIM_ARM64=$PREFIX/iOS_simulator_arm64
if [[ $TARGETS =~ "IOS_SIM_ARM64" ]]; then
rm -rf "$OUT_IOS_SIM_ARM64"
pushd pjproject

sed -i '' -e '1i\
#define PJ_CONFIG_IPHONE 1
' pjlib/include/pj/config_site.h

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/iOS_simulator_arm64)
if [[ -d "$OPUS" ]]
then
	CONFIGURE_EXTRA_PARAMS="--with-opus=$OPUS"
fi

DEVPATH="$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer" \
ARCH="-arch arm64" \
MIN_IOS="-miphonesimulator-version-min=13" \
CFLAGS="-isysroot $(xcrun -sdk iphonesimulator --show-sdk-path) $CFLAGS" \
./configure-iphone --prefix="$OUT_IOS_SIM_ARM64" "$CONFIGURE_EXTRA_PARAMS"

make dep && make clean
CFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable" make
make install

sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib $OUT_IOS_SIM_ARM64/lib
popd
fi

#
# build for iOS simulator running on x86_64
#
OUT_IOS_SIM_X86_64=$PREFIX/iOS_simulator_x86_64
if [[ $TARGETS =~ "IOS_SIM_X86_64" ]]; then
rm -rf "$OUT_IOS_SIM_X86_64"
pushd pjproject

sed -i '' -e '1i\
#define PJ_CONFIG_IPHONE 1
' pjlib/include/pj/config_site.h

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/iOS_simulator_x86_64)
if [[ -d "$OPUS" ]]
then
	CONFIGURE_EXTRA_PARAMS="--with-opus=$OPUS"
fi

DEVPATH="$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer" \
ARCH="-arch x86_64" \
MIN_IOS="-miphonesimulator-version-min=13.0" \
CFLAGS="-isysroot $(xcrun -sdk iphonesimulator --show-sdk-path) $CFLAGS" \
./configure-iphone --prefix="$OUT_IOS_SIM_X86_64" "$CONFIGURE_EXTRA_PARAMS"

make dep && make clean
CFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable" make
make install

sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib $OUT_IOS_SIM_X86_64/lib
popd
fi

#
# build for iOS arm64
#
OUT_IOS_ARM64=$PREFIX/iOS_arm64
if [[ $TARGETS =~ "IOS_ARM64" ]]; then
rm -rf "$OUT_IOS_ARM64"
pushd pjproject

sed -i '' -e '1i\
#define PJ_CONFIG_IPHONE 1
' pjlib/include/pj/config_site.h

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/iOS_arm64)
if [[ -d "$OPUS" ]]
then
	CONFIGURE_EXTRA_PARAMS="--with-opus=$OPUS"
fi

DEVPATH="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer" \
ARCH="-arch arm64" \
MIN_IOS="-miphoneos-version-min=13" \
CFLAGS="-isysroot $(xcrun -sdk iphonesimulator --show-sdk-path) $CFLAGS" \
./configure-iphone $CONFIGURE_EXTRA_PARAMS --prefix="$OUT_IOS_ARM64"

make dep && make clean
CFLAGS="-Wno-deprecated-declarations -Wno-unused-but-set-variable" make
make install

sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib $OUT_IOS_ARM64/lib
popd
fi


#
# build for macOS arm64
#
OUT_MACOS_ARM64=$PREFIX/macOS_arm64
if [[ $TARGETS =~ "MACOS_ARM64" ]]; then
rm -rf "$OUT_MACOS_ARM64"
pushd pjproject

sed -i '' -e '/PJ_CONFIG_IPHONE/d' pjlib/include/pj/config_site.h

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/macOS_arm64)
if [[ -d "$OPUS" ]]
then
	CONFIGURE_EXTRA_PARAMS="--with-opus=$OPUS"
fi

CFLAGS="-isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=11 $CFLAGS" \
./configure --prefix="$OUT_MACOS_ARM64" --host=arm-apple-darwin $CONFIGURE_EXTRA_PARAMS

make dep && make clean
CFLAGS="-Wno-unused-but-set-variable" make
make install

sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib $OUT_MACOS_ARM64/lib
popd
fi

#
# build for macOS x86_64
#
OUT_MACOS_X86_64=$PREFIX/macOS_x86_64
if [[ $TARGETS =~ "MACOS_X86_64" ]]; then
rm -rf "$OUT_MACOS_X86_64"
pushd pjproject

sed -i '' -e '/PJ_CONFIG_IPHONE/d' pjlib/include/pj/config_site.h

OPUS=(/opt/homebrew/Cellar/opus-apple-platforms/*/macOS_x86_64)
if [[ -d "$OPUS" ]]
then
	CONFIGURE_EXTRA_PARAMS="--with-opus=$OPUS"
fi

CFLAGS="-isysroot $(xcrun -sdk macosx --show-sdk-path) -mmacosx-version-min=11 $CFLAGS" \
arch -arch x86_64 ./configure --prefix="$OUT_MACOS_X86_64" --host=x86_64-apple-darwin $CONFIGURE_EXTRA_PARAMS

make dep && make clean
CFLAGS="-Wno-unused-but-set-variable" arch -arch x86_64 make
make install

sed -i '' -e '1d' pjlib/include/pj/config_site.h

createLib $OUT_MACOS_X86_64/lib
popd
fi

#
# create fat lib for the mac
#
if [ -f "$OUT_MACOS_ARM64"/lib/libpjproject.a ] && [ -f "$OUT_MACOS_X86_64"/lib/libpjproject.a ]; then
OUT_MACOS="$PREFIX/macOS_arm64_x86_64"
mkdir -p $OUT_MACOS/lib
lipo -create $OUT_MACOS_ARM64/lib/libpjproject.a $OUT_MACOS_X86_64/lib/libpjproject.a -output $OUT_MACOS/lib/libpjproject.a
fi

#
# create fat lib for the simulator
#
if [ -f "$OUT_IOS_SIM_ARM64"/lib/libpjproject.a ] && [ -f "$OUT_IOS_SIM_X86_64"/lib/libpjproject.a ]; then
OUT_IOS_SIM="$PREFIX/iOS_simulator_arm64_x86_64"
mkdir -p $OUT_IOS_SIM/lib
lipo -create $OUT_IOS_SIM_ARM64/lib/libpjproject.a $OUT_IOS_SIM_X86_64/lib/libpjproject.a -output $OUT_IOS_SIM/lib/libpjproject.a
fi

XCFRAMEWORK="$PREFIX/libpjproject.xcframework"
rm -rf $XCFRAMEWORK
xcodebuild -create-xcframework \
-library $OUT_IOS_SIM/lib/libpjproject.a \
-library $OUT_IOS_ARM64/lib/libpjproject.a \
-library $OUT_MACOS/lib/libpjproject.a \
-output $XCFRAMEWORK

mkdir -p $XCFRAMEWORK/Headers
cp -a "$OUT_MACOS_ARM64"/include/* $XCFRAMEWORK/Headers

/usr/libexec/PlistBuddy -c 'add:HeadersPath string Headers' $XCFRAMEWORK/Info.plist

rm -rf "$OUT_IOS_SIM"
rm -rf "$OUT_MACOS"

#
# link lib & include
#
ln -sf "$PREFIX"/"macOS_$(arch)"/lib "$PREFIX"
ln -sf "$PREFIX"/"macOS_$(arch)"/include "$PREFIX"
