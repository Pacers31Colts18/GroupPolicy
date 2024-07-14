Function Promote-GPO {
<#
.Synopsis
   Move settings from one section to another
.DESCRIPTION
   Promotes GPO settings between environments and backs up all settings for easy rollback.
.EXAMPLE
  Promote-GPO -BaseGPO 'GPO Name' -Promotion Dev to Test
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
    [CmdletBinding()]

    Param (
        # Base GPO name
        [Parameter(Mandatory=$True,
                    ValueFromPipeline=$False,
                    HelpMessage="Enter the Base GPO name.")]
        [ValidateNotNullorEmpty()]
        [String]$BaseGPO,

         
        # Promotion
        [Parameter(Mandatory=$True,
                    ValueFromPipeline=$False,
                    HelpMessage="Enter the promotion route.")]
        [ValidateSet('Dev to Test' , 'Test to Prod' , IgnoreCase = $True)]
        [String]$Promotion    

)


    Begin {

        # Check for the ActiveDirectory module and try to load it if needed.  
        If (-Not (Get-Module | Select-Object -expand name).contains("ActiveDirectory")) {
            Try {Import-Module ActiveDirectory -ErrorAction Stop}
            Catch {Throw "Unable to load ActiveDirectory module"}
        }
    
    }

    Process {
        $ErrorActionPreference = 1

        $DevPath = '\\backuplocation\dev$'
        $TestPath = '\\backuplocation\test$'
        $ProdPath = '\\backuplocation\prod$'
       

        if($Promotion -match 'Dev to test'){
            $GPO1 = $BaseGPO + '-dev'
            $GPO2 = $BaseGPO + '-test'
            backup-gpo -Name $GPO1 -Path $DevPath
            backup-gpo -Name $GPO2 -Path $TestPath
            import-gpo -TargetName $GPO2 -BackupGpoName $GPO1 -Path $devpath
            Get-GPOReport -Name $GPO2 -ReportType Html -Path "\\backuplocation\dev\$GPO1.html"
            Get-GPOReport -Name $GPO2 -ReportType Html -Path "\\backuplocation\test\$GPO2.html"
            Send-MailMessage -from "EMAIL ADDRESS" -To "EMAIL ADDRESS" -Subject "$baseGPO  'has been promoted from dev to test.'" -Body "Please be aware of any issues and report them as soon as they are verified. All changes are logged in the Workstation GPO Change Log file under the Client Engineering documents folder: LOCATION HERE" -SmtpServer 'SMPT Server Address'

        }

        else{
            $GPO1 = $BaseGPO + '-test'
            $GPO2 = $BaseGPO + '-prod'
            backup-gpo -Name $GPO1 -Path $TestPath
            backup-gpo -Name $GPO2 -Path $ProdPath
            import-gpo -TargetName $GPO2 -BackupGpoName $GPO1 -Path $testpath
            Get-GPOReport -Name $GPO2 -ReportType Html -Path "\\backuplocation\test\$GPO1.html"
            Get-GPOReport -Name $GPO2 -ReportType Html -Path "\\backuplocation\prod\$GPO2.html"
            Send-MailMessage -from "EMAIL ADDRESS" -To "EMAIL ADDRESS" -Subject "$baseGPO  'has been promoted from dev to test.'" -Body "Please be aware of any issues and report them as soon as they are verified. All changes are logged in the Workstation GPO Change Log file under the Client Engineering documents folder: LOCATION HERE" -SmtpServer 'SMPT Server Address'


        }
     
    }
    
    End {
    }
}

