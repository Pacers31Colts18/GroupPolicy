#Requires -Version 3.0
#Requires -Modules GroupPolicy

function Copy-GPOLinks { 

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [string]$SourceOU = (Read-Host -Prompt 'Enter the Source OU'),
        [Parameter(Mandatory = $False)]
        [string]$TargetOU = (Read-Host -Prompt 'Enter the Target OU'),
        [Parameter(Mandatory = $False)]
        [string]$Domain = (Read-Host -Prompt 'Enter the domain name (FQDN)'))

    $source = Get-ADOrganizationalUnit -LDAPFilter '(name=*)' -SearchBase "$SourceOU" -SearchScope Subtree -Server $Domain
    $target =  Get-ADOrganizationalUnit -LDAPFilter '(name=*)' -SearchBase "$TargetOU" -SearchScope Subtree -Server $Domain
    

    Try {
   $linked = (Get-GPInheritance -Target $sourceOU -Domain $Domain).gpolinks
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Output $ErrorMessage
        Exit
    }


    # Loop through each GPO and link it to the target 
foreach ($link in $linked) 
{ 
    $guid = $link.GPOId 
    $order = $link.Order 
    $enabled = $link.Enabled 
    if ($enabled) 
    { 
        $enabled = "Yes" 
    } 
    else 
    { 
        $enabled = "No" 
    } 
    # Create the link on the target

    foreach ($OU in $TargetOU) {
    New-GPLink -Guid $guid -Target "$Target" -LinkEnabled $enabled -Order $order -confirm:$false -Domain $Domain -WhatIf
    }
}
   
    }
    
