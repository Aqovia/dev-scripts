Function Get-CoreInfo {
    if(Test-Path "$env:programfiles/dotnet/"){
        try{

            [Collections.Generic.List[string]] $info = dotnet --info

            $versionLineIndex = $info.FindIndex( {$args[0].ToString().ToLower() -like "*version*:*"} )

            $runtimes = (ls "$env:programfiles/dotnet/shared/Microsoft.NETCore.App").Name | Out-String

            $sdkVersion = dotnet --version

            $fhVersion = (($info[$versionLineIndex]).Split(':')[1]).Trim()

            return "Installed .NET Core SDK version: `r`n$sdkVersion`r`n`r`nInstalled .NET Core runtime versions:`r`n$runtimes`r`nInstalled .NET Core Framework Host:`r`n$fhVersion"
        }
        catch{
            $errorMessage = $_.Exception.Message

            Write-Host "Something went wrong`r`nError: $errorMessage"
        }
    }
    else{
    
        Write-Host 'No .NET Core SDK installed'
        return ""
    }
}

Write-Host '-------------------------'
Write-Host '.NET Core'
Write-Host '-------------------------'
Get-CoreInfo

Write-Host '-------------------------'
Write-Host '.NET Full framework'
Write-Host '-------------------------'
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse |
Get-ItemProperty -name Version,Release -EA 0 |
Where { $_.PSChildName -match '^(?!S)\p{L}'} |
Select PSChildName, Version, Release
