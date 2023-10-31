function Get-HyperV {
    $hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
    # Check if Hyper-V is enabled
    if($hyperv.State -eq "Enabled") {
        Write-Host "Hyper-V is enabled."
    } else {
        Write-Host "Hyper-V is disabled."
    }
    
}

function Set-VmSwitch {    
    $net = Get-NetAdapter | Where-Object {  $_.Status -eq 'Up' }
    New-VMSwitch -Name "External VM Switch" -AllowManagementOS $True -NetAdapterName $net.Name
}

function Get-VmSwitch {
    $SwitchName = "External VM Switch"
    return $SwitchName
    
}

function Get-LatestToolVersion($repository) {
    try {
        $uri = "https://api.github.com/repos/$repository/releases/latest"
        $response = Invoke-WebRequest -Uri $uri
        $version = ($response.content  | ConvertFrom-Json).tag_name
        return $version.TrimStart("v")
    }
    catch {
        Throw "Could not get $repository version. $_"
    }
}