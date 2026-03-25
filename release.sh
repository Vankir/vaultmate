#!/bin/bash

# VaultMate Release Automation Script
# This script automates the release process by:
# 1. Incrementing version in pubspec.yaml
# 2. Committing the version bump
# 3. Creating and pushing a git tag
# 4. Triggering CI/CD pipeline

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [VERSION_TYPE]

Automates the release process for VaultMate.

VERSION_TYPE:
  patch    Increment patch version (x.y.Z)
  minor    Increment minor version (x.Y.0)
  major    Increment major version (X.0.0)
  custom   Specify custom version (will prompt)

Examples:
  $0 patch          # 1.6.4 -> 1.6.5
  $0 minor          # 1.6.4 -> 1.7.0
  $0 major          # 1.6.4 -> 2.0.0
  $0 custom         # Specify exact version

The script will:
  1. Check you're on main branch
  2. Ensure working directory is clean
  3. Increment version in pubspec.yaml
  4. Commit the version bump
  5. Create and push git tag
  6. CI will automatically build and create GitHub release

EOF
    exit 1
}

# Check if version type is provided
if [ $# -eq 0 ]; then
    usage
fi

VERSION_TYPE=$1

# Ensure we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    print_error "You must be on the 'main' branch to create a release."
    print_info "Current branch: $CURRENT_BRANCH"
    print_info "Switch to main: git checkout main"
    exit 1
fi

# Ensure working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    print_error "Working directory is not clean. Commit or stash your changes first."
    git status --short
    exit 1
fi

# Pull latest changes
print_info "Pulling latest changes from origin/main..."
git pull origin main

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')
VERSION_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

print_info "Current version: $VERSION_NUMBER (build $BUILD_NUMBER)"

# Parse semantic version
MAJOR=$(echo $VERSION_NUMBER | cut -d'.' -f1)
MINOR=$(echo $VERSION_NUMBER | cut -d'.' -f2)
PATCH=$(echo $VERSION_NUMBER | cut -d'.' -f3)

# Calculate new version based on type
case $VERSION_TYPE in
    patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
        ;;
    minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="$MAJOR.$NEW_MINOR.0"
        ;;
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION="$NEW_MAJOR.0.0"
        ;;
    custom)
        read -p "Enter new version (e.g., 1.7.0): " NEW_VERSION
        # Validate version format
        if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            print_error "Invalid version format. Use semantic versioning (e.g., 1.7.0)"
            exit 1
        fi
        ;;
    *)
        print_error "Invalid version type: $VERSION_TYPE"
        usage
        ;;
esac

# Increment build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_FULL_VERSION="$NEW_VERSION+$NEW_BUILD_NUMBER"

print_info "New version will be: $NEW_VERSION (build $NEW_BUILD_NUMBER)"

# Confirm with user
read -p "Proceed with release $NEW_VERSION? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warn "Release cancelled."
    exit 0
fi

# Update version in pubspec.yaml
print_info "Updating pubspec.yaml..."
sed -i.bak "s/^version: .*/version: $NEW_FULL_VERSION/" pubspec.yaml
rm pubspec.yaml.bak

# Verify the change
UPDATED_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')
if [ "$UPDATED_VERSION" != "$NEW_FULL_VERSION" ]; then
    print_error "Failed to update version in pubspec.yaml"
    git checkout pubspec.yaml
    exit 1
fi

print_info "Version updated to $NEW_FULL_VERSION"

# Commit the version bump
print_info "Committing version bump..."
git add pubspec.yaml
git commit -m "chore: release $NEW_VERSION"

# Create git tag
TAG_NAME="v$NEW_VERSION"
print_info "Creating tag $TAG_NAME..."
git tag -a "$TAG_NAME" -m "Release $NEW_VERSION"

# Push changes and tag
print_info "Pushing to origin..."
git push origin main
git push origin "$TAG_NAME"

print_info "✅ Release process completed successfully!"
echo ""
print_info "Next steps:"
echo "  1. CI will automatically run tests and build the app bundle"
echo "  2. GitHub Release will be created at: https://github.com/vankir/VaultMate/releases/tag/$TAG_NAME"
echo "  3. Download the unsigned AAB from the release"
echo "  4. Sign it locally with your keystore"
echo "  5. Upload signed AAB to Google Play Console"
echo ""
print_info "Monitor CI progress at: https://github.com/vankir/VaultMate/actions"
