#!/bin/sh

set -e

# PROJECT_DIR will be set when run from xcode, else we infer it
if [ "${PROJECT_DIR}" = "" ]; then
    PROJECT_DIR=`git rev-parse --show-toplevel`
    echo "inferred ${PROJECT_DIR}"
fi

# Capture project hashes that we want to add to the Info.plist
cd $PROJECT_DIR
_git_commit_difft=`git log --pretty=oneline --decorate=no | head -1`

readonly appplistname=$1

# Remove existing .plist entry, if any.
/usr/libexec/PlistBuddy -c "Delete BuildDetails" Signal/$appplistname.plist || true
# Add new .plist entry.
/usr/libexec/PlistBuddy -c "add BuildDetails dict" Signal/$appplistname.plist

echo "--->>> CONFIGURATION: ${CONFIGURATION}"
if [[ "${CONFIGURATION}" = "Release" || "${CONFIGURATION}" = "Release_test" ]]; then
    /usr/libexec/PlistBuddy -c "add :BuildDetails:XCodeVersion string '${XCODE_VERSION_MAJOR}.${XCODE_VERSION_MINOR}'" Signal/$appplistname.plist
    /usr/libexec/PlistBuddy -c "add :BuildDetails:SignalCommit string '$_git_commit_difft'" Signal/$appplistname.plist

    # Use UTC
    _build_datetime=`date -u`
    /usr/libexec/PlistBuddy -c "add :BuildDetails:DateTime string '$_build_datetime'" Signal/$appplistname.plist

    _build_timestamp=`date +%s`
    /usr/libexec/PlistBuddy -c "add :BuildDetails:Timestamp integer $_build_timestamp" Signal/$appplistname.plist

    echo "--->>> complete: ${_build_datetime}"
fi
