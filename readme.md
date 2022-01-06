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
Just clone the repository under one of the paths in `$env:PSMODULEPATH`.

```powershell
# Clone the repository.
git clone https://github.com/insomnimus/ps-rust-docs
$mod = get-item ./ps-rust-docs/src
# Change into $profile
# You don't have to put it there, see the text above.
$modulesPath = join-path (split-path "$profile") "Modules"
copy-item -recurse $module "$modulesPath/rust-docs"

import-module rust-docs
```
