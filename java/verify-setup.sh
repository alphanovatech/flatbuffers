#!/bin/bash

# Verify GitHub Packages setup for FlatBuffers Java
# This script checks all configurations and permissions

set -e

echo "============================================"
echo "GitHub Packages Setup Verification"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Score tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Function to check a condition
check() {
    local description="$1"
    local command="$2"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    echo -n "Checking $description... "
    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✅ Passed${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

# Function for detailed check with output
check_with_output() {
    local description="$1"
    local command="$2"
    local expected="$3"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    echo -n "Checking $description... "
    result=$(eval "$command" 2>/dev/null || echo "ERROR")

    if [[ "$result" == "ERROR" ]]; then
        echo -e "${RED}❌ Failed (command error)${NC}"
        return 1
    elif [[ -n "$expected" ]] && [[ "$result" != *"$expected"* ]]; then
        echo -e "${RED}❌ Failed (unexpected result)${NC}"
        echo "  Expected: $expected"
        echo "  Got: $result"
        return 1
    else
        echo -e "${GREEN}✅ Passed${NC}"
        if [[ -n "$result" ]]; then
            echo "  → $result"
        fi
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    fi
}

# Load configuration if exists
if [ -f ".github-package-config" ]; then
    source .github-package-config
    echo -e "${BLUE}Loaded configuration from .github-package-config${NC}"
    echo "  Organization: ${GITHUB_ORG:-not set}"
    echo "  Repository: ${GITHUB_REPO:-not set}"
    echo "  User: ${GITHUB_USER:-not set}"
    echo ""
fi

# Set defaults
ORG_NAME=${GITHUB_ORG:-alphanovatech}
REPO_NAME=${GITHUB_REPO:-flatbuffers-java}

echo "============================================"
echo "1. Environment Checks"
echo "============================================"
echo ""

# Check Java
check "Java installation" "java -version"
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -n 1)
    echo "  Java version: $java_version"
fi

# Check Maven
check "Maven installation" "mvn --version"
if command -v mvn &> /dev/null; then
    mvn_version=$(mvn --version | head -n 1)
    echo "  Maven version: $mvn_version"
fi

# Check GitHub CLI
check "GitHub CLI installation" "gh --version"
echo ""

echo "============================================"
echo "2. GitHub Authentication"
echo "============================================"
echo ""

# Check gh CLI auth
if check "GitHub CLI authentication" "gh auth status"; then
    current_user=$(gh api user --jq .login 2>/dev/null || echo "unknown")
    echo "  Authenticated as: $current_user"
fi

# Check Maven settings
echo ""
SETTINGS_FILE="$HOME/.m2/settings.xml"
if check "Maven settings.xml exists" "[ -f $SETTINGS_FILE ]"; then
    # Check if it has GitHub configuration
    if grep -q "github-$ORG_NAME" "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Contains github-$ORG_NAME server configuration"

        # Check if placeholder values exist
        if grep -q "YOUR_GITHUB" "$SETTINGS_FILE" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠${NC} Contains placeholder values (YOUR_GITHUB_USERNAME/TOKEN)"
            echo "     Please update with actual credentials"
        else
            echo -e "  ${GREEN}✓${NC} No placeholder values found"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Missing github-$ORG_NAME server configuration"
    fi
fi

# Check Gradle properties
echo ""
GRADLE_PROPS="$HOME/.gradle/gradle.properties"
if check "Gradle properties exists" "[ -f $GRADLE_PROPS ]"; then
    if grep -q "gpr.user" "$GRADLE_PROPS" 2>/dev/null; then
        gpr_user=$(grep "^gpr.user=" "$GRADLE_PROPS" | cut -d'=' -f2)
        echo -e "  ${GREEN}✓${NC} Contains gpr.user: $gpr_user"
    else
        echo -e "  ${YELLOW}⚠${NC} Missing gpr.user property"
    fi

    if grep -q "gpr.key" "$GRADLE_PROPS" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Contains gpr.key: [REDACTED]"
    else
        echo -e "  ${YELLOW}⚠${NC} Missing gpr.key property"
    fi
fi

echo ""
echo "============================================"
echo "3. Repository Checks"
echo "============================================"
echo ""

# Check repository exists
if check "Repository $ORG_NAME/$REPO_NAME exists" "gh api repos/$ORG_NAME/$REPO_NAME --jq .name"; then
    # Get repository details
    repo_visibility=$(gh api repos/$ORG_NAME/$REPO_NAME --jq .visibility 2>/dev/null || echo "unknown")
    echo "  Visibility: $repo_visibility"
    echo "  URL: https://github.com/$ORG_NAME/$REPO_NAME"
fi

# Check organization membership
echo ""
if [[ "$ORG_NAME" != "$current_user" ]]; then
    if check "Organization $ORG_NAME membership" "gh api user/orgs --jq '.[].login' | grep -q '^$ORG_NAME\$'"; then
        echo "  You are a member of $ORG_NAME"
    else
        echo "  You may need additional permissions from the organization admin"
    fi
fi

echo ""
echo "============================================"
echo "4. Token Permissions Check"
echo "============================================"
echo ""

# Try to extract token from settings.xml or environment
if [ -f "$SETTINGS_FILE" ]; then
    # Try to extract token (this is just for testing, normally we shouldn't read tokens)
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Using GITHUB_TOKEN from environment"
        TEST_TOKEN="$GITHUB_TOKEN"
    else
        echo "Checking token permissions (if configured)..."
        echo -e "${YELLOW}Note: Token validation requires the token to be set in environment${NC}"
        echo "Export GITHUB_TOKEN to test permissions"
    fi
fi

if [ -n "$TEST_TOKEN" ]; then
    echo "Testing token permissions..."

    # Test token validity
    if curl -s -H "Authorization: token $TEST_TOKEN" https://api.github.com/user | grep -q "\"login\""; then
        echo -e "${GREEN}✅ Token is valid${NC}"

        # Check scopes
        SCOPES=$(curl -sI -H "Authorization: token $TEST_TOKEN" https://api.github.com/user | grep -i "x-oauth-scopes:" | cut -d' ' -f2- | tr -d '\r')
        echo "Token scopes: ${SCOPES:-none}"

        # Check individual scopes
        for scope in "write:packages" "read:packages" "repo"; do
            if [[ $SCOPES == *"$scope"* ]]; then
                echo -e "  ${GREEN}✓${NC} $scope"
            else
                echo -e "  ${YELLOW}✗${NC} $scope (may be needed)"
            fi
        done
    else
        echo -e "${RED}❌ Token appears to be invalid${NC}"
    fi
fi

echo ""
echo "============================================"
echo "5. Project Configuration"
echo "============================================"
echo ""

# Check pom.xml
if check "pom.xml exists" "[ -f pom.xml ]"; then
    # Check distribution management
    if grep -q "github-$ORG_NAME" pom.xml 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Distribution management configured for github-$ORG_NAME"
        dist_url=$(grep -A1 "github-$ORG_NAME" pom.xml | grep "<url>" | sed 's/.*<url>//;s/<\/url>.*//' | head -1)
        echo "  Repository URL: $dist_url"
    else
        echo -e "  ${YELLOW}⚠${NC} Distribution management not configured for github-$ORG_NAME"
    fi

    # Check version
    version=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout 2>/dev/null || echo "unknown")
    echo "  Package version: $version"
fi

# Check deploy script
echo ""
if check "deploy-to-github.sh exists" "[ -f deploy-to-github.sh ]"; then
    if [ -x deploy-to-github.sh ]; then
        echo -e "  ${GREEN}✓${NC} Script is executable"
    else
        echo -e "  ${YELLOW}⚠${NC} Script is not executable (run: chmod +x deploy-to-github.sh)"
    fi
fi

echo ""
echo "============================================"
echo "6. Test Maven Connection"
echo "============================================"
echo ""

echo "Testing Maven repository access..."
if mvn help:effective-settings 2>/dev/null | grep -q "github-$ORG_NAME"; then
    echo -e "${GREEN}✅ Maven can see github-$ORG_NAME configuration${NC}"
else
    echo -e "${YELLOW}⚠️  Maven settings may not be properly configured${NC}"
fi

echo ""
echo "============================================"
echo "Summary"
echo "============================================"
echo ""

SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
echo "Passed $PASSED_CHECKS out of $TOTAL_CHECKS checks (${SUCCESS_RATE}%)"
echo ""

if [ $SUCCESS_RATE -eq 100 ]; then
    echo -e "${GREEN}🎉 All checks passed! You're ready to deploy.${NC}"
    echo ""
    echo "Run: ./deploy-to-github.sh"
elif [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "${GREEN}✅ Setup is mostly complete.${NC}"
    echo "Review the warnings above before deploying."
elif [ $SUCCESS_RATE -ge 50 ]; then
    echo -e "${YELLOW}⚠️  Setup is partially complete.${NC}"
    echo "Please address the failed checks before deploying."
else
    echo -e "${RED}❌ Setup is incomplete.${NC}"
    echo "Please run ./setup-github-repo.sh first."
fi

echo ""
echo "For detailed setup instructions, see GITHUB_PACKAGES_SETUP.md"