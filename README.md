# .github

The issue and pull request labels shared by [@coatless](https://github.com/coatless)
and the `coatless-*` organizations, and the GitHub specific template files for
@coatless's own repositories.

| Path | Purpose |
|------|---------|
| `labels.json`, `tools/sync-labels.sh` | The labels, and the script that puts them on a repository |
| `.github/ISSUE_TEMPLATE/` | The bug report and feature request forms |
| `.github/PULL_REQUEST_TEMPLATE.md` | The pull request checklist |
| `SECURITY.md` | The way to report a vulnerability |

The template files reach every repository of @coatless that has no copy of its
own. A repository with any file in its own `.github/ISSUE_TEMPLATE/` uses none
of the forms here. Each `coatless-*` organization keeps its own template files
in its own `.github` repository.

## Labels

A prefix says what a label records:

| Prefix | Records | Labels |
|--------|---------|--------|
| `t:` | The type of issue | `bug`, `chore`, `discussion`, `documentation`, `enhancement`, `feature-request`, `question`, `upstream` |
| `s:` | Its status | `triage-needed`, `confirmed`, `can't reproduce`, `needs information`, `duplicate`, `won't do/fix`, `question-needs-answer`, `question-answered` |
| `p:` | Its priority | `critical`, `high`, `medium`, `low` |

`good first issue` and `help wanted` keep GitHub's names.

`labels.json` holds the labels, and `tools/sync-labels.sh` brings an account's
repositories to them with the [GitHub CLI](https://cli.github.com) and `jq`:

```sh
tools/sync-labels.sh coatless-rpkg              # every repository of the organization
tools/sync-labels.sh coatless-rpkg searcher     # only the repositories named
tools/sync-labels.sh --dry-run coatless         # print the changes, make none
```

A new repository starts with GitHub's default labels. The script renames the
ones that have a counterpart here (`bug` becomes `t: bug`), so issues keep
their labels, and deletes a retired label only when nothing carries it. A
label that `labels.json` does not name is left alone, and so are forks and
archived repositories.

The issue forms apply these labels by name, so run the script on a repository
before its first issue arrives.
