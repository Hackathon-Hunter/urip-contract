echo "🔧 Fixing Solidity pragma versions..."

# Find all .sol files and replace pragma version
find . -name "*.sol" -type f -exec sed -i 's/pragma solidity \^0\.8\.20;/pragma solidity ^0.8.19;/g' {} \;

echo "✅ Updated all pragma versions from ^0.8.20 to ^0.8.19"

# List all affected files
echo "📝 Updated files:"
find . -name "*.sol" -type f | xargs grep "pragma solidity" | head -10