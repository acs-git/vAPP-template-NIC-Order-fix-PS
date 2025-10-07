### this 


## export data $true or $false
$export = $true

## details for destination cloud
$duser = 'administrator'
$dpass = 'Acs@123!'
$dvcd= 'cloud-01.ascendcloudsolutions.com'
$dorg = 'system'
$dvappname = 'KFC'





##### code no changes required from here#####
$outslist = 'Networking_Source_KFC-Ver1.8_Dec10_EDU.csv'   
$outdlist = 'Networking_Destination.csv'

$slist = Import-Csv -Path ".\Networking_Source_KFC-Ver1.8_Dec10_EDU.csv"

###destination
Import-Module VMware.VimAutomation.Cloud
$dvcd_conn = Connect-CIServer -Server $dvcd -Org $dorg -User $duser -Password $dpass
Write-Warning "connected to vCD $($dvcd_conn.name)"

write-host "change network settings on the $dvappname"
$dvapp= Get-CIVApp -name $dvappname ## -Catalog VCF_SYNC
foreach($vm in $dvapp | Get-CIVM ){
    Write-Host "$($vm.Name)"
    $vm_view = $vm | Get-CIView
    $networks = ($vm_view.Section | ?{$_.type -like 'application/vnd.vmware.vcloud.networkConnectionSection+xml'})
    foreach($network in $($networks.NetworkConnection| sort NetworkConnectionIndex)){
        ## finding the nework on the list
        $aux = $slist | ?{$_.vmname -like $($vm.name) -and $_.NetworkConnectionIndex -eq $($network.NetworkConnectionIndex)}
        $networks.PrimaryNetworkConnectionIndex = $aux.primary
        ## if esxi host then it reset the mac address else copies from original vapp
        if($vm.name -like "*ESXi-0*"){
            $network.MACAddress = ""
        }
        else{
            $network.MACAddress = $aux.MACAddress
        }
        $network.IpAddress = $aux.IpAddress
        $network.IpAddressAllocationMode = $aux.IpAddressAllocationMode
        $network.Network = $aux.Network
        
    }
    $networks.UpdateServerData()
}


$dvapp= Get-CIVApp -name $dvappname ## -Catalog VCF_SYNC

write-host "Gathering info on the destination"
$dlist = @()
foreach($vmtemplate in $($dvapp | Get-CIVM)){
    $view = $vmtemplate | Get-CIView
    $networks = ($view.Section | ?{$_.type -like 'application/vnd.vmware.vcloud.networkConnectionSection+xml'})
    foreach($network in $($networks.networkconnection | sort NetworkConnectionIndex)){
        $dlist += [PSCustomObject]@{
            vmname = $view.name
            primary = $networks.PrimaryNetworkConnectionIndex
            Network = $network.Network
            NetworkConnectionIndex = $network.NetworkConnectionIndex
            MACAddress = $network.MACAddress
            NetworkAdapterType = $network.NetworkAdapterType
            IpAddressAllocationMode = $network.IpAddressAllocationMode
            IpAddress = $network.IpAddress
            IsConnected = $network.IsConnected
        }
    }
}


if($export){
    ## prints on the screen
    $dlist | ft -AutoSize
    $dlist | Export-Csv $outdlist
    Write-host "file exported to $((get-item $outdlist).fullname)" -ForegroundColor Green
}


Disconnect-CIServer -server $dvcd_conn  -Confirm:$false
Write-Warning "All done `nDisconnected from vCD $($dvcd_conn.name)"

$compare = Compare-Object -ReferenceObject $slist -DifferenceObject $dlist -Property vmname, primary, Network, NetworkConnectionIndex, MACAddress, NetworkAdapterType, IpAddressAllocationMode, IpAddress, IsConnected

if([bool]$compare){
    Write-Warning "please examine the differences below"
    $compare | ft -auto
}