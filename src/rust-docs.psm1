class Doc {
	[DocKind] $Kind
	[string] $Name
	[string] $File
	[string] $Import

	[string] ToString() {
		return $this.Import
	}

	[string] Parent() {
		if(!$this.Import -or !$this.Import.Contains("::")) {
			return $null
		}
		return $this.Import -replace '\:\:[^\:]+$', ""
	}

	[void] Open() {
		script::open $this.File
	}

	[bool] Matches([DocKind]$Kind) {
		return (($kind -band $this.kind) -eq $this.kind)
	}
}

class ItemDoc: Doc {
	[ItemDoc] Clone() {
		return ([ItemDoc] @{
				Name = $this.Name
				File = $this.File
				Kind = $this.Kind
				Import = $this.Import
			})
	}
}

class ModuleDoc: Doc {
	[DocKind] $Kind = [DocKind]::Module
	[ModuleDoc []] $Children = @()
	[ItemDoc[]] $Items = @()

	hidden ModuleDoc([ModuleDoc]$other) {
		$this.Name = $other.Name
		if($other.children) {
			$this.Children = $other.Children | foreach-object { if($_) { $_.clone() } }
		}
		if($other.items) {
			$this.Items = $other.Items | foreach-object { if($_) { $_.clone() } }
		}
		$this.File = $other.File
		$this.Import = $other.Import
	}

	hidden ModuleDoc() {}

	static [ModuleDoc] FromDir([System.IO.DirectoryInfo]$File, [string]$parent) {
		$self = [ModuleDoc]::new()
		$self.File = join-path $File.fullname "index.html"
		$self.Name = $file.name
		$self.Import = if($parent) {
			"${parent}::$($file.name)"
		} else {
			$file.name
		}

		$self.items = get-childitem -file "$file/*.*.html" | foreach-object {
			try {
				$split = $_.basename.split(".", 2)
				[ItemDoc] @{
					Kind = $split[0]
					Name = $split[1]
					File = $_.fullname
					Import = "$($self.Import)::$($split[1])"
				}
			} catch {}
		}

		[ModuleDoc[]] $subs = get-childitem -directory $file `
		| where-object { -not (!$parent -and $_.name.startswith("prim_")) -and (test-path -pathType leaf "$_/index.html") } `
		| foreach-object { [ModuleDoc]::FromDir($_, $self.Import) }

		if($subs) {
			$self.Children = $subs
		}
		return $self
	}

	[Doc[]] Find([string[]]$Components, [DocKind]$kind) {
		if($components.count -eq 0) {
			return $null
		}

		if($components[0] -ceq "**") {
			if($components.count -eq 1) {
				return ($this.GetAllItems() | where-object { $_ -and $_.matches($kind) })
			}
			# find all submodules and continue the query afterwards
			$rest = $components[1..($components.count)]
			$results = $this.GetAllSubmodules() `
			| foreach-object { $_.Find($rest, $kind) } `
			| group-object -property File `
			| foreach-object { $_.group[0] }
			return $results
		}

		if($components.count -eq 1) {
			$query = $components[0]
			$results = [System.Collections.ArrayList]::new()
			if(($kind -band [DocKind]::Module) -eq [DocKind]::Module) {
				foreach($mod in $this.children) {
					if($mod.Name -clike $query) {
						[void] $results.add($mod)
					}
				}
			}

			if($kind -ne [DocKind]::Module) {
				foreach($item in $this.items) {
					if($item.matches($kind) -and $item.name -clike $query) {
						[void] $results.add($item)
					}
				}
			}
			return $results
		}

		$results = [System.Collections.ArrayList]::new()
		[string[]] $rest = $components[1..($components.count)]
		foreach($mod in $this.children) {
			if($mod.Name -clike $components[0]) {
				$res = $mod.Find($rest, $kind)
				if($res) {
					[void] $results.AddRange($res)
				}
			}
		}
		return $results
	}

	hidden [ModuleDoc[]] GetAllSubmodules() {
		return @(
			$this
			$this.children | foreach-object { $_.GetAllSubmodules() }
		)
	}

	hidden [Doc[]] GetAllItems() {
		return @(
			$this
			$this.items | foreach-object { $_ }
			$this.children | foreach-object { $_.GetAllItems() }
		)
	}

	[ModuleDoc] Clone() {
		return [ModuleDoc]::new($this)
	}
}

function :open($file) {
	if($env:BROWSER) {
		&$env:BROWSER $file
	} elseif($IsMacOS) {
		/bin/open $file
	} elseif($IsLinux) {
		foreach($cmd in @("xdg-open", "sensible-browser", "x-www-browser", "gnome-open")) {
			if(get-command -ea silentlyContinue $cmd) {
				&$cmd $file
				return
			}
		}
		&$file
	} else {
		&$file
	}
}

[Flags()] enum DocKind {
	Module = 1
	Primitive = 2
	Enum = 4
	Struct = 8
	Trait = 16
	Fn = 32
	Type = 64
	Macro = 128
	Constant = 256
	Union = 512
	Keyword = 1024
}

[DocKind] $AnyDoc = [DocKind]::Module + [DocKind]::Primitive + [DocKind]::Enum + [DocKind]::Struct + [DocKind]::Trait + [DocKind]::Fn + [DocKind]::Type + [DocKind]::Macro + [DocKind]::Constant + [DocKind]::Union + [DocKind]::Keyword

[ModuleDoc]$STD = $null

<#
.SYNOPSIS
Imports the structure of the rust stdlib documentation to memory.
.DESCRIPTION
Imports the structure of the rust stdlib documentation to memory.
Only the paths are loaded so there's not much overhead.
.EXAMPLE
Import-RustDoc
#>
function Import-RustDoc {
	[CmdletBinding()]
	param(
		[parameter(position = 0, HelpMessage = "The path of the stdlib documentation source. If omitted, it will be obtained from rustup.")]
		[string]$DocsStdPath
	)
	if(!$docsStdPath) {
		$DocsStdPath = rustup doc --path --std
		if($lastExitCode) {
			return
		}
		$DocsStdPath = split-path -parent "$DocsStdPath"
	}

	$script:STD = [ModuleDoc]::FromDir($docsStdPath, "")
}

<#
.SYNOPSIS
Opens documentation for a given rust std import.
.DESCRIPTION
Opens documentation for a given rust std import.
The syntax is 'module_name::submodule_name::item_name'.
.EXAMPLE
Open-RustDoc sync::mpsc::channel
#>
function Open-RustDoc {
	[CmdletBinding()]
	param(
		[parameter(position = 0, HelpMessage = "Rust syntax import path of the item.")]
		[ValidateScript({ !$_ -or (!$_.endswith(":") -and $_ -match '^[a-zA-Z0-9_]+(\:\:[a-zA-Z0-9_]+)*(\:\:)?$') })]
		[string]$Path,
		[parameter(position = 1, HelpMessage = "The kind of item, e.g. 'fn' or 'struct'.")]
		[DocKind]$Kind = $script:AnyDoc
	)

	if($null -eq $script:STD) {
		script:Import-RustDoc
	}
	if(!$path -or $path -eq "std") {
		rustup doc --std
		return
	}
	$query = if($path.startswith("std::")) {
		$path.Substring("std::".length).split("::")
	} else {
		$path.split("::")
	}

	$item = $script:STD.Find($query, $kind) `
	| sort -property Kind `
	| select -first 1

	if($item) {
		$item.open()
	} else {
		write-error "no documentation found for $path"
	}
}

<#
.SYNOPSIS
Gets Doc objects by their import (accepts wildcards).
.DESCRIPTION
Gets Doc objects by their import (accepts wildcards).
The syntax is 'module_name::submodule_name::item_name'.
.EXAMPLE
Get-RustDoc sync::mpsc::channel
#>
function Get-RustDoc {
	[CmdletBinding()]
	[OutputType([Doc])]
	param(
		[parameter(position = 0, HelpMessage = "Rust syntax import path of the item.")]
		[ValidateScript({ !$_ -or (!$_.endswith(":") -and $_ -match '^[a-zA-Z0-9_]+(\:\:[a-zA-Z0-9_]+)*(\:\:)?$') })]
		[string]$Path,
		[parameter(position = 1, HelpMessage = "The kind of item, e.g. 'fn' or 'struct'.")]
		[DocKind]$Kind = $script:AnyDoc
	)

	if($null -eq $script:STD) {
		script:Import-RustDoc
	}
	if(!$path -or $path -eq "std") {
		return $script:STD.clone()
	}

	$query = if($path.startswith("std::")) {
		$path.Substring("std::".length).split("::")
	} else {
		$path.split("::")
	}
	$query = $query | where-object { $_ }

	if($query.count -eq 0) {
		return $script:STD.clone()
	}

	$script:STD.Find($query, $kind) `
	| sort-object -property Kind `
	| foreach-object { $_.clone() }
}

Register-ArgumentCompleter -CommandName Open-RustDoc, Get-RustDoc -ParameterName Path -ScriptBlock {
	param($_a, $_b, $buf = "", $_d, $params)
	if($buf.endswith(":") -and !$buf.endswith("::")) {
		return "$buf`:"
	}
	if($null -eq $script:STD) {
		script:Import-RustDoc
	}

	$buf = if("$buf".startswith("std::")) {
		$stdPrefix = $true
		"$buf".Substring("std::".length)
	} else {
		$stdPrefix = $false
		"$buf"
	}

	if(!$buf -or $buf.endswith("::")) {
		$buf = "$buf*"
	}

	[string[]] $comps = $buf.split("::") | where-object { $_ -ne "" }
	if($comps.Count -ge 1 -and -not $comps[-1].endsWith("*")) {
		$comps[-1] += "*"
	}

	$kind = $params["Kind"]

	# primitives and keywords are only top-level
	if($kind -eq [DocKind]::Primitive -or $kind -eq [DocKind]::Keyword) {
		if($comps.count -gt 1) {
			return
		}
		$script:STD.find($comps, $kind) `
		| sort-object -property Name `
		| foreach-object {
			if($stdPrefix) {
				"std::" + $_.name
			} else {
				$_.name
			}
		}
		return
	}

	[DocKind] $queryKind = if($kind) {
		$kind -bor [DocKind]::Module
	} else {
		$script:AnyDoc
	}

	$results = $script:STD.find($comps, $queryKind)

	if($null -eq $kind) {
		$kind = [DocKind]::Module
	}

	[System.Collections.ArrayList]$sameKinds = @()
	$others = [ordered] @{}
	[System.Enum]::GetValues([DocKind]) | foreach-object {
		$others[$_] = [System.Collections.ArrayList]::new()
	}

	foreach($doc in $results) {
		if($doc.Kind -eq $kind) {
			[void] $sameKinds.Add($doc)
		} else {
			[void] $others[$doc.Kind].Add($doc)
		}
	}

	@(
		$sameKinds | sort-object -property Import
		foreach($doc in $others.values) {
			$doc | sort-object -property Import
		}
	) | where-object { $_.Import -and $_.Import.Contains("::") } `
	| foreach-object {
		if($stdPrefix) {
			"$_"
		} else {
			"$_".substring("std::".length)
		}
	}
}

Set-Alias rdocs Open-RustDoc
Set-Alias oprsd Open-RustDoc
Set-Alias grsd Get-RustDoc
