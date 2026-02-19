# wt — Git Worktree Manager

An Oh My Zsh plugin for managing git worktrees with an opinionated directory layout and optional [Copilot CLI](https://githubnext.com/projects/copilot-cli) integration.

## Directory Layout

For a repo at `~/repos/my-repo`, worktrees are created under:

```
~/repos/my-repo.worktrees/
├── cschleiden-foo/      # branch: cschleiden/foo
├── fix-auth-bug/        # branch: fix/auth-bug
└── main-hotfix/         # branch: main-hotfix
```

Branch names are automatically sanitized to safe directory names (`/` → `-`).

## Commands

All commands support short prefixes (e.g., `wt s` for `wt status`).

### `wt create <branch> [-c]`

Create a new branch and worktree, then cd into it.

```sh
$ wt create cschleiden/my-feature
Created worktree at ~/repos/my-repo.worktrees/cschleiden-my-feature

# With Copilot CLI:
$ wt create cschleiden/my-feature -c
```

### `wt checkout <branch> [-c]`

Create a worktree for an existing branch, then cd into it.

```sh
$ wt checkout origin/fix/auth-bug
Created worktree at ~/repos/my-repo.worktrees/fix-auth-bug

# If the worktree already exists, just cd into it:
$ wt checkout fix/auth-bug
Worktree already exists, changing directory.
```

### `wt cd <worktree> [-c]`

Change into an existing worktree directory.

```sh
$ wt cd cschleiden-my-feature

# With Copilot CLI:
$ wt cd cschleiden-my-feature -c
```

### `wt list`

List all worktrees for the current repo.

```sh
$ wt l
Worktrees for my-repo:

  cschleiden-my-feature          cschleiden/my-feature
  fix-auth-bug                   fix/auth-bug
```

### `wt status`

Interactive TUI dashboard showing all checkouts (including the main repo) with git status, sync info, and GitHub PR status.
Expensive columns are loaded asynchronously, so the view appears immediately and fills in as data is ready.

```
  Worktrees for my-repo

  ▸ my-repo              main             ✔ clean    ↑0 ↓0    (no PR)
    cschleiden-foo       cschleiden/foo   ✔ clean    ↑2 ↓0    PR #42 open
    fix-auth-bug         fix/auth-bug     ● 3 dirty  ↑0 ↓5    PR #87 draft

  ↑↓ navigate  Enter cd  o open PR  p push  f pull  r refresh  d delete  q/Esc quit
```

**Keybindings:**

| Key       | Action                              |
|-----------|-------------------------------------|
| `↑` / `↓` | Move row selection                 |
| `Enter`   | cd into selected worktree          |
| `o`       | Open PR in browser (requires `gh`) |
| `p`       | Git push from selected worktree    |
| `f`       | Git pull in selected worktree      |
| `r`       | Refresh all data                   |
| `d`       | Delete worktree (with confirmation + live progress)|
| `q` / `Esc` | Quit dashboard                  |

### `wt delete <worktree>`

Remove a worktree.
While deletion is running, `wt` shows live progress in the terminal.

```sh
$ wt d cschleiden-my-feature
Removed worktree: cschleiden-my-feature
```

## Flags

| Flag | Description |
|------|-------------|
| `-c` | Launch `copilot --yolo` after changing into the worktree. Available on `create`, `checkout`, and `cd`. |

## Tab Completion

The plugin provides context-aware completions:

- **Subcommands** — `wt <TAB>` completes command names
- **`wt checkout`** — completes from local and remote branch names
- **`wt cd`** / **`wt delete`** — completes from existing worktree directory names

## Requirements

- **git** with worktree support (2.5+)
- **Oh My Zsh**
- **`gh` CLI** (optional) — for PR status in `wt status` and `o` to open PRs

## Installation

The `install` script in this dotfiles repo automatically symlinks the plugin into `~/.oh-my-zsh/custom/plugins/wt` and adds `wt` to your `.zshrc` plugins list.

To install manually:

```sh
ln -s /path/to/dotfiles/plugins/wt ~/.oh-my-zsh/custom/plugins/wt
```

Then add `wt` to your plugins in `~/.zshrc`:

```sh
plugins=(git wt)
```
