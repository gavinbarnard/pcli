# -grb 10/16/2015
# update 11/2/2015 added parameter to only check connected state hosts
# Finds VIBs in rebooting image
#
# 
#
param($ClusterName,$VibVer="2921500")
if ($PSBoundParameters.Keys.Count -lt 1)
{
	"Please run as .\nsx_rebooting_image_check.ps1 <ClusterName> <VibVersion defaults to 2921500>"
	Exit
}
Write-Host "Please note this script only works if rebooting image is populated see .\rebooting_image_check.ps1"

Get-Cluster -Name $ClusterName | Get-VMHost -State "Connected" | %{
    $esxcli = Get-EsxCli -VMHost $_
    $_.toString()
    $esxcli.software.vib.list($true) | where {$_.Name -like "esx-v*" -or $_.Name -like "esx-dvfilter-switch*"} | %{
    	$vibn = $_.Name
	$ver = $_.Version.toString()
	$vibv = $ver.substring($ver.length-7,7)
	if ( $vibv -ne $VibVer ) 
	{
		Write-Host -foregroundcolor "Red" "Found vib $vibn but build $vibv installed when expected is $VibVer"	
	} else
	{
		"Found vib $vibn at $vibv"
	}
    }

}
