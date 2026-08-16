.PHONY: generate build test release install run

generate:
	swift run --package-path Tools/XcodeGen xcodegen generate --spec project.yml

build: generate
	xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth -destination 'platform=macOS' build

test: generate
	xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth -destination 'platform=macOS' test

release: generate
	xcodebuild -project Pennyworth.xcodeproj -scheme Pennyworth -configuration Release -destination 'platform=macOS' build

install: release
	APP="$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Release/Pennyworth.app' -print -quit)"; \
	rm -rf "$$HOME/Applications/Pennyworth.app"; \
	cp -R "$$APP" "$$HOME/Applications/"

run: install
	open "$$HOME/Applications/Pennyworth.app"