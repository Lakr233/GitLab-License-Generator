#!/bin/zsh

set -e

cd "$(dirname "$0")"
if [ ! -f ".root" ]; then
    echo "[!] failed to locate project directory, aborting..."
    exit 1
fi
WORKING_DIR=$(pwd)

mkdir temp || true

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
curl -L $RB_GEM_DOWNLOAD_URL -o $RB_GEM_DOWNLOAD_PATH
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
git clean -fdx -f
git reset --hard
git pull
popd > /dev/null

echo "[*] scanning features..."
FEATURE_LIST_FILE=$(pwd)/temp/features.txt
rm -f $FEATURE_LIST_FILE || true
./feature.scan.py $GITLAB_SOURCE_CODE_DIR $FEATURE_LIST_FILE

echo "[*] generating license..."
OUTPUT_DIR=$(pwd)/output
mkdir -p $OUTPUT_DIR
ruby ./generate_licenses.rb $OUTPUT_DIR $FEATURE_LIST_FILE

echo "[*] done $(basename $0)"