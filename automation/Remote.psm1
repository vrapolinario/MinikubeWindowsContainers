# $VMName = 'minikube-m03';
# $UserName = 'Administrator';
# $Password = 'M@kindu.2021';
function Set-Credential {
    param (
        [String]
        [ValidateNotNullOrEmpty()]
        $VMName = 'minikube-m03',

        [String] 
        [ValidateNotNullOrEmpty()]
        $UserName = 'Administrator',

        [String]
        [ValidateNotNullOrEmpty()]
        $Pass = 'M@kindu.2021'
    )

    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force;
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SecurePassword ;

    return $Credential
    
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

 





function Enable-FireWall-Ports {
    New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
    
}


