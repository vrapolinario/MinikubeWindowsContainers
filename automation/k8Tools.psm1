Import-Module -Name "$PSScriptRoot\SetUpUtilities.psm1" -Force

function Get-k8LatestVersion {
    $latestVersion = Get-LatestToolVersion -Repository "kubernetes/kubernetes"
    return $latestVersion
}

function Install-Kubelet {
    param (
        [string]
        $KubernetesVersion
    )

    # Check if kubelet service is already installed
    $nssmService = Get-WmiObject win32_service | Where-Object {$_.PathName -like '*nssm*'}
    if ($nssmService.Name -eq 'kubelet') {
        Write-Output "Kubelet service is already installed."
        return
    }

    # Define the URL for kubelet download
    $KubeletUrl = "https://dl.k8s.io/v$KubernetesVersion/bin/windows/amd64/kubelet.exe"

    # Download kubelet
    try {
        Invoke-WebRequest -Uri $KubeletUrl -OutFile "c:\k\kubelet.exe" | Out-Null
    } catch {
        Write-Error "Failed to download kubelet: $_"
    }

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
    c:\k\nssm.exe install kubelet Powershell -ExecutionPolicy Bypass -NoProfile c:\k\Start-kubelet.ps1 | Out-Null
    c:\k\nssm.exe set Kubelet AppStdout C:\k\kubelet.log | Out-Null
    c:\k\nssm.exe set Kubelet AppStderr C:\k\kubelet.err.log | Out-Null

    Write-Output "* Kubelet is installed and the service is started  ..."
}

function Set-Port {
    $firewallRule = Get-NetFirewallRule -Name 'kubelet' -ErrorAction SilentlyContinue
    if ($firewallRule) {
        Write-Output "Firewall rule 'kubelet' already exists."
        return
    }

    $ruleParams = @{
        Name = 'kubelet'
        DisplayName = 'kubelet'
        Enabled = "True"
        Direction = 'Inbound'
        Protocol = 'TCP'
        Action = 'Allow'
        LocalPort = 10250
    }

    New-NetFirewallRule @ruleParams | Out-Null
}

function Get-Kubeadm {
    param (
        [string]
        $KubernetesVersion
    )
    try {
        Invoke-WebRequest -Uri "https://dl.k8s.io/v$KubernetesVersion/bin/windows/amd64/kubeadm.exe" -OutFile "c:\k\kubeadm.exe" | Out-Null
    } catch {
        Write-Error "Failed to download kubeadm: $_"
    }
}

Export-ModuleMember -Function Get-k8LatestVersion
Export-ModuleMember -Function Install-Kubelet
Export-ModuleMember -Function Set-Port
Export-ModuleMember -Function Get-Kubeadm
Export-ModuleMember -Function Get-k8LatestVersion
