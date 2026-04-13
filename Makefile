PREFIX ?= /usr/local
BINARY = apfel
VERSION_FILE = .version

.PHONY: check-toolchain build install uninstall install-demo-scripts uninstall-demo-scripts clean bump-patch bump-minor bump-major generate-build-info update-readme version release release-patch release-minor release-major package-release-asset print-release-asset print-release-sha256 update-homebrew-formula preflight benchmark test

DEMO_SCRIPTS = cmd explain gitsum mac-narrator naming oneliner port wtd

# --- Environment checks ---

check-toolchain:
	@sdk=$$(xcrun --show-sdk-version 2>/dev/null || echo "missing"); \
	devdir=$$(xcode-select -p 2>/dev/null || echo "missing"); \
	os_ver=$$(sw_vers -productVersion 2>/dev/null || echo "unknown"); \
	if [ "$$sdk" = "missing" ]; then \
		echo ""; \
		echo "error: apfel could not determine your active Apple SDK version."; \
		echo "Selected developer dir: $$devdir"; \
		echo "Install or update Command Line Tools, then retry."; \
		echo ""; \
		echo "Checks:"; \
		echo "  xcode-select -p"; \
		echo "  xcrun --show-sdk-version"; \
		echo "  xcode-select --install"; \
		exit 1; \
	fi; \
	major=$$(echo "$$sdk" | cut -d. -f1); \
	minor=$$(echo "$$sdk" | cut -d. -f2); \
	if [ -z "$$minor" ]; then minor=0; fi; \
	if [ "$$major" -lt 26 ] || { [ "$$major" -eq 26 ] && [ "$$minor" -lt 4 ]; }; then \
		echo ""; \
		echo "error: apfel requires Apple developer tools with the macOS 26.4 SDK or newer."; \
		echo "Your macOS version: $$os_ver"; \
		echo "Active SDK version: $$sdk"; \
		echo "Selected developer dir: $$devdir"; \
		echo ""; \
		echo "Why this fails:"; \
		echo "  FoundationModels token-counting APIs (tokenCount/contextSize) are missing from older SDKs."; \
		echo ""; \
		echo "What you need to update:"; \
		echo "  1. Update Command Line Tools to the macOS 26.4 SDK or newer."; \
		echo "  2. Select Command Line Tools explicitly if needed:"; \
		echo "     sudo xcode-select -s /Library/Developer/CommandLineTools"; \
		echo "  3. Re-check with: xcrun --show-sdk-version"; \
		echo "  4. Re-run: make install"; \
		exit 1; \
	fi

# --- Build ---

build: check-toolchain generate-build-info
	swift build -c release

install: build
	@pkill -f "apfel --serve" 2>/dev/null || true
	@sleep 1
	@# If Homebrew apfel is linked and would shadow our install, unlink it.
	@# This only removes the symlink — the Homebrew package stays installed.
	@# `brew upgrade apfel` or `brew link apfel` restores it.
	@if command -v brew >/dev/null 2>&1 && brew list apfel >/dev/null 2>&1; then \
		brew_path=$$(brew --prefix)/bin/$(BINARY); \
		if [ -L "$$brew_path" ]; then \
			echo "unlinking Homebrew apfel (dev build takes priority)..."; \
			brew unlink apfel 2>/dev/null || true; \
		fi; \
	fi
	@if [ ! -d "$(PREFIX)/bin" ]; then \
		if [ -w "$(PREFIX)" ] 2>/dev/null || [ -w "$$(dirname $(PREFIX))" ]; then \
			mkdir -p "$(PREFIX)/bin"; \
		else \
			sudo mkdir -p "$(PREFIX)/bin"; \
		fi; \
	fi
	@if [ -w "$(PREFIX)/bin" ]; then \
		install .build/release/$(BINARY) $(PREFIX)/bin/$(BINARY); \
	else \
		sudo install .build/release/$(BINARY) $(PREFIX)/bin/$(BINARY); \
	fi
	@echo "✓ installed: $$($(PREFIX)/bin/$(BINARY) --version)"
	@resolved=$$(which $(BINARY) 2>/dev/null || echo "not in PATH"); \
	if [ "$$resolved" != "$(PREFIX)/bin/$(BINARY)" ]; then \
		echo "⚠ warning: 'which $(BINARY)' resolves to $$resolved, not $(PREFIX)/bin/$(BINARY)"; \
		echo "  Run: brew unlink apfel   (then make install again)"; \
	fi

# --- Version bumps ---

bump-patch:
	@v=$$(cat $(VERSION_FILE)); \
	major=$$(echo $$v | cut -d. -f1); \
	minor=$$(echo $$v | cut -d. -f2); \
	patch=$$(echo $$v | cut -d. -f3); \
	new="$$major.$$minor.$$((patch+1))"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "$$v → $$new"

bump-minor:
	@v=$$(cat $(VERSION_FILE)); \
	major=$$(echo $$v | cut -d. -f1); \
	minor=$$(echo $$v | cut -d. -f2); \
	new="$$major.$$((minor+1)).0"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "$$v → $$new"

bump-major:
	@v=$$(cat $(VERSION_FILE)); \
	major=$$(echo $$v | cut -d. -f1); \
	new="$$((major+1)).0.0"; \
	echo "$$new" > $(VERSION_FILE); \
	echo "$$v → $$new"

# --- Release targets (version bump + build, used by CI workflow only) ---

release-patch: check-toolchain bump-patch generate-build-info update-readme
	swift build -c release

release-minor: check-toolchain bump-minor generate-build-info update-readme
	swift build -c release

release-major: check-toolchain bump-major generate-build-info update-readme
	swift build -c release

# --- Generated files ---

generate-build-info:
	@v=$$(cat $(VERSION_FILE)); \
	commit=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown"); \
	branch=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"); \
	date=$$(git log -1 --format='%cd' --date=format:'%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date -u +"%Y-%m-%d %H:%M:%S UTC"); \
	swift_ver=$$(swift --version 2>/dev/null | head -1 | sed 's/.*version //' | sed 's/ .*//'); \
	os_ver=$$(sw_vers -productVersion 2>/dev/null || echo "unknown"); \
	tmp=$$(mktemp); \
	echo "// Auto-generated by make — do not edit" > "$$tmp"; \
	echo "let buildVersion = \"$$v\"" >> "$$tmp"; \
	echo "let buildCommit = \"$$commit\"" >> "$$tmp"; \
	echo "let buildBranch = \"$$branch\"" >> "$$tmp"; \
	echo "let buildDate = \"$$date\"" >> "$$tmp"; \
	echo "let buildSwiftVersion = \"$$swift_ver\"" >> "$$tmp"; \
	echo "let buildOS = \"macOS $$os_ver\"" >> "$$tmp"; \
	if ! cmp -s "$$tmp" Sources/BuildInfo.swift; then \
		mv "$$tmp" Sources/BuildInfo.swift; \
	else \
		rm "$$tmp"; \
	fi

update-readme:
	@v=$$(cat $(VERSION_FILE)); \
	sed -i '' 's/Version [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/Version '"$$v"'/' README.md; \
	sed -i '' 's/version-[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*-blue/version-'"$$v"'-blue/' README.md

# --- One-command release (runs locally with full test qualification) ---
# GitHub-hosted runners lack Apple Intelligence, so releases run locally.
# Usage:
#   make release              # patch bump (default)
#   make release TYPE=minor   # minor bump
#   make release TYPE=major   # major bump
TYPE ?= patch
release:
	@scripts/publish-release.sh $(TYPE)

# --- Test (build + all tests, single command) ---

test: build
	@echo ""
	@echo "=== Unit tests ==="
	@swift run apfel-tests
	@echo ""
	@echo "=== Integration tests ==="
	@pkill -f "apfel --serve" 2>/dev/null || true
	@sleep 1
	@.build/release/apfel --serve --port 11434 2>/dev/null & echo $$! > /tmp/apfel-test-server.pid; \
	.build/release/apfel --serve --port 11435 --mcp mcp/calculator/server.py 2>/dev/null & echo $$! > /tmp/apfel-test-mcp.pid; \
	READY=0; for i in $$(seq 1 15); do \
		curl -sf http://localhost:11434/health >/dev/null 2>&1 && \
		curl -sf http://localhost:11435/health >/dev/null 2>&1 && \
		READY=1 && break; sleep 1; done; \
	if [ "$$READY" -ne 1 ]; then echo "FATAL: servers did not start"; exit 1; fi; \
	python3 -m pytest Tests/integration/ -v --tb=short; \
	STATUS=$$?; \
	kill $$(cat /tmp/apfel-test-server.pid) $$(cat /tmp/apfel-test-mcp.pid) 2>/dev/null || true; \
	rm -f /tmp/apfel-test-server.pid /tmp/apfel-test-mcp.pid; \
	exit $$STATUS

# --- Pre-release qualification ---

preflight:
	@scripts/release-preflight.sh

# --- Utilities ---

version:
	@cat $(VERSION_FILE)

uninstall:
	@if [ -w "$(PREFIX)/bin" ]; then \
		rm -f $(PREFIX)/bin/$(BINARY); \
	else \
		sudo rm -f $(PREFIX)/bin/$(BINARY); \
	fi
	@# Restore Homebrew apfel if it was unlinked by make install.
	@if command -v brew >/dev/null 2>&1 && brew list apfel >/dev/null 2>&1; then \
		if ! [ -L "$$(brew --prefix)/bin/$(BINARY)" ]; then \
			echo "restoring Homebrew apfel link..."; \
			brew link apfel 2>/dev/null || true; \
		fi; \
	fi

install-demo-scripts:
	@repo_root=$$(pwd); \
	for script in $(DEMO_SCRIPTS); do \
		src="$$repo_root/demo/$$script"; \
		dest="$(PREFIX)/bin/$$script"; \
		if [ -w "$(PREFIX)/bin" ]; then \
			ln -sf "$$src" "$$dest"; \
		else \
			sudo ln -sf "$$src" "$$dest"; \
		fi; \
		echo "✓ linked: $$script → $(PREFIX)/bin/$$script"; \
	done

uninstall-demo-scripts:
	@for script in $(DEMO_SCRIPTS); do \
		dest="$(PREFIX)/bin/$$script"; \
		if [ -L "$$dest" ] || [ -f "$$dest" ]; then \
			if [ -w "$(PREFIX)/bin" ]; then \
				rm -f "$$dest"; \
			else \
				sudo rm -f "$$dest"; \
			fi; \
			echo "✓ removed: $(PREFIX)/bin/$$script"; \
		fi; \
	done

clean:
	swift package clean

benchmark:
	@if [ -x "$(PREFIX)/bin/$(BINARY)" ]; then \
		$(PREFIX)/bin/$(BINARY) --benchmark -o json; \
	else \
		echo "error: missing $(PREFIX)/bin/$(BINARY). Run make install first."; \
		exit 1; \
	fi

package-release-asset:
	@v=$$(cat $(VERSION_FILE)); \
	asset="apfel-$$v-arm64-macos.tar.gz"; \
	if [ ! -x ".build/release/$(BINARY)" ]; then \
		echo "error: missing .build/release/$(BINARY). Build a release binary first."; \
		exit 1; \
	fi; \
	tar -C .build/release -czf "$$asset" $(BINARY); \
	echo "$$asset"

print-release-asset:
	@v=$$(cat $(VERSION_FILE)); \
	echo "apfel-$$v-arm64-macos.tar.gz"

print-release-sha256:
	@v=$$(cat $(VERSION_FILE)); \
	asset="apfel-$$v-arm64-macos.tar.gz"; \
	if [ ! -f "$$asset" ]; then \
		echo "error: missing $$asset. Run make package-release-asset first."; \
		exit 1; \
	fi; \
	shasum -a 256 "$$asset" | awk '{print $$1}'

update-homebrew-formula:
	@if [ -z "$(HOMEBREW_FORMULA_OUTPUT)" ]; then \
		echo "error: set HOMEBREW_FORMULA_OUTPUT=/path/to/Formula/apfel.rb"; \
		exit 1; \
	fi
	@if [ -z "$(HOMEBREW_FORMULA_SHA256)" ]; then \
		echo "error: set HOMEBREW_FORMULA_SHA256=<sha256>"; \
		exit 1; \
	fi
	@./scripts/write-homebrew-formula.sh \
		--version "$$(cat $(VERSION_FILE))" \
		--sha256 "$(HOMEBREW_FORMULA_SHA256)" \
		--output "$(HOMEBREW_FORMULA_OUTPUT)"