.PHONY: lint format test test-unit test-int test-ui coverage build

SCHEME      := TrueRPCMini
DESTINATION := platform=macOS
BUILD_DIR   := build

lint: ## Check formatting — fails on any violation (no files modified)
	@echo "→ Linting…"
	swiftformat --lint --config .swiftformat Sources Tests
	@echo "Lint passed."

format: ## Auto-format all Swift source files in-place
	@echo "→ Formatting…"
	swiftformat --config .swiftformat Sources Tests
	@echo "Format complete."

test: ## Run all unit and integration tests
	xcodebuild test \
		-scheme $(SCHEME) \
		-testPlan AllTests \
		-destination '$(DESTINATION)' \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

test-unit: ## Run unit tests only
	xcodebuild test \
		-scheme $(SCHEME) \
		-testPlan UnitTests \
		-destination '$(DESTINATION)' \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

test-int: ## Run integration tests only
	xcodebuild test \
		-scheme $(SCHEME) \
		-testPlan IntegrationTests \
		-destination '$(DESTINATION)' \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

test-ui: ## Run UI tests (requires ad-hoc code signing)
	xcodebuild test \
		-scheme TrueRPCMiniUITests \
		-testPlan UITests \
		-destination '$(DESTINATION)' \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO

coverage: ## Run tests with code coverage and print report
	@rm -rf $(BUILD_DIR)/coverage.xcresult
	@mkdir -p $(BUILD_DIR)
	xcodebuild test \
		-scheme $(SCHEME) \
		-testPlan AllTests \
		-destination '$(DESTINATION)' \
		-enableCodeCoverage YES \
		-resultBundlePath $(BUILD_DIR)/coverage.xcresult \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
	@printf '\n%s\n' "────────────────────── Coverage Report ──────────────────────"
	xcrun xccov view --report $(BUILD_DIR)/coverage.xcresult

build: ## Build the application
	xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
