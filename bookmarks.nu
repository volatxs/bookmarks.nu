# Configuration options:
# - $env.nu_bookmarks_dir: where the bookmarks file is stored, defaults to $nu.home-path

$env.nu_bookmarks_path =  ([($env.nu_bookmarks_dir? | default $nu.home-path), ".bookmarks"] | path join)
$env._nu_bookmarks_registry = {}

# List available bookmarks
def "bookmark list" [] {
    if ($env._nu_bookmarks_registry | values | length) == 0 {
        print $"(ansi light_yellow)\(Bookmarks)(ansi reset) No bookmarks."
        return null
    }

    $env._nu_bookmarks_registry
}

# Save bookmarks to .bookmarks
def "bookmark save" [location?: string] {
    let target_path = ($location | default $env.nu_bookmarks_path) | path expand

    $env._nu_bookmarks_registry | transpose name path | each {|| $"($in.name)::($in.path)"} | save $target_path --force

    print $"(ansi light_yellow)\(Bookmarks)(ansi reset) Bookmarks saved to (ansi light_magenta)($target_path)(ansi reset)."
    null
}

# Load bookmarks from .bookmarks
def --env "bookmark load" [location?: string] {
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

# Make a new bookmark
def --env "bookmark make" [name: string, path?: string] {
    # If <path> is provided, <name> is set to <path>, otherwise it's set to PWD.

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

# Remove a bookmark
def --env "bookmark remove" [...names: string] {
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

# Jump to a bookmark
def --env "bookmark go" [name: string] {
    let target_directory = $env._nu_bookmarks_registry | get $name --ignore-errors

    if $target_directory == null {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmark (ansi light_magenta)($name) (ansi light_red)not found.(ansi reset)"
        return null
    }

    cd $target_directory

    null
}

def "bookmark get" [name: string] {
    let target_directory = ($env._nu_bookmarks_registry | get $name --ignore-errors)

    if $target_directory == null {
        print $"(ansi light_yellow)\(Bookmarks) (ansi light_red)Bookmark (ansi light_magenta)($name) (ansi light_red)not found.(ansi reset)"
        return null
    }

    $target_directory
}
