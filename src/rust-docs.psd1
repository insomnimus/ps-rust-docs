@{
	RootModule = "rust-docs.psm1"
	ModuleVersion = "0.3.0"
	GUID = '1a947aec-7fb1-4b02-b358-35275ea0acf5'
	Author = "Taylan Gökkaya <insomnimus.dev@gmail.com>"
	Copyright = "Copyright (c) 2021 Taylan Gökkaya <insomnimus.dev@gmail.com>"
	Description = "Open rust language documentation from powershell."
	PowerShellVersion = "5.0"

	FunctionsToExport = @("Open-RustDoc", "Import-RustDoc", "Get-RustDoc")
	CmdletsToExport = @()
	VariablesToExport = @()
	AliasesToExport = "*"

	PrivateData = @{
		PSData = @{
			Tags = @("rust", "docs")
			LicenseUri = "https://github.com/insomnimus/ps-rust-docs/blob/main/LICENSE"
			ProjectUri = "https://github.com/insomnimus/ps-rust-docs"
		}
	}
}
