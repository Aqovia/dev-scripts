<#

.SYNOPSIS

Allows you to update service bus connection strings in the directory (and sub-directories) supplied.

.DESCRIPTION

Updates the service connection string in .config and .json files 

#>

[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True,Position=1)]
   [string]$directoryPath,
	
   [Parameter(Mandatory=$True)]
   [string]$connectionString
)

$configFiles = Get-ChildItem -Path $directoryPath -Recurse  -Include *.config
$configFiles | ForEach-Object {
        $configFile = $_.FullName

        $xmlFile = (Get-Content $configFile) -as [Xml]

        foreach($add in $xmlFile.configuration.appSettings.add) {
            if ($add.key -eq 'ServiceBus') 
            {   
                $add.value = $connectionString
                $xmlFile.Save($configFile)  
                
                write-host "File Changed : " $configFile            
            }
        } 

        foreach($add in $xmlFile.connectionStrings.add) {
            if ($add.name -eq 'EpiServerServiceBus') 
            {   
                $add.connectionString = $connectionString
                $xmlFile.Save($configFile)  
                
                write-host "File Changed : " $configFile            
            }
        }
    }

$jsonFiles = Get-ChildItem -Path $directoryPath -Recurse  -Include *configuration.json
$jsonFiles | ForEach-Object {
        $jsonFile = $_.FullName
                  
        $jsonObject = (Get-Content $jsonFile) | ConvertFrom-Json

        if (Get-Member -InputObject $jsonObject -Name "ServiceBus" -MemberType Properties)
        {
            $jsonObject.ServiceBus = $connectionString 
            $jsonObject | ConvertTo-Json | set-content $jsonFile

            write-host "File Changed : " $jsonFile
        }
    }