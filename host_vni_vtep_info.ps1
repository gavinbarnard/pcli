param($ClusterName="Physical")
if ($PSBoundParameters.Keys.Count -lt 1)
{
	"Please run as .\host_vni_vtep_info.ps1 <ClusterName>"
	Exit
}
Get-Cluster -Name $ClusterName | Get-VMHost -State "Connected" | %{
    $e = Get-EsxCli -VMHost $_
    Write-Host "Hostname $_"
    $vxlanid = $e.network.vswitch.dvs.vmware.vxlan.network.list($vdsname,$NULL).VXLANID
    $vxlanid | % { 
	Write-Host "VTEP Information for VNI $_"
	$vxlan = [int]$_; $e.network.vswitch.dvs.vmware.vxlan.network.vtep.list($NULL,$vdsname,$NULL,$vxlan) }

   Write-Host "--"
}
