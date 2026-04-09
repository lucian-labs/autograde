APP       = autograde
BUNDLE_ID = ca.lucianlabs.autograde
SCHEME    = autograde
PROJECT   = autograde.xcodeproj
BUILD_DIR = .build
APP_PATH  = $(BUILD_DIR)/Build/Products/Debug/$(APP).app

# ── default ──────────────────────────────────────────────────────────────────
.PHONY: all build run kill reset fresh clean regen

all: run

# ── build ─────────────────────────────────────────────────────────────────────
build: regen
	xcodebuild \
	  -project $(PROJECT) \
	  -scheme  $(SCHEME) \
	  -configuration Debug \
	  -derivedDataPath $(BUILD_DIR) \
	  build 2>&1 | tee /tmp/$(APP)-build.log \
	  | grep --line-buffered -E 'error:|warning:|\*\* BUILD'

# ── kill any running instance ─────────────────────────────────────────────────
kill:
	-pkill -x "$(APP)" 2>/dev/null; true

# ── reset TCC permissions for this bundle ────────────────────────────────────
reset:
	-tccutil reset Accessibility  $(BUNDLE_ID)
	-tccutil reset ScreenCapture  $(BUNDLE_ID)
	-tccutil reset ListenEvent    $(BUNDLE_ID)
	@echo "permissions cleared for $(BUNDLE_ID)"

# ── run: kill old instance, build, launch ─────────────────────────────────────
run: kill build
	open "$(APP_PATH)"

# ── fresh: full clean + permission reset + run ───────────────────────────────
# Use this when permissions are stale or you want a completely clean slate.
fresh: kill reset clean run

# ── clean build artifacts ─────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR)

# ── regenerate xcodeproj from project.yml ─────────────────────────────────────
regen:
	xcodegen generate --quiet
