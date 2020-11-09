#Created By U.G. 2018
#install script back_release.ps1
#powershell.exe -noexit -ExecutionPolicy Bypass -File install.ps1 %1 %2 %3
param ($var1, $var2, $var3)

function ParamToCharArray([string]$s){
	$($s.ToCharArray() | %{ $c=[string]$([int][char]$_); $s_out += $(if($s_out -eq $null){$c}else{"," + $c}) })
[string]$s_out
}
function CharArrayToParam([string]$s){
	$($s -Split ',') | %{ $s_out += $([char][int]$_) }
[string]$s_out
}

function SetFlagStartByAdministrator($file) {
	$bytes = [System.IO.File]::ReadAllBytes($file)
	$bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON (Use –bor to set RunAsAdministrator option and –bxor to unset)
	[System.IO.File]::WriteAllBytes($file, $bytes)
}

function CopyScriptInWorkDir([string] $path, [string] $name){
	# If not found directory script in AppData
	If ($(Test-Path $path) -eq $false) {
		CMD /C "mkdir `"$path`" && echo 1 || echo 0" | %{
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
	} 
	CMD /C "copy `"$name.ps1`" `"$path`" && echo 1 || echo 0" | %{
		if($f -eq $null){
			if ($_ -match '1')    
			{ Write-Host "Copy script is success." -f Green }    
			elseif ($_ -match '0')   
			{ Write-Host "Copy script is failed." -f Red }   
			else    
			{ Write-Host $_ }
		}
	$f=@()
	}
}	

function Install([string] $source, [string] $destination, [string] $password="12345678") {

	$NameScript = "backup_lite"
	$AppDataScriptPath=$env:APPDATA + "\" + $NameScript

	CopyScriptInWorkDir -path $AppDataScriptPath -name $NameScript
		
	$desktopPath = [Environment]::GetFolderPath("Desktop")
	$shtCutFile = "$desktopPath\Àðõèâàöèÿ.lnk"
	If (Test-Path $shtCutFile) {
		Remove-Item $shtCutFile
	}

	Write-Host "Create shortcut script is success." -f Green
	$scrFile = "$($AppDataScriptPath)\$($NameScript).ps1"
	$exePath = "$((Get-Process powershell | select -First 1).Path)"
	$exeArgs = "-ExecutionPolicy Bypass -File `"$scrFile`" `"$source`" `"$destination`" `"1`""
	$objWsh = New-Object -comObject Wscript.Shell
	$objShtCut = $objWsh.CreateShortcut($shtCutFile)
	$objShtCut.TargetPath = $exePath
	$objShtCut.Arguments = $exeArgs
	$objShtCut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($script:MyInvocation.MyCommand.Path)
	$objShtCut.IconLocation = "%windir%\\system32\\shell32.dll,238"
	$objShtCut.Save()

	SetFlagStartByAdministrator -file $shtCutFile
	Write-Host "Create script 'js' for silent start 'ps'" -f Green
	"var shell = WScript.CreateObject('WScript.Shell');"  | Out-File "$AppDataScriptPath\run.js"
	"shell.Run(`"$($exePath.Replace('\','\\')) $($exeArgs.Replace('\','\\').Replace('"','\"'))`",0,true);"| Out-File "$AppDataScriptPath\run.js" -Append

	$date = Get-Date
	$hhmmss = $date.ToString('hh:mm:ss')
	$hhmmss = '12:00:00'
	$user = $env:UserDomain+"\"+$env:UserName
	CMD /C "SCHTASKS /Create /RU "$user" /IT /SC weekly /D fri /TN Archive /TR `"$AppDataScriptPath\run.js`" /ST $hhmmss /V1 /F && echo 1 || echo 0" | %{
			if($f -eq $null){
				if ($_ -ne '0')    
				{ Write-Host "Create shedule is success." -f Green }    
				elseif ($_ -eq '0')   
				{ Write-Host "Create shedule is failed." -f Red }   
				else    
				{ Write-Host $_ }
			}
		$f=@()
		}
		
	Write-Host "Set password for archive" -f Green
	$password = $password | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
	Write-Host "Create TMP script file" -f Green
	CMD /C "copy `"$AppDataScriptPath\$NameScript.ps1`" `"$AppDataScriptPath\$NameScript.tmp`" && echo 1 || echo 0" | %{
			if($f -eq $null){
				if ($_ -match '1')    
				{ Write-Host "Copy script .tmp is success." -f Green }    
				elseif ($_ -match '0')   
				{ Write-Host "Copy script .tmp is failed." -f Red }   
				else    
				{ Write-Host $_ }
			}
		$f=@()
		}
	Write-Host "Change script file" -f Green
	Get-Content "$AppDataScriptPath\$NameScript.tmp" | % {
		$_ -replace '^\$SecureTextPassword = \@\(\)$',"`$SecureTextPassword = `"$password`""
	} | Set-Content "$AppDataScriptPath\$NameScript.ps1"
	Write-Host "Delete TMP script file" -f Green
	CMD /C "del /F /Q `"$AppDataScriptPath\$NameScript.tmp`" && echo 1 || echo 0" | %{
			if($f -eq $null){
				if ($_ -match '1')    
				{ Write-Host "Delete script .tmp is success." -f Green }    
				elseif ($_ -match '0')   
				{ Write-Host "Delete script .tmp is failed." -f Red }   
				else    
				{ Write-Host $_ }
			}
		$f=@()
		}
}

Install -source $var1 -destination $var2 -password $var3