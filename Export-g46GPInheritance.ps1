function Export-g46GPInheritance {
    <#
    .Synopsis
    Export Group Policy inheritance details for a specified OU in a domain or multiple domains.
    .Description
    Export group policy inheritance for an OU. Will provide from the base level, and any policy linked above the OU.
    .Example
    Export-g46GPInheritance -Domains "domain.name.com" -OU "OU=Workstations,DC=domain,DC=name,DC=com"
    .Example
    Export-g46GPInheritance -Domains "domain.name.com","domain1.name.com" -OU "OU=Workstations,DC=domain,DC=name,DC=com"
    .Parameter Domains
    Single or multiple domains can be entered. Should be in FQDN format. If not entered, Out-GridView will present the domain names to choose from.
    .Parameter OU
    Single or multiple OUs can be entered. Should be in distinguished name format, DC portion can be omitted.
    #>

    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Domains,
        [Parameter(Mandatory = $true)]
        [string]$OU
    )

    #region Parameter Logic
    if (-not $Domains -or $Domains.Count -eq 0) {
        $Domains = (Import-CSV -Path $global:DomainsFile | Out-GridView -PassThru).Title
    }
    #endregion

    #region Declarations
    $FunctionName = $MyInvocation.MyCommand.Name
    $date = Get-Date -Format yyyyMMdd-HHmm
    if (-not $OutputDir) { $OutputDir = $pwd }
    $OutputFilePath = "$OutputDir\$FunctionName-$date.csv"
    $ResultsArray = @()
    #endregion

    #region Process Domains
    foreach ($domain in $Domains) {

    # Normalize OU
    if ($OU -notmatch '^.*DC=.*') {
        try {
            $DomainDN = (Get-ADDomain -Server $domain).DistinguishedName
        } catch {
            Write-Error "Error getting DistinguishedName for $($domain): $_"
            continue
        }
        $OUFull = "$OU,$DomainDN"
    } else {
        $OUFull = $OU
    }

    Write-Progress -Activity "Processing $domain" -Status "Analyzing OU: $OUFull"

    try {
        $gpInheritance = Get-GPInheritance -Target $OUFull -Domain $domain

        foreach ($link in $gpInheritance.InheritedGpoLinks) {
            $ResultsArray += [pscustomobject]@{
                DomainName   = $domain
                TargetOUPath = $gpInheritance.Path
                PolicyName   = $link.DisplayName
                OUPath       = $link.Target
                LinkOrder    = $link.Order
                LinkEnabled  = if ($link.Enabled) { "Yes" } else { "No" }
                LinkEnforced = if ($link.Enforced) { "Yes" } else { "No" }
                Inherited    = if ($link.Target -ne $gpInheritance.Path) { "Yes" } else { "No" }
            }
        }
    } 
    catch {
        Write-Error "Error processing OU $OUFull in domain $($domain): $_"
    }
}

    #endregion

    #region Results
    if ($ResultsArray.Count -gt 0) {
        $ResultsArray | Sort-Object DomainName, OUPath, LinkOrder | Export-Csv -Path $OutputFilePath -NoTypeInformation

        Write-Output "Output file created at $($OutputFilePath)."
    }
    else {
        Write-Warning "No results found to export."
    }
    #endregion
}
