#!/bin/bash

# Setup GitHub repository and configuration for FlatBuffers Java package
# This script uses GitHub CLI (gh) to automate repository creation and setup

set -e

echo "============================================"
echo "GitHub Repository Setup for FlatBuffers Java"
echo "Organization: alphanovatech"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo ""
    echo "Please install it first:"
    echo "  macOS: brew install gh"
    echo "  Linux: See https://github.com/cli/cli#installation"
    echo ""
    exit 1
fi

# Check gh authentication
echo "Checking GitHub CLI authentication..."
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI is not authenticated${NC}"
    echo ""
    echo "Please authenticate first:"
    echo "  gh auth login"
    echo ""
    echo "Make sure to grant the following scopes:"
    echo "  - repo (full control of private repositories)"
    echo "  - write:packages (upload packages)"
    echo "  - read:packages (download packages)"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI is authenticated${NC}"
echo ""

# Get current user
GITHUB_USER=$(gh api user --jq .login)
echo "Authenticated as: $GITHUB_USER"
echo ""

# Check if alphanovatech organization exists and user has access
echo "Checking access to alphanovatech organization..."
if gh api orgs/alphanovatech &> /dev/null; then
    echo -e "${GREEN}✅ Organization 'alphanovatech' found${NC}"

    # Check if user is a member
    if gh api user/orgs --jq '.[].login' | grep -q "^alphanovatech$"; then
        echo -e "${GREEN}✅ You are a member of alphanovatech${NC}"
    else
        echo -e "${YELLOW}⚠️  You don't appear to be a member of alphanovatech${NC}"
        echo "You may need to request access from the organization admin"
    fi
else
    echo -e "${YELLOW}⚠️  Organization 'alphanovatech' not found or not accessible${NC}"
    echo ""
    echo "Options:"
    echo "1. Create the organization at https://github.com/organizations/new"
    echo "2. Use your personal account instead (modify the scripts to use $GITHUB_USER)"
    echo ""
    read -p "Use your personal account instead? (y/n): " use_personal
    if [[ $use_personal == "y" ]]; then
        ORG_NAME=$GITHUB_USER
        echo "Proceeding with personal account: $ORG_NAME"
    else
        exit 1
    fi
fi
echo ""

# Set organization name
ORG_NAME=${ORG_NAME:-alphanovatech}

# Check if repository exists
REPO_NAME="flatbuffers-java"
echo "Checking if repository $ORG_NAME/$REPO_NAME exists..."

if gh api repos/$ORG_NAME/$REPO_NAME &> /dev/null; then
    echo -e "${GREEN}✅ Repository already exists${NC}"
    echo "URL: https://github.com/$ORG_NAME/$REPO_NAME"
else
    echo -e "${YELLOW}Repository does not exist${NC}"
    echo ""
    read -p "Create repository $ORG_NAME/$REPO_NAME? (y/n): " create_repo

    if [[ $create_repo == "y" ]]; then
        echo "Creating repository..."

        if [[ $ORG_NAME == $GITHUB_USER ]]; then
            # Create in personal account
            gh repo create $REPO_NAME \
                --private \
                --description "FlatBuffers Java package for internal use" \
                --add-readme || {
                    echo -e "${RED}❌ Failed to create repository${NC}"
                    exit 1
                }
        else
            # Create in organization
            gh repo create $ORG_NAME/$REPO_NAME \
                --private \
                --description "FlatBuffers Java package for internal use" \
                --add-readme || {
                    echo -e "${RED}❌ Failed to create repository${NC}"
                    echo "Make sure you have permission to create repositories in $ORG_NAME"
                    exit 1
                }
        fi

        echo -e "${GREEN}✅ Repository created successfully${NC}"
        echo "URL: https://github.com/$ORG_NAME/$REPO_NAME"
    fi
fi
echo ""

# Generate Personal Access Token instructions
echo "============================================"
echo "Personal Access Token Setup"
echo "============================================"
echo ""
echo "You need a Personal Access Token for Maven to publish packages."
echo ""
echo -e "${YELLOW}Steps to create a token:${NC}"
echo ""
echo "1. Open: https://github.com/settings/tokens/new"
echo ""
echo "2. Token settings:"
echo "   - Note: 'FlatBuffers Java Package Publishing'"
echo "   - Expiration: 90 days (or your preference)"
echo "   - Select scopes:"
echo "     ✅ repo (if using private repository)"
echo "     ✅ write:packages"
echo "     ✅ read:packages"
echo "     ✅ delete:packages (optional)"
echo ""
echo "3. Click 'Generate token'"
echo ""
echo "4. IMPORTANT: Copy the token immediately (starts with ghp_)"
echo ""

read -p "Press Enter when you have copied your token..."
echo ""

# Prompt for token
echo "Please enter your Personal Access Token:"
read -s GITHUB_TOKEN
echo ""

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo -e "${RED}❌ No token provided${NC}"
    exit 1
fi

# Validate token
echo "Validating token..."
if curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -q "\"login\""; then
    echo -e "${GREEN}✅ Token is valid${NC}"

    # Check token scopes
    echo ""
    echo "Checking token permissions..."
    SCOPES=$(curl -sI -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep -i "x-oauth-scopes:" | cut -d' ' -f2- | tr -d '\r')

    echo "Token scopes: $SCOPES"

    if [[ $SCOPES == *"write:packages"* ]]; then
        echo -e "${GREEN}✅ write:packages permission found${NC}"
    else
        echo -e "${YELLOW}⚠️  write:packages permission not found${NC}"
        echo "You may not be able to publish packages"
    fi

    if [[ $SCOPES == *"read:packages"* ]]; then
        echo -e "${GREEN}✅ read:packages permission found${NC}"
    else
        echo -e "${YELLOW}⚠️  read:packages permission not found${NC}"
    fi
else
    echo -e "${RED}❌ Token is invalid or expired${NC}"
    exit 1
fi
echo ""

# Update Maven settings
echo "============================================"
echo "Updating Maven Configuration"
echo "============================================"
echo ""

SETTINGS_FILE="$HOME/.m2/settings.xml"

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup"
    echo "Backed up existing settings to ${SETTINGS_FILE}.backup"
fi

# Update settings.xml with actual values
echo "Updating $SETTINGS_FILE..."
cat > "$SETTINGS_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">

  <servers>
    <!-- GitHub Packages authentication for $ORG_NAME organization -->
    <server>
      <id>github-$ORG_NAME</id>
      <username>$GITHUB_USER</username>
      <password>$GITHUB_TOKEN</password>
    </server>
  </servers>

  <!-- Add $ORG_NAME GitHub Packages as a repository for consuming packages -->
  <profiles>
    <profile>
      <id>github-$ORG_NAME</id>
      <repositories>
        <repository>
          <id>github-$ORG_NAME</id>
          <name>GitHub $ORG_NAME Apache Maven Packages</name>
          <url>https://maven.pkg.github.com/$ORG_NAME/*</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>
      </repositories>
    </profile>
  </profiles>

  <!-- Activate the $ORG_NAME GitHub profile by default -->
  <activeProfiles>
    <activeProfile>github-$ORG_NAME</activeProfile>
  </activeProfiles>

</settings>
EOF

echo -e "${GREEN}✅ Maven settings updated${NC}"
echo ""

# Update Gradle properties
echo "============================================"
echo "Updating Gradle Configuration"
echo "============================================"
echo ""

GRADLE_PROPS="$HOME/.gradle/gradle.properties"
mkdir -p "$HOME/.gradle"

# Backup existing properties
if [ -f "$GRADLE_PROPS" ]; then
    cp "$GRADLE_PROPS" "${GRADLE_PROPS}.backup"
    echo "Backed up existing properties to ${GRADLE_PROPS}.backup"
fi

# Check if properties already exist
if [ -f "$GRADLE_PROPS" ] && grep -q "gpr.user" "$GRADLE_PROPS"; then
    echo "Updating existing Gradle properties..."
    # Update existing properties
    sed -i.tmp "s/^gpr.user=.*/gpr.user=$GITHUB_USER/" "$GRADLE_PROPS"
    sed -i.tmp "s/^gpr.key=.*/gpr.key=$GITHUB_TOKEN/" "$GRADLE_PROPS"
    rm -f "${GRADLE_PROPS}.tmp"
else
    echo "Adding GitHub Package Registry credentials to Gradle properties..."
    echo "" >> "$GRADLE_PROPS"
    echo "# GitHub Package Registry" >> "$GRADLE_PROPS"
    echo "gpr.user=$GITHUB_USER" >> "$GRADLE_PROPS"
    echo "gpr.key=$GITHUB_TOKEN" >> "$GRADLE_PROPS"
fi

echo -e "${GREEN}✅ Gradle properties updated${NC}"
echo ""

# Update pom.xml if needed
if [[ $ORG_NAME != "alphanovatech" ]]; then
    echo "============================================"
    echo "Updating pom.xml for $ORG_NAME"
    echo "============================================"
    echo ""

    POM_FILE="pom.xml"
    if [ -f "$POM_FILE" ]; then
        echo "Updating distribution management in pom.xml..."
        sed -i.backup "s/alphanovatech/$ORG_NAME/g" "$POM_FILE"
        sed -i.backup "s/github-alphanovatech/github-$ORG_NAME/g" "$POM_FILE"
        echo -e "${GREEN}✅ pom.xml updated for $ORG_NAME${NC}"
    fi
fi

# Final summary
echo ""
echo "============================================"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "============================================"
echo ""
echo "Configuration Summary:"
echo "  Organization: $ORG_NAME"
echo "  Repository: https://github.com/$ORG_NAME/$REPO_NAME"
echo "  User: $GITHUB_USER"
echo "  Maven config: ~/.m2/settings.xml"
echo "  Gradle config: ~/.gradle/gradle.properties"
echo ""
echo "Next steps:"
echo "1. Deploy the package:"
echo "   ./deploy-to-github.sh"
echo ""
echo "2. In your Gradle project, add:"
echo "   repository: https://maven.pkg.github.com/$ORG_NAME/flatbuffers-java"
echo ""
echo "3. View your packages at:"
echo "   https://github.com/$ORG_NAME/$REPO_NAME/packages"
echo ""

# Save configuration for other scripts
CONFIG_FILE=".github-package-config"
cat > "$CONFIG_FILE" << EOF
# GitHub Package Configuration
export GITHUB_ORG=$ORG_NAME
export GITHUB_REPO=$REPO_NAME
export GITHUB_USER=$GITHUB_USER
EOF

echo "Configuration saved to $CONFIG_FILE for use by other scripts"