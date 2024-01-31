$SwitchName = "External VM Switch" 
$ISOFile = "$HOME\Downloads\SERVER_EVAL_x64FRE_en-us-uni.iso"
$VMName = 'minikube-m05' 
$VM = @{
    Name = $VMName;
    MemoryStartupBytes = 1GB;
    NewVHDPath = "${env:homepath}\.minikube\machines\$VMName\VHD.vhdx";
    NewVHDSizeBytes = 10GB;
    BootDevice = "VHD";
    Path = "${env:homepath}\.minikube\machines\";
    SwitchName = $SwitchName
}
New-VM @VM
Set-VM -Name $VMName -ProcessorCount 2 -AutomaticCheckpointsEnabled $false
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
Set-VMDvdDrive -VMName $VMName -Path $ISOFile
Start-VM -Name $VMName