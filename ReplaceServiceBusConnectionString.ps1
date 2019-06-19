function Aqovia-ServiceBus-ConnectionString-Update{
<#

.SYNOPSIS

Allows you to update service bus connection strings in the directory (and sub-directories) supplied.

.DESCRIPTION

Updates the service connection string in .config and .json files 

.EXAMPLE
    
    Aqovia-ServiceBus-ConnectionString-Update -directoryPath E:\dev\Interxion -connectionString "Endpoint=sb://inxn-local-janed.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=V4mjurGpYakbBmAb2lcsBvoWMQ4ACtb91Vvk9UOLp7M="

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
                
                write-host "File Changed (ServiceBus in appSettings): " $configFile            
            }
        } 

        foreach($add in $xmlFile.configuration.connectionStrings.add) {
            if ($add.name -eq 'ServiceBus'){
                $add.connectionString = $connectionString
                $xmlFile.Save($configFile)  
                    
                write-host "File Changed (ServiceBus in connectionStrings tag): " $configFile            
            }
        }

        foreach($add in $xmlFile.connectionStrings.add) {
            if ($add.name -eq 'EpiServerServiceBus') 
            {   
                $add.connectionString = $connectionString
                $xmlFile.Save($configFile)  
                
                write-host "File Changed (EpiServerServiceBus in connectionStrings file): " $configFile            
            }
        }
    }

$jsonFiles = Get-ChildItem -Path $directoryPath -Recurse  -Include *configuration.json
$jsonFiles | ForEach-Object {
        $jsonFile = $_.FullName
                  
        $jsonObject = Get-Content $jsonFile -Raw | ConvertFrom-Json

        if (Get-Member -InputObject $jsonObject -Name "ServiceBus" -MemberType Properties)
        {
            $jsonObject.ServiceBus = $connectionString 
            $jsonObject | ConvertTo-Json | set-content $jsonFile

            write-host "File Changed : " $jsonFile
        }
    }
 }
