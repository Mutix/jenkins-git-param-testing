#!/bin/bash
# Test setup for git-parameter-plugin fix

set -e

echo "=== Building plugin ==="
mvn clean package -DskipTests

echo ""
echo "=== Cloning test repository ==="
WORK_DIR="/tmp/test-git-work"
rm -rf "$WORK_DIR"
git clone https://github.com/Mutix/jenkins-git-param-testing.git "$WORK_DIR"
cd "$WORK_DIR"

# Configure git
git config user.email "test@example.com"
git config user.name "Test User"

echo ""
echo "=== Test repository ready ==="
echo "Repository: https://github.com/Mutix/jenkins-git-param-testing.git"
echo "Working copy: $WORK_DIR"
echo ""
echo "=== Next steps ==="
echo "1. Start Jenkins: mvn hpi:run"
echo "2. Open http://localhost:8080/jenkins"
echo "3. Install Pipeline: Build Step plugin"
echo "4. Create JobA and JobB using the pipeline scripts"
echo "5. In JobB git parameter, use: https://github.com/Mutix/jenkins-git-param-testing.git"
echo ""
echo "⚠️  NOTE: You'll need push access to the GitHub repo to create tags"
echo "   Or fork the repo and update the URLs in the scripts"

