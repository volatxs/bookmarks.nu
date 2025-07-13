# Bookmarks.nu: bookmarking commands for navigation in Nushell.
# Copyright (C) 2025 Volatus
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along with this program. If not, see
# <https://www.gnu.org/licenses/>.

# Configuration options:
# - $env.nu_bookmarks_dir: where the bookmarks file is stored, defaults to $nu.home-path

alias builtin-save = save
alias builtin-get = get

export-env {
    $env.nu_bookmarks_path = ([($env.nu_bookmarks_dir? | default $nu.home-path), ".bookmarks"] | path join)
    $env._nu_bookmarks_registry = {}
}

def bookmark_names [] {
    $env._nu_bookmarks_registry | transpose name path | builtin-get name
}

def msg [silent: bool, msg: string] {
    if $silent {
        return
    }

    print $"(ansi light_yellow)\(Bookmarks)(ansi reset) ($msg)"
}

def err [msg: string] {
    print --stderr $"(ansi light_yellow)\(Bookmarks)(ansi reset) (ansi light_red)Error(ansi reset): ($msg)"
}

# List bookmarks.
export def list [] {
    if ($env._nu_bookmarks_registry | values | length) == 0 {
        msg false "No bookmarks."
        return null
    }

    $env._nu_bookmarks_registry
}

# Save bookmarks to file.
export def save [
    location?: string, # Path of file to use. If absent, the default is used.
    --silent,          # If passed, info messages are not printed.
] {
    let target_path = ($location | default $env.nu_bookmarks_path) | path expand

    $env._nu_bookmarks_registry | transpose name path | each {|| $"($in.name)::($in.path)"} | builtin-save $target_path --force

    msg $silent $"Bookmarks save to (ansi light_magenta)($target_path)(ansi reset)."
    null
}

# Load bookmarks from file.
export def --env load [
    location?: string, # Path of file to use. If absent, the default is used.
    --silent,          # If passed, info messages are not printed.
] {
    let target_path = ($location | default $env.nu_bookmarks_path) | path expand

    if not ($target_path | path exists) {
        err $"bookmarks file not found at (ansi light_magenta)($target_path)(ansi reset)."
        return null
    }

    let bookmarks_table = open $target_path | lines | each {|| split column "::" name path } | reduce {|elem, acc| $acc | append $elem }

    $env._nu_bookmarks_registry = {}

    for $entry in $bookmarks_table {
        $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | insert $entry.name $entry.path
    }

    msg $silent $"Bookmarks loaded from (ansi light_magenta)($target_path)(ansi reset)."
    null
}

# Create new bookmark.
export def --env create [
    name: string,  # Name of new bookmark.
    path?: string, # Path of new bookmark. If absent, current directory is used.
    --silent,      # If passed, info messages are not printed.
] {
    if ($name | str contains "::") {
        err $"a bookmark name can no contain a '(ansi light_magenta)::(ansi light_red)' (double-colon)."
        return null
    }

    if ($env._nu_bookmarks_registry | builtin-get $name --ignore-errors) != null {
        err $"bookmark (ansi light_magenta)($name)(ansi reset) already exists."
        return null
    }

    let target_path = ($path | default $env.PWD) | path expand

    if not ($target_path | path exists) {
        err $"path (ansi light_magenta)($target_path)(ansi reset) not found."
        return null
    }

    $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | insert $name $target_path

    msg $silent $"Bookmark (ansi light_magenta)($name)(ansi reset) created at (ansi light_magenta)($target_path)(ansi reset)."
    null
}

# Remove bookmarks.
export def --env remove [
    ...names: string@bookmark_names, # Name of bookmarks to remove.
    --silent, # If passed, info messages are not printed.
] {
    for $name in $names {
        if ($env._nu_bookmarks_registry | builtin-get $name --ignore-errors) == null {
            err $"bookmark (ansi light_magenta)($name)(ansi reset) not found."
        } else {
            $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | reject $name
            msg $silent $"Bookmark (ansi light_magenta)($name)(ansi reset) removed."
        }
    }

    null
}

# Get path of bookmark.
export def get [
    name: string@bookmark_names, # Bookmark name.
] {
    let target_directory = ($env._nu_bookmarks_registry | builtin-get $name --ignore-errors)

    if $target_directory == null {
        err $"bookmark (ansi light_magenta)($name)(ansi reset) not found."
        return null
    }

    $target_directory
}

# Go (cd) to bookmark.
export def --env go [
    name: string@bookmark_names, # Bookmark name.
] {
    let target_directory = get $name

    if $target_directory != null {
        cd $target_directory
    }

    null
}

# Rename bookmark.
export def --env rename [
    name: string@bookmark_names, # Old bookmark name.
    new_name: string, # New bookmark name.
    --silent, # If passed, info messages are not printed.
] {
    let bookmark_path = $env._nu_bookmarks_registry | builtin-get $name --ignore-errors

    if bookmark_path == null {
        err $"bookmark (ansi light_magenta)($name)(ansi reset) not found."
        return null
    }

    if ($new_name | str contains "::") {
        err $"a bookmark name can not contain a '(ansi light_magenta)::(ansi reset)' (double-colon)."
        return null
    }

    if ($env._nu_bookmarks_registry | builtin-get $new_name --ignore-errors) != null {
        err $"bookmark (ansi light_magenta)($new_name)(ansi reset) already exists."
        return null
    }

    $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | reject $name | insert $new_name $bookmark_path

    msg $silent $"Bookmark (ansi light_magenta)($name)(ansi reset) renamed to (ansi light_magenta)($new_name)(ansi reset)."
    null
}

# Remove bookmarks with invalid paths.
export def --env clear [
    --list,   # List removed bookmarks.
    --paths,  # Show paths of removed bookmarks (does nothing without --list).
    --silent, # If passed, info messages are not printed.
] {
    mut filtered_registry = $env._nu_bookmarks_registry
    mut removal_count = 0

    for $bookmark in ($env._nu_bookmarks_registry | transpose name path) {
        if ($bookmark.path | path exists) {
            continue
        }

        if $list {
            if $paths {
                msg $silent $"Bookmark (ansi light_magenta)($bookmark.name)(ansi reset) with path (ansi light_magenta)($bookmark.path)(ansi reset) removed."
            } else {
                msg $silent $"Bookmark (ansi light_magenta)($bookmark.name)(ansi reset) removed."
            }
        }

        $filtered_registry = $filtered_registry | reject $bookmark.name
        $removal_count += 1
    }

    $env._nu_bookmarks_registry = $filtered_registry

    msg $silent $"Cleared (ansi light_magenta)($removal_count)(ansi reset) bookmarks with invalid paths."
    null
}

# Find bookmarks pointing to path.
export def find [
    path?: string, # Path to look for. If absent, current directory is used.
] {
    let target_path = ($path | default $env.PWD) | path expand

    if not ($target_path | path exists) {
        err $"path (ansi light_magenta)($target_path)(ansi reset) not found."
        return null
    }

    mut path_list = []

    for $bookmark in ($env._nu_bookmarks_registry | transpose name path) {
        if $bookmark.path == $target_path {
            $path_list = $path_list | append $bookmark.name
        }
    }

    if ($path_list | length) == 0 {
        msg false $"No bookmark points to (ansi light_magenta)($target_path)(ansi reset)."
    } else {
        msg false $"Bookmarks to (ansi light_magenta)($target_path)(ansi reset) \(total of (ansi light_magenta)($path_list | length)(ansi reset)):"

        for path in $path_list {
            print (["- ", $path] | str join)
        }
    }

    null
}

# Change bookmark's path.
export def --env change [
    name: string@bookmark_names, # Bookmark's name.
    new_path: string, # New path for bookmark.
    --silent, # If passed, info messages are not printed.
] {
    if ($env._nu_bookmarks_registry | builtin-get $name --ignore-errors) == null {
        err $"bookmark (ansi light_magenta)($name)(ansi reset) not found."
        return null
    }

    let target_path = $new_path | path expand

    if not ($target_path | path exists) {
        err $"path (ansi light_magenta)($target_path)(ansi reset) not found."
        return null
    }

    $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | update $name $target_path

    msg $silent $"Bookmark path of (ansi light_magenta)($name)(ansi reset) changed to (ansi light_mangeta)($target_path)(ansi reset)."
    null
}
