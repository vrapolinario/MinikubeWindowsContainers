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