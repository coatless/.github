# .github

The issue and pull request labels shared by [@coatless](https://github.com/coatless)
and the `coatless-*` organizations.

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

Each organization's issue forms apply these labels by name, so run the script
on a repository before its first issue arrives.
