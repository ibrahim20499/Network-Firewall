
Import-Module AWSPowerShell 

#AWS Credentials 

$UserSecretKey = ""

$UserAccessKey = ""

$ProfileName = "Ibrahim"

$region = "us-east-1"

#Setting Credentials

$SetCredentials = Set-AWSCredential -AccessKey $UserAccessKey -SecretKey $UserSecretKey -StoreAs $ProfileName

#Setting Sessions

$session = Initialize-AWSDefaults -ProfileName $ProfileName  -Region $region

#----------------------------------------------------------------------------------------------------------------------------------------------
Write-Host " 1. STRICT_ORDER  2. for DEFAULT_ACTION_ORDER"
$Input = Read-Host "please choose the Rule evaluation order you want :"
#---------------------- <Common Variables > -----------------------------------------

$yes = @("yes", "Yes" , "y" , "Y" )

$no = @("no", "No" , "n" , "N" )

#----------------------------------------------------------------------------------

#------------------------------------------------------------< Create VPC >--------------------------------------------------------------------

$askforvpc = Read-Host "Do you want to create a VPC [ yes | no ]"

if ($askforvpc -in $yes) {

    $VpcCidrBlock = Read-Host "Enter your vpc cider "
    $tags_vpc = @(
        @{
            Key   = "Name";
            Value = (Read-Host "Enter your tag value ")
        }
    )

    $myvpc = New-EC2Vpc -CidrBlock $VpcCidrBlock -InstanceTenancy "default" -Region $region  
    
    New-EC2Tag -Resource $myvpc.VpcId -Tag $tags_vpc

    Write-Output "VPC created with Id: $($myvpc.VpcId) and tag $($tags_vpc.Value)"
}
elseif ($askforvpc -in $no) {

    Write-Output "Thanks"

}
else {

    Write-Output " $askforvpc is not recognized please enter it correctly" 

}


#-----------------------------------------------< Create Internet Gateway >-------------------------------------------------------------------

$igw = New-EC2InternetGateway 
Add-EC2InternetGateway -VpcId $myvpc.VpcId -InternetGatewayId $igw.InternetGatewayId

#----------------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------< Create Subnets >-----------------------------------------------------------------------------

$myvpc = Get-EC2Vpc


$askforsubnet = Read-Host "Do you want to create a subnet [ yes | no ] "

$numberofsubnet = Read-Host "How many subnet do you want"

if ($askforsubnet -in $yes) {

    for ($i = 1; $i -le $numberofsubnet; $i++) {
       
        $SubnetCidrBlock = Read-Host "Enter your subnet $i cider "

        $SubnetAvailabilityZone = Read-Host "Enter your subnet $i AvailabilityZone "
        #$SubnetTagValue = Read-Host "Enter your subnet $i tag "
        
        $mySubnets = New-EC2Subnet -CidrBlock $SubnetCidrBlock -VpcId  $myvpc.VpcId  -AvailabilityZone $SubnetAvailabilityZone #"vpc-03c1cd9f299c225c8" 

        $tags = @(
            @{
                Key   = "Name";
                Value = (Read-Host "Enter your subnet $i tag ")
            }
        )

        New-EC2Tag -Resource $mySubnets.SubnetId -Tag $tags

        Write-Output "Subnet $i created with Id: $($mySubnets.SubnetId) and tag $($tags.Value)"

    }
    
}
elseif ($askforsubnet -in $no) {
    Write-Output "Thanks there is no subnet created"
}
else {
    Write-Output " $askforsubnet is not recognized please enter it correctly"
}

#--------------------------------------

#---------------------------------------------Rule group-------------------------------------------------------------------------------------
$RGname = Read-Host "Enter your Rule Group Name "

$type = Read-Host "Enter your Rule Group type (STATEFUL , STATLESS) "

$Capacity = Read-Host "Enter your Capacity"

$domain = Read-Host "Enter your DOMAIN ("ex. .example.com" ) "

New-NWFWRuleGroup -RuleGroupName $RGname `
                  -Type $type `
                  -StatefulRuleOptions_RuleOrder "STRICT_ORDER" `
                  -Capacity $Capacity `
                  -RulesSourceList_Target $domain `
                  -RulesSourceList_TargetType TLS_SNI, HTTP_HOST 


#----------------------------------------------CREATE Policy----------------------------------------------------------------------------------
$rule = Get-NWFWRuleGroupList

$FWPname = Read-Host "Enter your -Firewall Policy Name "


New-NWFWFirewallPolicy -FirewallPolicyName $FWPname `
                       -StatefulEngineOptions_StreamExceptionPolicy DROP `
                       -StatefulEngineOptions_RuleOrder "STRICT_ORDER" `
                       -FirewallPolicy_StatefulDefaultAction "aws:drop_established" `
                       -FirewallPolicy_StatelessDefaultAction  "aws:forward_to_sfe" `
                       -FirewallPolicy_StatelessFragmentDefaultAction "aws:forward_to_sfe" `
                       -FirewallPolicy_StatefulRuleGroupReference @{ResourceArn = $rule.Arn ; Priority = 1}
                                        

 -RuleGroupArn "arn:aws:network-firewall:us-east-1:654654537019:stateful-firewallpolicy/myRule" -Type STATEFUL

#-------------------------------------------------Create Firewall---------------------------------------------------------------------------------
$myvpc = Get-EC2Vpc
$subnets = Get-EC2Subnet
$policy = Get-NWFWFirewallPolicyList

function sub {
    foreach($subnet in $subnets){
           Write-Output " `e[34m$($subnet.Tag.Value)`e[0m `e[31m( $($subnet.SubnetId ) )`e[0m"   
    } 
}
$(sub)

[String]$subnetId = Read-Host "Enter your  subnet that you want to create your Firewall  $(sub) "

$Fwname = Read-Host "Enter your Firewall Name "

$ipType = Read-Host "Enter your IP Address Type (IPV4, IPV6) "

New-NWFWFirewall -FirewallPolicyArn $policy.Arn `
                 -FirewallName $Fwname `
                 -VpcId $myvpc.VpcId `
                 -SubnetMapping @{IPAddressType = $ipType  ; SubnetId = $subnetId }



#-----------------------------------------------< Create Route Tables and associate to Subnets >----------------------------------------------------------------

$vpce = Get-EC2VpcEndpoint -Region us-east-1 | Select-Object -ExpandProperty VpcEndpointId


$myvpc = Get-EC2Vpc
$subnets = Get-EC2Subnet
$igw = Get-EC2InternetGateway

function sub {
    foreach($subnet in $subnets){
           Write-Output " `e[34m$($subnet.Tag.Value)`e[0m `e[31m( $($subnet.SubnetId ) )`e[0m"   
    } 
}
$(sub)


$numberofroutetables = Read-Host "How many route tables do you want"

    for ($i = 1; $i -le $numberofroutetables; $i++) {
    $DestCidrBlock = Read-Host "Enter your Destination Cidr Block "
    $publicRouteTable = New-EC2RouteTable -VpcId $myvpc.VpcId  #"vpc-03c1cd9f299c225c8" 
    New-EC2Route -RouteTableId $publicRouteTable.RouteTableId `
           -DestinationCidrBlock $DestCidrBlock -VpcEndpointId $vpce
          
           $tags = @(
            @{
                Key   = "Name";
                Value = (Read-Host "Enter your Route table tag value ")
            }
        )
    
        New-EC2Tag -Resource $($publicRouteTable.RouteTableId)  -Tag $tags
        $ask = Read-Host "Do you want to register these route to a subnet"
        if ($ask -eq "yes"){
            [String]$subnetId = Read-Host "Enter your  subnet that you want to create your Firewall  $(sub) "
            Register-EC2RouteTable -GatewayId -RouteTableId $publicRouteTable.RouteTableId -SubnetId $subnetId
            Write-Output "Route Table With id: $($publicRouteTable.RouteTableId) created and tag: $($tags.Value) is associate to subnet id: $($subnetId) "

        } elseif ($ask -eq "no") {
            $ask_For_edge_association = Read-Host "Do you want to edit edge association for  these route table"
            if($ask_For_edge_association -eq "yes"){
                Register-EC2RouteTable -GatewayId $igw.InternetGatewayId -RouteTableId $publicRouteTable.RouteTableId
            }else{
                Write-Host "there is no association done"
            }
        } 
    
}


#---------------------------- Route Table for firewall subnet --------------------------------------------------------------------------

$publicRouteTable = New-EC2RouteTable -VpcId $myvpc.VpcId  #"vpc-03c1cd9f299c225c8" 

New-EC2Route -RouteTableId $publicRouteTable.RouteTableId `
        -DestinationCidrBlock 0.0.0.0/0 -GatewayId $igw.InternetGatewayId
       
        $tags = @(
         @{
             Key   = "Name";
             Value = (Read-Host "Enter your Route table tag value ")
         }
     )
 
     New-EC2Tag -Resource $($publicRouteTable.RouteTableId)  -Tag $tags

     [String]$subnetId = Read-Host "Enter your  subnet that you want to associate to your route table  $(sub) "

     Register-EC2RouteTable -RouteTableId $publicRouteTable.RouteTableId -SubnetId $subnetId
 
     #Write-Output "Route table $($publicRouteTable.RouteTableId)  created with tag: $($tags.Value) "
 
     Write-Output "Route Table With id: $($publicRouteTable.RouteTableId) created and tag: $($tags.Value) is associate to subnet id: $($subnetId) "



#-----------------------------------------------< Create EC2 Instances with Security Group >----------------------------------------------------------------

$userData = @"
#!/bin/bash
sudo yum update -y
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable --now httpd
sudo echo "web server 1" > /var/www/html/index.html
"@

$encodedUserData = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))


$key = Get-EC2KeyPair


$vpc = Get-EC2vpc
$subnets = Get-EC2Subnet

$askforinstance = Read-Host "Do you want to create a instance [ yes | no ] "

$numberofinstance = Read-Host "How many instance do you want"

if ($askforinstance -in $yes) {

    for ($i = 1; $i -le $numberofinstance; $i++) {
       
        
        #-------------------------------< Create Security Group > --------------------------------------------------------------------------------
        $SecurityGroupParams = @{
            GroupName   = Read-Host "Enter your Security group name"
            Description = Read-Host "Enter your Security group Description"
            VpcId       = $vpc.VpcId
        }
        
        $security = New-EC2SecurityGroup @SecurityGroupParams
            
        #Get-EC2SecurityGroup

        $numberofSG = Read-Host "How many permissions do you want"

        for ($n = 1; $n -le $numberofSG; $n++) {
            $IpPermission = @{
                IpProtocol = Read-Host "Enter your $n protocol "
                FromPort   = Read-Host "Enter your $n FromPort"
                ToPort     = Read-Host "Enter your $n ToPort"
                IpRanges   = Read-Host "Enter your $n IpRanges"
            }

            $security | Grant-EC2SecurityGroupIngress -IpPermission $IpPermission 

        }

        $tags = @(
            @{
                Key   = "Name";
                Value = (Read-Host "Enter your Security Group $i tag ")
            })

        New-EC2Tag -Resource $security -Tag $tags    
        Write-Output "Security group created with Id: $($security) and tag $($tags.Value)"

        #--------------------------------------------------------------------------------------------------------------------------------------       
        #-----------------------------------------------< Create EC2 Instances >--------------------------------------------------------------

        [String]$SubnetCidrBlock = Read-Host "Enter your  subnet that you want to create your instance  $(sub) "

        $params = @{
            ImageId           = "ami-079db87dc4c10ac91"
            AssociatePublicIp = $false
            InstanceType      = 't2.micro'
            SubnetId          = $SubnetCidrBlock
            KeyName           = $key.KeyName
            SecurityGroupId   = "$security"
            #UserData          = $encodedUserData
            
        }

        $myInstance = New-EC2Instance @params 

        $tags = @(
            @{
                Key   = "Name";
                Value = (Read-Host "Enter your instance $i tag ")
            }
        )

        New-EC2Tag -Resource $myInstance.Instances.InstanceId -Tag $tags
        Write-Output "instance $i created with Id: $($myInstance.Instances.InstanceId) and tag $($tags.Value)"

    }
    
}
elseif ($askforinstance -in $no) {

    Write-Output "Thanks there is no subnet created"
}
else {
    Write-Output " $askforinstance is not recognized please enter it correctly"
}



function Subnet_Search {
    $allsubnet , $subnet_num , $output = $null
    $allsubnet = Get-EC2Subnet 
    $i =1
    foreach($subnet_num in $allsubnet){
        $output = Write-Output " $i. $($subnet_num.SubnetId) <-----> $($subnet_num.Tags.value)"
        $output | Format-Table
        $i++
    } 
}
