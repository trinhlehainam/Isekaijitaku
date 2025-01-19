@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ImageHelpers.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

    # ID used to uniquely identify this module
    GUID = '850eca81-8971-4193-8796-8b1f8310c24c'

    # Author of this module
    Author = 'Gitea Action Runner Contributors'

    # Description of the functionality provided by this module
    Description = 'Helper functions for managing Windows build environment in Gitea Action Runner'

    # Minimum version of the Windows PowerShell engine required by this module
    # PowerShellVersion = ''

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = '*'

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = '*'

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = '*'

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the main website for this project.
            # ProjectUri = ''
        }
    }
}
