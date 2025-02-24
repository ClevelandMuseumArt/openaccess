#!/bin/bash

set -e  # Exit on error

# Ensure we are in a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: This is not a Git repository."
    exit 1
fi

# Ensure Git LFS is installed
if ! git lfs version >/dev/null 2>&1; then
    echo "Error: Git LFS is not installed."
    exit 1
fi

# Fetch latest changes and prune unreachable objects
git fetch --prune

# Get the last two commit hashes
LATEST_TWO_COMMITS=$(git rev-list --max-count=5 HEAD | tac)
OLDEST_COMMIT=$(echo "$LATEST_TWO_COMMITS" | head -n 1)

echo "Preserving commits starting from: $OLDEST_COMMIT"

# Create a new branch with only the last two commits
git checkout --orphan temp-prune-branch "$OLDEST_COMMIT"
git commit --allow-empty -m "Rewriting history with only the last two commits"

# Cherry-pick the last two commits onto the new branch
echo "$LATEST_TWO_COMMITS" | while read commit; do
    git cherry-pick "$commit" || {
        echo "Conflict detected while cherry-picking $commit. Attempting auto-resolve..."

        # Auto-resolve conflicts by keeping current changes
        git add -A  # Stage all resolved files
        git commit --no-edit --allow-empty-message || {
            echo "Manual intervention required. Resolve conflicts and run 'git cherry-pick --continue'."
            exit 1
        }
    }
done

# Delete the old master branch and replace it
git branch -D master || true  # Delete master if exists
git checkout -b master

# Force push the cleaned branch to overwrite remote history
git push --force origin master

# Cleanup orphaned Git LFS files and history
git lfs prune
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git branch -D temp-prune-branch || true # delete temp-prune-branch

echo "Successfully pruned all but the last two commits."
