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
                write-host "File Changed : " $configFile
                $add.value = $connectionString
                $xmlFile.Save($configFile)               
            }
        } 
    }

$jsonFiles = Get-ChildItem -Path $directoryPath -Recurse  -Include *configuration.json
$jsonFiles | ForEach-Object {
        $jsonFile = $_.FullName
                  
        $jsonObject = (Get-Content $jsonFile) | ConvertFrom-Json

        if (Get-Member -InputObject $jsonObject -Name "ServiceBus" -MemberType Properties)
        {
            write-host "File Changed : " $jsonFile

            $jsonObject.ServiceBus = $connectionString 
            $jsonObject | ConvertTo-Json | set-content $jsonFile
        }
    }