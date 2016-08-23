# -grb 10/16/2015
# update 11/2/2015 - checks only connected state hosts
# Finds out if Rebooting image contains anything
#
# 
#
param($ClusterName)
if ($PSBoundParameters.Keys.Count -ne 1)
{
	"Please run as .\rebooting_image_check.ps1 <ClusterName>"
	Exit
}
Get-Cluster -Name $ClusterName | Get-VMHost -State "Connected" | %{
    $esxcli = Get-EsxCli -VMHost $_
    $_.toString()
    $esxcli.software.vib.list($true) | Measure-Object | %{
	   if ($_.Count -eq 0) 
		{
			"No rebooting image populated"	
	       	} 
	   else
	   {
		   $objc = $_.Count.toString()
		   Write-Host -foregroundcolor "Red" "Found $objc vibs in the rebooting image" 
	   }
    }

}
