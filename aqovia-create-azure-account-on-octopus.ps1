function Aqovia-Create-Azure-Account-On-Octopus {
<#

.SYNOPSIS

Creates an AzureServicePrincipal account on Octopus

.DESCRIPTION

Inorder to use you will be prompted to log onto Azure and you will have previously generated an API Key in Octopus

.EXAMPLE
    
    Aqovia-Create-Azure-Account-On-Octopus -octopusURL http://octopus.office.interxion.net -octopusAPIKey API-CREATEYOUOWNINOCTOPUS -userName janed -azureServicePrincipalKey 67007a3b-e54b-4d79-bce6-9fb705302ba1

#>

[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True,Position=1)]
   [string]$octopusURL,
	
   [Parameter(Mandatory=$True)]
   [string]$octopusAPIKey,

   [Parameter(Mandatory=$True)]
   [string]$userName,

   [Parameter(Mandatory=$True)]
   [string]$azureServicePrincipalKey
)

# Import the module into the PowerShell session
Import-Module AzureRM

# Connect to Azure with an interactive dialog for sign-in
Connect-AzureRmAccount

$OctopusURL = $octopusURL
$OctopusAPIKey = $octopusAPIKey

$Subscription = Get-AzureRMSubscription -SubscriptionName "Interxion-Dev-$userName"

$SubscriptionId = $Subscription.Id
$TenantId = $Subscription.TenantId

$Application = Get-AzureRmADApplication -DisplayName "Octopus"

$ClientId = $Application.ApplicationId

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$body = @{
      AccountType = "AzureServicePrincipal"
      SubscriptionNumber = $SubscriptionId
      ClientId = $ClientId
      TenantId = $TenantId
      Password = @{
        HasValue = $True
        NewValue = $azureServicePrincipalKey
      }
      AzureEnvironment = ""
      ResourceManagementEndpointBaseUri = ""
      ActiveDirectoryEndpointBaseUri = ""
      Name = "Azure-Local - $userName"
      Description = "Local - $userName"
      EnvironmentIds = @()
      TenantedDeploymentParticipation= "Untenanted"
      TenantIds = @()
      TenantTags = @()
      Id = "azureserviceprincipal-azure-local-$userName"
      LastModifiedOn = $null
      LastModifiedBy = $null
      Links = @{
        Self = "/api/accounts/azureserviceprincipal-azure-local-$userName"
        Usages = "/api/accounts/azureserviceprincipal-azure-local-$userName/usages"
        ResourceGroups = "/api/accounts/azureserviceprincipal-azure-local-$userName/resourceGroups"
        WebSites = "/api/accounts/azureserviceprincipal-azure-local-$userName/websites"
        StorageAccounts = "/api/accounts/azureserviceprincipal-azure-local-$userName/storageAccounts"
      }
    } | ConvertTo-Json

Invoke-WebRequest $OctopusURL/api/accounts -Method Post -Headers $header -Body $body
}