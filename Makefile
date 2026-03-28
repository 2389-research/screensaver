# ABOUTME: Build, test, and install the Code Agent Screensaver.
# ABOUTME: Targets: build, test, install, uninstall, release, clean, hup.

SCHEME = ClaudeCodeScreenSaver
DEST = platform=macOS
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
BUILD_DIR = $(shell find $(DERIVED_DATA)/ClaudeCodeScreenSaver-* -path '*/Build/Products/Release/ClaudeCodeScreenSaver.saver' -maxdepth 4 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
SAVER_NAME = ClaudeCodeScreenSaver.saver
INSTALL_DIR = $(HOME)/Library/Screen Savers
GIT_HASH = $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE = $(shell date '+%Y-%m-%d %H:%M')

.PHONY: build test install uninstall release clean hup stamp dev reinstall-hard

# Stamp git hash and build date into Info.plist before build
stamp:
	@/usr/libexec/PlistBuddy -c "Delete :GitHash" ClaudeCodeScreenSaver/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :GitHash string $(GIT_HASH)" ClaudeCodeScreenSaver/Info.plist
	@/usr/libexec/PlistBuddy -c "Delete :BuildDate" ClaudeCodeScreenSaver/Info.plist 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :BuildDate string $(BUILD_DATE)" ClaudeCodeScreenSaver/Info.plist

build: stamp
	xcodebuild build -scheme $(SCHEME) -configuration Release -destination '$(DEST)'

test:
	xcodebuild test -scheme $(SCHEME) -destination '$(DEST)'

install: build
	@rm -rf "$(INSTALL_DIR)/$(SAVER_NAME)"
	@cp -R "$(BUILD_DIR)/$(SAVER_NAME)" "$(INSTALL_DIR)/$(SAVER_NAME)"
	@echo "Installed to $(INSTALL_DIR)/$(SAVER_NAME)"
	@echo "Run 'make hup' to reload, or open System Settings > Screen Saver."

uninstall:
	@rm -rf "$(INSTALL_DIR)/$(SAVER_NAME)"
	@echo "Uninstalled $(SAVER_NAME)"

# Kill the screensaver host so it picks up the new version
hup:
	@killall legacyScreenSaver 2>/dev/null || true
	@killall WallpaperAgent 2>/dev/null || true
	@echo "Killed screensaver host. It will reload on next activation."

# Build + install + reload in one command
dev: install hup
	@echo "Dev build $(GIT_HASH) installed and reloaded."

# Remove installed saver, reinstall from a fresh build, then reload the host
reinstall-hard: uninstall install hup
	@echo "Hard reinstall complete."

release: build
	@mkdir -p build
	@rm -rf "build/$(SAVER_NAME)"
	@cp -R "$(BUILD_DIR)/$(SAVER_NAME)" "build/$(SAVER_NAME)"
	@cd build && zip -r "$(SAVER_NAME).zip" "$(SAVER_NAME)"
	@echo "Release artifact: build/$(SAVER_NAME).zip"

clean:
	xcodebuild clean -scheme $(SCHEME) -destination '$(DEST)'
	@rm -rf build
