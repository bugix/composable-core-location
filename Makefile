PLATFORM_IOS = iOS Simulator,name=iPhone 17 Pro

default: test

test:
	xcodebuild test \
		-scheme ComposableCoreLocation \
		-destination platform="$(PLATFORM_IOS)"
	cd Examples/LocationManager \
		&& xcodebuild test \
		-scheme LocationManagerMobile \
		-destination platform="$(PLATFORM_IOS)"

format:
	swift format --in-place --recursive \
		./Examples ./Package.swift ./Sources ./Tests

.PHONY: format test
