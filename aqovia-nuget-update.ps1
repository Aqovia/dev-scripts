function aqovia-nuget-update{
    <#
    .SYNOPSIS
    Updates nuget package version in working directory.

    .DESCRIPTION
    The Aqovia-Nuget-Update function updates nuget package version in packages.config files recursively in working directory. Hence, working directory should be the parent directory for all local repositories. After updating packages config files, it restores nuget packages in solution level and builds solutions, runs unit tests. It uses msbuild.exe to build solutions and xunit.console.x86.exe to run unit tests. It downloads nuget.exe and xunit.console.x86.exe temporarirly into working directory and deletes after finishing its work. If there are any exceptions on build or on tests run, the script exists with code 1 and throws exception list.If build and tests run are succeeded, then it creates new git branch with given branch name, chekouts new branch and commits changes. It requires user confirmation to push changes to remote.
    
    .PARAMETER packageName 
    The name of the package that is wanted to change its version.

    .PARAMETER parentPackageName 
    The name of the parent package that exists that this package must be installed with.

    .PARAMETER targetVersion
    The new version of the package.

    .PARAMETER branchName
    The name of the branch which is used for pushing changes to remote.

    .PARAMETER addOrupdateOrRemove
    add or remove the nuget package. valid values : add, update, remove

    .PARAMETER pushToRemove
    push changes to remote branch. valid values : y, Y, n, N

    .PARAMETER build
    build and test. valid values : y, Y, n, N

    .EXAMPLE
    Working Directory: E:\dev\Interxion
    Aqovia-Nuget-Update -packageName Powershell.Deployment -targetVersion 1.2.5.0 -branchName Update-PowershellDeployment-nuget-package -addOrupdateOrRemove update -pushToRemove N -build N

    .NOTES
    You need to run this function as administrator.
    #>
    [CmdletBinding()]
    Param(
       [Parameter(Mandatory=$True,Position=1)]
       [string]$packageName,

       [Parameter(Mandatory=$False)]
       [string]$parentPackageName,
	
       [Parameter(Mandatory=$False)]
       [string]$targetVersion,
	
       [Parameter(Mandatory=$True)]
       [string]$branchName,

       [Parameter(Mandatory=$True)]
       [string]$addOrupdateOrRemove,

       [Parameter(Mandatory=$True)]
       [string]$pushToRemote,

       [Parameter(Mandatory=$True)]
       [string]$build
    )
    
    if($targetVersion -eq "" -and $addOrupdateOrRemove -eq "update")
    {
        Write-Host "If -addOrupdateOrRemove = update, then you must supply a -targetVersion"
        exit
    }

    if($targetVersion -eq "" -and $addOrupdateOrRemove -eq "add")
    {
        Write-Host "If -addOrupdateOrRemove = add, then you must supply a -targetVersion"
        exit
    }
    if($parentPackageName -eq "" -and $addOrupdateOrRemove -eq "add")
    {
        Write-Host "If -addOrupdateOrRemove = add, then you must supply a -parentPackageName"
        exit
    }

    Get-Date -Format g
    
    $hasUpdate = $false
    $workingDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')

    #msbuild path
    $MsBuildExe = Resolve-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio*\MSBuild\*\bin\msbuild.exe" -ErrorAction SilentlyContinue

    #install nuget.exe
    $sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    $targetNugetExe = "$workingDir\nuget.exe"
    if(-not (Test-Path -path $targetNugetExe)){
        Invoke-WebRequest $sourceNugetExe -OutFile $targetNugetExe
        Set-Alias nuget $targetNugetExe -Scope Global -Verbose
    }

    #install xunit runner console.exe
    $xunitConsoleExe = $workingDir+"\xunit.runner.console.*\tools\*\xunit.console.x86.exe"
    $xUnitNuget = "http://www.nuget.org/api/v2/"
    if(-not (Test-Path -path $xunitConsoleExe)){
        iex "$targetNugetExe install xunit.runner.console -source $xUnitNuget"
    }

    #searching directories
    Get-ChildItem $workingDir -Recurse -Directory -Depth 3 | where {$_.psiscontainer} | where { (test-path (join-path $_.fullname "*.sln")) } | ForEach-Object {
        $path = $_
        $fullPath = $path.FullName

        $packageConfigFiles = Get-ChildItem $path -Recurse -Filter packages.config -ErrorAction SilentlyContinue -Force

        $projectConfigFilesCore = Get-ChildItem $path -Recurse -Filter *.csproj -ErrorAction SilentlyContinue -Force | Where-Object {(Select-String -InputObject $_ -Pattern 'PackageReference' -Quiet) -eq $true}

        $projectConfigFilesStandard = Get-ChildItem $path -Recurse -Filter *.csproj -ErrorAction SilentlyContinue -Force | Where-Object {(Select-String -InputObject $_ -Pattern '<Reference Include=' -Quiet) -eq $true}
    
        #if there is a packages.config or project config files with package references, and if there is a git repo
        if( ((($packageConfigFiles | measure).Count -gt 0) -or (($projectConfigFiles | measure).Count -gt 0)) -and (Test-Path -path $fullPath'\.git')){
            #fetch and checkout master
            Write-host 'fetch and checkout master for' $path '...'

            $gitBranch = (((git -C $fullPath status) -split '\n')[0]).Substring(10)

            if($gitBranch -ne $branchName)
            {
                git -C $fullPath fetch -q
                git -C $fullPath checkout master -q

                #pull
                Write-host 'pull for' $path '...'
                git -C $fullPath pull -q
            }
            else
            {
                Write-host "Branch " $branchName " already exists"
            }
    
            #change packages.config files
            $packageConfigFiles | ForEach-Object {
                $configFile = $_.FullName

                $xmlFile = (Get-Content $configFile) -as [Xml]

                foreach($package in $xmlFile.packages.package) {
                    if ($package.id -eq $packageName){
                        if($addOrupdateOrRemove -eq "update")
                        {
                            if($package.version -ne $targetVersion)
                            {
                                $package.version = $targetVersion
                            }
                        }
                        if($addOrupdateOrRemove -eq "remove")
                        {
                            $package.ParentNode.RemoveChild($package)
                        }
                        Write-Host "saving nuget packages.config file..." -ForegroundColor green
                        $xmlFile.Save($configFile)
                        $hasUpdate = $true
                    }
                }
                if($addOrupdateOrRemove -eq "add" -and $xmlFile.packages.package.id -contains $parentPackageName -and $xmlFile.packages.package.id -notcontains $packageName)
                {
                    $package = $xmlFile.CreateElement("package")
                    $package.SetAttribute("id", $packageName)
                    $package.SetAttribute("version", $targetVersion)
                    $package.SetAttribute("targetFramework", "net452")

                    $xmlFile.packages.AppendChild($package)
                    $xmlFile.Save($configFile)
                    $hasUpdate = $true
                }
            }

            #change csproj core files
            $projectConfigFilesCore | ForEach-Object {
                $configFile = $_.FullName

                $xmlFile = (Get-Content $configFile) -as [Xml]

                foreach($package in $xmlFile.project.itemgroup.packagereference) {
                    if ($package.include -eq $packageName){
                        if($addOrupdateOrRemove -eq "update")
                        {
                            if($package.version -ne $targetVersion)
                            {
                                $package.version = $targetVersion
                            }
                        }
                        if($addOrupdateOrRemove -eq "remove")
                        {
                            $package.ParentNode.RemoveChild($package)
                        }
                        Write-Host "saving csproj file..." -ForegroundColor green
                        $xmlFile.Save($configFile)
                        $hasUpdate = $true
                    }
                }
                if($addOrupdateOrRemove -eq "add" -and $xmlFile.project.itemgroup.packagereference.include -contains $parentPackageName -and $xmlFile.project.itemgroup.packagereference.include -notcontains $packageName)
                {
                    $package = $xmlFile.CreateElement("PackageReference")
                    $package.SetAttribute("include", $packageName)
                    $package.SetAttribute("Version", $targetVersion)
                    $xmlFile.project.itemgroup.packagereference.AppendChild($package)
                    $xmlFile.Save($configFile)
                    $hasUpdate = $true
                }
            }

            #change csproj standard files - for removal
            $projectConfigFilesStandard | ForEach-Object {
                $configFile = $_.FullName

                $xmlFile = (Get-Content $configFile) -as [Xml]

                foreach($package in $xmlFile.project.itemgroup.reference) {
                    if(($package.include -split ',' | Where({$_.Trim() -eq $packageName}) | measure).Count -gt 0)
                    {
                        if($addOrupdateOrRemove -eq "remove")
                        {
                            $package.ParentNode.RemoveChild($package)
                        }
                        Write-Host "saving csproj file..." -ForegroundColor green
                        $xmlFile.Save($configFile)
                        $hasUpdate = $true
                    }
                }
            }

            if($hasUpdate -eq $true)  {
                $hasUpdate = $false

                if($build -match "[yY]")
                {

                    $solutionFile = Get-ChildItem $path -Filter *.sln -ErrorAction SilentlyContinue -Force
            
                    #restore nuget packages
                    Write-Host "restoring nuget packages for" $solutionFile "..." -ForegroundColor Yellow
                    .\nuget restore $solutionFile.FullName

                    #build solution
                    $mArgs = @($solutionFile.FullName, '/t:ReBuild','/p:Configuration=Debug')
                    Write-Host "building" $solutionFile "..." -ForegroundColor Yellow

                    $buildOutput = &$MsBuildExe $mArgs
                    if ($buildOutput -notcontains "Build succeeded."){
        
                        $exceptionList = @()
                        $buildOutput | foreach {
                            $matchInfo =  [regex]::match($_,'error [a-zA-Z]{2}\d{1,4}')

                            if ($matchInfo.Success)
                            {
                                $exception = $buildOutput | Select-String -Pattern $matchInfo.Value -Context 0,0 | Out-String
                                If ($exceptionList -notcontains $exception){
                                    $exceptionList += $exception
                                }
                            }    
                        }

                        Throw $exceptionList
                        exit 1
                    }
                    else{
                        Write-Host "build succeeded" -ForegroundColor Green
                    }
        
                    #run unit tests
                    Write-Host "running unit tests for" $solutionFile "..." -ForegroundColor Yellow
                    $testsPath = $fullPath + '\tests\*\bin\Debug'
                    $assemblies = Get-ChildItem $testsPath -Recurse -Filter *.Tests.dll -ErrorAction SilentlyContinue -Force
                    foreach($assembly in $assemblies){
                        $testOutput = &$xunitConsoleExe $assembly
            
                        if($testOutput -like "Exception"){
                            $exceptionList = @()

                            $testOutput | foreach {
                                $exception = $buildOutput | Select-String -Pattern ".*Exception$" -Context 0,0 | Out-String
                                If ($exceptionList -notcontains $exception){
                                    $exceptionList += $exception
                                }
                            }

                            Throw $exceptionList
                            exit 1
                        }
                        else{
                            Write-Host "unit tests succeeded" -ForegroundColor Green
                        }
                    }
                }

                if($gitBranch -ne $branchName)
                {
                    Write-host 'check out branch' $branchName 'for' $path '...'
                    git -C $fullPath checkout -B $branchName
                }

                #commit
                Write-host 'commit changes for' $path '...'
                if($addOrupdateOrRemove -eq "update")
                {
                    $message = 'Updated '+$packageName+' version to '+$targetVersion
                }
                if($addOrupdateOrRemove -eq "remove")
                {
                    $message = 'Removed '+$packageName
                }
                if($addOrupdateOrRemove -eq "add")
                {
                    $message = 'Added '+$packageName
                }
                
                git -C $fullPath add .
                git -C $fullPath commit -m $message

                #push
                if ($pushToRemote -match "[yY]"){
                    Write-host 'push changes for' $path '...'
                    git -C $fullPath push -u origin $branchName
                }
            }
        }
    }

    #remove nuget.exe
    Remove-Item –path $targetNugetExe

    #remove xunit folder
    Remove-Item –path $workingDir'\xunit.runner.console.*' –recurse

    Write-host 'Done!'
    
    Get-Date -Format g
}

