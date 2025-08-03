#!/bin/bash
set -e

# Get the latest tag
last_tag=$(git tag --sort=-v:refname | head -n 1)

if [ -z "$last_tag" ]; then
  echo "No tags found, creating the first v0.1.0"
  new_tag="v0.1.0"
else
  echo "Latest tag: $last_tag"

  # Remove prefix v (if present)
  version=${last_tag#v}

  # Split into parts
  IFS='.' read -r major minor patch <<< "$version"

  # Increment patch
  patch=$((patch + 1))

  # Build new tag
  new_tag="v${major}.${minor}.${patch}"
fi

echo "Creating tag: $new_tag"

# Create and push the tag
git tag "$new_tag"
git push origin "$new_tag"
