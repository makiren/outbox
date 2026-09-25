.PHONY: build app run install release clean

VERSION := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)

build:
	swift build -c release

# Assemble build/Outbox.app from a binary given as $(BIN)
define bundle
	rm -rf build/Outbox.app
	mkdir -p build/Outbox.app/Contents/MacOS build/Outbox.app/Contents/Resources
	cp $(1) build/Outbox.app/Contents/MacOS/Outbox
	cp Info.plist build/Outbox.app/Contents/
	printf 'APPL????' > build/Outbox.app/Contents/PkgInfo
	codesign --force --sign - build/Outbox.app
endef

app: build
	$(call bundle,.build/release/Outbox)

run: app
	pkill -x Outbox || true
	open build/Outbox.app

install: app
	pkill -x Outbox || true
	rm -rf /Applications/Outbox.app
	cp -R build/Outbox.app /Applications/
	open /Applications/Outbox.app

# Universal (arm64 + x86_64) bundle and a zip for GitHub Releases
release:
	swift build -c release --triple arm64-apple-macosx
	swift build -c release --triple x86_64-apple-macosx
	mkdir -p build
	lipo -create -output build/Outbox-universal .build/arm64-apple-macosx/release/Outbox .build/x86_64-apple-macosx/release/Outbox
	$(call bundle,build/Outbox-universal)
	rm -f build/Outbox-universal
	rm -f build/Outbox-$(VERSION).zip
	ditto -c -k --keepParent build/Outbox.app build/Outbox-$(VERSION).zip
	shasum -a 256 build/Outbox-$(VERSION).zip | tee build/Outbox-$(VERSION).zip.sha256

clean:
	rm -rf .build build
