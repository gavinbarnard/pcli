# -grb 10/10/2015
# update 11/2/2015 checks only connected state hosts
# verifies that vsfwd has open rabbitmq connections to nsx manager
#
param($ClusterName)
if ($PSBoundParameters.Keys.Count -ne 1)
{
	"Please run as .\vsfwd_check.ps1 <ClusterName>"
	Exit
}
Get-Cluster -Name $ClusterName | Get-VMHost -State "Connected" | %{
    $esxcli = Get-EsxCli -VMHost $_
    $_.toString()
    $esxcli.network.ip.connection.list() | where {$_.WorldName -match "vsfwd" -and $_.ForeignAddress -like "*:5671"} | Measure-Object | %{
	    if ($_.Count -gt 1) {
		    $_.Count.toString()+" vsfwd rabbitmq connection(s) found"
	    }
	    else
	    {
		    Write-Host -foregroundcolor "Red" "No vsfwd rabbitmq connections were not found"
	    }
    }

}
