#!/bin/sh

set -o pipefail
xcodebuild clean -scheme JSONCache | xcpretty
xcodebuild test -scheme JSONCache -destination "platform=iOS Simulator,name=iPhone XR" | xcpretty
xcodebuild test -scheme JSONCache -destination "platform=macOS" | xcpretty
xcodebuild test -scheme JSONCache -destination "platform=tvOS Simulator,name=Apple TV" | xcpretty
xcodebuild build -scheme JSONCache -destination "platform=watchOS Simulator,name=Apple Watch Series 4 - 44mm" | xcpretty
