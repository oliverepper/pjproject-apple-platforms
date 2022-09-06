#!/bin/sh
# Oliver Epper <oliver.epper@gmail.com>

export PJSIP_VERSION=2.12.1

function clean {
	echo "Cleaning"
	rm -rf pjproject
	rm -rf build
	rm clean.sh .install.sh	
}

function install {
	local PREFIX=$1
	local PC_FILE=pjproject-apple-platforms.pc
	local PC_FILE_MACOSX=pjproject-apple-platforms-MacOSX.pc
	local PC_FILE_IPHONEOS=pjproject-apple-platforms-iPhoneOS.pc
	local PC_FILE_IPHONESIMULATOR=pjproject-apple-platforms-iPhoneSimulator.pc
	local PC_FILE_SPM=pjproject-apple-platforms-SPM.pc

	mkdir -p $PREFIX/lib/pkgconfig
	
	# copy xcframework
	cp -a build/libpjproject.xcframework $PREFIX

	# link in lib
	pushd $PREFIX/lib
	ln -sf ../libpjproject.xcframework .
	popd

	# link in include
	pushd $PREFIX
	ln -sf libpjproject.xcframework/Headers include
	popd
	
	# create pkg-config files
	# for macOS (x86_64 and arm64)
	cat << END > $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX
prefix=$PREFIX

END

	cat << 'END' >> $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX
pjsip=${prefix}/libpjproject.xcframework/Headers/pjsip
pjlib=${prefix}/libpjproject.xcframework/Headers/pjlib
pjlibutil=${prefix}/libpjproject.xcframework/Headers/pjlib-util
pjmedia=${prefix}/libpjproject.xcframework/Headers/pjmedia
pjnath=${prefix}/libpjproject.xcframework/Headers/pjnath

libdir=${prefix}/libpjproject.xcframework/macos-arm64_x86_64

Name: Cpjproject
END

	echo "Version: ${PJSIP_VERSION}" >> $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX
	
	cat << 'END' >> $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX
Description: Multimedia communication library
Libs: -L${libdir} -framework Network -framework Security -framework AudioToolbox -framework AVFoundation -framework CoreAudio -framework Foundation -lpjproject
Cflags: -I${pjsip} -I${pjlib} -I${pjlibutil} -I${pjmedia} -I${pjnath}
END

	# for iOS
	sed -e s/macos-arm64_x86_64/ios_arm64/ < $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX > $PREFIX/lib/pkgconfig/$PC_FILE_IPHONEOS

	# for iOS Simulator
	sed -e s/macos-arm64_x86_64/ios-arm64_x86_64-simulator/ < $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX > $PREFIX/lib/pkgconfig/$PC_FILE_IPHONESIMULATOR

	# for SPM
	sed -e /^libdir=/,+2d -e 's/^Libs: -L${libdir} -f/Libs: -f/' < $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX > $PREFIX/lib/pkgconfig/$PC_FILE_SPM

	# link pjproject-apple-platforms.pc
	ln -sf $PREFIX/lib/pkgconfig/$PC_FILE_MACOSX $PREFIX/lib/pkgconfig/$PC_FILE

	exit 0
}

me=`basename $0`
if [[ $me = "clean.sh" ]]
then
	clean
	exit 0
elif [[ $me == ".install.sh" ]]
then
	install $1
	exit 0
fi

if [[ ! -f clean.sh ]]
then
	ln -sf start.sh clean.sh
fi

if [[ ! -f .install.sh ]]
then
	ln -sf start.sh .install.sh
fi

git -c advice.detachedHead=false clone --depth 1 --branch $PJSIP_VERSION https://github.com/pjsip/pjproject # > /dev/null 2>&1

cat << 'END' > pjproject/build_apple_platforms.sh
#!/bin/sh

#
# ask user if she wants to overwrite files
#
read -p "This will overwrite site_config.h and user.mak. Continue?" -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
   [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

cat << EOF > pjlib/include/pj/config_site.h
#define PJ_CONFIG_IPHONE 1
#define PJ_HAS_SSL_SOCK 1
#undef PJ_SSL_SOCK_IMP
#define PJ_SSL_SOCK_IMP PJ_SSL_SOCK_IMP_APPLE
#include <pj/config_site_sample.h>
EOF

cat << EOF > user.mak
export CFLAGS += -Wno-unused-label -Werror
export LDFLAGS += -framework Network -framework Security
EOF


#
# setup path to Xcode installation
#
COMMAND_LINE_TOOLS_PATH="$(xcode-select -p)"

#
# where to build
#
BUILD_DIR=../build

#
# build for simulator arm64 & create lib
#
find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a" -exec rm {} \;
IPHONESDK="$COMMAND_LINE_TOOLS_PATH/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk" \
DEVPATH="$COMMAND_LINE_TOOLS_PATH/Platforms/iPhoneSimulator.platform/Developer" \
ARCH="-arch arm64" \
MIN_IOS="-mios-simulator-version-min=13" \
./configure-iphone --with-opus=/Users/oliver/Developer/opus-apple-platforms/build/iOS_simulator_arm64
make dep && make clean
CFLAGS="-Wno-macro-redefined -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-unused-private-field -Wno-unused-but-set-variable" make

OUT_SIM_ARM64="$BUILD_DIR/sim_arm64"
mkdir -p $OUT_SIM_ARM64
# the Makefile is a little more selective about which .o files go into the lib
# so let's use libtool instead of ar
# ar -csr $OUT_SIM_ARM64/libpjproject.a `find . -not -path "./pjsip-apps/*" -name "*.o"`
libtool -static -o $OUT_SIM_ARM64/libpjproject.a `find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a"`

#
# build for simulator x86_64 & create lib
#
find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a" -exec rm {} \;
IPHONESDK="$COMMAND_LINE_TOOLS_PATH/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk" \
DEVPATH="$COMMAND_LINE_TOOLS_PATH/Platforms/iPhoneSimulator.platform/Developer" \
ARCH="-arch x86_64" \
MIN_IOS="-mios-simulator-version-min=13" \
./configure-iphone
make dep && make clean
CFLAGS="-Wno-macro-redefined -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-unused-private-field -Wno-unused-but-set-variable" make

OUT_SIM_X86_64="$BUILD_DIR/sim_x86_64"
mkdir -p $OUT_SIM_X86_64
# the Makefile is a little more selective about which .o files go into the lib
# so let's use libtool instead of ar
# ar -csr $OUT_SIM_X86_64/libpjproject.a `find . -not -path "./pjsip-apps/*" -name "*.o"`
libtool -static -o $OUT_SIM_X86_64/libpjproject.a `find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a"`


#
# build for device arm64 & create lib
#
find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a" -exec rm {} \;
IPHONESDK="$COMMAND_LINE_TOOLS_PATH/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" \
DEVPATH="$COMMAND_LINE_TOOLS_PATH/Platforms/iPhoneOS.platform/Developer" \
ARCH="-arch arm64" \
MIN_IOS="-miphoneos-version-min=13" \
./configure-iphone
make dep && make clean
CFLAGS="-Wno-macro-redefined -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-unused-private-field -Wno-unused-but-set-variable -fembed-bitcode" make

OUT_DEV_ARM64="$BUILD_DIR/dev_arm64"
mkdir -p $OUT_DEV_ARM64
libtool -static -o $OUT_DEV_ARM64/libpjproject.a `find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a"`


#
# build for Mac arm64 & create lib
#
find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a" -exec rm {} \;
sed -i '' '1d' pjlib/include/pj/config_site.h
./configure
make dep && make clean
CFLAGS="-Wno-macro-redefined -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-unused-private-field -Wno-unused-but-set-variable -fembed-bitcode" make

OUT_MAC_ARM64="$BUILD_DIR/mac_arm64"
mkdir -p $OUT_MAC_ARM64
libtool -static -o $OUT_MAC_ARM64/libpjproject.a `find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a"`


#
# build for Mac x86_64 & create lib
#
cat << EOF > user.mak
export CFLAGS += -Wno-unused-label -Werror --target=x86_64-apple-darwin
export LDFLAGS += -framework Network -framework Security --target=x86_64-apple-darwin
EOF
find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a" -exec rm {} \;
./configure --host=x86_64-apple-darwin
make dep && make clean
CFLAGS="-Wno-macro-redefined -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-unused-private-field -Wno-unused-but-set-variable -fembed-bitcode" make

OUT_MAC_X86_64="$BUILD_DIR/mac_x86_64"
mkdir -p $OUT_MAC_X86_64
libtool -static -o $OUT_MAC_X86_64/libpjproject.a `find . -not -path "./pjsip-apps/*" -not -path "$BUILD_DIR/*" -name "*.a"`


#
# create fat lib for the mac
#
OUT_MAC="$BUILD_DIR/mac"
mkdir -p $OUT_MAC
lipo -create $OUT_MAC_ARM64/libpjproject.a $OUT_MAC_X86_64/libpjproject.a -output $OUT_MAC/libpjproject.a

#
# create fat lib for the simulator
#
OUT_SIM="$BUILD_DIR/simulator"
mkdir -p $OUT_SIM
lipo -create $OUT_SIM_ARM64/libpjproject.a $OUT_SIM_X86_64/libpjproject.a -output $OUT_SIM/libpjproject.a

#
# collect headers & create xcframework
#
LIBS="pjlib pjlib-util pjmedia pjnath pjsip" # third_party"
OUT_HEADERS="$BUILD_DIR/headers"
for path in $LIBS; do
	mkdir -p $OUT_HEADERS/$path
	cp -a $path/include/* $OUT_HEADERS/$path
done

XCFRAMEWORK="$BUILD_DIR/libpjproject.xcframework"
rm -rf $XCFRAMEWORK
xcodebuild -create-xcframework \
-library $OUT_DEV_ARM64/libpjproject.a \
-library $OUT_SIM/libpjproject.a \
-library $OUT_MAC/libpjproject.a \
-output $XCFRAMEWORK

mkdir -p $XCFRAMEWORK/Headers
cp -a $OUT_HEADERS/* $XCFRAMEWORK/Headers

/usr/libexec/PlistBuddy -c 'add:HeadersPath string Headers' $XCFRAMEWORK/Info.plist
END

cd pjproject
yes | sh ./build_apple_platforms.sh
