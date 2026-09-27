APP = NotchMeter.app

build:
	swift build -c release

run:
	swift run NotchMeter

demo:
	swift run NotchMeter --demo

bundle: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/NotchMeter $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	codesign --force --deep --sign - $(APP)

install: bundle
	cp -r $(APP) /Applications/

clean:
	rm -rf .build $(APP)

.PHONY: build run demo bundle install clean
