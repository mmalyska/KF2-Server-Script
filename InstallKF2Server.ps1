Param(
[string]$option
)

function KF2Server-Install()
{
    function Select-Folder($message='Select a folder', $path = 0) 
    { 
        $object = New-Object -comObject Shell.Application  
     
        $folder = $object.BrowseForFolder(0, $message, 0, $path) 
        if ($folder -ne $null) { 
            $folder.self.Path 
        } 
    } 
    function Extract-Zip($file)
    {
        $dest = (Get-ChildItem $file | Select-Object Directory).Directory.FullName
        [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | out-null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $dest)
    }
    function Get-ShortcutPath($shortcut)
    {
        $WshShell = New-Object -ComObject WScript.Shell;
        $WshShell.CreateShortcut($shortcut).TargetPath
    }
    function Preapare()
    {
        $SteamCMDNotSelected = $false
        $SteamCMDUri = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip'
    
        write-host 'Do you want to choose folder where to install server?'
        Write-Host "Yes/Y - Let's you choose folders"
        Write-Host "Press Enter to install in script folder"
        $option = Read-Host 
        switch -Regex ($option)
        {
            "(Yes)|(y)" 
            {
                $InstallPath = Select-Folder -mess 'Select KF2ServerFolder'
                if($InstallPath -eq $null)
                {
                 write-host 'You did not selected install folder. Setup is stopping.'
                 Write-Host 'Press any key to exit.'
                 Read-Host
                 Exit
                }
                $SteamCMDPath = Select-Folder -mess 'Select SteamCMD folder'
                if($SteamCMDPath -eq $null)
                {
                    $SteamCMDPath = $InstallPath + '\SteamCMD'
                    $SteamCMDNotSelected = $true
                }
            }
            default
            {
                $InstallPath = $MyInvocation.PSScriptRoot + '\KF2Server'
                $SteamCMDPath = $MyInvocation.PSScriptRoot + '\SteamCMD'
                $SteamCMDNotSelected = $true
           }
        }
        $global:InstallPath = $InstallPath
        $global:SteamCMDPath = $SteamCMDPath
    
        if ($SteamCMDNotSelected -eq $true)
        {
            if ( -Not (Test-Path $global:SteamCMDPath))
            {
                New-Item $global:SteamCMDPath -Force -ItemType directory | out-null
            }
            $dest = $global:SteamCMDPath + '\steamcmd.zip'
            Write-Host 'Downloading SteamCMD'
            Invoke-WebRequest -uri $SteamCMDUri -OutFile $dest
            Unblock-File $dest
            Write-Host 'Unzipping SteamCMD'
            Write-Host "Please unzip steamcmd.zip in $global:SteamCMDPath"
            Write-Host 'Make sure, that exe is in same directory as zip.'
            Write-Host 'Press Enter to open folder containing zip file.'
            Read-Host
            Invoke-Item $global:SteamCMDPath
            Write-Host 'When you finish please press Enter to continue.'
            Read-Host
            Remove-Item -Force $dest
        }
        if(!(Test-Path("$global:SteamCMDPath\steamcmd.exe")))
        {
            Write-Host 'Cannot find steamcmd.exe'
            Write-Host 'Please check if you extracted exe correctly and run Setup again.'
            Write-Host 'Press Enter to finish.'
            Read-Host
            Exit
        }
        Write-Host 'Creating server directory'
        $serverPath = $global:InstallPath + '\Server'
        if ( -Not (Test-Path $serverPath))
        {
            New-Item $serverPath -Force -ItemType directory | out-null
        }
        Write-Host 'Creating SteamCMD scripts'
        $configsPath = $global:InstallPath + '\Configs'
        if ( -Not (Test-Path $configsPath))
        {
            New-Item $configsPath -Force -ItemType directory | out-null
        }
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut("$configsPath\steamcmd.lnk")
        $shortcut.TargetPath = "$global:SteamCMDPath\steamcmd.exe"
        $shortcut.IconLocation = "$global:SteamCMDPath\steamcmd.exe"
        $shortcut.WorkingDirectory = "$global:SteamCMDPath"
        $shortcut.StartIn
        $shortcut.Save()
    }
    function Run()
    {
        Write-Host 'Downloading KF2Server'
        Copy-Item $MyInvocation.PSCommandPath "$global:InstallPath\KF2Server.ps1"
        New-Item "$global:InstallPath\Start.bat" -Force -ItemType file -Value "@ECHO OFF `r`nPowerShell -NoProfile -ExecutionPolicy Bypass -Command ""& '%~dp0KF2Server.ps1' -option Run"""
        $runEXE = Get-ShortcutPath("$global:InstallPath\Configs\steamcmd.lnk")
        $serverPath = $global:InstallPath + "\Server"
        $steamCMDOptions += "+login anonymous "
        $steamCMDOptions += "+force_install_dir $serverPath "
        $steamCMDOptions += "+app_update 232130 validate "
        $steamCMDOptions += "+exit "
            
        Invoke-Expression "$runEXE $steamCMDOptions"    
    }
    function PostInstall()
    {
        #install redista
        Clear-Host
        Write-Host 'We need to install UE3Redist, press Enter to continue...'
        Read-Host
        Invoke-Expression "$global:InstallPath\Server\Binaries\Redist\UE3Redist.exe"
        Write-Host 'After installation of UE3Redist press Enter to continue...'
        Read-Host
        #Run server once
        Clear-Host 
        Write-Host 'Now we need to run server once to generate files.'
        Write-Host 'Starting server for the first time. Press Enter to start server...'
        Read-Host
        Invoke-Expression "$global:InstallPath\Server\Binaries\win64\kfserver kf-bioticslab?adminpassword=123"
        Write-Host 'After it finished starting please stop and close it. Press Enter after that step is complete.'
        Read-Host
        Write-Host 'No we are done with preparations of server.'
        Write-Host 'Use shortcut on desktop to start/update server.'
        #
        $shell = New-Object -ComObject WScript.Shell
        $desktop = $shell.SpecialFolders.Item('Desktop')
        $shortcut = $shell.CreateShortcut("$desktop\KF2 Server.lnk")
        $shortcut.TargetPath = "$global:InstallPath\Start.bat"
        $shortcut.IconLocation = $global:InstallPath + '\Server\Binaries\Win64\KFServer.exe,1'
        $shortcut.WorkingDirectory = "$global:InstallPath"
        $shortcut.StartIn
        $shortcut.Save()
    }
    $global:InstallPath
    $global:SteamCMDPath
    Preapare
    Run
    PostInstall
    Write-Host
    Write-Host "Installation is complete."
    Write-Host "Press any key to exit."
    Read-Host
}
function KF2Server-Run()
{
    function Select-Folder($message='Select a folder', $path = 0) 
    { 
        $object = New-Object -comObject Shell.Application  
         
        $folder = $object.BrowseForFolder(0, $message, 0, $path) 
        if ($folder -ne $null) { 
            $folder.self.Path 
        } 
    }
    function Get-ShortcutPath($shortcut)
    {
        $WshShell = New-Object -ComObject WScript.Shell;
        $WshShell.CreateShortcut($shortcut).TargetPath
    }
    function KF2Server-Start()
    {
        function SelectMap()
        {
            Write-Host "Map selection option"
            Write-Host "1) Burning Paris(default)"
            Write-Host "2) Bioticslab"
            Write-Host "3) Outpost"
            Write-Host "4) Volter Manor"
            Write-Host "5) Catacombs"
            Write-Host "6) Evacuation Point"
            Write-Host "or press Enter to select default."
            [int]$mapOption = Read-Host -Prompt "Select map"
    
            switch($mapOption)
            {
                "1" {"KF-BurningParis"}
                "2" {"KF-Bioticslab"}
                "3" {"KF-Outpost"}
                "4" {"KF-VolterManor"}
                "5" {"KF-Catacombs"}
                "6" {"KF-EvacuationPoint"}
                default {"KF-BurningParis"}
            }
        }
        function SelectConfig()
        {
            Write-Host "Input config name."
            Write-Host "or press Enter to use default name('ServerDefault')"
            $configName = Read-Host -Prompt "Enter name"
            if(!$configName)
            {
                $configName = "ServerDefault"
            }
            $configName
        }
        Clear-Host
        $map = SelectMap
        Write-Host
        $config = SelectConfig
        Write-Host
    
        Invoke-Expression ".\Server\Binaries\win64\kfserver $map ConfigSubDir=..\..\..\Configs\$config"
    }
    function KF2Server-Update()
    {
        Clear-Host
        $scriptPath = $MyInvocation.PSScriptRoot 
        $serverPath = $scriptPath + "\Server"
        $steamCMDOptions += "+login anonymous "
        $steamCMDOptions += "+force_install_dir $serverPath "
        $steamCMDOptions += "+app_update 232130 "
        $steamCMDOptions += "+exit "
    
        $runEXE = Get-ShortcutPath("$scriptPath\Configs\steamcmd.lnk")
        Write-Host $runEXE
        Invoke-Expression "$runEXE $steamCMDOptions"
        Menu
    }
    function KF2Server-Validate()
    {
        Clear-Host
        $scriptPath = $MyInvocation.PSScriptRoot 
        $serverPath = $scriptPath + "\Server"
        $steamCMDOptions += "+login anonymous "
        $steamCMDOptions += "+force_install_dir $serverPath "
        $steamCMDOptions += "+app_update 232130 validate "
        $steamCMDOptions += "+exit "
    
        $runEXE = Get-ShortcutPath("$scriptPath\Configs\steamcmd.lnk")
        Write-Host $runEXE
        Invoke-Expression "$runEXE $steamCMDOptions"
        Menu
    }
    function Select-SteamCMD()
    {
        Clear-Host
        $SteamCMDPath = Select-Folder -mess 'Select SteamCMD folder'
        if($SteamCMDPath -eq $null)
        {
            write-host 'You did not selected SteamCMD folder. Selecting is stopping.'
            Write-Host 'Press any key to exit.'
            Read-Host
            Exit
        }
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut(".\Configs\steamcmd.lnk")
        $shortcut.TargetPath = "$SteamCMDPath\steamcmd.exe"
        $shortcut.IconLocation = "$SteamCMDPath\steamcmd.exe"
        $shortcut.StartIn
        $shortcut.Save()
        Menu
    }
    function Menu()
    {
        Clear-Host
        Write-Host "1) Start(default)"
        Write-Host "2) Update"
        Write-Host "3) Validate"
        Write-Host "4) ReSelect SteamCMD location"
        Write-Host "or press Enter to select default."
        [int]$serverOption = Read-Host -Prompt "Select action"
    
        switch($serverOption)
        {
            "1" {KF2Server-Start}
            "2" {KF2Server-Update}
            "3" {KF2Server-Validate}
            "4" {Select-SteamCMD}
            default {KF2Server-Start}
        }
    }
    Menu
}
function KF2Server-Info()
{
	Write-Host "Script created by mmalyska."
	Write-Host "There are two options:"
	Write-Host "-option Install"
	Write-Host "Installation of KF2 Server."
	Write-Host "-option Run"
	Write-Host "Starts installed KF2 Server."
}

switch($option)
{
    "Install" {KF2Server-Install}
    "Run" {KF2Server-Run}
    default {KF2Server-Info}
}