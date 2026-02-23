#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <branch-name>
       $0 --print-completion <bash|zsh>
EOF
}

list_git_branches() {
  git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | sort -u
}

complete_branches() {
  local prefix="${1:-}"

  while IFS= read -r branch; do
    if [[ -z "$prefix" || "$branch" == "$prefix"* ]]; then
      echo "$branch"
    fi
  done < <(list_git_branches)
}

print_branch_suggestions() {
  local prefix="${1:-}"
  local suggestions
  suggestions="$(complete_branches "$prefix" | head -n 10 || true)"

  if [[ -n "$suggestions" ]]; then
    echo "" >&2
    echo "Branch suggestions:" >&2
    echo "$suggestions" >&2
  fi
}

print_completion_script() {
  local shell_name="$1"

  case "$shell_name" in
    bash)
      cat <<'EOF'
_mkworktree_complete() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"

  COMPREPLY=()
  if [[ "$COMP_CWORD" -eq 1 ]]; then
    while IFS= read -r branch; do
      COMPREPLY+=("$branch")
    done < <(mkworktree --complete-branches "$cur")
  fi
}

complete -o nosort -F _mkworktree_complete mkworktree
EOF
      ;;
    zsh)
      cat <<'EOF'
#compdef mkworktree
_mkworktree() {
  local cur
  cur="${words[CURRENT]}"
  local -a branches
  branches=("${(@f)$(mkworktree --complete-branches "$cur")}")
  _describe -t branches 'git branches' branches
}

compdef _mkworktree mkworktree
EOF
      ;;
    *)
      echo "Error: unsupported shell '$shell_name'. Expected bash or zsh." >&2
      return 1
      ;;
  esac
}

parse_args() {
  MODE="run"

  if [[ "$#" -ge 1 && "$1" == "--complete-branches" ]]; then
    MODE="complete-branches"
    BRANCH_PREFIX="${2:-}"
    return 0
  fi

  if [[ "$#" -eq 2 && "$1" == "--print-completion" ]]; then
    MODE="print-completion"
    COMPLETION_SHELL="$2"
    return 0
  fi

  if [[ "$#" -ne 1 ]]; then
    usage
    print_branch_suggestions
    return 1
  fi

  BRANCH_NAME="$1"
  if [[ -z "$BRANCH_NAME" ]]; then
    usage
    print_branch_suggestions
    return 1
  fi
}

compute_worktree_dir() {
  local git_common_dir
  local primary_worktree_root

  git_common_dir="$(git rev-parse --git-common-dir)"
  primary_worktree_root="$(cd "${git_common_dir}/.." && pwd -P)"
  WORKTREE_DIR="${primary_worktree_root}/.worktrees/${BRANCH_NAME}"
}

validate_existing_directory() {
  if [[ ! -d "$WORKTREE_DIR" ]]; then
    return 0
  fi

  if git -C "$WORKTREE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  echo "Error: $WORKTREE_DIR exists but is not a git worktree." >&2
  return 1
}

create_worktree_if_needed() {
  WORKTREE_CREATED=0

  if [[ -d "$WORKTREE_DIR" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$WORKTREE_DIR")"

  if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
  else
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" master
  fi

  WORKTREE_CREATED=1
}

track_with_graphite_if_created() {
  if [[ "$WORKTREE_CREATED" -eq 1 ]]; then
    (
      cd "$WORKTREE_DIR"
      gt track
    )
  fi
}

install_dependencies_if_created() {
  if [[ "$WORKTREE_CREATED" -eq 1 ]]; then
    (
      cd "$WORKTREE_DIR"
      pnpm install --frozen-lockfile --offline
    )
  fi
}

cd_to_worktree() {
  cd "$WORKTREE_DIR"
}

main() {
  parse_args "$@"

  if [[ "$MODE" == "complete-branches" ]]; then
    complete_branches "$BRANCH_PREFIX"
    return 0
  fi

  if [[ "$MODE" == "print-completion" ]]; then
    print_completion_script "$COMPLETION_SHELL"
    return 0
  fi

  compute_worktree_dir
  validate_existing_directory
  create_worktree_if_needed
  track_with_graphite_if_created
  install_dependencies_if_created
  cd_to_worktree
}

main "$@"
