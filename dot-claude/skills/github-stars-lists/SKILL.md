---
name: github-stars-lists
description: Use when the user asks to look for projects, repos, or tools they've starred or curated on GitHub — especially their own GitHub Stars lists. Triggers on phrases like "find projects on GitHub", "from my starred repos", "in my AI starred repos list".
user-invocable: false
---

# Pulling repos from GitHub Stars lists

GitHub Stars lists have **no API endpoint** — `gh api` cannot reach them. The
list pages are server-rendered HTML (no JS, no auth needed for public lists),
so scrape them with `curl`.

## The user's lists (franky47)

URL pattern: `https://github.com/stars/franky47/lists/<slug>`

| Display name | Slug |
|---|---|
| Terminal / CLIs | `terminal-clis` |
| AI / Machine Learning | `ai-machine-learning` |
| TypeScript Wizardry | `%EF%B8%8F-typescript-wizardry` |
| Infrastructure | `infrastructure` |
| UI | `ui` |
| Testing | `testing` |
| React | `%EF%B8%8F-react` |
| OSS services | `oss-services` |
| Audio | `audio` |
| Cryptography | `cryptography` |
| A11y | `a11y` |

**Gotcha:** lists whose name starts with an emoji get a slug containing the
URL-encoded emoji bytes (`%EF%B8%8F` is the U+FE0F variation selector). Pass
the slug exactly as encoded above — `react` alone 404s, `%EF%B8%8F-react` works.

To refresh this list if it looks stale (the `%` in the regex is what catches
emoji slugs):

```bash
curl -sL "https://github.com/franky47?tab=stars" \
  | grep -oE 'stars/franky47/lists/[A-Za-z0-9_.%-]+' | sed 's@^@/@' | sort -u
```

## Extract all repos from one list

Handles pagination (`?page=N`, stops when `rel="next"` disappears) and filters
non-repo GitHub paths.

```bash
# Usage: set USER and LIST slug
USER="franky47"; LIST="ai-machine-learning"
base="https://github.com/stars/$USER/lists/$LIST"
page=1
while :; do
  html=$(curl -sL "$base?page=$page")
  repos=$(echo "$html" | grep -oE 'href="/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"' \
    | sed -E 's@href="(.*)"@\1@' \
    | grep -vE '^/(sponsors|orgs|users|topics|collections|stars|settings)/')
  [ -z "$repos" ] && break
  echo "$repos"
  echo "$html" | grep -q 'rel="next"' || break
  page=$((page+1))
done | sed 's@^/@https://github.com/@' | sort -u
```

## All starred repos (the full set, including unlisted)

Starred repos **do** have an API — unlike lists. ~2000 repos, paginated:

```bash
gh api --paginate "users/franky47/starred?per_page=100" --jq '.[].full_name' \
  | sort -uf
```

## Starred repos NOT in any list

Most starred repos belong to no list. Compute the difference: full starred set
minus the union of all list members. Run after the list-discovery script so
slugs are current.

```bash
USER="franky47"
SLUGS="terminal-clis ai-machine-learning %EF%B8%8F-typescript-wizardry \
infrastructure ui testing %EF%B8%8F-react oss-services audio cryptography a11y"

# 1. union of every list's members
: > /tmp/listed.txt
for LIST in $SLUGS; do
  base="https://github.com/stars/$USER/lists/$LIST"; page=1
  while :; do
    html=$(curl -sL "$base?page=$page")
    repos=$(echo "$html" | grep -oE 'href="/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"' \
      | sed -E 's@href="/(.*)"@\1@' \
      | grep -vE '^(sponsors|orgs|users|topics|collections|stars|settings)/')
    [ -z "$repos" ] && break
    echo "$repos" >> /tmp/listed.txt
    echo "$html" | grep -q 'rel="next"' || break
    page=$((page+1))
  done
done
sort -uf /tmp/listed.txt -o /tmp/listed.txt

# 2. full starred set
gh api --paginate "users/$USER/starred?per_page=100" --jq '.[].full_name' \
  | sort -uf > /tmp/starred.txt

# 3. starred minus listed
comm -23 /tmp/starred.txt /tmp/listed.txt
```

`comm` needs both inputs sorted identically — both use `sort -uf` (case-fold),
so keep that consistent or `comm` reports false differences.

## Keyword search across starred repos

To search starred repos by name/description (not enumerate all), GitHub's stars
tab has a server-side `q` param — handy when the user wants e.g. starred repos
matching "auth":

```bash
curl -sL "https://github.com/franky47?tab=stars&q=auth" \
  | grep -oE 'href="/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"' \
  | sed -E 's@href="/(.*)"@\1@' \
  | grep -vE '^(sponsors|orgs|users|topics|collections|stars|settings)/' | sort -u
```

This searches *only* the user's own starred set — narrower and faster than
fetching all ~2000 then filtering.

## Caveats

- HTML scraping breaks if GitHub changes its markup — verify output looks like
  real repo slugs before trusting it.
- The path filter is a denylist; a new GitHub path prefix could slip through.
- A repo card links its repo multiple times — `sort -u` dedupes.
