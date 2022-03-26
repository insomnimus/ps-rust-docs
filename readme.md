# ps-rust-docs
A powershell module to open local rust documentation.

# Usage
```powershell
Open-RustDoc sync::mpsc::channel
# `rdocs` is an alias to Open-RustDoc
rdocs collections::HashMap
```

## Tab Completion
Most of the effort in writing the module went to providing excellent tab completions, as a result even double-star glob patterns will complete efficiently and exactly.

You can press tab to complete a partial path:

`os::wi<tab>` will complete to `os::windows`.

You can provide the type beforehand, so that you don't get completions for structs when you're looking for an enum etc:

`rdocs -kind enum io::<tab>`

You can use wildcards to match an arbitrary item:

-	`*` matches any number of any character except a path separator (`::`).
-	`**` matches any number of characters, including path separators. For example, `**::*Ext` will match `os::linux::process::ChildExt`.

Rest of the patterns are the same as Powershell's.

# Dependencies
Powershell 5.0 or above and `rustup` which you should already have.

# Installation
## Via Scoop (recommended)
First add [my bucket](https://github.com/insomnimus/scoop-bucket) to scoop:

`scoop bucket add insomnia https://github.com/insomnimus/scoop-bucket`

Update scoop:

`scoop update`

Install the module:

`scoop install ps-rust-docs`

## Download From Releases
Download and extract `rust-docs.zip` from [releases](https://github.com/insomnimus/ps-rust-docs/releases) into your PS module directory.

## Clone and Install Manually
```powershell
# Clone the repository.
git clone https://github.com/insomnimus/ps-rust-docs
$module = get-item ./ps-rust-docs/src
$modulesPath = join-path (split-path "$profile") "Modules"
copy-item -recurse $module "$modulesPath/rust-docs"

import-module rust-docs
```
