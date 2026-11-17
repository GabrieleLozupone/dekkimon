#!/usr/bin/env bash
# Merge chiaki-ng into a new branch and report what needs a human.
#
#   scripts/dev/merge-upstream.sh [upstream-ref] [base-branch]
#
#   upstream-ref  what to merge (default: upstream/main; a tag such as v1.11.0 also works)
#   base-branch   branch to start from (default: main)
#
# Creates the branch upstream-merge-<date> from the base branch and merges upstream into it.
# Changes to paths listed in scripts/dev/upstream-removed.txt are dropped automatically
# (Dekkimon removed them on purpose). The script never pushes anything, and the base branch is
# never modified. See docs/upstream.md.
set -euo pipefail

UPSTREAM_URL="https://github.com/chiaki-ng/chiaki-ng.git"
REF="${1:-upstream/main}"
BASE="${2:-main}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
REMOVED_LIST="scripts/dev/upstream-removed.txt"

die() { echo "error: $*" >&2; exit 1; }

[ -z "$(git status --porcelain --untracked-files=no)" ] || die "commit or stash your changes first"

if ! git remote get-url upstream >/dev/null 2>&1; then
    echo "Adding remote 'upstream' -> $UPSTREAM_URL"
    git remote add upstream "$UPSTREAM_URL"
fi
# Never push to chiaki-ng by accident.
git remote set-url --push upstream DISABLED-never-push-to-chiaki-ng

echo "Fetching upstream..."
git fetch --quiet upstream --tags
git rev-parse --verify --quiet "$REF^{commit}" >/dev/null || die "unknown upstream ref: $REF"

if git merge-base --is-ancestor "$REF" "$BASE"; then
    echo "Nothing to do: $BASE already contains $REF."
    exit 0
fi

BRANCH="upstream-merge-$(date +%Y%m%d)"
n=2
while git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; do
    BRANCH="upstream-merge-$(date +%Y%m%d)-$n"; n=$((n + 1))
done
git switch --quiet -c "$BRANCH" "$BASE"
echo "Created branch $BRANCH from $BASE"
echo
echo "Upstream commits being merged:"
git log --oneline --no-merges "$BASE..$REF" | sed 's/^/  /' | head -50
total=$(git rev-list --count --no-merges "$BASE..$REF")
[ "$total" -gt 50 ] && echo "  ... and $((total - 50)) more"
echo

git merge --no-ff --no-commit "$REF" >/dev/null 2>&1 || true

# Drop upstream changes to the paths Dekkimon removed (modify/delete conflicts and new files).
mapfile -t patterns < <(grep -v -e '^#' -e '^[[:space:]]*$' "$REMOVED_LIST" | sed 's/^/:(glob)/')
dropped=""
while IFS= read -r p; do
    # Only paths the base branch doesn't have; a file Dekkimon still ships is never dropped.
    git cat-file -e "$BASE:$p" 2>/dev/null && continue
    dropped+="$p"$'\n'
done < <(git ls-files --cached -- "${patterns[@]}" | sort -u)
if [ -n "$dropped" ]; then
    printf '%s' "$dropped" | while IFS= read -r p; do
        git rm -q --cached --ignore-unmatch -- "$p"
        rm -f -- "$p"
        rmdir -p -- "$(dirname -- "$p")" 2>/dev/null || true
    done
    echo "Dropped $(printf '%s' "$dropped" | wc -l) upstream path(s) that Dekkimon removed (see $REMOVED_LIST)."
fi

conflicts=$(git diff --name-only --diff-filter=U)
if [ -z "$conflicts" ]; then
    git commit --quiet -m "Merge chiaki-ng $(git describe --tags --always "$REF") into Dekkimon"
    echo "Merged without conflicts and committed on $BRANCH."
else
    echo "CONFLICTS to resolve by hand ($(echo "$conflicts" | wc -l)):"
    echo "$conflicts" | while IFS= read -r f; do
        printf '  %-60s %s\n' "$f" "$(git status --porcelain -- "$f" | cut -c1-2)"
    done
    echo
    echo "Resolve each file, then: git add <file> ... && git commit"
    echo "To give up: git merge --abort && git switch $BASE && git branch -D $BRANCH"
fi
echo
echo "Next: build in the SteamOS container, run the unit and GUI smoke tests (docs/building.md),"
echo "then merge $BRANCH into $BASE."
