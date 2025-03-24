function Export-SitetoZoneAssignments {
    <#
    .Synopsis
    Exports all Site to Zone Assignments to a CSV file.
    .Description
    Queries all GPOs in a domain(s) and then exports any Site To Zone Assignments to a CSV file.
    .Example
    Export-SitetoZoneAssignments -Domains "joeloveless.com"
    .Parameter Domains
    Enter the domain name or leave blank to utilize Out-GridView selection.
    #> 

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [array]$Domains
    )

    #region Parameter Logic
    if ($Domains.Count -eq 0) { $Domains = (Import-CSV -path $global:DomainsFile | Out-GridView -PassThru).Title }   
    #endregion

    #region Declarations
    $FunctionName = $MyInvocation.MyCommand.Name.ToString()
    $date = Get-Date -Format yyyyMMdd-HHmm
    if ($outputdir.Length -eq 0) { $outputdir = $pwd }
    $OutputFilePath = "$OutputDir\$FunctionName-$date.csv"
    $LogFilePath = "$OutputDir\$FunctionName-$date.log"
    $resultsArray = @()
    #endregion


    $registryPaths = @("HKCU\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMapKey",
        "HKLM\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMapKey")


    #region Get GPOs from specified domain(s)
    foreach ($domain in $domains) {
        Try {
            $GPOs = Get-GPO -All -Domain $Domain -ErrorAction Stop
        }
        Catch {
            Write-Error -Message "An error occured getting GPOs: $_"
        }
        #endregion 

        #region Build a psCustomObject
        foreach ($gpo in $GPOs) {
            foreach ($path in $registryPaths) {
                Try {
                    $regValue = Get-GPRegistryValue -name $GPO.DisplayName -FullKeyPath $path -Domain $domain -ErrorAction SilentlyContinue
                    #($regValue)
                    foreach ($value in $regValue) {
                        $result = New-Object -TypeName PSObject -Property @{
                            DomainName           = $domain
                            PolicyName           = $gpo.DisplayName
                            PolicyConfiguration  = if ($value.Hive -eq "LocalMachine") {"Computer Configuration"} elseif ($value.Hive -eq "CurrentUser") {"User Configuration"} else {$value.Hive}
                            ValueName            = $value.ValueName
                            Value                = $value.value
                        }
                        $ResultsArray += $result
                    }
                }
                Catch {
                    Write-Error -message "$($GPO): Error getting registry information : $_"
                }
            }
        }
        #endregion
    }
    #region Results
    if ($ResultsArray.Count -ge 1) {
        $ResultsArray | Select-Object DomainName, PolicyName, PolicyConfiguration, ValueName, Value | Sort-Object -Property DomainName, PolicyName | Export-Csv -Path $outputfilepath -NoTypeInformation
    }

    # Test if output file was created
    if (Test-Path $outputfilepath) {
        Write-Output "Output file = $outputfilepath."
    }
    else {
        Write-Warning -Message "No output file created."
    }
    #endregion
}
