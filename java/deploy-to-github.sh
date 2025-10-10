#!/bin/bash

# Deploy FlatBuffers Java to GitHub Packages (alphanovatech organization)
#
# Prerequisites:
# 1. GitHub Personal Access Token with write:packages permission
# 2. Token configured in ~/.m2/settings.xml or as environment variables
#
# Usage:
#   ./deploy-to-github.sh                    # Deploy using settings.xml credentials
#   GITHUB_USERNAME=user GITHUB_TOKEN=token ./deploy-to-github.sh  # Using env vars

set -e

echo "========================================="
echo "FlatBuffers Java - GitHub Packages Deploy"
echo "Organization: alphanovatech"
echo "========================================="

# Check if we're in the right directory
if [ ! -f "pom.xml" ]; then
    echo "Error: pom.xml not found. Please run this script from the java directory."
    exit 1
fi

# Check Maven installation
if ! command -v mvn &> /dev/null; then
    echo "Error: Maven is not installed or not in PATH"
    exit 1
fi

# Check authentication method
if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "Using environment variables for authentication"
    AUTH_METHOD="env"
else
    echo "Using ~/.m2/settings.xml for authentication"
    AUTH_METHOD="settings"

    # Check if settings.xml exists
    if [ ! -f ~/.m2/settings.xml ]; then
        echo "Error: ~/.m2/settings.xml not found"
        echo "Please configure your GitHub credentials or set GITHUB_USERNAME and GITHUB_TOKEN environment variables"
        exit 1
    fi

    # Remind user to configure credentials
    if grep -q "YOUR_GITHUB_USERNAME" ~/.m2/settings.xml; then
        echo "Warning: Please update YOUR_GITHUB_USERNAME and YOUR_GITHUB_TOKEN in ~/.m2/settings.xml"
        echo "Or set GITHUB_USERNAME and GITHUB_TOKEN environment variables"
        exit 1
    fi
fi

# Display current version
VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
echo "Deploying version: $VERSION"

# Clean and build
echo ""
echo "Step 1: Cleaning and building..."
mvn clean compile -Dgpg.skip=true

# Run tests
echo ""
echo "Step 2: Running tests..."
mvn test -Dgpg.skip=true

# Package with sources and javadocs
echo ""
echo "Step 3: Packaging..."
mvn package -Dgpg.skip=true

# Deploy to GitHub Packages
echo ""
echo "Step 4: Deploying to GitHub Packages..."
echo "Repository: https://maven.pkg.github.com/alphanovatech/flatbuffers-java"

# Use deploy:deploy-file to bypass nexus-staging plugin conflicts
# This method works reliably with GitHub Packages

# Deploy main JAR
echo "Deploying main JAR..."
mvn deploy:deploy-file \
  -DgroupId=com.google.flatbuffers \
  -DartifactId=flatbuffers-java \
  -Dversion=$VERSION \
  -Dpackaging=jar \
  -Dfile=target/flatbuffers-java-$VERSION.jar \
  -DpomFile=pom.xml \
  -DrepositoryId=github-alphanovatech \
  -Durl=https://maven.pkg.github.com/alphanovatech/flatbuffers-java \
  -Dgpg.skip=true

# Deploy sources JAR if it exists
if [ -f "target/flatbuffers-java-$VERSION-sources.jar" ]; then
    echo "Deploying sources JAR..."
    mvn deploy:deploy-file \
      -DgroupId=com.google.flatbuffers \
      -DartifactId=flatbuffers-java \
      -Dversion=$VERSION \
      -Dpackaging=jar \
      -Dfile=target/flatbuffers-java-$VERSION-sources.jar \
      -DrepositoryId=github-alphanovatech \
      -Durl=https://maven.pkg.github.com/alphanovatech/flatbuffers-java \
      -Dclassifier=sources \
      -Dgpg.skip=true || echo "Sources JAR deployment skipped (may already exist)"
fi

# Deploy javadoc JAR if it exists
if [ -f "target/flatbuffers-java-$VERSION-javadoc.jar" ]; then
    echo "Deploying javadoc JAR..."
    mvn deploy:deploy-file \
      -DgroupId=com.google.flatbuffers \
      -DartifactId=flatbuffers-java \
      -Dversion=$VERSION \
      -Dpackaging=jar \
      -Dfile=target/flatbuffers-java-$VERSION-javadoc.jar \
      -DrepositoryId=github-alphanovatech \
      -Durl=https://maven.pkg.github.com/alphanovatech/flatbuffers-java \
      -Dclassifier=javadoc \
      -Dgpg.skip=true || echo "Javadoc JAR deployment skipped (may already exist)"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "========================================="
    echo "✅ Deployment successful!"
    echo "========================================="
    echo ""
    echo "Package published to:"
    echo "https://github.com/alphanovatech/flatbuffers-java/packages"
    echo ""
    echo "To use this package in another project:"
    echo ""
    echo "For Gradle (Kotlin DSL) - add to build.gradle.kts:"
    echo "----------------------------------------"
    echo "repositories {"
    echo "    maven {"
    echo "        url = uri(\"https://maven.pkg.github.com/alphanovatech/flatbuffers-java\")"
    echo "        credentials {"
    echo "            username = project.findProperty(\"gpr.user\") as String? ?: System.getenv(\"GITHUB_USERNAME\")"
    echo "            password = project.findProperty(\"gpr.key\") as String? ?: System.getenv(\"GITHUB_TOKEN\")"
    echo "        }"
    echo "    }"
    echo "}"
    echo ""
    echo "dependencies {"
    echo "    implementation(\"com.google.flatbuffers:flatbuffers-java:$VERSION\")"
    echo "}"
    echo ""
    echo "For Maven - add to pom.xml:"
    echo "----------------------------------------"
    echo "<dependency>"
    echo "  <groupId>com.google.flatbuffers</groupId>"
    echo "  <artifactId>flatbuffers-java</artifactId>"
    echo "  <version>$VERSION</version>"
    echo "</dependency>"
    echo ""
    echo "See GITHUB_PACKAGES_SETUP.md for detailed configuration instructions"
else
    echo ""
    echo "❌ Deployment failed!"
    echo "Please check the error messages above."
    exit 1
fi