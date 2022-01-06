@{
	RootModule = "ps-rust-docs.psm1"
	ModuleVersion = "0.1.0"
	GUID = '1a947aec-7fb1-4b02-b358-35275ea0acf5'
	Author = "Taylan Gökkaya <insomnimus.dev@gmail.com>"
	Copyright = "Copyright (c) 2021 Taylan Gökkaya <insomnimus.dev@gmail.com>"
	Description = "Open rust language documentation from powershell."
	PowerShellVersion = "5.0"

	FunctionsToExport = @("Open-RustDoc", "Import-RustDoc")
	CmdletsToExport = @()
	VariablesToExport = @()
	AliasesToExport = @("rdocs", "oprsd")
	FileList = @("LICENSE", "ps-rust-docs.psm1", "ps-rust-docs.psd1")

	PrivateData = @{
		PSData = @{
			Tags = @("rust", "docs")
			LicenseUri = "https://github.com/insomnimus/ps-rust-docs/blob/main/LICENSE"
			ProjectUri = "https://github.com/insomnimus/ps-rust-docs"
		}
	}
}
