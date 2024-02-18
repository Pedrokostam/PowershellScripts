[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $ModuleFolder,
    [Parameter()]
    [string]
    $NewRepoName = ''
)

$defaultRepoName = 'MyLocalPwshRepository'

$localRepos = Get-PSRepository | Where-Object SourceLocation -Match '[A-Z]:\\.*'

if ($localRepos) {
    $localRepo = $localRepo[0]
    $reponame = $localRepo.name
} else {
    if (-not $NewRepoName.Trim()) {
        $NewRepoName = $defaultRepoName
    }
    $path = Resolve-Path ~
    $path = Join-Path $path $reponame
    Register-PSRepository -SourceLocation $path -Name $repoName -InstallationPolicy Trusted -Verbose
}
publish-module -Path $ModuleFolder -Verbose -Repository MyLocalRepository

