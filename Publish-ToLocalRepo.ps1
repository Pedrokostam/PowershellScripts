<#
.Description
Publishes a folder to a local repository, if repository does not exist it will be created
.PARAMETER ModuleFolder
Path to a folder containing module files. Module name must match folder name.
.PARAMETER NewRepoName
Name to be used when creating a new repo. Will be ignored if a repo already exists
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory,ValueFromPipeline)]
    [string[]]
    $ModuleFolder,
    [Parameter()]
    [string]
    $NewRepoName = 'MyLocalPwshRepository'
)
begin{
	$defaultRepoName = 'MyLocalPwshRepository'

	$localRepos = Get-PSRepository | Where-Object SourceLocation -Match '[A-Z]:\\.*'

	if ($localRepos) {
	    $localRepo = $localRepos[0]
	    $NewRepoName = $localRepo.name
	} else {
	    if ($NewRepoName.Trim().Length -eq 0) {
	        $NewRepoName = $defaultRepoName
	    }
	    $path = Resolve-Path ~
	    $path = Join-Path $path $NewRepoName
    	New-item -itemtype Directory $path -Force
	    Write-Host "Creating local repo at $path"
	    $localRepo = Register-PSRepository -SourceLocation $path -Name $NewRepoName -InstallationPolicy Trusted -Verbose
	}
	Write-Host "Publish to $($localRepo.Name) ($($localRepo.SourceLocation))"
}
process{
	foreach($folder in $moduleFolder){
		publish-module -Path $Folder -Verbose -Repository $NewRepoName
	}
}
