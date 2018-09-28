function Aqovia-Utf8NoBomEncoding{
    <#
    .SYNOPSIS
    Changes file encoding to UTF8 without BOM for a given directory.

    .DESCRIPTION
    The Aqovia-Utf8NoBomEncoding function changes file encoding to UTF8 without BOM for a given directory.
    
    .EXAMPLE
    Aqovia-Utf8NoBomEncoding -Directory E:\dev\Interxion\services-login\src\Web\less

    .NOTES
    
    #>
    [CmdletBinding()]
    Param(
       [Parameter(Mandatory=$True,Position=1)]
       [string]$Directory
    )

    Get-ChildItem $Directory | ForEach-Object {

		$path = $_.FullName

		$file = Get-Content $path

		if($file.length -eq 0 ){
            Set-Content -Path $path -Value "" -Encoding UTF8
            Clear-Content -Path $path
		}
		else{
			$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
			[System.IO.File]::WriteAllLines($path, $file, $Utf8NoBomEncoding)
		}
    }
}