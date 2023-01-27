#!/bin/bash
set -ex
export VERSION=$1
export RELEASE_NAME=`basename $GITHUB_REPO`

# Get release url
export RELEASE_URL=$(curl -H  "Authorization: token $SECRET_TOKEN" https://api.github.com/repos/$GITHUB_REPO/releases/tags/$VERSION)

# Build TF modules that require source building
function create_zip_file() {
  BUILD_DIR=/tmp/${RELEASE_NAME}
  DESTINATION_DIR=${PWD}/dist
  rm -rf ${DESTINATION_DIR}
  mkdir -p ${BUILD_DIR} ${DESTINATION_DIR}
  cp *tf ${BUILD_DIR}
  cd ${BUILD_DIR}
  zip -r9 ${RELEASE_NAME}.zip .
  mv ${RELEASE_NAME}.zip ${DESTINATION_DIR}/.
  cd $DESTINATION_DIR
  rm -rf ${BUILD_DIR}
}

# Release package
create_zip_file

# Post the release
curl -X POST -H "Authorization: token $SECRET_TOKEN" --data-binary "@${RELEASE_NAME}.zip" -H "Content-type: application/octet-stream" $RELEASE_URL/assets?name=${RELEASE_NAME}.zip
