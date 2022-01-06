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
Download and extract `rust-docs.zip` from [releases](https://github.com/insomnimus/ps-rust-docs/releases) into your PS module directory.

Or if you want the development version, follow the steps below.

```powershell
# Clone the repository.
git clone https://github.com/insomnimus/ps-rust-docs
$module = get-item ./ps-rust-docs/src
$modulesPath = join-path (split-path "$profile") "Modules"
copy-item -recurse $module "$modulesPath/rust-docs"

import-module rust-docs
```
