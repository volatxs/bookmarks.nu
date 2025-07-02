# Bookmarks.nu

A simple [Nushell](https://github.com/nushell/nushell) script that introduces
commands for bookmarking and navigating around directories with a local-first
philosophy.

```nu
# Create a new bookmark named "myproj" that points to "D:/code/my_project"
bookmark create myproj D:/code/my_project

# Create another bookmark pointing to the current directory
bookmark create another

# Jump to your newly created bookmark
bookmark go myproj

# Rename your bookmark
bookmark rename myproj main_project

# Save your bookmarks to the default location
bookmark save

# Save your bookmarks to a specific file
bookmark save my_bookmarks

# Load your bookmarks from the default location
bookmark load
```

## Setup

There are many ways to do it, but here is a very simple one.

Jump to your Nushell config directory.

```nu
cd ($nu.config-path | path dirname)
```

Clone this project as a local directory named `bookmarks`.

```nu
git clone https://github.com/volatxs/bookmarks.nu.git bookmarks
```

Add these two lines to your `config.nu`.

```nu
source bookmarks/bookmarks.nu  # Run the bookmarks script
bookmark load                  # Load the default bookmarks when starting
```

## Commands

The following commands are available:

| Command                             | Description                          |
| :---------------------------------- | :----------------------------------- |
| `bookmark create <name> [path]`     | Create a new bookmark.               |
| `bookmark remove {name}`            | Remove bookmarks.                    |
| `bookmark rename <name> <new_name>` | Rename bookmark.                     |
| `bookmark clear`                    | Remove bookmarks with invalid paths. |
| `bookmark go <name>`                | Go (cd) to bookmark.                 |
| `bookmark get <name>`               | Get path of bookmark.                |
| `bookmark list`                     | List bookmarks.                      |
| `bookmark save [location]`          | Save bookmarks to file.              |
| `bookmark load [location]`          | Load bookmarks from file.            |
| `bookmark change <name> <new_path>` | Change bookmark's path.              |

Completions for bookmarks are available and all commands have a description, as
well as their arguments and flags, so usage should be fairly straightforward
due to Nushell's incredible completion features.

## Usage

Commands that create, delete or modify existing bookmarks operate on a local,
per-session, registry. Writing (`bookmark save`) saves to a local file such
that the state of the bookmarks registry can be retrieved later by reading
(`bookmark load`) from a local file.

When explicit paths aren't provided, these commands fall back to the default
bookmarks file path, which is initially `$nu.home-path/.bookmarks`. This can be
changed by modifying the `$env.nu_bookmarks_dir` variable before running the
bookmarks script. The following config makes bookmarks.nu save to
`C:/.bookmarks` by default:

```nu
$env.nu_bookmarks_dir = "C:"
source bookmarks/bookmarks.nu
bookmark load
```

A bookmarks file is a simple text file where each line is a bookmark name and
a directory path, separated by a double-colon (`::`). Therefore, double-colons
are disallowed in bookmark names, and commands will give you an error about
this if you try to use double-colons when creating or renaming a bookmark.
