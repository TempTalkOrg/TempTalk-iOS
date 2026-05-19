SHELL=/bin/bash -o pipefail -o errexit

# ── Configuration ──────────────────────────────────────────
WORKSPACE   = Difft.xcworkspace
SCHEME     ?= TempTalk
CONFIG     ?= Debug
DESTINATION = generic/platform=iOS

XCODEBUILD  = xcodebuild \
	-workspace $(WORKSPACE) \
	-scheme $(SCHEME) \
	-configuration $(CONFIG) \
	-destination '$(DESTINATION)' \
	-skipPackagePluginValidation \
	-skipMacroValidation \
	CODE_SIGNING_ALLOWED=NO \
	COMPILER_INDEX_STORE_ENABLE=NO

.PHONY: setup build clean test ci help

# ── Default ────────────────────────────────────────────────
default: help

# ── Setup ──────────────────────────────────────────────────
setup:  ## Install all dependencies (gems + brew tools + pods)
	bundle install
	brew bundle install --no-upgrade
	bundle exec pod install

# ── Build ──────────────────────────────────────────────────
build:  ## Build project (errors-only output via xcsift)
	$(XCODEBUILD) build 2>&1 | xcsift -f toon --exit-on-failure

# ── Test ───────────────────────────────────────────────────
test:  ## Run tests
	bundle exec fastlane scan

# ── CI ─────────────────────────────────────────────────────
ci: build test  ## CI pipeline: build + test

# ── Maintenance ────────────────────────────────────────────
clean:  ## Clean build artifacts
	$(XCODEBUILD) clean 2>&1 | xcsift -f toon

# ── Help ───────────────────────────────────────────────────
help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Override scheme/config:  make build SCHEME=TempTalk CONFIG=Release"
