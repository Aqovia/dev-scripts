function aqovia-nuget-update{
    <#
    .SYNOPSIS
    Updates or removes a nuget package version in child working directories.

    .DESCRIPTION
    The Aqovia-Nuget-Update function updates or removes a nuget package version in packages.config files recursively in working directory. Hence, working directory should be the parent directory for all local repositories. After updating packages config files, it restores nuget packages in solution level and builds solutions, runs unit tests. It uses msbuild.exe to build solutions and xunit.console.x86.exe to run unit tests. It downloads nuget.exe and xunit.console.x86.exe temporarirly into working directory and deletes after finishing its work. If there are any exceptions on build or on tests run, the script exists with code 1 and throws exception list.If build and tests run are succeeded, then it creates new git branch with given branch name, chekouts new branch and commits changes.
    
    .PARAMETER packageName 
    The name of the package that is wanted to change its version.

    .PARAMETER targetVersion
    The new version of the package.

    .PARAMETER branchName
    The name of the branch which is used for pushing changes to remote.

    .PARAMETER updateOrRemove
    add or remove the nuget package. valid values : add, update, remove

    .PARAMETER pushToRemove
    push changes to remote branch. valid values : y, Y, n, N

    .PARAMETER build
    build and test. valid values : y, Y, n, N

    .EXAMPLE
    Working Directory: E:\dev\Interxion
    Aqovia-Nuget-Update -packageName Powershell.Deployment -targetVersion 1.2.5.0 -branchName Update-PowershellDeployment-nuget-package -updateOrRemove update -pushToRemove N -build N

    .NOTES
    You need to run this function as administrator.
    #>
    [CmdletBinding()]
    Param(
       [Parameter(Mandatory=$True,Position=1)]
       [string]$packageName,
	
       [Parameter(Mandatory=$False)]
       [string]$targetVersion,
	
       [Parameter(Mandatory=$True)]
       [string]$branchName,

       [Parameter(Mandatory=$True)]
       [string]$updateOrRemove,

       [Parameter(Mandatory=$True)]
       [string]$pushToRemote,

       [Parameter(Mandatory=$True)]
       [string]$build
    )

    # validate input
    if($targetVersion -eq "" -and $updateOrRemove -eq "update")
    {
        Write-Host "If -updateOrRemove = update, then you must supply a -targetVersion"
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

        $solutionFile = Get-ChildItem $path -Filter *.sln -ErrorAction SilentlyContinue -Force

        $packageConfigFiles = Get-ChildItem $path -Recurse -Filter packages.config -ErrorAction SilentlyContinue -Force

        $projectConfigFilesCore = Get-ChildItem $path -Recurse -Filter *.csproj -ErrorAction SilentlyContinue -Force | Where-Object {(Select-String -InputObject $_ -Pattern 'PackageReference' -Quiet) -eq $true}

        $projectConfigFilesStandard = Get-ChildItem $path -Recurse -Filter *.csproj -ErrorAction SilentlyContinue -Force | Where-Object {(Select-String -InputObject $_ -Pattern '<Reference Include=' -Quiet) -eq $true}

        #if there is a packages.config or project config files with package references, and if there is a git repo
        if( ((($packageConfigFiles | measure).Count -gt 0) -or (($projectConfigFiles | measure).Count -gt 0)) -and (Test-Path -path $fullPath'\.git')){
            
            #fetch and checkout master
            Write-host 'fetch and checkout master for' $path '...'

            $gitBranch = (((git -C $fullPath status) -split '\n')[0]).Substring(10)

            if($gitBranch -ne $branchName){

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

            Push-Location $fullPath

            if($updateOrRemove -eq "update"){

                Write-Host "Restoring .NET Standard projects"
                ..\nuget restore $solutionFile.Name

                Write-Host "Update .NET Standard projects"
                ..\nuget update $solutionFile.Name -Id $packageName -Version $targetVersion

                Write-Host "Update .NET Core projects"
                $projectConfigFilesCore | ForEach-Object {

                    $configFile = $_.FullName

                    $xmlFile = (Get-Content $configFile) -as [Xml]

                    if($xmlFile.project.itemgroup.packagereference.include -contains $packageName)
                    {
            
                        Push-Location $_.DirectoryName

                        dotnet add package $packageName -v $targetVersion

                        Pop-Location
                    
                    }
            
                }
            }

            if($updateOrRemove -eq "remove"){

                #change packages.config files
                $packageConfigFiles | ForEach-Object {

                    $configFile = $_.FullName

                    $xmlFile = (Get-Content $configFile) -as [Xml]

                    foreach($package in $xmlFile.packages.package) {
                        if ($package.id -eq $packageName){
                            
                            $package.ParentNode.RemoveChild($package)
                            
                            Write-Host "saving nuget packages.config file..." -ForegroundColor green
                            $xmlFile.PreserveWhitespace = $true
                            $xmlFile.Save($configFile)
                            $hasUpdate = $true

                        }
                    }
                }
                
                #change csproj standard files - for removal
                $projectConfigFilesStandard | ForEach-Object {

                    $configFile = $_.FullName

                    $xmlFile = (Get-Content $configFile) -as [Xml]

                    foreach($package in $xmlFile.project.itemgroup.reference) {
                        if(($package.include -split ',' | Where({$_.Trim() -eq $packageName}) | measure).Count -gt 0){

                            $package.ParentNode.RemoveChild($package)
                            Write-Host "saving csproj file $configFile" -ForegroundColor green
                            $xmlFile.PreserveWhitespace = $true
                            $xmlFile.Save($configFile)
                            $hasUpdate = $true

                        }
                    }
                }
                
                #change csproj core files
                $projectConfigFilesCore | ForEach-Object {
                    
                    $configFile = $_.FullName

                    $xmlFile = (Get-Content $configFile) -as [Xml]

                    foreach($package in $xmlFile.project.itemgroup.packagereference) {
                        if ($package.include -eq $packageName){
                            
                            $package.ParentNode.RemoveChild($package)
                            Write-Host "saving csproj file $configFile" -ForegroundColor green
                            $xmlFile.Save($configFile)
                            $hasUpdate = $true

                        }
                    }
                }                               
            }

            Pop-Location

            if($build -match "[yY]")
            {

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


            if($gitBranch -ne $branchName){
                Write-host 'check out branch' $branchName 'for' $path '...'
                git -C $fullPath checkout -B $branchName
            }

            #commit
            Write-host 'commit changes for' $path '...'
            if($updateOrRemove -eq "update")
            {
                $message = 'Updated package: '+$packageName+' version to '+$targetVersion
            }
            if($updateOrRemove -eq "remove")
            {
                $message = 'Removed package: '+$packageName
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

    #remove nuget.exe
    Remove-Item –path $targetNugetExe

    #remove xunit folder
    Remove-Item –path $workingDir'\xunit.runner.console.*' –recurse

    Write-host 'Done!'
    
    Get-Date -Format g
}
