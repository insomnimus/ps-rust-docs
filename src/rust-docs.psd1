@{
	RootModule = "rust-docs.psm1"
	ModuleVersion = "0.5.1"
	GUID = '1a947aec-7fb1-4b02-b358-35275ea0acf5'
	Author = "Taylan Gökkaya <insomnimus.dev@gmail.com>"
	Copyright = "Copyright (c) 2022 Taylan Gökkaya <insomnimus.dev@gmail.com>"
	Description = "Open rust language documentation from powershell."
	PowerShellVersion = "5.0"

	FunctionsToExport = @("Open-RustDoc", "Import-RustDoc", "Get-RustDoc")
	CmdletsToExport = @()
	VariablesToExport = @()
	AliasesToExport = @("rdocs", "oprsd", "grsd")

	PrivateData = @{
		PSData = @{
			Tags = @("rust", "docs")
			LicenseUri = "https://github.com/insomnimus/ps-rust-docs/blob/main/LICENSE"
			ProjectUri = "https://github.com/insomnimus/ps-rust-docs"
		}
	}
}
