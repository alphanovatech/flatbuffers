# GitHub Packages Setup for FlatBuffers Java

This guide explains how to publish FlatBuffers Java to GitHub Packages (alphanovatech organization) and consume it in your Gradle/Kotlin or Maven projects.

## Prerequisites

### For Publishing (This Repository)

1. **GitHub Personal Access Token**
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Select scopes:
     - `write:packages` - Upload packages to GitHub Package Registry
     - `read:packages` - Download packages from GitHub Package Registry
     - `delete:packages` (optional) - Delete packages from GitHub Package Registry
   - Save the token securely

2. **Configure Maven Authentication**

   Option A: Using `~/.m2/settings.xml` (already configured):
   ```xml
   <server>
     <id>github-alphanovatech</id>
     <username>YOUR_GITHUB_USERNAME</username>
     <password>YOUR_GITHUB_TOKEN</password>
   </server>
   ```

   Option B: Using environment variables:
   ```bash
   export GITHUB_USERNAME=your-username
   export GITHUB_TOKEN=your-token
   ```

## Publishing to GitHub Packages

### Quick Deploy

```bash
cd /Users/alexey/Projects/flatbuffers/java

# Make the script executable (first time only)
chmod +x deploy-to-github.sh

# Deploy using settings.xml
./deploy-to-github.sh

# Or deploy using environment variables
GITHUB_USERNAME=your-username GITHUB_TOKEN=your-token ./deploy-to-github.sh
```

### Manual Deploy

```bash
# Build and install locally
mvn clean install -Dgpg.skip=true

# Deploy to GitHub Packages
mvn deploy -Dgpg.skip=true
```

## Consuming the Package in Your Gradle Project

### 1. Configure Gradle Authentication

Create or update `~/.gradle/gradle.properties`:

```properties
gpr.user=YOUR_GITHUB_USERNAME
gpr.key=YOUR_GITHUB_TOKEN
```

**Security Note:** Never commit tokens to version control. Use gradle.properties or environment variables.

### 2. Add Repository and Dependency to build.gradle.kts

```kotlin
// build.gradle.kts

repositories {
    mavenCentral()

    // alphanovatech GitHub Packages repository
    maven {
        name = "GitHubPackages"
        url = uri("https://maven.pkg.github.com/alphanovatech/flatbuffers-java")
        credentials {
            // Try gradle.properties first, then environment variables
            username = project.findProperty("gpr.user") as String?
                ?: System.getenv("GITHUB_USERNAME")
            password = project.findProperty("gpr.key") as String?
                ?: System.getenv("GITHUB_TOKEN")
        }
    }
}

dependencies {
    // FlatBuffers Java from GitHub Packages
    implementation("com.google.flatbuffers:flatbuffers-java:25.9.23")

    // Your other dependencies...
}
```

### 3. Alternative: Using Settings Script (settings.gradle.kts)

For multi-module projects, configure repositories in settings:

```kotlin
// settings.gradle.kts

dependencyResolutionManagement {
    repositories {
        mavenCentral()

        maven {
            name = "GitHubPackages-AlphaNovaTech"
            url = uri("https://maven.pkg.github.com/alphanovatech/flatbuffers-java")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull
                    ?: System.getenv("GITHUB_USERNAME")
                password = providers.gradleProperty("gpr.key").orNull
                    ?: System.getenv("GITHUB_TOKEN")
            }
        }
    }
}
```

### 4. For CI/CD (GitHub Actions)

```yaml
# .github/workflows/build.yml

- name: Setup Gradle
  uses: gradle/gradle-build-action@v2

- name: Build with Gradle
  env:
    GITHUB_USERNAME: ${{ github.actor }}
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: ./gradlew build
```

## Consuming in Maven Projects

### Add to pom.xml:

```xml
<!-- Repository configuration -->
<repositories>
  <repository>
    <id>github-alphanovatech</id>
    <url>https://maven.pkg.github.com/alphanovatech/flatbuffers-java</url>
  </repository>
</repositories>

<!-- Dependency -->
<dependencies>
  <dependency>
    <groupId>com.google.flatbuffers</groupId>
    <artifactId>flatbuffers-java</artifactId>
    <version>25.9.23</version>
  </dependency>
</dependencies>
```

## Troubleshooting

### Authentication Issues

1. **401 Unauthorized**
   - Verify your token has `read:packages` permission
   - Check username and token are correct
   - Ensure token hasn't expired

2. **404 Not Found**
   - Package may not be published yet
   - Check the repository URL is correct
   - Verify you have access to the alphanovatech organization

3. **Gradle Can't Find Package**
   ```bash
   # Clear Gradle cache
   ./gradlew clean build --refresh-dependencies

   # Or clear specific dependency
   rm -rf ~/.gradle/caches/modules-2/files-2.1/com.google.flatbuffers/
   ```

### Verify Package Publication

1. Check GitHub Packages UI:
   - Go to https://github.com/alphanovatech
   - Click on "Packages" tab
   - Look for "flatbuffers-java"

2. Using GitHub CLI:
   ```bash
   gh api /orgs/alphanovatech/packages/maven/com.google.flatbuffers.flatbuffers-java/versions
   ```

### Debug Gradle Repository Access

Add to build.gradle.kts for debugging:

```kotlin
tasks.register("checkRepos") {
    doLast {
        repositories.forEach { repo ->
            println("Repository: ${repo.name}")
            if (repo is MavenArtifactRepository) {
                println("  URL: ${repo.url}")
            }
        }
    }
}
```

Run: `./gradlew checkRepos`

## Version Management

### Using Version Catalogs (Recommended for Gradle)

Create `gradle/libs.versions.toml`:

```toml
[versions]
flatbuffers = "25.9.23"

[libraries]
flatbuffers-java = { group = "com.google.flatbuffers", name = "flatbuffers-java", version.ref = "flatbuffers" }
```

Then in build.gradle.kts:
```kotlin
dependencies {
    implementation(libs.flatbuffers.java)
}
```

## Security Best Practices

1. **Never commit tokens** to version control
2. Use **environment variables** in CI/CD
3. **Rotate tokens** regularly
4. Use **least privilege** - only grant necessary permissions
5. Consider using **GitHub Apps** for organization-wide access

## Additional Resources

- [GitHub Packages Documentation](https://docs.github.com/en/packages)
- [Gradle GitHub Packages Guide](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-gradle-registry)
- [FlatBuffers Documentation](https://google.github.io/flatbuffers/)

## Support

For issues with:
- **This setup**: Create an issue in the alphanovatech repository
- **FlatBuffers**: See https://github.com/google/flatbuffers/issues
- **GitHub Packages**: Contact GitHub Support