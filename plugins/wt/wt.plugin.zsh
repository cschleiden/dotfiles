#!/usr/bin/env zsh
# wt - Git worktree manager plugin for Oh My Zsh
#
# Commands:
#   wt create <branch> [-c]     Create new branch + worktree, cd into it
#   wt checkout <branch> [-c]   Worktree for existing branch, cd into it
#   wt cd <worktree> [-c]       cd into existing worktree
#   wt list                     List worktrees for current repo
#   wt status                   Interactive TUI dashboard
#   wt delete <worktree>        Remove a worktree

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Sanitize branch name to safe directory name
_wt_sanitize() {
    echo "${1//\//-}"
}

# Get the repo root or fail
# Get the main repo root (works from both the main repo and any worktree)
_wt_repo_root() {
    local toplevel
    toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || return 1

    # Check if we're in a worktree by looking at the .git file
    if [[ -f "${toplevel}/.git" ]]; then
        # This is a worktree — read the main repo's gitdir
        local gitdir
        gitdir=$(sed -n 's/^gitdir: //p' "${toplevel}/.git" 2>/dev/null)
        if [[ -n "$gitdir" ]]; then
            # gitdir points to <main-repo>/.git/worktrees/<name>
            # Resolve to absolute, then go up to the main repo
            local abs_gitdir
            if [[ "$gitdir" == /* ]]; then
                abs_gitdir="$gitdir"
            else
                abs_gitdir="${toplevel}/${gitdir}"
            fi
            # Navigate from .git/worktrees/<name> up to the repo root
            local main_git_dir="${abs_gitdir:h:h:h}"
            echo "$main_git_dir"
            return
        fi
    fi

    echo "$toplevel"
}

# Compute the .worktrees base directory
_wt_base_dir() {
    local root="$1"
    local repo_name="${root:t}"
    echo "${root:h}/${repo_name}.worktrees"
}

# Optionally launch copilot
_wt_maybe_copilot() {
    if [[ "$1" == "true" ]]; then
        copilot --yolo
    fi
}

# ---------------------------------------------------------------------------
# wt create <branch> [-c]
# ---------------------------------------------------------------------------
_wt_create() {
    local branch="" copilot_flag=false
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "-c" ]]; then
            copilot_flag=true
        else
            args+=("$arg")
        fi
    done
    branch="${args[1]}"

    if [[ -z "$branch" ]]; then
        echo "Usage: wt create <branch-name> [-c]" >&2
        return 1
    fi

    local root
    root="$(_wt_repo_root)" || { echo "Error: not in a git repository" >&2; return 1; }

    local base_dir="$(_wt_base_dir "$root")"
    local safe_name="$(_wt_sanitize "$branch")"
    local wt_dir="${base_dir}/${safe_name}"

    if [[ -d "$wt_dir" ]]; then
        echo "Error: worktree directory already exists: $wt_dir" >&2
        return 1
    fi

    mkdir -p "$base_dir"
    git worktree add -b "$branch" "$wt_dir" || return 1

    echo "Created worktree at $wt_dir"
    cd "$wt_dir" || return 1
    _wt_maybe_copilot "$copilot_flag"
}

# ---------------------------------------------------------------------------
# wt checkout <branch> [-c]
# ---------------------------------------------------------------------------
_wt_checkout() {
    local branch="" copilot_flag=false
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "-c" ]]; then
            copilot_flag=true
        else
            args+=("$arg")
        fi
    done
    branch="${args[1]}"

    if [[ -z "$branch" ]]; then
        echo "Usage: wt checkout <branch-name> [-c]" >&2
        return 1
    fi

    local root
    root="$(_wt_repo_root)" || { echo "Error: not in a git repository" >&2; return 1; }

    local base_dir="$(_wt_base_dir "$root")"
    local safe_name="$(_wt_sanitize "$branch")"
    local wt_dir="${base_dir}/${safe_name}"

    if [[ -d "$wt_dir" ]]; then
        echo "Worktree already exists, changing directory."
        cd "$wt_dir" || return 1
        _wt_maybe_copilot "$copilot_flag"
        return 0
    fi

    # Strip remote prefix for local checkout (e.g., origin/feature -> feature)
    local local_branch="$branch"
    if [[ "$branch" == *//* ]]; then
        local_branch="${branch#*/}"
    elif [[ "$branch" == origin/* ]]; then
        local_branch="${branch#origin/}"
    fi

    mkdir -p "$base_dir"
    git worktree add "$wt_dir" "$local_branch" || return 1

    echo "Created worktree at $wt_dir"
    cd "$wt_dir" || return 1
    _wt_maybe_copilot "$copilot_flag"
}

# ---------------------------------------------------------------------------
# wt cd <worktree-name> [-c]
# ---------------------------------------------------------------------------
_wt_cd() {
    local name="" copilot_flag=false
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "-c" ]]; then
            copilot_flag=true
        else
            args+=("$arg")
        fi
    done
    name="${args[1]}"

    if [[ -z "$name" ]]; then
        echo "Usage: wt cd <worktree-name> [-c]" >&2
        return 1
    fi

    local root
    root="$(_wt_repo_root)" || { echo "Error: not in a git repository" >&2; return 1; }

    local base_dir="$(_wt_base_dir "$root")"
    local wt_dir="${base_dir}/${name}"

    if [[ ! -d "$wt_dir" ]]; then
        echo "Error: worktree not found: $wt_dir" >&2
        return 1
    fi

    cd "$wt_dir" || return 1
    _wt_maybe_copilot "$copilot_flag"
}

# ---------------------------------------------------------------------------
# wt list
# ---------------------------------------------------------------------------
_wt_list() {
    local root
    root="$(_wt_repo_root)" || { echo "Error: not in a git repository" >&2; return 1; }

    local base_dir="$(_wt_base_dir "$root")"

    if [[ ! -d "$base_dir" ]]; then
        echo "No worktrees found."
        return 0
    fi

    local dirs=("${base_dir}"/*(N/))
    if (( ${#dirs} == 0 )); then
        echo "No worktrees found."
        return 0
    fi

    local repo_name="${root:t}"
    echo "Worktrees for ${repo_name}:\n"
    for dir in "${dirs[@]}"; do
        local name="${dir:t}"
        local branch=""
        if [[ -f "${dir}/.git" ]]; then
            branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
        fi
        printf "  %-30s %s\n" "$name" "${branch:-(detached)}"
    done
}

# ---------------------------------------------------------------------------
# wt delete <worktree-name>
# ---------------------------------------------------------------------------
_wt_delete() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Usage: wt delete <worktree-name>" >&2
        return 1
    fi

    local root
    root="$(_wt_repo_root)" || { echo "Error: not in a git repository" >&2; return 1; }

    local base_dir="$(_wt_base_dir "$root")"
    local wt_dir="${base_dir}/${name}"

    if [[ ! -d "$wt_dir" ]]; then
        echo "Error: worktree not found: $wt_dir" >&2
        return 1
    fi

    git worktree remove "$wt_dir" || return 1
    echo "Removed worktree: $name"
}

# ---------------------------------------------------------------------------
# wt status - Interactive TUI dashboard
# ---------------------------------------------------------------------------

# Gather/refresh worktree data into the caller's arrays
_wt_status_refresh() {
    local base_dir="$1"
    local repo_root="$2"
    local has_gh=false
    (( $+commands[gh] )) && has_gh=true

    wt_names=()
    wt_branches=()
    wt_statuses=()
    wt_sync=()
    wt_prs=()
    wt_dirs=()

    # Include the main repo checkout first
    local all_dirs=("$repo_root")
    # Then add worktree directories
    if [[ -d "$base_dir" ]]; then
        all_dirs+=("${base_dir}"/*(N/))
    fi

    local name branch dirty sync pr_info changes upstream ahead behind pr_json pr_num pr_state pr_draft
    for dir in "${all_dirs[@]}"; do
        if [[ "$dir" == "$repo_root" ]]; then
            name="${repo_root:t}"
        else
            name="${dir:t}"
        fi
        branch=""
        dirty=""
        sync=""
        pr_info="(no PR)"

        wt_dirs+=("$dir")
        wt_names+=("$name")

        if [[ -e "${dir}/.git" ]]; then
            branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

            # Dirty/clean
            changes=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            if (( changes > 0 )); then
                dirty="● ${changes} dirty"
            else
                dirty="✔ clean"
            fi

            # Ahead/behind
            upstream=$(git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
            if [[ -n "$upstream" ]]; then
                ahead=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
                behind=$(git -C "$dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
                sync="↑${ahead} ↓${behind}"
            else
                sync="(no upstream)"
            fi

            # PR status
            if [[ "$has_gh" == "true" && -n "$branch" ]]; then
                pr_json=$(gh pr list --repo "$(git -C "$dir" remote get-url origin 2>/dev/null)" --head "$branch" --json number,state,isDraft --limit 1 2>/dev/null)
                if [[ -n "$pr_json" && "$pr_json" != "[]" ]]; then
                    pr_num=$(echo "$pr_json" | command grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
                    pr_state=$(echo "$pr_json" | command grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
                    pr_draft=$(echo "$pr_json" | command grep -o '"isDraft":[a-z]*' | head -1 | cut -d: -f2)
                    if [[ "$pr_draft" == "true" ]]; then
                        pr_info="PR #${pr_num} draft"
                    else
                        pr_info="PR #${pr_num} ${pr_state:l}"
                    fi
                fi
            fi
        fi

        wt_branches+=("${branch:-(detached)}")
        wt_statuses+=("$dirty")
        wt_sync+=("$sync")
        wt_prs+=("$pr_info")
    done
}

_wt_status() {
    local root
    root="$(_wt_repo_root)" || { echo "Error: not in a git repository" >&2; return 1; }

    local base_dir="$(_wt_base_dir "$root")"
    local repo_name="${root:t}"

    # Gather data for each worktree (includes main checkout)
    local -a wt_names wt_branches wt_statuses wt_sync wt_prs wt_dirs
    _wt_status_refresh "$base_dir" "$root"

    local count=${#wt_names}
    local selected=1
    local result_action=""
    local result_dir=""
    local key seq confirm

    # Enter alternate screen buffer
    tput smcup 2>/dev/null
    # Hide cursor
    printf '\e[?25l'

    # Cleanup on exit
    trap '_wt_status_cleanup' INT TERM

    while true; do
        # Clear screen
        printf '\e[2J\e[H'

        # Header
        printf '\e[1m  Worktrees for %s\e[0m\n\n' "$repo_name"

        # Rows
        for i in {1..$count}; do
            local prefix="   "
            local fmt="\e[0m"
            if (( i == selected )); then
                prefix=" ▸ "
                fmt="\e[1;36m"  # bold cyan
            fi

            # Color dirty/clean
            local status_color="\e[32m"  # green
            if [[ "${wt_statuses[$i]}" == *dirty* ]]; then
                status_color="\e[33m"  # yellow
            fi

            # Color PR
            local pr_color="\e[90m"  # dim
            if [[ "${wt_prs[$i]}" == *open* ]]; then
                pr_color="\e[32m"  # green
            elif [[ "${wt_prs[$i]}" == *draft* ]]; then
                pr_color="\e[33m"  # yellow
            elif [[ "${wt_prs[$i]}" == *merged* ]]; then
                pr_color="\e[35m"  # magenta
            fi

            printf "${fmt}%s%-22s \e[0;37m%-22s ${status_color}%-12s \e[0;37m%-14s ${pr_color}%s\e[0m\n" \
                "$prefix" "${wt_names[$i]}" "${wt_branches[$i]}" "${wt_statuses[$i]}" "${wt_sync[$i]}" "${wt_prs[$i]}"
        done

        # Status bar
        printf '\n  \e[90m \e[1;37m↑↓\e[0;90m navigate  \e[1;37mEnter\e[0;90m cd  \e[1;37mo\e[0;90m open PR  \e[1;37mp\e[0;90m push  \e[1;37mf\e[0;90m pull  \e[1;37mr\e[0;90m refresh  \e[1;37md\e[0;90m delete  \e[1;37mq\e[0;90m/\e[1;37mEsc\e[0;90m quit \e[0m\n'

        # Read keypress
        key=""
        read -sk 1 key

        case "$key" in
            $'\e')
                # Arrow key or Esc
                seq=""
                read -sk 2 -t 0.1 seq 2>/dev/null
                case "$seq" in
                    '[A') # Up
                        (( selected > 1 )) && (( selected-- ))
                        ;;
                    '[B') # Down
                        (( selected < count )) && (( selected++ ))
                        ;;
                    *)
                        # Plain Esc - quit
                        break
                        ;;
                esac
                ;;
            $'\n'|$'\r')
                # Enter - cd into worktree
                result_action="cd"
                result_dir="${wt_dirs[$selected]}"
                break
                ;;
            'o')
                # Open PR in browser
                if [[ "${wt_prs[$selected]}" != "(no PR)" ]]; then
                    gh pr view "${wt_branches[$selected]}" --web -R "$(git -C "${wt_dirs[$selected]}" remote get-url origin 2>/dev/null)" >/dev/null 2>&1 &!
                fi
                ;;
            'p')
                # Push
                printf '\e[2J\e[H'
                echo "Pushing ${wt_names[$selected]}..."
                git -C "${wt_dirs[$selected]}" push 2>&1
                echo "\nPress any key to continue..."
                read -sk 1
                ;;
            'f')
                # Pull
                printf '\e[2J\e[H'
                echo "Pulling ${wt_names[$selected]}..."
                git -C "${wt_dirs[$selected]}" pull 2>&1
                echo "\nPress any key to continue..."
                read -sk 1
                # Refresh dirty/sync data for this worktree
                local i=$selected
                local dir="${wt_dirs[$i]}"
                local changes
                changes=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                if (( changes > 0 )); then
                    wt_statuses[$i]="● ${changes} dirty"
                else
                    wt_statuses[$i]="✔ clean"
                fi
                local upstream
                upstream=$(git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
                if [[ -n "$upstream" ]]; then
                    local ahead behind
                    ahead=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
                    behind=$(git -C "$dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
                    wt_sync[$i]="↑${ahead} ↓${behind}"
                fi
                ;;
            'd')
                # Delete with confirmation
                printf '\e[2J\e[H'
                printf 'Delete worktree "%s"? [y/N] ' "${wt_names[$selected]}"
                confirm=""
                read -sk 1 confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    git worktree remove "${wt_dirs[$selected]}" 2>&1
                fi
                # Full refresh after delete
                _wt_status_refresh "$base_dir" "$root"
                count=${#wt_names}
                if (( count == 0 )); then
                    break
                fi
                (( selected > count )) && selected=$count
                ;;
            'r')
                # Refresh all data
                _wt_status_refresh "$base_dir" "$root"
                count=${#wt_names}
                if (( count == 0 )); then
                    break
                fi
                (( selected > count )) && selected=$count
                ;;
            'q')
                break
                ;;
        esac
    done

    # Restore terminal
    _wt_status_cleanup

    # Execute deferred action
    if [[ "$result_action" == "cd" && -n "$result_dir" ]]; then
        cd "$result_dir"
    fi
}

_wt_status_cleanup() {
    printf '\e[?25h'              # show cursor
    tput rmcup 2>/dev/null        # leave alternate screen
    trap - INT TERM
}

# ---------------------------------------------------------------------------
# Main dispatcher
# ---------------------------------------------------------------------------
wt() {
    local cmd="$1"
    shift 2>/dev/null

    case "$cmd" in
        cr|cre|crea|creat|create)     _wt_create "$@" ;;
        ch|che|chec|check|checko|checkou|checkout) _wt_checkout "$@" ;;
        cd)                           _wt_cd "$@" ;;
        l|li|lis|list)                _wt_list "$@" ;;
        s|st|sta|stat|statu|status)   _wt_status "$@" ;;
        d|de|del|dele|delet|delete)   _wt_delete "$@" ;;
        *)
            echo "Usage: wt <command> [args]"
            echo ""
            echo "Commands:"
            echo "  create <branch> [-c]     Create new branch + worktree"
            echo "  checkout <branch> [-c]   Worktree for existing branch"
            echo "  cd <worktree> [-c]       cd into existing worktree"
            echo "  list                     List worktrees"
            echo "  status                   Interactive dashboard"
            echo "  delete <worktree>        Remove a worktree"
            echo ""
            echo "Flags:"
            echo "  -c    Launch copilot --yolo after cd"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Completions
# ---------------------------------------------------------------------------

# List worktree directory names for the current repo
_wt_worktree_names() {
    local root base_dir
    root="$(_wt_repo_root)" 2>/dev/null || return
    base_dir="$(_wt_base_dir "$root")"
    [[ -d "$base_dir" ]] || return
    local dirs=("${base_dir}"/*(N/:t))
    compadd -a dirs
}

# List git branch names
_wt_branch_names() {
    local branches
    branches=(${${(f)"$(git branch -a --format='%(refname:short)' 2>/dev/null)"}})
    compadd -a branches
}

_wt() {
    local -a subcommands
    subcommands=(
        'create:Create new branch + worktree'
        'checkout:Worktree for existing branch'
        'cd:cd into existing worktree'
        'list:List worktrees'
        'status:Interactive dashboard'
        'delete:Remove a worktree'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' subcommands
        return
    fi

    case "${words[2]}" in
        create)
            # New branch name - no completion, plus -c flag
            _arguments '1:branch name:' '-c[Launch copilot after cd]'
            ;;
        checkout)
            _arguments '1:branch name:_wt_branch_names' '-c[Launch copilot after cd]'
            ;;
        cd)
            _arguments '1:worktree name:_wt_worktree_names' '-c[Launch copilot after cd]'
            ;;
        delete)
            _arguments '1:worktree name:_wt_worktree_names'
            ;;
    esac
}

compdef _wt wt
