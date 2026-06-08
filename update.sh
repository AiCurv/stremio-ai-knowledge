#!/usr/bin/env bash
#
# update.sh — Auto-update script for the Stremio AI Knowledge Base
#
# Usage:
#   ./update.sh              # Update all timestamps and push
#   ./update.sh --no-push    # Update timestamps without pushing
#   ./update.sh --dry-run    # Show what would be updated without making changes
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TODAY="$(date +%Y-%m-%d)"
COMMIT_MSG="chore: update knowledge base — ${TODAY}"
NO_PUSH=false
DRY_RUN=false

# ─── Parse Arguments ─────────────────────────────────────────────────

for arg in "$@"; do
    case "$arg" in
        --no-push)  NO_PUSH=true ;;
        --dry-run)  DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [--no-push] [--dry-run] [--help]"
            echo ""
            echo "  --no-push   Update timestamps but don't push to GitHub"
            echo "  --dry-run   Show what would be updated without making changes"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

echo "=== Stremio AI Knowledge Base Updater ==="
echo "Date: ${TODAY}"
echo "Repo: ${REPO_DIR}"
echo ""

# ─── Helper Functions ────────────────────────────────────────────────

update_json_field() {
    local file="$1"
    local field="$2"
    local value="$3"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would update ${file}: ${field} → ${value}"
        return
    fi

    # Use python for reliable JSON manipulation
    python3 -c "
import json
with open('${file}', 'r') as f:
    data = json.load(f)
${field} = '${value}'
with open('${file}', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
    echo "  ✓ Updated ${file}: ${field} → ${value}"
}

update_md_timestamp() {
    local file="$1"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would update ${file}: timestamp → ${TODAY}"
        return
    fi

    # Replace the last updated date in the markdown file
    if [ -f "${file}" ]; then
        sed -i "s/\*Last updated: [0-9-]\+\*/\*Last updated: ${TODAY}\*/" "${file}"
        echo "  ✓ Updated ${file}: timestamp → ${TODAY}"
    else
        echo "  ⚠ File not found: ${file}"
    fi
}

# ─── Step 1: Update agent-index.json ────────────────────────────────

echo "Step 1: Updating agent-index.json..."
update_json_field "${REPO_DIR}/agent-index.json" "data['meta']['updated']" "${TODAY}"
echo ""

# ─── Step 2: Update Markdown file timestamps ─────────────────────────

echo "Step 2: Updating markdown timestamps..."
update_md_timestamp "${REPO_DIR}/KNOWLEDGE_BASE.md"
update_md_timestamp "${REPO_DIR}/ERRORS_DB.md"
update_md_timestamp "${REPO_DIR}/SITE_PATTERNS.md"
update_md_timestamp "${REPO_DIR}/AGENT_GUIDE.md"
update_md_timestamp "${REPO_DIR}/AI_AGENT_PROMPT.md"
update_md_timestamp "${REPO_DIR}/README.md"
echo ""

# ─── Step 3: Validate JSON ───────────────────────────────────────────

echo "Step 3: Validating agent-index.json..."
if python3 -c "import json; json.load(open('${REPO_DIR}/agent-index.json'))" 2>/dev/null; then
    echo "  ✓ agent-index.json is valid JSON"
else
    echo "  ✗ agent-index.json has JSON errors — please fix before pushing"
    exit 1
fi
echo ""

# ─── Step 4: Check for uncommitted changes ───────────────────────────

echo "Step 4: Checking git status..."
cd "${REPO_DIR}"

if git diff --quiet && git diff --cached --quiet; then
    echo "  No changes to commit."
else
    echo "  Changes detected:"
    git diff --stat
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would commit with message: ${COMMIT_MSG}"
    else
        git add -A
        git commit -m "${COMMIT_MSG}"
        echo "  ✓ Committed: ${COMMIT_MSG}"
    fi
fi
echo ""

# ─── Step 5: Push to GitHub ─────────────────────────────────────────

if [ "$NO_PUSH" = false ] && [ "$DRY_RUN" = false ]; then
    echo "Step 5: Pushing to GitHub..."
    git push origin main
    echo "  ✓ Pushed to origin/main"
elif [ "$NO_PUSH" = true ]; then
    echo "Step 5: Skipping push (--no-push)"
elif [ "$DRY_RUN" = true ]; then
    echo "Step 5: [DRY RUN] Would push to origin/main"
fi
echo ""

# ─── Done ────────────────────────────────────────────────────────────

echo "=== Update Complete ==="
echo "Knowledge base updated for ${TODAY}"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git diff HEAD~1"
echo "  2. Test locally if needed"
echo "  3. Push if not already done: git push origin main"
