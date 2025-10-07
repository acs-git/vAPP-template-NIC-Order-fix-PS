### this 


## export data $true or $false
$export = $true



## details for sourcecloud
$suser = 'check1'
$spass = 'VMware123!'
$svcd= 'lvn-cm3-vcd2.broadcom.com'
$sorg = 'lvn3-vcd2-eduprod-r'
$templateName = 'VCF5-TS-stage2-Rev-U-GA-May08'




##### code no changes required from here#####
$outslist = 'Networking_Source_{0}.csv' -f $templateName


Import-Module VMware.VimAutomation.Cloud
$svcd_conn = Connect-CIServer -Server $svcd -Org $sorg -User $suser -Password $spass
Write-Warning "connected to vCD $($svcd_conn.name)"
$svappTemplate = get-catalog -name "Ascend" | Get-CIVAppTemplate -name $templateName ## -Catalog VCF_SYNC

write-host "Gathering info on the source"
$slist = @()
foreach($vmtemplate in $($svappTemplate | Get-CIVMTemplate)){
    $view = $vmtemplate | Get-CIView
    $networks = ($view.Section | ?{$_.type -like 'application/vnd.vmware.vcloud.networkConnectionSection+xml'})
    foreach($network in $($networks.networkconnection | sort NetworkConnectionIndex)){
        $slist += [PSCustomObject]@{
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
    $slist | ft -AutoSize
    $slist | Export-Csv $outslist
    Write-host "file exported to $((get-item $outslist).fullname)" -ForegroundColor Green
}

Disconnect-CIServer -server $svcd_conn  -Confirm:$false
Write-Warning "disconnected from vCD $($svcd_conn.name)"

