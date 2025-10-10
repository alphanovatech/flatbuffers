# Quick Setup Guide - FlatBuffers Java GitHub Packages

## 🚀 Automated Setup (Recommended)

Run this single command to set up everything:

```bash
# Make scripts executable
chmod +x setup-github-repo.sh verify-setup.sh deploy-to-github.sh

# Run automated setup
./setup-github-repo.sh
```

This script will:
1. ✅ Check/install GitHub CLI
2. ✅ Authenticate with GitHub
3. ✅ Create the repository (if needed)
4. ✅ Guide you through token creation
5. ✅ Configure Maven and Gradle
6. ✅ Update all configuration files

## 📋 Manual Setup Steps

If you prefer manual setup or the script fails:

### Step 1: Create GitHub Personal Access Token

1. **Go to:** https://github.com/settings/tokens/new

2. **Configure token:**
   - **Note:** `FlatBuffers Java Package Publishing`
   - **Expiration:** 90 days (recommended)
   - **Select scopes:**
     - ☑️ `repo` (if using private repository)
     - ☑️ `write:packages`
     - ☑️ `read:packages`
     - ☑️ `delete:packages` (optional)

3. **Generate and copy the token** (starts with `ghp_`)

### Step 2: Create Repository

```bash
# Using GitHub CLI
gh repo create alphanovatech/flatbuffers-java --private

# Or create manually at:
# https://github.com/organizations/alphanovatech/repositories/new
```

### Step 3: Configure Maven

Edit `~/.m2/settings.xml`:

```xml
<server>
  <id>github-alphanovatech</id>
  <username>YOUR_GITHUB_USERNAME</username>
  <password>ghp_YOUR_TOKEN_HERE</password>
</server>
```

### Step 4: Configure Gradle

Edit `~/.gradle/gradle.properties`:

```properties
gpr.user=YOUR_GITHUB_USERNAME
gpr.key=ghp_YOUR_TOKEN_HERE
```

### Step 5: Deploy

```bash
./deploy-to-github.sh
```

## ✅ Verification

Check if everything is configured correctly:

```bash
./verify-setup.sh
```

This will test:
- Environment (Java, Maven, GitHub CLI)
- Authentication (tokens, credentials)
- Repository access
- Configuration files

## 🔧 Using in Your Gradle Project

Add to your `build.gradle.kts`:

```kotlin
repositories {
    maven {
        url = uri("https://maven.pkg.github.com/alphanovatech/flatbuffers-java")
        credentials {
            username = project.findProperty("gpr.user") as String?
                ?: System.getenv("GITHUB_USERNAME")
            password = project.findProperty("gpr.key") as String?
                ?: System.getenv("GITHUB_TOKEN")
        }
    }
}

dependencies {
    implementation("com.google.flatbuffers:flatbuffers-java:25.9.23")
}
```

## 🆘 Troubleshooting

### "Repository not found"
```bash
# Create it with GitHub CLI
gh repo create alphanovatech/flatbuffers-java --private
```

### "401 Unauthorized"
- Check token has `write:packages` permission
- Verify token hasn't expired
- Ensure username is correct

### "Package not found" in Gradle
```bash
# Clear Gradle cache
./gradlew clean build --refresh-dependencies
```

### Token expired
1. Generate new token at https://github.com/settings/tokens/new
2. Update `~/.m2/settings.xml` and `~/.gradle/gradle.properties`

## 📦 View Published Packages

After successful deployment:
- **Organization packages:** https://github.com/orgs/alphanovatech/packages
- **Repository packages:** https://github.com/alphanovatech/flatbuffers-java/packages

## 🔒 Security Notes

- **Never commit tokens** to version control
- Store tokens in `~/.m2/settings.xml` and `~/.gradle/gradle.properties`
- Use environment variables in CI/CD:
  ```yaml
  env:
    GITHUB_USERNAME: ${{ github.actor }}
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ```

## 📝 Command Reference

```bash
# Setup
./setup-github-repo.sh      # Complete automated setup

# Verify
./verify-setup.sh           # Check configuration

# Deploy
./deploy-to-github.sh       # Publish to GitHub Packages

# Deploy with env vars (CI/CD)
GITHUB_USERNAME=user GITHUB_TOKEN=token ./deploy-to-github.sh
```

## ✨ Next Steps

1. ✅ Run `./setup-github-repo.sh`
2. ✅ Verify with `./verify-setup.sh`
3. ✅ Deploy with `./deploy-to-github.sh`
4. ✅ Use in your Gradle project

---

**Need help?** Check the detailed guide: `GITHUB_PACKAGES_SETUP.md`