#!/usr/bin/env bash

CWD=$(pwd)
BUNDLE_ID="no.alrek"
VUEJS_DEVTOOLS="$CWD/devtools"
CHROME_EXTENSION="$VUEJS_DEVTOOLS/packages/shell-chrome"
XCODE_PROJECT="$CWD/Vue.js devtools"
SAFARI_EXTENSION="$XCODE_PROJECT/Vue.js devtools Extension"
BUILD_DIR="$CWD/dist"

function pull () {
    echo "Pulling latest changes..."
    git submodule init
    if [ $? -ne 0 ]; then exit 1; fi
    git submodule update
    if [ $? -ne 0 ]; then exit 1; fi
}

function clean () {
    if test -d "$XCODE_PROJECT"; then
        echo "Cleaning up previously generated Xcode project..."
        rm -rf "$XCODE_PROJECT"
    fi;
    if test -d "$BUILD_DIR"; then
        echo "Cleaning up previously generated builds..."
        rm -rf "$BUILD_DIR"
    fi;
}

function generate_xcode_project () {
    echo "Generating Xcode project..."
    xcrun safari-web-extension-converter "$VUEJS_DEVTOOLS/packages/shell-chrome" --macos-only --project-location "$CWD" --bundle-identifier $BUNDLE_ID --swift --copy-resources --no-open --no-prompt --force  > /dev/null
    if [ $? -ne 0 ]; then exit 1; fi
    rm -rf "$SAFARI_EXTENSION/Resources"
    ln -sf "$CHROME_EXTENSION" "$SAFARI_EXTENSION/Resources"
    sed -i '' '/GENERATE_INFOPLIST_FILE = YES;/d' "$XCODE_PROJECT/Vue.js devtools.xcodeproj/project.pbxproj"
    if [ $? -ne 0 ]; then exit 1; fi
    set_version
}

function update () {
    echo "Updating dependencies..."
    pull
    cd "$VUEJS_DEVTOOLS"
    yarn install > /dev/null
    if [ $? -ne 0 ]; then exit 1; fi
    cd $CWD
}

function build_extension () {
    cd "$VUEJS_DEVTOOLS"
    NODE_ENV=production
    yarn build > /dev/null
    if [ $? -ne 0 ]; then exit 1; fi
    cd $CWD
}

function set_version () {
    echo "Setting version number for Xcode project..."
    cd $CWD
    VERSION_NUMBER=$(node version.js)
    SHORT_VERSION_NUMBER=${VERSION_NUMBER%.*}
    cd "$XCODE_PROJECT"
    agvtool new-version -all $VERSION_NUMBER  > /dev/null
    if [ $? -ne 0 ]; then exit 1; fi
    agvtool new-marketing-version $SHORT_VERSION_NUMBER  > /dev/null
    if [ $? -ne 0 ]; then exit 1; fi
    cd $CWD
}

function build () {
    clean
    echo "Building Safari extension..."
    build_extension
    generate_xcode_project
    cd "$XCODE_PROJECT"
    mkdir -p "$BUILD_DIR"
    xcodebuild -scheme "Vue.js devtools" -project "Vue.js devtools.xcodeproj" build -configuration Release BUILD_DIR="$BUILD_DIR" > /dev/null
    if [ $? -ne 0 ]; then exit 1; fi
    echo "Build completed successfully."
}

update
build

exit 0