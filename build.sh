#!/bin/sh
set -eu

# Configuration
DEVICE="bullhead" #Nexus 5x
VERSION="N2G47X.2017.06.06.00.02.24"
BUILD_HOME="$HOME/cos/"
JOBS="$(nproc --all)"

###################
# Configure git
git config --global user.name "Kabir Sala"
git config --global user.email "kabirsala.cos@airmail.cc"

# Configure the environment
export USE_CCACHE=1
export JACK_SERVER_VM_ARGUMENTS='-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx10g'
export LANG=C
unset _JAVA_OPTIONS
export BUILD_NUMBER=$(date --utc +%Y.%m.%d.%H.%M.%S)
export DISPLAY_BUILD_NUMBER=true
chrt -b -p 0 $$

# Create root directory for build
mkdir -p "${BUILD_HOME}"
cd "${BUILD_HOME}"

# Install dependencies
apt-get install git-core unzip
rm -rf scripts
git clone https://github.com/akhilnarang/scripts
cd scripts
./setup/ubuntu1604linuxmint18.sh
cd "${BUILD_HOME}"

# Install repo
curl https://storage.googleapis.com/git-repo-downloads/repo > repo
chmod a+x repo
sudo install repo /usr/local/bin
rm repo

# Clone the source
repo init -u https://github.com/CopperheadOS/platform_manifest.git -b refs/tags/"${VERSION}"
repo forall -vc "git reset --hard"
repo sync -j32

# Apply patches
rm -rf cos_patches
git clone "https://github.com/ksala/cos_patches.git"
cd cos_patches
for patch in "${PWD}"/device_lge_bullhead/*.patch; do
	echo "${patch}"
	(
	  cd "${BUILD_HOME}"/device/lge/bullhead
		git apply < "${patch}"
	)
done
for patch in "${PWD}"/platform_frameworks_base/*.patch; do
	echo "${patch}"
	(
		cd "${BUILD_HOME}"/frameworks/base
		git apply < "${patch}"
	)
done
for patch in "${PWD}"/platform_frameworks_av/*.patch; do
	echo "${patch}"
	(
		cd "${BUILD_HOME}"/frameworks/av
		git apply < "${patch}"
	)
done
for patch in "${PWD}"/platform_packages_apps_F-Droid_privileged-extension/*.patch; do
	echo "${patch}"
	(
		cd "${BUILD_HOME}"/packages/apps/F-Droid/privileged-extension
		git apply < "${patch}"
	)
done
for patch in "${PWD}"/platform_packages_apps_Settings/*.patch; do
	echo "${patch}"
	(
		cd "${BUILD_HOME}"/packages/apps/Settings
		git apply < "${patch}"
	)
done
wget 'https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts' -O "${BUILD_HOME}"/system/core/rootdir/etc/hosts

# Configure CCACHE
ccache -M 50G

# Configure build
source build/envsetup.sh
choosecombo release aosp_"${DEVICE}" user

# Clean eventual previous builds
make clobber
rf -rf out

# Generate/Copy keys
#
#
time make generate_verity_key -j"${JOBS}"
out/host/linux-x86/bin/generate_verity_key -convert keys/verity.x509.pem keys/verity_key

# Start the build
time make target-files-package -j"${JOBS}"
chmod a+x release.sh
time ./release.sh "${DEVICE}"

# Done!
