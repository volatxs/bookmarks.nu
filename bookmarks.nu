# Configuration options:
# - $env.nu_bookmarks_dir: where the bookmarks file is stored, defaults to $nu.home-path

$env.nu_bookmarks_path =  ([($env.nu_bookmarks_dir? | default $nu.home-path), ".bookmarks"] | path join)
$env._nu_bookmarks_registry = {}

def _bookmark_name_completions [] {
    $env._nu_bookmarks_registry | transpose name path | get name
}

# List bookmarks.
def "bookmark list" [] {
    if ($env._nu_bookmarks_registry | values | length) == 0 {
        print $"(ansi light_yellow)\(Bookmarks)(ansi reset) No bookmarks."
        return null
    }

    $env._nu_bookmarks_registry
}

# Save bookmarks to file.
def "bookmark save" [
    location?: string, # Path of file to use. If absent, the default is used.
] {
    let target_path = ($location | default $env.nu_bookmarks_path) | path expand

    $env._nu_bookmarks_registry | transpose name path | each {|| $"($in.name)::($in.path)"} | save $target_path --force

    print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmarks saved to (ansi light_magenta)($target_path)(ansi reset)."
    null
}

# Load bookmarks from file.
def --env "bookmark load" [
    location?: string, # Path of file to use. If absent, the default is used.
] {
    let target_path = ($location | default $env.nu_bookmarks_path) | path expand

    if not ($target_path | path exists) {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmarks file not found at (ansi light_magenta)($target_path)(ansi light_red).(ansi reset)"
        return null
    }

    let bookmarks_table = open $target_path | lines | each {|| split column "::" name path } | reduce {|elem, acc| $acc | append $elem }

    $env._nu_bookmarks_registry = {}

    for $entry in $bookmarks_table {
        $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | insert $entry.name $entry.path
    }

    print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmarks loaded from (ansi light_magenta)($target_path)(ansi reset)."
    null
}

# Create new bookmark.
def --env "bookmark create" [
    name: string,  # Name of new bookmark.
    path?: string, # Path of new bookmark. If absent, current directory is used.
] {
    if ($name | str contains "::") {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)A bookmark name can not contain a double-colon \((ansi light_magenta)'::'(ansi light_red)).(ansi reset)"
        return null
    }

    if ($env._nu_bookmarks_registry | get $name --ignore-errors) != null {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmark (ansi light_magenta)($name) (ansi light_red)already exists.(ansi reset)"
        return null
    }

    let target_path = ($path | default $env.PWD) | path expand

    if not ($target_path | path exists) {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Path (ansi light_magenta)($target_path) (ansi light_red)not found.(ansi reset)"
        return null
    }

    $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | insert $name $target_path

    print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmark (ansi light_magenta)($name)(ansi reset) created at (ansi light_magenta)($target_path)(ansi reset)."
    null
}

# Remove bookmarks.
def --env "bookmark remove" [
    ...names: string@_bookmark_name_completions, # Name of bookmarks to remove.
] {
    for $name in $names {
        if ($env._nu_bookmarks_registry | get $name --ignore-errors) == null {
            print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmark (ansi light_magenta)($name) (ansi light_red)not found.(ansi reset)"
        } else {
            $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | reject $name
            print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmark (ansi light_magenta)($name)(ansi reset) removed."
        }
    }

    null
}

# Get path of bookmark.
def "bookmark get" [
    name: string@_bookmark_name_completions, # Bookmark name.
] {
    let target_directory = ($env._nu_bookmarks_registry | get $name --ignore-errors)

    if $target_directory == null {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmark (ansi light_magenta)($name) (ansi light_red)not found.(ansi reset)"
        return null
    }

    $target_directory
}

# Go (cd) to bookmark.
def --env "bookmark go" [
    name: string@_bookmark_name_completions, # Bookmark name.
] {
    let target_directory = bookmark get $name

    if $target_directory != null {
        cd $target_directory
    }

    null
}

# Rename bookmark.
def --env "bookmark rename" [
    name: string@_bookmark_name_completions, # Old bookmark name.
    new_name: string,                        # New bookmark name.
] {
    let bookmark_path = $env._nu_bookmarks_registry | get $name --ignore-errors

    if bookmark_path == null {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmark (ansi light_magenta)($name) (ansi light_red)not found.(ansi reset)"
        return null
    }

    if ($new_name | str contains "::") {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)A bookmark name can not contain a double-colon \((ansi light_magenta)'::'(ansi light_red)).(ansi reset)"
        return null
    }

    if ($env._nu_bookmarks_registry | get $new_name --ignore-errors) != null {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmark (ansi light_magenta)($new_name) (ansi light_red)already exists.(ansi reset)"
        return null
    }

    $env._nu_bookmarks_registry = $env._nu_bookmarks_registry | reject $name | insert $new_name $bookmark_path

    print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmark (ansi light_magenta)($name)(ansi reset) renamed to (ansi light_magenta)($new_name)(ansi reset)."
    null
}

# Remove bookmarks with invalid paths.
def --env "bookmark clear" [
    --list,  # List removed bookmarks.
    --paths, # Show paths of removed bookmarks (does nothing without --list).
] {
    mut filtered_registry = $env._nu_bookmarks_registry
    mut removal_count = 0

    for $bookmark in ($env._nu_bookmarks_registry | transpose name path) {
        if ($bookmark.path | path exists) {
            continue
        }

        if $list {
            if $paths {
                print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmark (ansi light_magenta)($bookmark.name)(ansi reset) with path (ansi light_magenta)($bookmark.path)(ansi reset) removed."
            } else {
                print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmark (ansi light_magenta)($bookmark.name)(ansi reset) removed."
            }
        }

        $filtered_registry = $filtered_registry | reject $bookmark.name
        $removal_count += 1
    }

    $env._nu_bookmarks_registry = $filtered_registry

    print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Cleared (ansi light_magenta)($removal_count)(ansi reset) bookmarks with invalid paths."
    null
}

# Find bookmarks pointing to path.
def "bookmark find" [
    path?: string, # Path to look for. If absent, current directory is used.
] {
    let target_path = ($path | default $env.PWD) | path expand

    if not ($target_path | path exists) {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Path (ansi light_magenta)($target_path) (ansi light_red)not found.(ansi reset)"
        return null
    }

    mut path_list = []

    for $bookmark in ($env._nu_bookmarks_registry | transpose name path) {
        if $bookmark.path == $target_path {
            $path_list = $path_list | append $bookmark.name
        }
    }

    if ($path_list | length) == 0 {
        print $"(ansi light_yellow)\(Bookmarks)(ansi reset) No bookmark points to (ansi light_magenta)($target_path)(ansi reset)."
    } else {
        print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmarks to (ansi light_magenta)($target_path)(ansi reset) \(total of (ansi light_magenta)($path_list | length)(ansi reset)):"

        for path in $path_list {
            print (["- ", $path] | str join)
        }
    }

    null
}
