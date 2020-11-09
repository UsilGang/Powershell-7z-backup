#######################################################################
# Author: Usil Gang
# 05-11-2018
#######################################################################
param ($var1, $var2, $var3, $var4)
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"

#Organization
$Org = "Your organization."

#Current full path, name and directory
$CurScriptPath = $script:MyInvocation.MyCommand.Path
$CurScriptName = [System.IO.Path]::GetFileNameWithoutExtension($CurScriptPath)
$CurScriptDir = [System.IO.Path]::GetDirectoryName($CurScriptPath)

#Full path log file
$LogPath = $CurScriptDir + "\" + $CurScriptName + "_$(Get-Date -format 'yyyyMMdd')"+".log"

#Get archicecture OS
$ArchOs = (Get-Process -Id $PID).StartInfo.EnvironmentVariables["PROCESSOR_ARCHITECTURE"];

#Path to 7zip exe file
$Prog7zipPath="C:\Program Files\7-Zip\7z.exe"
if((Test-Path -Path $Prog7zipPath -PathType 'Leaf') -eq $False){ 
	$Prog7zipPath="C:\Program Files (x86)\7-Zip\7z.exe"
	if((Test-Path -Path $Prog7zipPath -PathType 'Leaf') -eq $False){ 
				 
		Write-Host "install copy 7zip programm not found!" -f Red
		return
	}
}

#Return destination path archive
$DstPathArchive = @()

# Mail Message
$From = "sender@mail.ru"
$To = "receiver@mail.ru"
$SecureTextPassword = @()

#$SrcPath - Source path directory, variable must be with last slash '\'
#$DstPath - Destination path directory
function Backup {
Param(
        [Parameter(Mandatory = $True)]
		[ValidateScript({(Test-Path -Path $_ -PathType 'Leaf') -Or (Test-Path -Path $_)})]
        [String] $SrcPath,

        [Parameter(Mandatory = $True)]
        [ValidateScript({Test-Path -Path $_})]
        [String] $DstPath,
		
		[Parameter(Mandatory = $False)]
        [bool] $TypeBackup = $True,
		
		[Parameter(Mandatory = $False)]
        [bool] $HasSendMail = $False
    )
	
	Start-Transcript -path $LogPath
	Write-Host "Backup started at: $(Get-Date)" -f Yellow	
	
	# Add '\' to end path
	if($DstPath.EndsWith("\") -eq $False){ $DstPath=$DstPath+"\" }
	
	#Running backup with the selected parameter
	$IsCreateArchive = $False	
	if($TypeBackup -eq $True){
		$IsCreateArchive = DirectAccessBackup $SrcPath $DstPath
	} 
	else {
		$IsCreateArchive = ShadowCopyBackup $SrcPath $DstPath
	}
	Write-Host "Backup finished at: $(Get-Date)" -f Yellow
	Stop-Transcript	
		
	if($HasSendMail -eq $True){
		$SubjectMail = "$Org !!!"
		$MessageMail=@()
		If ($IsCreateArchive -eq $True){ 
			$Size = "{0:N2}" -f (Get-Item $global:DstPathArchive).length
			$MessageMail = "Create archive is success: $($global:DstPathArchive) Size: $($Size)"
		} Else {
			$MessageMail = "Create archive is failed: $($global:DstPathArchive)"
		}
		SendMail $SubjectMail $MessageMail $LogPath
	}
}

function DirectAccessBackup {
Param(
        [Parameter(Mandatory = $True)]
        [String] $SrcPath,

        [Parameter(Mandatory = $True)]
        [String] $DstPath
    )
	$ret=$False

	try {
		#Source and destination path archive
		Write-Host "Source path: $SrcPath" -f DarkCyan
		Write-Host "Destination path: $DstPath" -f DarkCyan
		#Build destination archive path 
		$global:DstPathArchive = $DstPath+$CurScriptName+"_$(Get-Date -format 'yyyy-MM-dd_HH-mm-ss').7z"
		Write-Host "Build destination archive path:" -f Yellow
		Write-Host "$global:DstPathArchive" -f DarkCyan
		
		#Create archive at shadow copy
		Write-Host "Create archive by direct access to files." -f Yellow
		
		# Get user credentials if required
		$SecurePassword = ConvertTo-SecureString $SecureTextPassword
		$CredentialPS = New-Object System.Management.Automation.PSCredential ('0', $SecurePassword)
		$pwd = $CredentialPS.GetNetworkCredential().Password
		$ret7z = $False
		$Arg = @('a','-t7z','-ssw','-mx7',"-p$($pwd)",'-r0',"`"$global:DstPathArchive`"","`"$SrcPath`"")
		#"Normal, Idle, High, RealTime, BelowNormal, AboveNormal"
		$Output = CreateProcess -ProcessPath $Prog7zipPath -ProcessArg $Arg -Priority BelowNormal
		if ($Output -match “Everything is Ok” ) {
			$ret7z = $True
			Write-Host $Output -f Yellow
		} else {
			Write-Host $Output -f Red
		}
		#Validation archive
		Write-Host "Validation archive." -f Yellow
		$FileExists = Test-Path $global:DstPathArchive
		If ($FileExists -eq $True){
			$ret=$True
			$Size = "{0:N2}" -f (Get-Item $global:DstPathArchive).length
			Write-Host "Create archive is success: $($global:DstPathArchive) Size: $($Size)" -f Green
		} Else {
			Write-Host "Create archive is failed: $($global:DstPathArchive)" -f Red
		}
	} catch {
		Write-Host "Error:$($error[0].Exception.Message) `r`nLine:$($error[0].InvocationInfo.ScriptLineNumber) `r`nSymbol:$($error[0].InvocationInfo.OffsetInLine) `r`nBlock:$($error[0].InvocationInfo.Line)"
	} finally {

	}
	[bool]$ret
}

function ShadowCopyBackup {
Param(
        [Parameter(Mandatory = $True)]
        [String] $SrcPath,

        [Parameter(Mandatory = $True)]
        [String] $DstPath
    )
	
	$ret=$False
	try {
		#Source and destination path archive
		Write-Host "Source path: $SrcPath" -f DarkCyan
		Write-Host "Destination path: $DstPath" -f DarkCyan
		
		#Check user privilage, need for running script 'Administrator' privilage
		$UserIdentity = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent())
		if (-not $UserIdentity.IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator'))
		{
			Write-Host 'You must running func from an elevated command prompt.' -f Red
		}
		else
		{
			Write-Host 'Running func from administrative privilage.' -f Green
		}
		
		#Save status VSS Service
		$VssRunning = (Get-Service -Name VSS).Status
		Write-Host "Save status VSS Service: $($VssRunning)" -f Yellow
		
		#Get path root
		$VssRootPath = [System.IO.Path]::GetPathRoot($SrcPath)
		Write-Host "Get root path '$($VssRootPath)' at '$($SrcPath)'" -f Yellow
		
		#Create new shadow copy
		$VssNewCopy = (gwmi -List Win32_ShadowCopy).Create($VssRootPath, "ClientAccessible")
		Write-Host "Create new shadow copy. Return value '$($VssNewCopy.returnvalue)'" -f Yellow
		if($VssNewCopy.returnvalue -ne 0) {
			switch($VssNewCopy.returnvalue)
			{
				1 {Write-Host "Access denied." -f Red; break}
				2 {Write-Host "Invalid argument." -f Red; break}
				3 {Write-Host "Specified volume not found." -f Red; break}
				4 {Write-Host "Specified volume not supported." -f Red; break}
				5 {Write-Host "Unsupported shadow copy context." -f Red; break}
				6 {Write-Host "Insufficient storage." -f Red; break}
				7 {Write-Host "Volume is in use." -f Red; break}
				8 {Write-Host "Maximum number of shadow copies reached." -f Red; break}
				9 {Write-Host "Another shadow copy operation is already in progress." -f Red; break}
				10 {Write-Host "Shadow copy provider vetoed the operation." -f Red; break}
				11 {Write-Host "Shadow copy provider not registered." -f Red; break}
				12 {Write-Host "Shadow copy provider failure." -f Red; break}
				13 {Write-Host "Unknown error." -f Red; break}
				default {break}
			}
			return
		}
		
		$VssObjId = $VssNewCopy.ShadowID
		$VssObj = gwmi Win32_ShadowCopy | ? { $_.ID -eq $VssObjId }
		$VssObjPath  = $VssObj.DeviceObject + "\"
		Write-Host "Win32_ShadowCopy.ShadowID: '$($VssObjId)'" -f DarkCyan
		Write-Host "Win32_ShadowCopy.DeviceObject: '$($VssObjPath)'" -f DarkCyan
		
		# Current path script in appdata 
		$CurAppDataPath=$env:APPDATA + "\" + $CurScriptName
		Write-Host "Build appdata path for symlink:" -f Yellow
		Write-Host "$CurAppDataPath" -f DarkCyan
		# If not found directory script in AppData
		Write-Host CMD /C "mkdir `"$CurAppDataPath`""  -f DarkCyan
		CMD /C "mkdir `"$CurAppDataPath`" && echo 1 || echo 0" | %{
			if($f -eq $null){
				if ($_ -match '1')    
				{ Write-Host "Create appdata directory is success." -f Green }    
				elseif ($_ -match '0')   
				{ Write-Host "Create appdata directory is failed." -f Red }   
				else    
				{ Write-Host $_ }
			}
			$f=@()
		}
		
		# Build phisical path to shadow copy object
		$VssSymlinkPath = $CurAppDataPath+"\"+ $VssObjId
		Write-Host "Build phisical path to shadow copy object:" -f Yellow
		Write-Host "$VssSymlinkPath" -f DarkCyan
		
		#Delete old symlink and create new symlink to shadow copy object
		Write-Host "Create new symlink to shadow copy object." -f Yellow
		Write-Host CMD /C "mklink /d `"$VssSymlinkPath`" `"$VssObjPath`"" -f DarkCyan
		CMD /C "mklink /d `"$VssSymlinkPath`" `"$VssObjPath`" && echo 1 || echo 0" | %{
			if($f -eq $null){
				if ($_ -match '1')    
				{ Write-Host "Create symlink is success." -f Green }    
				elseif ($_ -match '0')   
				{ Write-Host "Create symlink is failed." -f Red }   
				else    
				{ Write-Host $_ }
			}
			$f=@()
		}
		
		#Prepare source path and build fake source path
		$VssSourcePath = $SrcPath.Replace($VssRootPath,$VssSymlinkPath+"\")
		Write-Host "Prepare source path and build fake source path:" -f Yellow
		Write-Host "$VssSourcePath" -f DarkCyan 
		
		#Build destination archive path 
		$VssDestPath = $DstPath+$CurScriptName+"_$(Get-Date -format 'yyyy-MM-dd_HH-mm-ss').7z"
		$global:DstPathArchive = $VssDestPath
		Write-Host "Build destination archive path:" -f Yellow
		Write-Host "$VssDestPath" -f DarkCyan
		
		#Create archive at shadow copy
		Write-Host "Create archive at shadow copy." -f Yellow
		
		# Get user credentials if required
		$SecurePassword = ConvertTo-SecureString $SecureTextPassword
		$CredentialPS = New-Object System.Management.Automation.PSCredential ('0', $SecurePassword)
		$pwd = $CredentialPS.GetNetworkCredential().Password
		$ret7z = $False
		$Arg = @('a','-t7z','-ssw','-mx7',"-p$($pwd)",'-r0',"`"$VssDestPath`"","`"$VssSourcePath`"")
		
		#"Normal, Idle, High, RealTime, BelowNormal, AboveNormal"
		$Output = CreateProcess -ProcessPath $Prog7zipPath -ProcessArg $Arg -Priority BelowNormal
		if ($Output -match “Everything is Ok” ) {
			$ret7z = $True
			Write-Host $Output -f Yellow
		} else {
			Write-Host $Output -f Red
		}
		#Delete symlink shadow copy
		Write-Host "Delete symlink shadow copy." -f Yellow
		Write-Host CMD /C "rd /S /Q `"$VssSymlinkPath`"" -f DarkCyan 
		CMD /C "rd /S /Q `"$VssSymlinkPath`" && echo 1 || echo 0" | %{   
		   if ($_ -match '1')    
		   { Write-Host "Delete symlink is success." -f Green }    
		   elseif ($_ -match '0')   
		   { Write-Host "Delete symlink is failed." -f Red }   
		   else    
		   { Write-Host $_ }    
		}
		
		#Delete new shadow copy
		$VssObj.Delete()
		Write-Host "Delete $($VssObjId) new shadow copy." -f Yellow
		
		#Validation archive
		Write-Host "Validation archive." -f Yellow
		$FileExists = Test-Path $VssDestPath
		If ($FileExists -eq $True){ 
			$ret=$True
			$Size = "{0:N2}" -f (Get-Item $VssDestPath).length
			Write-Host "Create archive is success: $($VssDestPath) Size: $($Size)" -f Green
		} Else {
			Write-Host "Create archive is failed: $($VssDestPath)" -f Red
		}	
	} catch {
		Write-Host "Error:$($error[0].Exception.Message) `r`nLine:$($error[0].InvocationInfo.ScriptLineNumber) `r`nSymbol:$($error[0].InvocationInfo.OffsetInLine) `r`nBlock:$($error[0].InvocationInfo.Line)"
	} finally {
		#If VSS Service was stopped at start, return status 'Stopped'
		Write-Host "Restore status VSS Service:" -f Yellow
		if($VssRunning -eq "Stopped")
		{
			Stop-Service -Name VSS
		}
	}
	[bool]$ret
}

function CreateProcess {
	Param(
        [Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
        [String]
        $ProcessPath,
		
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
        [String[]]
        $ProcessArg,
		
		[Parameter(Mandatory = $False)]
		[System.Diagnostics.ProcessPriorityClass]
		$Priority = [System.Diagnostics.ProcessPriorityClass]::Normal
    )
	
	$Process = New-Object System.Diagnostics.Process
	$Process.StartInfo.FileName = $ProcessPath
	$Process.StartInfo.Arguments = $ProcessArg
	$Process.StartInfo.UseShellExecute = $False
	$Process.StartInfo.RedirectStandardOutput = $True
	$Process.Start() | out-null
	$Process.PriorityClass = $Priority #[System.Diagnostics.ProcessPriorityClass]::Idle;
	$Process.WaitForExit()
	$ProcessOutput = $Process.StandardOutput.ReadToEnd()
	#return value
	[string]$ProcessOutput
}

function SendMail {
	Param(
        [Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
        [String]
        $Subject,
		
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
        [String]
        $Body,
		
		[Parameter(Mandatory = $True)]
        [ValidatePattern('^[a-zA-Z]:\\(((?![<>:"\/\\|?*]).)+((?<![ .])\\)?)*$')]
        [String]
        $AttachmentPath
    )

	# Mail Message
	#$From = ""
	#$To = ""
	#$SecureTextPassword = ""

	# Mail Server Settings
	$Server = "smtp.mail.ru"
	$ServerPort = 465
	$Timeout = 30000          # timeout in milliseconds

	# Get user credentials if required
	$SecurePassword = ConvertTo-SecureString $SecureTextPassword
	$CredentialPS = New-Object System.Management.Automation.PSCredential ($From, $SecurePassword)

	# Load System.Web assembly
	[System.Reflection.Assembly]::LoadWithPartialName("System.Web") > $null
		
	# Create a new mail with the appropriate server settigns
	$Mail = New-Object System.Web.Mail.MailMessage
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/smtpserver", $Server)
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/smtpserverport", $ServerPort)
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/smtpusessl", $true)
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/sendusername", $CredentialPS.UserName)
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/sendpassword", $CredentialPS.GetNetworkCredential().Password)
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/smtpconnectiontimeout", $Timeout / 1000)
	# Use network SMTP server...
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/sendusing", 2)
	# ... and basic authentication
	$Mail.Fields.Add("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate", 1)

	# Set up the mail message fields
	$Mail.From = $From
	$Mail.To = $To
	$Mail.Subject = $Subject
	$Mail.Body = $Body

	# Convert to full path and attach file to message
	$AttachmentPath = (get-item $AttachmentPath).FullName
	$Attachment = New-Object System.Web.Mail.MailAttachment $AttachmentPath
	$Mail.Attachments.Add($Attachment) > $null

	# Send the message
	Write-Host "Sending email to $To..."
	try
	{
		[System.Web.Mail.SmtpMail]::Send($Mail)
		Write-Host "Message sent."
	}
	catch
	{
		Write-Error $_
		Write-Host "Message send failed."
	}
}

Backup -SrcPath $var1 -DstPath $var2 -TypeBackup $var3 -HasSendMail $var4													  
#Backup -SrcPath $args[0] -DstPath $args[1] -TypeBackup $args[2] -HasSendMail $args[3]
