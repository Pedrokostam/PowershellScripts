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
    [Parameter(Mandatory)]
    [string]
    $ModuleFolder,
    [Parameter()]
    [string]
    $NewRepoName = 'MyLocalPwshRepository'
)

$defaultRepoName = 'MyLocalPwshRepository'

$localRepos = Get-PSRepository | Where-Object SourceLocation -Match '[A-Z]:\\.*'

if ($localRepos) {
    $localRepo = $localRepo[0]
    $reponame = $localRepo.name
} else {
    if ($NewRepoName.Trim().Length -eq 0) {
        $NewRepoName = $defaultRepoName
    }
    $path = Resolve-Path ~
    $path = Join-Path $path $reponame
    Register-PSRepository -SourceLocation $path -Name $repoName -InstallationPolicy Trusted -Verbose
}
publish-module -Path $ModuleFolder -Verbose -Repository MyLocalRepository

