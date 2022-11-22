# Install the Az module if you haven't already and connect to your Azure account.
# Install-Module -Name Az
Connect-AzAccount

# Check whether the signed in user is assigned the Owner or Administrator role.
Get-AzRoleAssignment | Select-Object RoleDefinitionName

# Check whether you are registered to be an Azure resource provider, and do so if you are not.
$registrationStates = Get-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization | Select-Object RegistrationState
if (-Not $registrationStates[0] -match 'Registered') { (Register-AzResourceProvider -ProviderNamespace Microsoft.DesktopVirtualization) }

# Overview of already existing resource groups and resources.
Get-AzResourceGroup
Get-AzResource -ExpandProperties

# Start by creating a new resource group.
New-AzResourceGroup -Name $RG -Location $Location

# Define subnet properties and deploy the virtual network.
$fesub = New-AzVirtualNetworkSubnetConfig -Name "FrontEndSubnet" -AddressPrefix "10.1.0.0/24"
$gwsub = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix "10.1.255.0/27"
New-AzVirtualNetwork `
   -ResourceGroupName "myRG" `
   -Location "westeurope" `
   -Name "myVNet" `
   -AddressPrefix "10.1.0.0/16" `
   -Subnet $fesub, $gwsub `

# Get a dynamic public IP address for the virtual network gateway and set configurations for subsequent creation.
$vnet = Get-AzVirtualNetwork -Name 'myVNet' -ResourceGroupName 'myRG'
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet
$pip = New-AzPublicIpAddress -Name 'myVNetGWpip' -ResourceGroupName 'myRG' -Location 'westeurope' -AllocationMethod Dynamic
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name "gwipconf" -Subnet $subnet -PublicIpAddress $pip

# Create the virtual network gateway. This will take approximately 45 minutes.
New-AzVirtualNetworkGateway -Name 'myVNetGW' -ResourceGroupName 'myRG' `
-Location 'westeurope' -IpConfigurations $ipconf -GatewayType Vpn `
-VpnType RouteBased -EnableBgp $false -GatewaySku VpnGw1 -VpnClientProtocol "IKEv2",'SSTP'

# Set the VPN Client Address pool for the virtual network gateway. 
# Note that this only works with PowerShell 7.2 or earlier versions of PowerShell 7.
# As of November 16th 2022 there have still been issues with PowerShell 7.3.
$Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName myRG -Name myVNetGW
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Gateway -VpnClientAddressPool "172.16.201.0/24"

# Generate a root certificate. This can only be done by an admin in a PowerShell session.
# The session should stay active for the next part, when the client certificate is generated.
$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

# Generate a client certificate.
New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
-Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" `
-Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# After generating both certificates, it is necessary to export the public key of the root certificates 
# to later upload it to Azure. Follow the instructions here: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-certificates-point-to-site#cer
# Upload the root certificate's public key to Azure.
$P2SRootCertName = "P2SRootCert1.cer"
$filePathForCert = "C:\Users\IWA-JUN-11\Documents\pwsh_project\P2SRootCert1.cer"
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($filePathForCert)
$CertBase64 = [system.convert]::ToBase64String($cert.RawData)
Add-AzVpnClientRootCertificate -VpnClientRootCertificateName $P2SRootCertName -VirtualNetworkGatewayname "myVNetGW" -ResourceGroupName "myRG" -PublicCertData $CertBase64

# Finally, create a client configuration package, follow the link in $vpnProfile.VPNProfileSASUrl to download the ZIP file,
# and configure your VPN client by opening the file that matches your operating system.
$vpnProfile = New-AzVpnClientConfiguration -ResourceGroupName 'myRG' -Name 'myVNetGW' -AuthenticationMethod "EapTls"
$vpnProfile.VPNProfileSASUrl
# You can now connect to the VPN in Settings > Network & Internet > VPN.

# Next, create a VM. If you want to use a an image from the marketplace, you first need to accept the product terms.
Get-AzMarketplaceTerms -Publisher 'ntegralinc1586961136942' -Product 'ntg_ubuntu_22_04_daas' -Name 'ntg_ubuntu_22_04_daas' -OfferType 'virtualmachine' `
 | Set-AzMarketplaceTerms -Accept

# Then you can deploy the VM with the following command. The VM specifications are declaratively defined by a Bicep file.
New-AzResourceGroupDeployment -ResourceGroupName myRG -TemplateFile .\main.bicep

# Unfortunately, I was not able to automatically execute Bash code after the VM was deployed. To clarify this issue, I have asked a question on StackOverflow:
# https://stackoverflow.com/questions/74478948/post-deployment-bash-script-in-bicep-file-does-not-execute

# Get the VM's private IP address, start Windows Remote Desktop Connection, enter the IP address and the credentials, and log in.
$privateIP = (Get-AzNetworkInterface).IpConfigurations | Select-Object -ExpandProperty PrivateIpAddress
mstsc /v:$privateIP

# Configure the VM.
Invoke-AzVMRunCommand -ResourceGroupName 'myRG' -VMName 'myVM' -CommandId 'RunPowerShellScript' -ScriptPath '.\vm_script.ps1'