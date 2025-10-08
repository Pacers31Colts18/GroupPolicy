function Export-GPOADMXSettings {
    <#
    .Synopsis
    Loops through either a folder or domain(s) and processes each ADMX file to gather data on the admx files.
    .Description
    Loops through either a folder or domain(s) and processes each ADMX file to gather data on the admx files.
    .Example
    Export-GPOADMXSettings -Domains "joeloveless.com"
    Export-GPOADMXSettings -Path "C:\temp\admx\access16.admx"
    .Parameter Domains
    Enter the domain name or leave blank to utilize Out-GridView selection.
    .Parameter Path
    Enter a folder path that contains ADMX files.
    #>
    Param(
        [Parameter(Mandatory = $false,
            HelpMessage = "Enter a path to the ADMX folder")]
        [string]$Path,
        [Parameter(Mandatory = $false,
            HelpMessage = "Provide a list of domains or leave blank to select interactively")]
        [array]$Domains
    )

    #region Declarations
    $FunctionName = $MyInvocation.MyCommand.Name.ToString()
    $date = Get-Date -Format yyyyMMdd-HHmm
    if ($outputdir.Length -eq 0) { $outputdir = $pwd }
    $OutputFilePath = "$OutputDir\$FunctionName-$date.csv"
    $LogFilePath = "$OutputDir\$FunctionName-$date.log"
    $ResultsArray = @()
    #endregion

    $targets = @()
    if ($Path) {
        $targets += [PSCustomObject]@{ Domain = "Local"; Path = $Path }
    }
    elseif (-not $Path) {
        if (-not $Domains -or $Domains.Count -eq 0) {
            if (-not $global:DomainsFile -or -not (Test-Path $global:DomainsFile)) {
                Write-Error "No domain file available and -Domains not specified."
                return
            }
            $Domains = (Import-Csv -Path $global:DomainsFile | Out-GridView -PassThru).Title
        }


        foreach ($domain in $Domains) {
            $domainPath = "\\$domain\SYSVOL\$domain\Policies\PolicyDefinitions"
            $targets += [PSCustomObject]@{ Domain = $domain; Path = $domainPath }
        }
    }
    else {
        Write-Error "No parameters."
        return
    }

    foreach ($target in $targets) {
        $domain = $target.Domain
        $admxPath = $target.Path

        Write-Output "Processing domain: $domain"
        Write-Output "ADMX path: $admxPath"

        if (-not (Test-Path $admxPath)) {
            Write-Warning "Path not found: $admxPath"
            continue
        }

        $admxFiles = Get-ChildItem -Path $admxPath -Filter "*.admx"
        foreach ($file in $admxFiles) {
            [xml]$admxContent = Get-Content -Path $file.FullName
            $valueName = $null
            $valueType = $null
            $categories = $admxcontent.policyDefinitions.categories.category.Name
            $supportedOn = $admxcontent.policyDefinitions.supportedOn.definitions.definition.name
            $policies = $admxcontent.policyDefinitions.policies.policy

            if ($policies.count -eq 0) {
                foreach ($category in $categories) {
                    $result = [PSCustomObject]@{
                        Domain      = $domain
                        GroupPolicy = ""
                        SettingName = ""
                        Class       = ""
                        Key         = ""
                        ValueName   = ""
                        ValueType   = ""
                        Category    = $category
                        SupportedOn = $supportedOn -join "; "
                        AdmxFile    = $file.Name
                    }
                    $resultsArray += $result
                }
            }
            else {
                foreach ($policy in $policies) {
                    $valueType = if ($policy.elements.list) { "List" }
                    elseif ($policy.enabledlist -and $policy.disabledList) { "Enabled/DisabledList" }
                    elseif ($policy.enabledList) { "EnabledList" }
                    elseif ($policy.disabledlist) { "DisabledList" }
                    elseif ($policy.enabledValue -and $policy.disabledValue) { "Enabled/DisabledValue" }
                    elseif ($policy.enabledValue) { "EnabledValue" }
                    elseif ($policy.disabledValue) { "DisabledValue" }
                    elseif ($policy.elements.text) { "TextBox" }
                    elseif ($policy.elements.multitext) { "MultiText" }
                    elseif ($policy.elements.decimal) { "Number" }
                    elseif ($policy.elements.enum) { "Dropdown" }
                    elseif ($policy.elements.boolean) { "Checkbox" }
                    else { "String" }
                    $valueName = if ($policy.valueName) { $policy.valueName }
                    elseif ($policy.Name) {$policy.Name }
                    else { "" }
                    $childNodeKey = if ($policy.enabledList.childnodes) { $policy.enabledList.ChildNodes.Key }
                    elseif ($policy.disabledList.childNodes) { $policy.disabledList.ChildNodes.Key }
                    elseif ($policy.elements.boolean) { $policy.elements.boolean.key }
                    elseif ($policy.elements.list) { $policy.elements.list.key }
                    elseif ($policy.elements.enum) { $policy.elements.enum.id }
                    elseif ($policy.elements.text) { $policy.elements.text.id }
                    elseif ($policy.elements.multitext) { $policy.elements.multitext.id }
                    else { "" }
                    $childNodeValue = if ($policy.enabledList.childnodes) { $policy.enabledList.ChildNodes.valueName }
                    elseif ($policy.disabledList.childNodes) { $policy.disabledList.ChildNodes.valueName }
                    elseif ($policy.elements.text) { $policy.elements.text.valueName }
                    elseif ($policy.elements.multitext) { $policy.elements.multitext.valueName }
                    elseif ($policy.elements.list) { $policy.elements.list.id }
                    elseif ($policy.elements.enum) { $policy.elements.enum.valueName }
                    elseif ($policy.elements.decimal) { $policy.elements.decimal.valueName }
                    elseif ($policy.elements.boolean) { $policy.elements.boolean.id }
                    elseif ($policy.enabledvalue.decimal -and $policy.disabledValue.decimal) { "Enabled: $($policy.enabledValue.decimal.value)" + "; Disabled: $($policy.disabledValue.decimal.value)" }
                    elseif ($policy.enabledValue.decimal) { "Enabled: $($policy.enabledValue.decimal.value)" }
                    elseif ($policy.disabledValue.decimal) { "Disabled: $($policy.disabledValue.decimal.value)" }
                    elseif ($policy.enabledValue.string) { "Enabled: $($policy.enabledValue.string)" }
                    elseif ($policy.disabledValue.string) { "Disabled: $($policy.disabledValue.string)" }
                    elseif ($policy.enabledValue.string -and $policy.disabledValue.string) { "Enabled: $($policy.enabledValue.string)" + "; Disabled: $($policy.disabledValue.string)" }
                    else { "" }
                    foreach ($childkey in $childNodeKey) {
                        foreach ($childValue in $childNodeValue) {
                            foreach ($name in $valueName) {
                                $result = [PSCustomObject]@{
                                    Domain         = $domain
                                    GroupPolicy    = "Yes"
                                    SettingName    = $policy.name
                                    Class          = $policy.class
                                    Key            = $policy.key
                                    ValueName      = $name
                                    ValueType      = $valueType
                                    ChildKey       = $childKey
                                    ChildValue     = $childValue
                                    Category       = $policy.parentCategory.ref -join "; "
                                    SupportedOn    = $policy.supportedOn.ref -join "; "
                                    AdmxFile       = $file.Name
                                }
                                $resultsArray += $result
                            }
                        }
                    }
                }
            }
        }
    }
    # Export results
    if ($ResultsArray.Count -ge 1) {
        $resultsArray | Select-Object Domain, SettingName, Class, Key, ValueName, ValueType, ChildKey, ChildValue, Category, SupportedOn, AdmxFile | Export-Csv -Path $OutputFilePath -NoTypeInformation
    }
    # Test if output file was created
    if (Test-Path $OutputFilePath) {
        Write-Output "Output file = $OutputFilePath."
    }
    else {
        Write-Warning "No output file created."
    }
    #endregion
}
