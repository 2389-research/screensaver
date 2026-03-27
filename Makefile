# ABOUTME: Build, test, and install the Claude Code Screensaver.
# ABOUTME: Targets: build, test, install, uninstall, release, clean.

SCHEME = ClaudeCodeScreenSaver
DEST = platform=macOS
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
BUILD_DIR = $(shell find $(DERIVED_DATA)/ClaudeCodeScreenSaver-* -path '*/Build/Products/Release/ClaudeCodeScreenSaver.saver' -maxdepth 4 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
SAVER_NAME = ClaudeCodeScreenSaver.saver
INSTALL_DIR = $(HOME)/Library/Screen Savers

.PHONY: build test install uninstall release clean

build:
	xcodebuild build -scheme $(SCHEME) -configuration Release -destination '$(DEST)'

test:
	xcodebuild test -scheme $(SCHEME) -destination '$(DEST)'

install: build
	@rm -rf "$(INSTALL_DIR)/$(SAVER_NAME)"
	@cp -R "$(BUILD_DIR)/$(SAVER_NAME)" "$(INSTALL_DIR)/$(SAVER_NAME)"
	@echo "Installed to $(INSTALL_DIR)/$(SAVER_NAME)"
	@echo "Open System Settings > Screen Saver to activate."

uninstall:
	@rm -rf "$(INSTALL_DIR)/$(SAVER_NAME)"
	@echo "Uninstalled $(SAVER_NAME)"

release: build
	@mkdir -p build
	@rm -rf "build/$(SAVER_NAME)"
	@cp -R "$(BUILD_DIR)/$(SAVER_NAME)" "build/$(SAVER_NAME)"
	@cd build && zip -r "$(SAVER_NAME).zip" "$(SAVER_NAME)"
	@echo "Release artifact: build/$(SAVER_NAME).zip"

clean:
	xcodebuild clean -scheme $(SCHEME) -destination '$(DEST)'
	@rm -rf build
