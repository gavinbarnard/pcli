# -grb 10/10/2015
# update 11/2/2015 checks only connected state hosts
# vdrPort check 
# verifies a vdrPort exists on the DV Switch to relay LDR traffic
#
param($ClusterName,$DVSName="nsxswitch",$VNI=5000)
if ($PSBoundParameters.Keys.Count -lt 1)
{
	"Please run as .\vdrPort_check.ps1 <ClusterName> <DVSName, optional defaults to nsxswitch> <VNI, defaults to 5000>"
	Exit
}

Get-Cluster -Name $ClusterName | Get-VMHost -State "Connected" | %{
    $esxcli = Get-EsxCli -VMHost $_
    $_.toString()
    $esxcli.network.vswitch.dvs.vmware.vxlan.network.port.list($DVSName,"vdrPort",$VNI) | Measure-Object | %{
	    if ($_.Count -eq 1) {
		    $_.Count.toString()+" vdrPort was found"
	    }
	    else
	    {
		    Write-Host -foregroundcolor "Red" "No vdrPort found"
	    }
    }

}
