#!/bin/sh

set -o pipefail
xcodebuild clean -scheme JSONCache | xcpretty
xcodebuild test -scheme JSONCache -destination "platform=iOS Simulator,name=iPhone 6S" | xcpretty
xcodebuild test -scheme JSONCache -destination "platform=OS X" | xcpretty
xcodebuild test -scheme JSONCache -destination "platform=tvOS Simulator,name=Apple TV 1080p" | xcpretty
xcodebuild build -scheme JSONCache -destination "platform=watchOS Simulator,name=Apple Watch - 42mm" | xcpretty
