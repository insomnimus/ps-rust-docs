enum DocKind {
	Module
	Primitive
	Enum
	Struct
	Trait
	Fn
	Type
	Macro
	Constant
	Union
	Keyword
}

class ItemDoc {
	[DocKind]$Kind
	[string]$Name
	[string]$Path
	[string]$Module

	[void] Open() {
		&$this.Path
	}

	[string] ToString() {
		if($this.Module) {
			return "$($this.module)::$($this.name)"
		} else {
			return $this.name
		}
	}
}

class ModuleDoc {
	[DocKind] $Kind = "Module"
	[string] $ModulePath
	[string] $IndexPath
	[System.Collections.Specialized.OrderedDictionary] $Children
	[ItemDoc[]] $Items

	ModuleDoc([System.IO.DirectoryInfo]$path, [string]$parent) {
		$this.IndexPath = join-path $path.fullname "index.html"
		if($parent) {
			$this.ModulePath = "${parent}::$($path.name)"
		} else {
			$this.ModulePath = $path.name
		}

		$this.items = get-childitem -file "$path/*.*.html" | % {
			try {
				$split = $_.basename.split(".", 2)
				[ItemDoc] @{
					Kind = $split[0]
					Name = $split[1]
					Module = $this.ModulePath
					path = $_.fullname
				}
			} catch {}
		}

		$map = [ordered] @{}
		foreach($dir in get-childitem -directory $path) {
			if(-not (test-path -pathType leaf "$dir/index.html")) {
				continue
			}
			$map[$dir.name] = [ModuleDoc]::new($dir, $this.ModulePath)
		}
		$this.Children = $map
	}

	[string] ToString() {
		return $this.ModulePath
	}

	[void]Open() {
		&$this.IndexPath
	}

	[object[]] Find([string[]]$Components) {
		if($components.count -eq 0) {
			return $null
		}
		if($components.count -eq 1) {
			$query = $components[0]
			$results = [System.Collections.ArrayList]::new()
			foreach($entry in $this.children.GetEnumerator()) {
				if($entry.name -clike $query) {
					[void] $results.add($entry.value)
				}
			}
			foreach($item in $this.items) {
				if($item.name -clike $query) {
					[void] $results.add($item)
				}
			}
			return $results
		}

		$results = [System.Collections.ArrayList]::new()
		foreach($entry in $this.children.GetEnumerator()) {
			if($entry.name -clike $components[0]) {
				$res = $entry.value.Find($components[1..$components.length])
				if($res) {
					[void] $results.AddRange($res)
				}
			}
		}
		return $results
	}
}

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
		[DocKind]$Kind
	)

	if($null -eq $script:STD) {
		script:Load-RustDocs
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

	$item = $script:STD.Find($query) `
	| where {
		!$kind -or $_.kind -eq $kind
	} `
	| sort -property Kind `
	| select -first 1

	if($item) {
		$item.open()
	} else {
		write-error "no documentation found for $path"
	}
}

Register-ArgumentCompleter -CommandName Open-RustDoc -ParameterName Path -ScriptBlock {
	param($_a, $_b, $buf, $_d, $params)
	if($buf.endswith(":") -and !$buf.endswith("::")) {
		return "$buf`:"
	}
	if($null -eq $script:STD) {
		script:Load-RustDocs
	}

	$buf = if("$buf".startswith("std::")) {
		$stdPrefix = $true
		"$buf".Substring("std::".length)
	} else {
		"$buf"
	}

	if(!$buf -or $buf.endswith("::")) {
		$buf = "$buf*"
	}

	$comps = $buf.split("::") | where-object { $_ -ne "" }

	if($comps.count -eq 1) {
		$results = $script:STD.find("$comps*")
	} else {
		$comps[-1] += "*"
		$results = $script:STD.find($comps)
	}

	$results `
	| where-object { !$params.kind -or $params.kind -eq $_.kind } `
	| sort-object -property Kind `
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
