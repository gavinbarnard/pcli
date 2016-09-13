# -grb 09/13/2015
# verifies that netcpa connections to nsx controllers
#
param($ClusterName)
if ($PSBoundParameters.Keys.Count -ne 1)
{
	"Please run as .\netcpa_check.ps1 <ClusterName>"
	Exit
}
Get-Cluster -Name $ClusterName | Get-VMHost -State "Connected" | %{
    $esxcli = Get-EsxCli -VMHost $_
    $_.toString()
    $esxcli.network.ip.connection.list() | where {$_.WorldName -match "netcpa-worker" -and $_.ForeignAddress -like "*:1234" -and $_.State -match "ESTABLISHED" } | Measure-Object | %{
	    if ($_.Count -gt 1) {
		    $_.Count.toString()+" established netcpa controller connection(s) found"
	    }
	    else
	    {
		    Write-Host -foregroundcolor "Red" "No netcpa connections were not found"
	    }
    }

}
