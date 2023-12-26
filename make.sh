#!/bin/zsh

set -e

cd "$(dirname "$0")"
if [ ! -f ".root" ]; then
    echo "[!] failed to locate project directory, aborting..."
    exit 1
fi
WORKING_DIR=$(pwd)

mkdir temp 2> /dev/null || true

echo "[*] fetching ruby gem version..."
RB_GEM_NAME="gitlab-license"
RB_GEM_LIST_OUTPUT=$(gem list --remote $RB_GEM_NAME)

RB_GEM_VERSION=""
while IFS= read -r line; do
    if [[ $line == "gitlab-license ("* ]]; then
        RB_GEM_VERSION=${line#"gitlab-license ("}
        RB_GEM_VERSION=${RB_GEM_VERSION%")"}
        break
    fi
done <<< "$RB_GEM_LIST_OUTPUT"

echo "[*] gitlab-license version: $RB_GEM_VERSION"
RB_GEM_DOWNLOAD_URL="https://rubygems.org/downloads/gitlab-license-$RB_GEM_VERSION.gem"
RB_GEM_DOWNLOAD_PATH=$(pwd)/temp/gem/gitlab-license.gem
mkdir -p $(dirname $RB_GEM_DOWNLOAD_PATH)
curl -L $RB_GEM_DOWNLOAD_URL -o $RB_GEM_DOWNLOAD_PATH 1> /dev/null 2> /dev/null
pushd $(dirname $RB_GEM_DOWNLOAD_PATH) > /dev/null
tar -xzf gitlab-license.gem
tar -xzf data.tar.gz

if [ ! -f "./lib/gitlab/license.rb" ]; then
    echo "[!] failed to locate gem file, aborting..."
    exit 1
fi

echo "[*] copying gem..."
rm -rf "$WORKING_DIR/lib" || true
mkdir -p "$WORKING_DIR/lib"
cp -r ./lib/gitlab/* $WORKING_DIR/lib
popd > /dev/null

pushd lib > /dev/null
echo "[*] patching lib requirements gem..."
# replace `require 'gitlab/license/` with `require 'license/` to make it work
find . -type f -exec sed -i '' 's/require '\''gitlab\/license\//require_relative '\''license\//g' {} \;
popd > /dev/null

echo "[*] updated gem"

echo "[*] fetching gitlab source code..."
GITLAB_SOURCE_CODE_DIR=$(pwd)/temp/src/
if [ -d "$GITLAB_SOURCE_CODE_DIR" ]; then
    echo "[*] gitlab source code already exists, skipping cloning..."
else
    echo "[*] cloning gitlab source code..."
    git clone https://gitlab.com/gitlab-org/gitlab.git $GITLAB_SOURCE_CODE_DIR
fi

echo "[*] updating gitlab source code..."
pushd $GITLAB_SOURCE_CODE_DIR > /dev/null
git clean -fdx -f > /dev/null
git reset --hard > /dev/null
git pull > /dev/null
popd > /dev/null

BUILD_DIR=$(pwd)/build
mkdir -p $BUILD_DIR

echo "[*] scanning features..."
FEATURE_LIST_FILE=$BUILD_DIR/features.json
rm -f $FEATURE_LIST_FILE || true
./src/scan.features.rb \
    -o $FEATURE_LIST_FILE \
    -s $GITLAB_SOURCE_CODE_DIR

echo "[*] generating key pair..."
PUBLIC_KEY_FILE=$BUILD_DIR/public.key
PRIVATE_KEY_FILE=$BUILD_DIR/private.key
cp -f ./keys/public.key $PUBLIC_KEY_FILE
cp -f ./keys/private.key $PRIVATE_KEY_FILE

# execute following command to generate new keys
# ./src/generator.keys.rb \
#     --public-key $PUBLIC_KEY_FILE \
#     --private-key $PRIVATE_KEY_FILE

echo "[*] generating license..."
LICENSE_FILE=$BUILD_DIR/result.gitlab-license
LICENSE_JSON_FILE=$BUILD_DIR/license.json

./src/generator.license.rb \
    -f $FEATURE_LIST_FILE \
    --public-key $PUBLIC_KEY_FILE \
    --private-key $PRIVATE_KEY_FILE \
    -o $LICENSE_FILE \
    --plain-license $LICENSE_JSON_FILE

echo "[*] done $(basename $0)"