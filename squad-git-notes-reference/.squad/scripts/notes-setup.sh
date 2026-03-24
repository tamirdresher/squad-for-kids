#!/usr/bin/env bash
# .squad/scripts/notes-setup.sh
# One-time setup for new team members. Run once after cloning.
# Configures git to fetch squad notes automatically.
#
# Usage: bash .squad/scripts/notes-setup.sh
# Safe to run multiple times — idempotent.

set -e
set -o pipefail

# Must be run from inside the repo
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: Not inside a git repository. Run from the repo root."
  exit 1
}
cd "$REPO_ROOT"

echo ""
echo "=== Squad Notes Setup ==="
echo ""

# 1. Add notes refspec to .git/config (not global — this is repo-specific)
REFSPEC="refs/notes/*:refs/notes/*"
if git config --get-all remote.origin.fetch | grep -qF "$REFSPEC"; then
  echo "✓ Notes refspec already configured in .git/config"
else
  git config --add remote.origin.fetch "$REFSPEC"
  echo "✓ Added notes refspec to .git/config"
fi

# 2. Fetch squad notes
echo ""
echo "Fetching squad notes from origin..."
git fetch origin 'refs/notes/*:refs/notes/*'
echo "✓ Fetched squad notes"

# 3. Show what's available
echo ""
echo "Available squad namespaces:"
for ns in data worf belanna picard q scribe ralph; do
  COUNT=$(git notes --ref="squad/$ns" list 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    echo "  refs/notes/squad/$ns  ($COUNT commits annotated)"
  else
    echo "  refs/notes/squad/$ns  (empty or not yet created)"
  fi
done

echo ""
echo "=== Setup complete ==="
echo ""
echo "Read notes for a commit:"
echo "  git notes --ref=squad/data show <commit-sha>"
echo ""
echo "Read all squad notes for a commit:"
echo "  for ns in data worf belanna picard q scribe ralph; do"
echo "    echo \"=== squad/\$ns ===\""
echo "    git notes --ref=\"squad/\$ns\" show <commit-sha> 2>/dev/null || true"
echo "  done"
echo ""
echo "Future git fetches will automatically include squad notes."
