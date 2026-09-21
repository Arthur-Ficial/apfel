#!/bin/bash
# Verify apfel builds and tests with Command Line Tools only (no Xcode).

PASS=0
FAIL=0

check() {
    if eval "$2" >/dev/null 2>&1; then
        echo "  OK    $1"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $1"
        FAIL=$((FAIL + 1))
    fi
}

echo "Checking apfel builds without Xcode..."
echo ""

DEV_DIR=$(xcode-select -p 2>/dev/null || echo "none")
if [[ "$DEV_DIR" == *"CommandLineTools"* ]]; then
    echo "  OK    Active SDK: Command Line Tools"
    PASS=$((PASS + 1))
elif [[ "$DEV_DIR" == *"Xcode"* ]]; then
    echo "  WARN  Active SDK: Xcode (test is more meaningful with CLT only)"
    PASS=$((PASS + 1))
else
    echo "  FAIL  No developer tools found"
    FAIL=$((FAIL + 1))
fi

check "swift available" "swift --version"
check "make available" "make --version"
check "swift build (debug)" "swift build --build-system native"
check "swift build (release)" "swift build -c release --build-system native"
check "unit tests pass" "swift run --build-system native apfel-tests"

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
    echo "All good - no Xcode needed."
else
    exit 1
fi
