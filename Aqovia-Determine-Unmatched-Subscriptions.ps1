function Aqovia-Determine-Unmatched-Subscriptions{
    <#
    .SYNOPSIS
    Determines unmatched subscriptions.

    .DESCRIPTION
    The Aqovia-Determine-Unmatched-Subscriptions function determines unmatched subscriptions between configuration.xml files of microservices which are in working directory and the given xml file which is exported from Service Bus Explorer. Hence, working directory should be the parent directory for all local repositories and also given xml file should be in the working directory. Function compares all topic-subscription pairs between these xml files.
    
    .PARAMETER serviceBusSubscriptionsFile 
    Service Bus Subscriptions xml file.

    .EXAMPLE
    Working Directory: E:\dev\Interxion

    Aqovia-Determine-Unmatched-Subscriptions -serviceBusSubscriptionsFile IX-Production-Cloudconnect_Entities.xml

    .NOTES
    You need to run this function as administrator.
    #>
    [CmdletBinding()]
    Param(
       [Parameter(Mandatory=$True,Position=1)]
       [string]$serviceBusSubscriptionsFile
    )
    
    Get-Date -Format g
    
    $workingDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')
    $hasAnyUnmatched = $false

    class Subscriptions {
        [string] $topic
        [string] $name
    }

    $SubscriptionsList = New-Object 'System.Collections.Generic.List[Subscriptions]'

    #searching directories
    $directories = @(Get-ChildItem $workingDir -Recurse -Directory -Depth 3 | where {$_.psiscontainer} | where { (test-path (join-path $_.fullname "*.sln")) })
    $directories | ForEach-Object {
        $directoryPath = $_

        $configurationFiles = Get-ChildItem $directoryPath -Recurse -Filter configuration.xml -ErrorAction SilentlyContinue -Force
        $configurationFiles | ForEach-Object {
            $configurationFile = $_.FullName
            
            $configurationXml = (Get-Content $configurationFile) -as [Xml]
            
            $serviceBuses = $configurationXml.configuration.serviceBuses.serviceBus

            foreach($serviceBus in $serviceBuses){
                $topics = $serviceBuses.Topics.Topic;
                
                foreach($topic in $topics){
                    foreach($subscriptionName in $topic.Subscriptions.Subscription.Name){
                        $newSubscription = New-Object Subscriptions -Property @{topic=$topic.Name.ToLower(); name=$subscriptionName.ToLower()}
                        $hasSubscription = $SubscriptionsList | Where {$_.topic -eq $newSubscription.topic -and $_.name -eq $newSubscription.name}
                        
                        If ($hasSubscription.Count -eq 0){
                            $SubscriptionsList.Add($newSubscription)
                        }
                    }
                }
            }
        }
    }

    $subscriptionsFile = @(Get-ChildItem $workingDir -Recurse -Filter $serviceBusSubscriptionsFile -ErrorAction SilentlyContinue -Force)
    $subscriptionsFile | ForEach-Object {
        $path = $_
        
        $xmlFile = (Get-Content $path.FullName) -as [Xml]
        
        $topics = $xmlFile.Entities.Topics.Topic;

        foreach($topic in $topics){
            foreach($subscriptionName in $topic.Subscriptions.Subscription.Name){            
                foreach($Subscription in $SubscriptionsList){
                    If ($Subscription.topic -eq $topic.Path.ToLower() -and $Subscription.name -eq $subscriptionName.ToLower()){
                        $hasAnyUnmatched = $false
                        break
                    }
                    else{
                        $hasAnyUnmatched = $True
                    }
                }
                
                if($hasAnyUnmatched -eq $True){
                    write-host 'Topic: ' $topic.Path.ToLower() ' - Subscription:' $SubscriptionName.ToLower() ' is missing at the related project'
                }
            }
        }
    }
    
    Write-host 'Done!'    
    
    Get-Date -Format g
}