$cluster = "Physical"
$vteplist = @()

# Find all VTEP
Get-Cluster $cluster |Get-VMHost | 
%{ 
	$e = Get-ESXCLI -VMhost $_.Name
	$tempip = $e.network.ip.interface.ipv4.get($NULL,"vxlan") | Select IPv4Address
	$vteplist += $tempip
	$e.network.vswitch.dvs.vmware.vxlan.list() | Select-Object MTU |
	%{
		$mtu = $_.MTU 
	}
}   
$framesize = $mtu - 28

"All VTEPs to be tested"
"----------------------"
$vteplist | %{ $_.IPv4Address.ToString() }

"Testing with framsize: $($framesize)"

Get-Cluster $cluster | Get-VMHost | 
%{
	"Testing from host: $($_.Name)"
	
	$e = Get-ESXCLI -VMHost $_.Name
	$e.network.ip.interface.ipv4.get($NULL,"vxlan") |
	%{
		$pingvmk = $_.Name
		"     Testing from vmk: $($_.Name)"
		
		$vteplist | 
		%{ 		
			$pingresult = $e.network.diag.ping(3,0,1,$_.IPv4Address.ToString(),$pingvmk,1,1,0,"vxlan",$NULL,$framesize,$NULL,$NULL)
			$pingresult.Summary 
		} | FT -Autosize -Property HostAddr,Transmitted,Recieved
	}
	
}
