Import-Module -Name "$PSScriptRoot\SetUpUtilities.psm1" -Force

function Get-ContainerdLatestVersion {
    $latestVersion = Get-LatestToolVersion -Repository "containerd/containerd"
    return $latestVersion
}

function Install-Containerd {
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        [parameter(HelpMessage = "ContainerD version to use. Default 1.7.6")]
        $Version,

        [String]
        [parameter(HelpMessage = "Path to install containerd. Defaults to ~\program files\containerd")]
        $InstallPath = "$Env:ProgramFiles\containerd",
        
        [String]
        [parameter(HelpMessage = "Path to download files. Defaults to user's Downloads folder")]
        $DownloadPath = "$HOME\Downloads"
    )

    # Uninstall if tool exists at specified location. Requires user consent
    # Uninstall-ContainerTool -Tool "ContainerD" -Path $InstallPath

    if(!$Version) {
        # Get default version
        $Version = Get-ContainerdLatestVersion
    }

    $Version = $Version.TrimStart('v')
    Write-Output "Downloading and installing Containerd v$version at $InstallPath"

    
    # Download file from repo
    $containerdTarFile = "containerd-${version}-windows-amd64.tar.gz"
    try {
        $Uri = "https://github.com/containerd/containerd/releases/download/v$version/$($containerdTarFile)"
        Invoke-WebRequest -Uri $Uri -OutFile $DownloadPath\$containerdTarFile -Verbose
    }
    catch {
        if ($_.ErrorDetails.Message -eq "Not found") {
            Throw "Containerd download failed. Invalid URL: $uri"
        }

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

    
    Install-RequiredFeature @params

    Write-Output "Containerd v$version successfully installed at $InstallPath"
    containerd.exe -v

    Write-Output "For containerd usage: run 'containerd -h'"
}

function Start-ContainerdService {
    Set-Service containerd -StartupType Automatic
    try {
        Start-Service containerd -Force

        # Waiting for containerd to come to steady state
        (Get-Service containerd -ErrorAction SilentlyContinue).WaitForStatus('Running', '00:00:30')
    }
    catch {
        Throw "Couldn't start Containerd service. $_"
    } 
}

function Initialize-ContainerdService {
    param(
        [string]
        [parameter(HelpMessage = "Containerd path")]
        $ContainerdPath = "$Env:ProgramFiles\containerd"
    )

    Write-Output "Configuring the containerd service"

    #Configure containerd service
    $containerdConfigFile = "$ContainerdPath\config.toml"
    $containerdDefault = containerd.exe config default
    $containerdDefault | Out-File $ContainerdPath\config.toml -Encoding ascii
    Write-Information -InformationAction Continue -MessageData "Review containerd configutations at $containerdConfigFile"

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

    # Perform the replacements
    foreach ($replacement in $replacements) {
        $containerdConfigContent = $containerdConfigContent -replace [regex]::Escape($replacement.Find), $replacement.Replace
    }

    # Save the modified content back to the config.toml file
    Set-Content -Path $containerdConfigFile -Value $containerdConfigContent

    # Output a message indicating the changes
    Write-Host "Changes applied to $containerdConfigFile"

    # Create the folders above
    mkdir c:\opt\cni\bin
    mkdir c:\etc\cni\net.d

    # Register containerd service
    Add-FeatureToPath -Feature "containerd" -Path "$ContainerdPath\bin"
    containerd.exe --register-service --log-level debug --service-name containerd --log-file "$env:TEMP\containerd.log"
    if ($LASTEXITCODE -gt 0) {
        Throw "Failed to register containerd service. $_"
    }

    Write-Output "Containerd service"
    Get-Service *containerd* | Select-Object Name, DisplayName, ServiceName, ServiceType, StartupType, Status, RequiredServices, ServicesDependedOn
}


Export-ModuleMember -Function Get-ContainerdLatestVersion
Export-ModuleMember -Function Install-Containerd
Export-ModuleMember -Function Start-ContainerdService
Export-ModuleMember -Function Initialize-ContainerdService