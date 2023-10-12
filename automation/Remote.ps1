function Start-VirtualMachine {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName,

        [String]
        [ValidateNotNullOrEmpty()]
        $SwitchName,

        [String]
        [ValidateNotNullOrEmpty()]
        $ISOFile
    )
    
    New-VM -Name $VMName -Generation 1 -MemoryStartupBytes 6000MB -Path ${env:homepath}\.minikube\machines\ -NewVHDPath ${env:homepath}\.minikube\machines\$VMName\VHD.vhdx -NewVHDSizeBytes 127000MB -SwitchName $SwitchName
    Set-VM -Name $VMName -ProcessorCount 2 -AutomaticCheckpointsEnabled $false  
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true 
    Set-VMDvdDrive -VMName $VMName -Path $ISOFile 
    Start-VM -Name $VMName 
}

# $VMName = 'minikube-m03';
# $UserName = 'Administrator';
# $Password = 'M@kindu.2021';
function Set-Credential {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName,

        [String] 
        [ValidateNotNullOrEmpty()]
        $UserName,

        [String]
        [ValidateNotNullOrEmpty()]
        $Pass
    )

    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force;
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword ;

    return $Credential
    
}

function Install-Containerd {
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        [parameter(HelpMessage = "ContainerD version to use. Default 1.7.6")]
        $Version = "1.7.6",

        [String]
        [parameter(HelpMessage = "Path to install containerd. Defaults to ~\program files\containerd")]
        $InstallPath = "$Env:ProgramFiles\containerd",
        
        [String]
        [parameter(HelpMessage = "Path to download files. Defaults to user's Downloads folder")]
        $DownloadPath = ".\bin\"
    )

    $Version = $Version.TrimStart('v')
    $EnvPath = "$InstallPath\bin"
    
    $containerdTarFile = "containerd-${version}-windows-amd64.tar.gz"
    $Uri = "https://github.com/containerd/containerd/releases/download/v$version/$($containerdTarFile)"
    $params = @{
        Feature      = "containerd"
        Version      = $Version
        Uri          = $Uri
        InstallPath  = $InstallPath
        DownloadPath = "$DownloadPath\$containerdTarFile"
        EnvPath      = $EnvPath
        cleanup      = $true
    }

    Write-Output "Downloading and installing Containerd at $InstallPath"
    Invoke-WebRequest -Uri $Uri -OutFile $DownloadPath\$containerdTarFile -Verbose
    Install-RequiredFeature @params

    Write-Output "Containerd successfully installed at $InstallPath"
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
    # Get-Content $containerdConfigFile
    # TODO: Complete the script make the following changes in the .toml file
    #    
    # Setting	Old value	                                New Value
    # bin_dir	"C:\\Program Files\\containerd\\cni\\bin"	"c:\\opt\\cni\\bin"
    # conf_dir	"C:\\Program Files\\containerd\\cni\\conf"	"c:\\etc\\cni\\net.d\\"

    # Register containerd service
    Add-FeatureToPath -Feature "containerd" -Path "$ContainerdPath\bin"
    containerd.exe --register-service --log-level debug --service-name containerd --log-file "$env:TEMP\containerd.log"
    if ($LASTEXITCODE -gt 0) {
        Throw "Failed to register containerd service. $_"
    }

    Write-Output "Containerd service"
    Get-Service *containerd* | Select-Object Name, DisplayName, ServiceName, ServiceType, StartupType, Status, RequiredServices, ServicesDependedOn
}

function Install-NSSM {
    param(
        [string]
        [ValidateNotNullOrEmpty()]
        [parameter(HelpMessage = "NSSM version to use. Default 2.24")]
        $Version = "2.24",

        [String]
        [parameter(HelpMessage = "Architecture ")]
        $Arch = "win64",
        
        [String]
        [parameter(HelpMessage = "Path to download files.")]
        $DownloadPath = "c:\k"
    )

    $Version = $Version.TrimStart('v')
    
    $nssmTarFile = "nssm-${version}.zip"
    $Uri = "https://k8stestinfrabinaries.blob.core.windows.net/nssm-mirror/$($nssmTarFile)"
    $params = @{
        Feature      = "nssm"
        Version      = $Version
        Uri          = $Uri
        InstallPath  = $InstallPath
        DownloadPath = "$DownloadPath\$containerdTarFile"
        EnvPath      = $EnvPath
        cleanup      = $true
    }

    Write-Output "Downloading and installing Containerd at $InstallPath"
    Invoke-WebRequest -Uri $Uri -OutFile $DownloadPath\$containerdTarFile -Verbose
    Install-RequiredFeature @params

    Write-Output "Containerd successfully installed at $InstallPath"
    containerd.exe -v

    Write-Output "For containerd usage: run 'containerd -h'"
}


function Install-Kubelet {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $KubernetesVersion = "v1.27.3"
    )

    # Define the URL for kubelet download
    $KubeletUrl = "https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubelet.exe"

    # Download kubelet
    Invoke-WebRequest -Uri $KubeletUrl -OutFile "c:\k\kubelet.exe"

    # Create the Start-kubelet.ps1 script
    @"
`$FileContent = Get-Content -Path "/var/lib/kubelet/kubeadm-flags.env"
`$kubeAdmArgs = `$FileContent.TrimStart(`'KUBELET_KUBEADM_ARGS=`').Trim(`'"`')

`$args = "--cert-dir=`$env:SYSTEMDRIVE/var/lib/kubelet/pki",
        "--config=`$env:SYSTEMDRIVE/var/lib/kubelet/config.yaml",
        "--bootstrap-kubeconfig=`$env:SYSTEMDRIVE/etc/kubernetes/bootstrap-kubelet.conf",
        "--kubeconfig=`$env:SYSTEMDRIVE/etc/kubernetes/kubelet.conf",
        "--hostname-override=`$(hostname)",
        "--enable-debugging-handlers",
        "--cgroups-per-qos=false",
        "--enforce-node-allocatable=``"``"",
        "--resolv-conf=``"``""

`$kubeletCommandLine = "c:\k\kubelet.exe " + (`$args -join " ") + " `$kubeAdmArgs"
Invoke-Expression `$kubeletCommandLine
"@ | Set-Content -Path "c:\k\Start-kubelet.ps1"

    # Install kubelet as a Windows service
    "c:\k\nssm.exe install kubelet Powershell -ExecutionPolicy Bypass -NoProfile c:\k\Start-kubelet.ps1"
    "c:\k\nssm.exe set Kubelet AppStdout C:\k\kubelet.log"
    "c:\k\nssm.exe set Kubelet AppStderr C:\k\kubelet.err.log"
}


# Example usage: Install-Kubelet -KubernetesVersion "v1.27.3"


function Enable-FireWall-Ports {
    New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
    
}


function Start-RemoteSession {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName,

        [PSCredential]
        [ValidateNotNullOrEmpty()]
        $Credential
    )
    
    Enter-PSSession -VMName $VMName -Credential $Credential;
}

function Remove-VirtualMachine {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName
    )

    Stop-VM -Name $VMName -TurnOff
    Remove-VM -Name $VMName -Force
    Remove-Item -Path ${env:homepath}\.minikube\machines\$VMName -Force -Recurse
    
}