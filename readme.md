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
# Change into $profile
# You don't have to put it there, see the text above.
split-path "$profile" | set-location
set-location modules
git clone https://github.com/insomnimus/ps-rust-docs
import-module ps-rust-docs
```
