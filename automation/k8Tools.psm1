function Install-Kubelet {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $KubernetesVersion = "v1.27.3"
    )

    # Check if kubelet service is already installed
    $nssmService = Get-WmiObject win32_service | Where-Object {$_.PathName -like '*nssm*'}
    if ($nssmService.Name -eq 'kubelet') {
        Write-Output "Kubelet service is already installed."
        return
    }

    # Define the URL for kubelet download
    $KubeletUrl = "https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubelet.exe"

    # Download kubelet
    Invoke-WebRequest -Uri $KubeletUrl -OutFile "c:\k\kubelet.exe" | Out-Null

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
}

function Set-Port {
    $firewallRule = Get-NetFirewallRule -Name 'kubelet' -ErrorAction SilentlyContinue
    if ($firewallRule) {
        Write-Output "Firewall rule 'kubelet' already exists."
        return
    }

    New-NetFirewallRule -Name 'kubelet' -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250 | Out-Null
}

function Get-Kubeadm {
    param (
        [string]
        [ValidateNotNullOrEmpty()]
        $KubernetesVersion = "v1.27.3"
    )
    curl.exe -L https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubeadm.exe -o c:\k\kubeadm.exe | Out-Null
    Set-Location c:\k | Out-Null
}


# Example usage: Install-Kubelet -KubernetesVersion "v1.27.3"
Export-ModuleMember -Function Install-Kubelet
Export-ModuleMember -Function Set-Port
Export-ModuleMember -Function Get-Kubeadm