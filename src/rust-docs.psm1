class ItemDoc {
	[DocKind]$Kind
	[string]$Name
	[string]$Path
	[string]$Parent

	[void] Open() {
		&script::open $this.path
	}

	[string] ToString() {
		if($this.Parent) {
			return "$($this.Parent)::$($this.name)"
		} else {
			return $this.name
		}
	}

	hidden [bool] Matches([DocKind]$Kind) {
		return (($kind -band $this.kind) -eq $this.kind)
	}
}

class ModuleDoc {
	[DocKind] $Kind = "Module"
	[string] $Parent
	[string] $Name
	[string] $Path
	[System.Collections.Specialized.OrderedDictionary] $Children = [ordered]@{}
	[ItemDoc[]] $Items = @()

	ModuleDoc([System.IO.DirectoryInfo]$File, [string]$parent) {
		$this.Path = join-path $File.fullname "index.html"
		$this.Name = $file.name
		$this.Parent = $parent
		$modulePath = if($parent) {
			"${parent}::$($this.name)"
		} else {
			$this.name
		}

		$this.items = get-childitem -file "$file/*.*.html" | foreach-object {
			try {
				$split = $_.basename.split(".", 2)
				[ItemDoc] @{
					Kind = $split[0]
					Name = $split[1]
					Parent = $modulePath
					path = $_.fullname
				}
			} catch {}
		}

		$map = [ordered] @{}
		foreach($dir in get-childitem -directory $file) {
			if((!$parent -and $dir.name.startswith("prim_")) -or -not (test-path -pathType leaf "$dir/index.html")) {
				continue
			}
			$map[$dir.name] = [ModuleDoc]::new($dir, $ModulePath)
		}
		$this.Children = $map
	}

	[string] ToString() {
		if($this.parent) {
			return "$($this.parent)::$($this.name)"
		} else {
			return $this.name
		}
	}

	hidden [bool] Matches([DocKind]$kind) {
		return (($kind -band [DocKind]::Module) -eq [DocKind]::Module)
	}

	[void]Open() {
		&script::open $this.Path
	}

	[object[]] Find([string[]]$Components, [DocKind]$kind) {
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
			| group-object -property Path `
			| foreach-object { $_.group[0] }
			return $results
		}

		if($components.count -eq 1) {
			$query = $components[0]
			$results = [System.Collections.ArrayList]::new()
			if(($kind -band [DocKind]::Module) -eq [DocKind]::Module) {
				foreach($entry in $this.children.GetEnumerator()) {
					if($entry.name -clike $query) {
						[void] $results.add($entry.value)
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
		foreach($entry in $this.children.GetEnumerator()) {
			if($entry.name -clike $components[0]) {
				$res = $entry.value.Find($rest, $kind)
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
			$this.children.values | foreach-object { $_.GetAllSubmodules() }
		)
	}

	hidden [object[]] GetAllItems() {
		return @(
			$this
			$this.items | foreach-object { $_ }
			$this.children.values | foreach-object { $_.GetAllItems() }
		)
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

	$script:STD = [ModuleDoc]::new($docsStdPath, "")
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

Register-ArgumentCompleter -CommandName Open-RustDoc -ParameterName Path -ScriptBlock {
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
	if($comps.Count -eq 1 -and -not $comps[0].endsWith("*")) {
		$comps[0] += "*"
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
		$sameKinds | sort-object -property Name
		foreach($doc in $others.values) {
			$doc | sort-object -property name
		}
	) | where-object { $_.parent } `
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
