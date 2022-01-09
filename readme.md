# ps-rust-docs
A powershell module to open local rust documentation.

# Usage
```powershell
Open-RustDoc sync::mpsc::channel
# `rdocs` is an alias to Open-RustDoc
rdocs collections::HashMap
```

> Note: you can press tab to complete the import path! It's fully supported.

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
