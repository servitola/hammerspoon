#!/bin/zsh
# Rebuild .reference/ — everything written about Hammerspoon, local and greppable.
#   zsh fork/fetch-reference.sh
#
# api/ is generated from THIS checkout, not downloaded: hammerspoon.org documents the last
# release, while the code here is master plus our patches, and the two disagree whenever a
# signature changes between releases.
set -euo pipefail

root=${0:a:h:h}
ref=$root/.reference
cd "$root"

mkdir -p .git/info
# DerivedData/ is where the hammerspoon-sync job builds in this same checkout.
for ignored in /.reference/ /DerivedData/; do
  grep -qxF "$ignored" .git/info/exclude 2>/dev/null || print "$ignored" >> .git/info/exclude
done
rm -rf "$ref"
mkdir -p "$ref"

# The same dirs scripts/build.sh lints and documents (DOCS_SEARCH_DIRS).
docs_dirs=(Hammerspoon extensions/)
docs() { uv run --quiet --with-requirements requirements.txt python3 scripts/docs/bin/build_docs.py "$@"; }
docs -l -o "$ref" "${docs_dirs[@]}"
mkdir -p "$ref/api"
docs -o "$ref/api" --json --markdown --html "${docs_dirs[@]}"

clone() { git clone --quiet --depth 1 "$1" "$ref/$2" && rm -rf "$ref/$2/.git"; }
clone https://github.com/Hammerspoon/hammerspoon.github.io.git site
clone https://github.com/Hammerspoon/hammerspoon.wiki.git wiki
clone https://github.com/Hammerspoon/Spoons.git spoons
# site/docs/ is the API reference of every release since 0.9 (645 MB, 247 copies); api/ above
# replaces it. The Spoons zips are build products of spoons/Source.
rm -rf "$ref/site/docs" "$ref/spoons/Spoons"

gh issue list -R Hammerspoon/hammerspoon --state open --limit 2000 \
  --json number,title,labels,createdAt,updatedAt,body,url > "$ref/issues-open.json"
gh pr list -R Hammerspoon/hammerspoon --state open --limit 500 \
  --json number,title,author,createdAt,updatedAt,body,url,headRefName > "$ref/prs-open.json"

{
  print "Fetched $(date '+%F %T') from $(git rev-parse --short HEAD) ($(git describe --tags --always))"
  print "issues: $(jq length "$ref/issues-open.json"), PRs: $(jq length "$ref/prs-open.json")"
} > "$ref/FETCHED"
cat "$ref/FETCHED"
