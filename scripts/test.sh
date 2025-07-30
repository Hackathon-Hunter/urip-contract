# ============================================================================
# test.sh - Comprehensive testing script
# ============================================================================

#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test options
VERBOSE=false
GAS_REPORT=false
COVERAGE=false
SPECIFIC_TEST=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -g|--gas-report)
            GAS_REPORT=true
            shift
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -t|--test)
            SPECIFIC_TEST="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --verbose        Verbose output"
            echo "  -g, --gas-report     Generate gas report"
            echo "  -c, --coverage       Generate coverage report"
            echo "  -t, --test TEST      Run specific test"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🧪 Running URIP Smart Contract Tests...${NC}"

# Build first
echo -e "${YELLOW}🔨 Building contracts...${NC}"
forge build

# Prepare test command
TEST_CMD="forge test"

if [ "$VERBOSE" = true ]; then
    TEST_CMD="$TEST_CMD -vvv"
fi

if [ "$GAS_REPORT" = true ]; then
    TEST_CMD="$TEST_CMD --gas-report"
fi

if [ -n "$SPECIFIC_TEST" ]; then
    TEST_CMD="$TEST_CMD --match-test $SPECIFIC_TEST"
fi

# Run tests
echo -e "${YELLOW}🔬 Executing tests...${NC}"
eval $TEST_CMD

# Generate coverage if requested
if [ "$COVERAGE" = true ]; then
    echo -e "${YELLOW}📊 Generating coverage report...${NC}"
    forge coverage --report lcov
    
    if command -v genhtml &> /dev/null; then
        genhtml lcov.info --output-directory coverage
        echo -e "${GREEN}📈 Coverage report generated in coverage/index.html${NC}"
    else
        echo -e "${YELLOW}⚠️  Install lcov to generate HTML coverage report${NC}"
    fi
fi

echo -e "${GREEN}✅ All tests completed!${NC}"
