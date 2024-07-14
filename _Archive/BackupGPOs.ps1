<# 
.SYNOPSIS
    Executes Group Policy backup commands.

.DESCRIPTION
    Executes Group Policy backup commands. Saves backups to specified Filepath.

.PARAMETER Domain
    Set domain value; default value [acme.com].
    -Domain contoso.acme.com

.PARAMETER Comment
    Set comment value; default value [Monthly Group Policy Backup].
    -Comment "Weekly GPO Backup"

.PARAMETER FilePath
    Set backup filepath value; default value [\\server01\Enterprise_Services\GPO Backup].
    -FilePath "\\Server01\Enterprise_Services\GPO Backup" 
    
.PARAMETER GPO
    Set specific GPO displayname to backup; if GPO isn't set, default is all GPO's.
    -GPO "SomeGPO", "OtherGPO" 
    
.PARAMETER FolderName
    Set specific folder name within the backup directory; default value is current date.
    -FolderName "TempBackup"

.EXAMPLE
    .\Script.ps1
    Connects to default domain, begins backup of all GPOs to $FilePath (default).

.EXAMPLE
    .\Script.ps1 -Domain acme.com -Comment "Weekly GPO Backup" -FilePath '\\Server01\Weekly Backups'
    Connects to acme.com domain; begins backup of all GPOs to $FilePath (default); changes comment to "Weekly GPO Backup"; 
    changes backup filepath to \\Server01\Weekly Backups.

.EXAMPLE
    .\Script.ps1 -GPO "PowerShell Policy" -FolderName TestFolder
    Connects to acme.com domain; backup [PowerShell Policy] object to [\\server01\Enterprise_Services\GPO Backup\TestFolder].
    
.NOTES
    Written by JBear 6/14/17	
#>

param(
    
    [Parameter(ValueFromPipeline=$true)]
    [String]$Domain = "acme.com",

    [Parameter(ValueFromPipeline=$true)]
    [String]$Comment = 'Monthly Group Policy Backup',

    [Parameter(ValueFromPipeline=$true)]
    [String]$FilePath = '\\server01\Enterprise_Services\GPO Backup',

    [Parameter(ValueFromPipeline=$true)]
    [String[]]$GPO,

    [Parameter(ValueFromPipeline=$true)]
    [String]$FolderName = (Get-Date -Format yyyyMMdd),

    #New directory by date
    $LogPath = "$($FilePath)\$($FolderName)",

    #Backup log path
    $PolicyLog = "$LogPath\PolicyBackupLog.txt"
)

#Import GroupPolicy Module
Try {

    Import-Module GroupPolicy -ErrorAction Stop
}

#Unable to load GroupPolicy Module; ensure it is enabled
Catch {

    Write-Error $_
    Break
}

#Create new directory for today's date within specified $FilePath
New-Item -ItemType Directory -Path $LogPath -ErrorAction SilentlyContinue

#If GPO values are not specified, default to ALL GPO's
if(!($GPO)) {

    Backup-GPO -Domain $Domain -All -Path $LogPath -Comment $Comment -ErrorAction SilentlyContinue | Out-File $PolicyLog -Append -Force
}

else {

    $i=0
    $j=0

    foreach($Obj in $GPO) {

        Write-Progress -Activity "Backing up Group Policies..." -Status ("Percent Complete:" + "{0:N0}" -f ((($i++) / $GPO.count) * 100) + "%") -CurrentOperation "Processing $($Obj)..." -PercentComplete ((($j++) / $GPO.count) * 100)

        #Backup each object in $GPO
        Backup-GPO -Domain $Domain -Name $Obj -Path $LogPath -Comment $Comment -ErrorAction SilentlyContinue | Out-File $PolicyLog -Append -Force
    }
}
