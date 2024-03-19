Import-Module -Name "$PSScriptRoot\SetUpUtilities.psm1" -Force

function Get-ContainerdLatestVersion {
    $latestVersion = Get-LatestToolVersion -Repository "containerd/containerd"
    return $latestVersion
}

function Install-Containerd {
    param(
        [String]
        [parameter(HelpMessage = "Path to install containerd. Defaults to ~\program files\containerd")]
        $InstallPath = "$Env:ProgramFiles\containerd",
        
        [String]
        [parameter(HelpMessage = "Path to download files. Defaults to user's Downloads folder")]
        $DownloadPath = "$HOME\Downloads"
    )

    # Uninstall if tool exists at specified location. Requires user consent
    Uninstall-ContainerTool -Tool "ContainerD" -Path $InstallPath

    $Version = Get-ContainerdLatestVersion

    $Version = $Version.TrimStart('v')
    Write-Output "* Downloading and installing Containerd v$version at $InstallPath"
    "Downloading and installing Containerd v$version at $InstallPath" >> logs

    
    # Download file from repo
    $containerdTarFile = "containerd-${version}-windows-amd64.tar.gz"
    try {
        $Uri = "https://github.com/containerd/containerd/releases/download/v$version/$($containerdTarFile)"
        Invoke-WebRequest -Uri $Uri -OutFile $DownloadPath\$containerdTarFile | Out-Null
    }
    catch {
        Throw "Containerd download failed. $_"
    }


    # Untar and install tool
    $params = @{
        Feature      = "containerd"
        InstallPath  = $InstallPath
        DownloadPath = "$DownloadPath\$containerdTarFile"
        EnvPath      = "$InstallPath\bin"
        cleanup      = $true
    }

    
    Install-RequiredFeature @params | Out-Null

    Write-Output "* Containerd v$version successfully installed at $InstallPath"
    "Containerd v$version successfully installed at $InstallPath" >> logs
    containerd.exe -v >> logs

    "For containerd usage: run 'containerd -h'" >> logs
}

function Start-ContainerdService {
    Set-Service containerd -StartupType Automatic
    try {
        Start-Service containerd

        # Waiting for containerd to come to steady state
        (Get-Service containerd -ErrorAction SilentlyContinue).WaitForStatus('Running', '00:00:30')
    }
    catch {
        Throw "Couldn't start Containerd service. $_"
    } 

    Write-Output "* Containerd is installed and the service is started  ..."
    "Containerd is installed and the service is started" >> logs

}

function Stop-ContainerdService {
    $containerdStatus = Get-Service containerd -ErrorAction SilentlyContinue
    if (!$containerdStatus) {
        Write-Warning "Containerd service does not exist as an installed service."
        "Containerd service does not exist as an installed service." >> logs
        return
    }

    try {
        Stop-Service containerd -NoWait

        # Waiting for containerd to come to steady state
        (Get-Service containerd -ErrorAction SilentlyContinue).WaitForStatus('Stopped', '00:00:30')
    }
    catch {
        Throw "Couldn't stop Containerd service. $_"
    } 
}

function Initialize-ContainerdService {
    param(
        [string]
        [parameter(HelpMessage = "Containerd path")]
        $ContainerdPath = "$Env:ProgramFiles\containerd"
    )

    "Configuring the containerd service" >> logs

    #Configure containerd service
    $containerdConfigFile = "$ContainerdPath\config.toml"
    $containerdDefault = containerd.exe config default
    $containerdDefault | Out-File $ContainerdPath\config.toml -Encoding ascii
    Write-Information -InformationAction Continue -MessageData "* Review containerd configutations at $containerdConfigFile ..."

    Add-MpPreference -ExclusionProcess "$ContainerdPath\containerd.exe"

    # Review the configuration. Depending on setup you may want to adjust:
    # - the sandbox_image (Kubernetes pause image)
    # - cni bin_dir and conf_dir locations


    # Setting	Old value	                                New Value
    # bin_dir	"C:\\Program Files\\containerd\\cni\\bin"	"c:\\opt\\cni\\bin"
    # conf_dir	"C:\\Program Files\\containerd\\cni\\conf"	"c:\\etc\\cni\\net.d\\"

    # Read the content of the config.toml file
    $containerdConfigContent = Get-Content -Path $containerdConfigFile -Raw

    # Define the replacements
    $replacements = @(
        @{
            Find = 'bin_dir = "C:\\Program Files\\containerd\\cni\\bin"'
            Replace = 'bin_dir = "c:\\opt\\cni\\bin"'
        },
        @{
            Find = 'conf_dir = "C:\\Program Files\\containerd\\cni\\conf"'
            Replace = 'conf_dir = "c:\\etc\\cni\\net.d\\"'
          }
    )

    # Perform the check and replacement in one loop
    $replacementsMade = $false
    foreach($replacement in $replacements) {
        if ($containerdConfigContent -match [regex]::Escape($replacement.Find)) {
            $containerdConfigContent = $containerdConfigContent -replace [regex]::Escape($replacement.Find), $replacement.Replace
            $replacementsMade = $true
        }
    }

    # Write the modified content back to the config.toml file if any replacements were made
    if ($replacementsMade) {
        $containerdConfigContent | Set-Content -Path $containerdConfigFile
        # Output a message indicating the changes
        # Write-Host "Changes applied to $containerdConfigFile"
        } else {
        # Write-Host "No changes needed in $containerdConfigFile"
    }

     # Create the folders if they do not exist
    $binDir = "c:\opt\cni\bin"
    $confDir = "c:\etc\cni\net.d"

    if (!(Test-Path $binDir)) {
        mkdir $binDir | Out-Null
        # Write-Host "Created $binDir"
    }

    if (!(Test-Path $confDir)) {
        mkdir $confDir | Out-Null
        # Write-Host "Created $confDir"
    }


    $pathExists = [System.Environment]::GetEnvironmentVariable('PATH', [System.EnvironmentVariableTarget]::Machine) -like "*$ContainerdPath\bin*"
    if (-not $pathExists) {
        # Register containerd service
        Add-FeatureToPath -Feature "containerd" -Path "$ContainerdPath\bin"
    }

    # Check if the containerd service is already registered
    $containerdServiceExists = Get-Service -Name "containerd" -ErrorAction SilentlyContinue
    if (-not $containerdServiceExists) {
        containerd.exe --register-service --log-level debug --service-name containerd --log-file "$env:TEMP\containerd.log"
        if ($LASTEXITCODE -gt 0) {
            Throw "Failed to register containerd service. $_"
        }
    } else {
        Write-Host "Containerd service is already registered."
    }

    Get-Service *containerd* | Select-Object Name, DisplayName, ServiceName, ServiceType, StartupType, Status, RequiredServices, ServicesDependedOn | Out-Null
}

function Uninstall-Containerd {
    param(
        [string]
        [parameter(HelpMessage = "Containerd path")]
        $Path
    )
    Write-Output "Uninstalling containerd"

    if (!$Path) {
        $Path = Get-DefaultInstallPath -Tool "containerd"
    }

    $pathItems = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
    if (!$pathItems.Name.Length) {
        Write-Warning "Containerd does not exist at $Path or the directory is empty"
        return
    }

    try {
        Stop-ContainerdService
    }
    catch {
        Write-Warning "$_"
    }

    # Unregister containerd service
    Unregister-Containerd

    # Delete the containerd key
    $regkey = "HKLM:\SYSTEM\CurrentControlSet\Services\containerd"
    Get-Item -path $regkey -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

    # Remove the folder where containerd service was installed
    Get-Item -Path $Path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force

    # Remove from env path
    Remove-FeatureFromPath -Feature "containerd"

    Write-Output "Successfully uninstalled Containerd."
}
function Unregister-Containerd {
    $scQueryResult = (sc.exe query containerd) | Select-String -Pattern "SERVICE_NAME: containerd"
    if (!$scQueryResult) {
        Write-Warning "Containerd service does not exist as an installed service."
        return
    }
    # Unregister containerd service
    containerd.exe --unregister-service
    if ($LASTEXITCODE -gt 0) {
        Write-Warning "Could not unregister containerd service. $_"
    }
    else {
        Start-Sleep -Seconds 15
    }
    
    # # Delete containerd service
    # sc.exe delete containerd
    # if ($LASTEXITCODE -gt 0) {
    #     Write-Warning "Could not delete containerd service. $_"
    # }
}


Export-ModuleMember -Function Get-ContainerdLatestVersion
Export-ModuleMember -Function Install-Containerd
Export-ModuleMember -Function Start-ContainerdService
Export-ModuleMember -Function Stop-ContainerdService -Alias Stop-Containerd
Export-ModuleMember -Function Initialize-ContainerdService
Export-ModuleMember -Function Uninstall-Containerd