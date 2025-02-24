# https://github.com/actions/runner-images/blob/main/images/windows/scripts/helpers/PathHelpers.ps1

function Add-MachinePathItem {
    <#
    .SYNOPSIS
        Adds a new item to the machine-level PATH environment variable.

    .DESCRIPTION
        The Add-MachinePathItem function adds a new item to the machine-level PATH environment variable.
        It takes a string parameter, $PathItem, which represents the new item to be added to the PATH.

    .PARAMETER PathItem
        Specifies the new item to be added to the machine-level PATH environment variable.

    .EXAMPLE
        Add-MachinePathItem -PathItem "C:\Program Files\MyApp"

        This example adds "C:\Program Files\MyApp" to the machine-level PATH environment variable.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string] $PathItem
    )

    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $newPath = $PathItem + ';' + $currentPath
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
}