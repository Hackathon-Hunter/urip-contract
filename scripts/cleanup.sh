# ============================================================================
# cleanup.sh - Clean build artifacts and logs
# ============================================================================

#!/bin/bash

echo "🧹 Cleaning up URIP project..."

# Remove build artifacts
echo "Removing build artifacts..."
rm -rf out/
rm -rf cache/
rm -rf broadcast/

# Remove coverage files
echo "Removing coverage files..."
rm -f lcov.info
rm -rf coverage/

# Remove logs
echo "Removing logs..."
rm -f *.log

# Remove temporary files
echo "Removing temporary files..."
find . -name "*.tmp" -delete
find . -name ".DS_Store" -delete

echo "✅ Cleanup completed!"