function Search-GPOCategory {
    <#
.SYNOPSIS
Searches Group Policy Objects (GPOs) across one or more domains for specified category names within policy settings.

.DESCRIPTION
This function generates GPO reports in XML format for the specified domains and searches for categories in Computer or User policy settings, based on the PolicyScope selected.
For each matching category, it outputs detailed metadata including setting name, state, GPO links, and security filters.

.PARAMETER Domains
An array of domain names to search against. If not provided, user can select from a predefined CSV domain list.

.PARAMETER Category
An array of partial or full category names to match within GPO settings.
Matches are performed with wildcard (`-like`) logic, so partial category names will match composite labels.

.PARAMETER PolicyScope
Defines which portion of GPOs to search:
- 'Computer' searches only computer-based settings.
- 'User' searches only user-based settings.
- 'All' searches both Computer and User scopes.

.EXAMPLE
Search-GPOCategory -Category "Microsoft Edge","SmartScreen" -PolicyScope All

This example searches for all GPO settings with categories that include "Microsoft Edge" or "SmartScreen" across both computer and user policy settings.

.OUTPUTS
Generates a CSV file containing:
- DomainName
- PolicyName
- PolicyStatus
- Category
- SettingName
- SettingState
- EnabledOULinks
- SecurityFiltering

.NOTES
- This function relies on `Get-GPOReport` and `Get-GPO` cmdlets, which require administrative privileges and RSAT installed.
- It assumes existence of a `$global:DomainsFile` CSV for dynamic domain selection if none are specified.
- Uses fuzzy matching for category identification (`-like`).

#>


    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [array]$Domains,
        [Parameter(Mandatory = $True, HelpMessage = "Category to search for")]
        [array]$Category,
        [ValidateSet('All', 'Computer', 'User')]
        [string]$PolicyScope = 'All'
    )

    #region Parameter Logic
    if ($Domains.Count -eq 0) { $Domains = (Import-CSV -path $global:DomainsFile | Out-GridView -PassThru).Title }
    #endregion

    #region Declarations
    $FunctionName = $MyInvocation.MyCommand.Name.ToString()
    $date = Get-Date -Format yyyyMMdd-HHmm
    if ($outputdir.Length -eq 0) { $outputdir = $pwd }
    $OutputFilePath = "$OutputDir\$FunctionName-$date.csv"
    $resultsArray = @() 
    $LogFilePath = "$OutputDir\$FunctionName-$date.log"
    #endregion

    #region Gather GPOs and Reports
    foreach ($domain in $domains) {
        Try {
            $GPOs = Get-GPO -All -Domain $domain -ErrorAction Continue
            Write-Output "Gathering GPOs from $domain"
        }
        Catch {
            Write-Error "Error getting GPOs from $domain : $_"
        }

        Write-Output "Gathering GPO Reports from $domain"
        foreach ($gpo in $gpos) {
            Try {
                [xml]$reportXML = Get-GPOReport -Guid $gpo.Id -ReportType XML -Domain $Domain -ErrorAction Stop
            }
            Catch {
                Write-Error "Error getting GPO Reports from $domain : $_"
            }
            #endregion
    
            switch ($PolicyScope) {
                'Computer' {
                    foreach ($item in $Category) {
                        Write-Output "Gathering Computer Settings for $item"
                        if ($reportXML.gpo.computer.extensiondata.extension.policy.category -like "*$item*") {
                            $gpoEnabledOULinks = ($reportXML.GPO.LinksTo | Where-Object { $_.Enabled -eq $true }).SomPath -Join ";"

                            if ([string]::IsNullOrEmpty($gpoEnabledOULinks)) {
                                continue
                            }
                            $gpoSecFilters = ($reportXML.gpo.SecurityDescriptor.Permissions.TrusteePermissions | Where-Object { $_.Standard.GPOGroupedAccessEnum -eq "Apply Group Policy" }).Trustee.Name.'#text' -Join ";"

                            foreach ($policy in $reportXML.gpo.computer.extensiondata.extension.policy) {
                                # Match only selected categories
                                if ($policy.category -like "*$item*") {
                                    $result = New-Object -TypeName PSObject -Property @{
                                        DomainName        = $domain
                                        PolicyName        = $gpo.DisplayName
                                        PolicyStatus      = $gpo.GpoStatus
                                        Category          = $policy.category
                                        Area              = $policyScope
                                        SettingName       = $policy.name
                                        SettingState      = $policy.state
                                        EnabledOULinks    = $gpoEnabledOULinks
                                        SecurityFiltering = $gpoSecFilters
                                    }
                                    $resultsArray += $result
                                }
                            }
                        }
                    }
                }
                'User' {
                    Write-Output "Gathering User settings for $item"
                    foreach ($item in $Category) {
                        if ($reportXML.gpo.user.extensiondata.extension.policy.category -like "*$item*") {
                            $gpoEnabledOULinks = ($reportXML.GPO.LinksTo | Where-Object { $_.Enabled -eq $true }).SomPath -Join ";"

                            if ([string]::IsNullOrEmpty($gpoEnabledOULinks)) {
                                continue
                            }
                            $gpoSecFilters = ($reportXML.gpo.SecurityDescriptor.Permissions.TrusteePermissions | Where-Object { $_.Standard.GPOGroupedAccessEnum -eq "Apply Group Policy" }).Trustee.Name.'#text' -Join ";"

                            foreach ($policy in $reportXML.gpo.user.extensiondata.extension.policy) {
                                # Match only selected categories
                                if ($policy.category -like "*$item*") {
                                    $result = New-Object -TypeName PSObject -Property @{
                                        DomainName        = $domain
                                        PolicyName        = $gpo.DisplayName
                                        PolicyStatus      = $gpo.GpoStatus
                                        Category          = $policy.category
                                        Area              = $policyScope
                                        SettingName       = $policy.name
                                        SettingState      = $policy.state
                                        EnabledOULinks    = $gpoEnabledOULinks
                                        SecurityFiltering = $gpoSecFilters
                                    }
                                    $resultsArray += $result
                                }
                            }
                        }
                    }
                }
                'All' {
                    Write-Output "Gathering All Settings for $item"
                    foreach ($item in $Category) {
                        if ($reportXML.gpo.user.extensiondata.extension.policy.category -like "*$item*") {
                            $gpoEnabledOULinks = ($reportXML.GPO.LinksTo | Where-Object { $_.Enabled -eq $true }).SomPath -Join ";"
                            if ([string]::IsNullOrEmpty($gpoEnabledOULinks)) {
                                continue
                            }
                            $gpoSecFilters = ($reportXML.gpo.SecurityDescriptor.Permissions.TrusteePermissions | Where-Object { $_.Standard.GPOGroupedAccessEnum -eq "Apply Group Policy" }).Trustee.Name.'#text' -Join ";"

                            foreach ($policy in $reportXML.gpo.user.extensiondata.extension.policy) {
                                # Match only selected categories
                                if ($policy.category -like "*$item*") {
                                    $result = New-Object -TypeName PSObject -Property @{
                                        DomainName        = $domain
                                        PolicyName        = $gpo.DisplayName
                                        PolicyStatus      = $gpo.GpoStatus
                                        Category          = $policy.category
                                        Area              = "User"
                                        SettingName       = $policy.name
                                        SettingState      = $policy.state
                                        EnabledOULinks    = $gpoEnabledOULinks
                                        SecurityFiltering = $gpoSecFilters
                                    }
                                    $resultsArray += $result
                                }
                            }
                        }
                        foreach ($item in $Category) {
                            if ($reportXML.gpo.computer.extensiondata.extension.policy.category -like "*$item*") {
                                $gpoEnabledOULinks = ($reportXML.GPO.LinksTo | Where-Object { $_.Enabled -eq $true }).SomPath -Join ";"
                                if ([string]::IsNullOrEmpty($gpoEnabledOULinks)) {
                                continue
                            }
                                $gpoSecFilters = ($reportXML.gpo.SecurityDescriptor.Permissions.TrusteePermissions | Where-Object { $_.Standard.GPOGroupedAccessEnum -eq "Apply Group Policy" }).Trustee.Name.'#text' -Join ";"

                                foreach ($policy in $reportXML.gpo.computer.extensiondata.extension.policy) {
                                    # Match only selected categories
                                    if ($policy.category -like "*$item*") {
                                        $result = New-Object -TypeName PSObject -Property @{
                                            DomainName        = $domain
                                            PolicyName        = $gpo.DisplayName
                                            PolicyStatus      = $gpo.GpoStatus
                                            Category          = $policy.category
                                            Area              = "Computer"
                                            SettingName       = $policy.name
                                            SettingState      = $policy.state
                                            EnabledOULinks    = $gpoEnabledOULinks
                                            SecurityFiltering = $gpoSecFilters
                                        }
                                        $resultsArray += $result
                                    }
                                }
                            }
                        }
                    }
                }
                default {
                    Write-Warning "Unknown PolicyScope value: $PolicyScope"
                }
            }

            # Append output to file
            if ($resultsArray.count -ge 1) {
                $resultsArray | Select-Object DomainName, PolicyName, PolicyStatus, Category, Area, SettingName, SettingState, EnabledOULinks, SecurityFiltering | Sort-Object -Property DomainName, PolicyName, Category | Export-Csv -Path $outputfilepath -NoTypeInformation -Append  
            }
        }

        # Test if results file was created
        If (Test-Path $outputfilepath) {
            Write-Output "Results found. Results file=$outputfilepath."
        }
        else {
            Write-Warning "No results found."
        }
    }
}
