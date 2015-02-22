#
#  vcsstatus.sh
#
#    Output:
#      vcs_name  : The vcs name string.
#      action    : Action name string. (No action : 0)
#      branch    : Branch name string.
#      ahead     : Ahead count. (No ahead : 0)
#      behind    : Behind count. (No behind : 0)
#      staged    : Staged count. (No staged : 0)
#      conflicts : Conflicts count. (No conflicts : 0)
#      unstaged  : Unstaged count. (No unstaged : 0)
#      untracked : Untracked count.(No untracked : 0)
#      stashed   : Stashed count.(No stashed : 0)
#      clean     : Clean flag. (Clean is 1, Not clean is 0, Unknown is ?)
#      unmerged  : Unmerged commits count. (No unmerged commits : 0)
#

## VCS_INFO configurations.
#  http://zsh.sourceforge.net/Doc/Release/User-Contributions.html#SEC273
#  https://github.com/olivierverdier/zsh-git-prompt
#  http://d.hatena.ne.jp/mollifier/20100906/p1
#  http://d.hatena.ne.jp/yuroyoro/20110219/1298089409
#  http://d.hatena.ne.jp/pasela/20110216/git_not_pushed
#  http://liosk.blog103.fc2.com/blog-entry-209.html
#  http://qiita.com/items/8d5a627d773758dd8078
if ! type vcs_info > /dev/null 2>&1; then
    autoload -Uz vcs_info || return 1
fi
zstyle ':vcs_info:*' enable git svn hg bzr

# Specify the command path to git used by VCS_INFO.
zstyle ':vcs_info:git:*:-all-' command =git

# The maximum number of vcs_info_msg_*_ variables.
zstyle ':vcs_info:*' max-exports 5

# To be enable check-for-changes with hg.
zstyle ':vcs_info:hg:*' get-revision true
#zstyle ':vcs_info:hg*:*' 'check-for-changes' true
zstyle ':vcs_info:(git|hg|bzr):*' use-simple true
#zstyle ':vcs_info:hg*' actionformats "(%s|%a)[%i%u %b %m]"

## Set formats.
#
# Escape string.
# In normal formats and actionformats the following replacements are done:
#   %s : The VCS in use (git, hg, svn, etc.).
#   %b : Information about the current branch.
#   %a : An identifier that describes the action. Only makes sense in actionformats.
#   %r : The repository name. If %R is /foo/bar/repoXY, %r is repoXY.
#   %c : The string from the stagedstr style if there are staged changes in the repository.
#   %u : The string from the unstagedstr style if there are unstaged changes in the repository.
#
# Put the data into vcs_info_msg_*_ variables.
zstyle ':vcs_info:*' formats '%s' '%b' '%m'
zstyle ':vcs_info:*' actionformats '%s' '%b' '%m' '%a'

zstyle ':vcs_info:(git|hg):*' check-for-changes false
#zstyle ':vcs_info:git:*' 'check-for-changes' false


# Check zsh version.
if ! type is-at-least > /dev/null 2>&1; then
    autoload -Uz is-at-least
fi
if is-at-least 4.3.11; then
    # Register the hook function.
    zstyle ':vcs_info:git+set-message:*' hooks git-hook-detail-info
fi

function _zsh_vcs_prompt_vcs_detail_info() {
	local vcs_name
	local vcs_branch_name
	local vcs_action=0
	local git_status
	
	# Run vcs_info.
	psvar=()
	LANG=en_US.UTF-8 vcs_info
	if [ -z "$vcs_info_msg_0_" ]; then
		return 0
	fi
	
	vcs_name=$vcs_info_msg_0_
	vcs_branch_name=$vcs_info_msg_1_
	vcs_action=${vcs_info_msg_3_:-$vcs_action}
	
	# Get git status.
	if is-at-least 4.3.11; then
		if [ "$vcs_name" = 'git' ]; then
			git_status=$vcs_info_msg_2_
		else
			if [ "$vcs_name" = 'hg' ]; then
				vcs_branch_name=$(hg prompt '{branch}')
				git_status=$(_zsh_vcs_prompt_get_hg_status)
			fi
		fi
	else
	
		if [ "$vcs_name" = 'git' ]; then
			git_status=$(_zsh_vcs_prompt_get_git_status "$vcs_branch_name")
		fi
	fi
	
	# Output result.
	echo "$vcs_name\n$vcs_action\n$vcs_branch_name\n$git_status"
}

# The hook function.
# If return the value except 0, subsequent hook functions is not called.
function +vi-git-hook-detail-info() {
    # Execute only when vcs_info_msg_2_.
    if [ "$1" != '2' ]; then
        return 0
    fi
    local git_status
    git_status=$(_zsh_vcs_prompt_get_git_status "$hook_com[branch]")
    hook_com[misc]+=$git_status
    return 0
}

function _zsh_vcs_prompt_get_hg_status() {
	local ahead=0
	local behind=0
	local staged=0
	local conflicts=0
	local unstaged=0
	local untracked=0
	local stashed=0
	local clean=0
	local unmerged=0

	# Get information
	local output="$(command hg summary --remote)"
	local commit_line="$(echo $output | grep commit)"
	local remote_line="$(echo $output | grep remote)"

	local synced=0
	local offline=0

	clean="$(echo "$commit_line" | grep clean)"

	if [ -z "$clean" ]; then
		clean=0
		if [ -n "$(echo $commit_line | grep modified)" ]; then
			unstaged="$(echo $commit_line | sed 's/.modified.*//' | sed 's/.* //')"
		fi

		if [ -n "$(echo $commit_line | grep added)" ]; then
			staged="$(echo $commit_line | sed 's/.added.*//' | sed 's/.* //')"
		fi

		if [ -n "$(echo $commit_line | grep unkwnon)" ]; then
			untracked="$(echo $commit_line | sed 's/.unknown.*//' | sed 's/.* //')"
		fi
	else
		clean=1
	fi
	
	synced="$(echo $remote_line | grep synced)"
	offline="$(echo $remote_line | grep resolve)"

	if [ -z "$synced" ] && [ -z "$offline" ]; then
		behind="$(echo $remote_line | sed 's/.or.more.incoming.*//' | sed '/.* //')"
		if [ "$behind" = 'unknown' ]; then
			behind=0
		else
			behind="$(hg incoming | command grep -c changeset)"
		fi

		ahead="$(echo $remote_line | sed 's/.outgoing.*//' | sed 's/.* //')"
		if [ "$ahead" = 'unknown' ]; then
			ahead=0
		fi
	fi
	# Output result
	echo "$ahead\n$behind\n$staged\n$conflicts\n$unstaged\n$untracked\n$stashed\n$clean\n$unmerged"
}


# $1 : Branch name.
function _zsh_vcs_prompt_get_git_status() {
    local branch_name=$1
    # Define variables for git status.
    local ahead=0
    local behind=0
    local staged=0
    local conflicts=0
    local unstaged=0
    local untracked=0
    local stashed=0
    local clean=0
    local unmerged=0

    # Get changed files and stash list.
    local staged_files
    local unstaged_files
    local untracked_files
    local stash_list
    local is_inside_work_tree

    if [ "$(command git rev-parse --is-inside-work-tree 2> /dev/null)" = 'true' ]; then
        is_inside_work_tree='true'
        staged_files=$(command git diff --staged --name-status)
        if [ $? -ne 0 ]; then
            # Error occurs on old version git.
            staged_files=$(command git status --short --porcelain | command grep '^[UMADRC]')
        fi
        unstaged_files=$(command git diff --name-status)
        untracked_files=$(command git ls-files --others --exclude-standard "$(command git rev-parse --show-toplevel)")
        if [ $? -ne 0 ]; then
	    #TODO: When branch name is same as file name in repo, I get an
	    #error here, as script tries to enter the directory. This quick and
	    #dirty workaround checks if file is a directory before entering -
	    #but that is of course not the solution. I have to investigate this
	    #further!
	    if [ -d $1 ]; then
		untracked_files=$(cd "$1" > /dev/null && command git ls-files --others --exclude-standard)
	    fi
        fi
        stash_list=$(command git stash list)
    else
        clean='?'
    fi

    # Count staged and conflicts files.
    if [ -n "$staged_files" ];then
        conflicts=$(echo "$staged_files" | sed '/^[^U]/d' | wc -l | tr -d ' ')

        staged=$(echo "$staged_files" | wc -l | tr -d ' ')
        staged=$(($staged - $conflicts))
    fi

    # Count unstaged files.
    if [ -n "$unstaged_files" ]; then
        unstaged=$(echo "$unstaged_files" | sed '/^U/d' | wc -l | tr -d ' ')
    fi

    # Count untracked files.
    if [ -n "$untracked_files" ]; then
        untracked=$(echo "$untracked_files" | wc -l | tr -d ' ')
    fi

    # Count commits not pushed.
    local tracking_branch=$(command git for-each-ref --format='%(upstream:short)' \
        "$(command git symbolic-ref -q HEAD)" 2> /dev/null)
    if [ -n "$tracking_branch" ]; then
        local -a behind_ahead
        behind_ahead=($(command git rev-list --left-right --count "$tracking_branch"...HEAD))
        if [ -n "$behind_ahead" ]; then
            behind=${behind_ahead[1]}
            ahead=${behind_ahead[2]}
        else
            # If the option --count is unsupported.
            local behind_ahead_lines
            behind_ahead_lines=$(command git rev-list --left-right "$tracking_branch"...HEAD)
            if [ -n "$behind_ahead_lines" ]; then
                local behead
                behead=$(echo "$behind_ahead_lines" | wc -l | tr -d ' ')
                ahead=$(echo "$behind_ahead_lines" | sed  '/^[^>]/d' | wc -l | tr -d ' ')
                behind=$((behead - ahead))
            fi
        fi
    fi

    # Count stash.
    if [ -n "$stash_list" ]; then
        stashed=$(echo "$stash_list" | wc -l | tr -d ' ')
    fi

    # Check clean.
    if [ "$is_inside_work_tree" = 'true' ]; then
        if (($staged + $unstaged + $untracked + $conflicts == 0)); then
            clean=1
        fi
    fi

    # Count unmerged commits.
    if [ -n "$ZSH_VCS_PROMPT_MERGE_BRANCH" -a "$branch_name" != "$ZSH_VCS_PROMPT_MERGE_BRANCH" ]; then
        unmerged=$(command git rev-list "$ZSH_VCS_PROMPT_MERGE_BRANCH".."${branch_name%'...'}" | wc -l | tr -d ' ')
    fi

    # Output result.
    echo "$ahead\n$behind\n$staged\n$conflicts\n$unstaged\n$untracked\n$stashed\n$clean\n$unmerged"
}

# vim: ft=zsh

