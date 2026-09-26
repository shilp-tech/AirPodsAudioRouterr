#!/bin/bash
set -euo pipefail

# Use this checkout regardless of the caller's working directory.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

derived_data="${TMPDIR:-/tmp}/AirPodsAudioRouter-DerivedData"
xcodebuild -quiet \
  -project 'AirPods Audio Router.xcodeproj' \
  -scheme 'AirPods Audio Router' \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_data" \
  CODE_SIGN_IDENTITY=- \
  build

echo 'Build passed. This checks compilation, not audio routing or UI behavior.'
