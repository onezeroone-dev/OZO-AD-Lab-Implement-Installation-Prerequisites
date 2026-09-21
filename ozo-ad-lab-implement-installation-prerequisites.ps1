#Requires -Modules @{ModuleName="OZO"; ModuleVersion="1.7.0"},OZOLogger -RunAsAdministrator

<#PSScriptInfo
    .VERSION 1.1.0
    .GUID 63ebd3a1-0d72-4090-9226-10db30d2e82f
    .AUTHOR Andy Lievertz <alievertz@onezeroone.dev>
    .COMPANYNAME One Zero One
    .COPYRIGHT This script is released under the terms of the GNU General Public License ("GPL") version 2.0.
    .TAGS
    .LICENSEURI https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites/blob/main/LICENSE
    .PROJECTURI https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites
    .ICONURI
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites/blob/main/CHANGELOG.md
    .PRIVATEDATA
#>

<# 
    .SYNOPSIS
    See description.
    .DESCRIPTION 
    Implements the installation prerequisites for the One Zero One AD Lab.
    .PARAMETER FeatureName
    The name of the Windows feature to install. Default is "Microsoft-Hyper-V-All".
    .PARAMETER InternalIP
    The internal IP address for the lab network. Default is "172.16.1.1".
    .PARAMETER InternalSwitchName
    The name of the internal virtual switch. Default is "OZO AD Lab NAT".
    .PARAMETER LocalGroup
    The local group to which the current user should be added. Default is "Hyper-V Administrators".
    .PARAMETER OZOADLabISOs
    An array of ISO filenames for the lab environment. Default is "OZO-AD-Lab-Client.iso" and "OZO-AD-Lab-Server.iso" in the user's Downloads folder.
    .PARAMETER PrefixLength
    The prefix length for the lab network subnet. Default is 24.
    .PARAMETER Subnet
    The subnet for the lab network. Default is "172.16.1.0".
    .EXAMPLE
    ozo-ad-lab-implement-installation-prerequisites
    .LINK
    https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites/blob/main/README.md
#>

#PARAMETERS
[CmdletBinding()] Param(
    [Parameter(Mandatory=$false)][String] $FeatureName = "Microsoft-Hyper-V-All",
    [Parameter(Mandatory=$false,HelpMessage="The internal IP address for the lab network.")][String] $InternalIP = "172.16.1.1",
    [Parameter(Mandatory=$false,HelpMessage="The name of the internal virtual switch.")][String] $InternalSwitchName = "OZO AD Lab NAT",
    [Parameter(Mandatory=$false)][String] $LocalGroup = "Hyper-V Administrators",
    [Parameter(Mandatory=$false,HelpMessage="A hashtable of ISO filenames and their corresponding download URIs.")][Array] $OZOADLabISOs = @(
        (Join-Path -Path $Env:UserProfile -ChildPath "Downloads\OZO-AD-Lab-Client.iso"),
        (Join-Path -Path $Env:UserProfile -ChildPath "Downloads\OZO-AD-Lab-Server.iso")
    ),
    [Parameter(Mandatory=$false,HelpMessage="The prefix length for the lab network subnet.")][Int32] $PrefixLength = 24,
    [Parameter(Mandatory=$false,HelpMessage="The subnet for the lab network.")][String] $Subnet = "172.16.1.0"
)

# CLASSES
Class Main {
    # PROPERTIES: Booleans
    [Boolean] $prerequisitesSatisfied = $true
    # PROPERTIES: PSCustomObjects
    [PSCustomObject] $ozoLogger = @()
    # METHODS: Constructor method
    Main($FeatureName,$InternalIP,$InternalSwitchName,$LocalGroup,$OZOADLabISOs,$PrefixLength,$Subnet) {
        # Create a logger object
        $this.ozoLogger = (New-OZOLogger)
        # Call ValidateEnvironment to determine if we can proceed
        If ($this.ValidateEnvironment() -eq $true) {
            # Determine if thefeature is not installed
            If ($this.InstallFeature($FeatureName) -eq $false) {
                # Feature not installed
                $this.prerequisitesSatisfied = $false
            } Else {
                # Feature is installed; determine if a restart is required
                If ($this.RestartRequired($FeatureName) -eq $true) {
                    # Restart is required
                    $this.prerequisitesSatisfied = $false
                }
            }
            # Determine if the user not is added to the local group
            If ($this.ManageLocalGroup(([System.Security.Principal.WindowsIdentity]::GetCurrent().Name),$LocalGroup) -eq $false) { $this.prerequisitesSatisfied = $false }
            # Determine if the VM switches are not created
            If ($this.CreateVMSwitch($InternalIP,$InternalSwitchName,$PrefixLength,$Subnet) -eq $false) { $this.prerequisitesSatisfied = $false }
            # Determine if the required ISOs do not exist
            If ($this.ISOsExist($OZOADLabISOs) -eq $false) { $this.prerequisitesSatisfied = $false }
            # Determine if all prerequisites were met
            If ($this.prerequisitesSatisfied -eq $true) {
                # All prerequisites are satisfied
                $this.ozoLogger.Write("All prerequisites are satisfied. Please see https://onezeroone.dev/active-directory-lab-part-iii-create-the-virtual-machines for the next steps.","Information")
            }
        } Else {
            # Environment did not validate
            $this.ozoLogger.Write("The environment did not validate.","Error")
        }
    }
    # METHODS: Environment validation method
    Hidden [Boolean] ValidateEnvironment() {
        # Control variable
        [Boolean] $Return = $true
        # Determine if this a user-interactive session
        If ((Get-OZOUserInteractive) -eq $false) {
            # Session is not user-interactive
            $this.ozoLogger.Write("Please run this script in a user-interactive session.","Error")
            $Return = $false
        }
        # Return
        return $Return
    }
    # METHODS: Install feature method
    Hidden [Boolean] InstallFeature($FeatureName) {
        # Control variable
        [Boolean] $Return = $true
        # Determine if the feature is present
        If ([Boolean](Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue) -eq $false) {
            # Report
            $this.ozoLogger.Write(("Installing " + $FeatureName + " feature."),"Information")
            # Feature is not present; try to install it
            Try {
                Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
                # Success
            } Catch {
                # Failure
                $this.ozoLogger.Write(("Error installing the " + $FeatureName + " feature. Please manually install this feature and then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information."),"Error")
                $Return = $false
            }
        }
        # Return
        return $Return
    }
    # METHODS: Restart required method
    Hidden [Boolean] RestartRequired($FeatureName) {
        # Control variable
        [Boolean] $Return = $false
        # Determine if a restart is required
        If ((Get-WindowsOptionalFeature -Online -FeatureName $FeatureName).RestartRequired -eq "Required") {
            # Restart is required
            $this.ozoLogger.Write(("Please restart to complete the " + $FeatureName + " feature installation and then run this script again to continue."),"Warning")
            $Return = $true
            # Get restart decision
            If ((Get-OZOYesNo) -eq "y") {
                # User elects to restart
                Restart-Computer
            }
        }
        # Return
        return $Return
    }
    # METHODS: Manage local group membership
    Hidden [Boolean] ManageLocalGroup($CurrentUser,$LocalGroup) {
        # Control variable
        [Boolean] $Return = $true
        # Determine if the current user is a member of the local group
        If ((Get-LocalGroupMember -Name $LocalGroup).Name -NotContains $CurrentUser) {
            # Report
            $this.ozoLogger.Write(("Adding user to the local " + $LocalGroup + " group."),"Information")
            # User is not in the local group; try to add them
            Try {
                Add-LocalGroupMember -Group $LocalGroup -Member $CurrentUser -ErrorAction Stop
                # Success
            } Catch {
                # Failure
                $this.ozoLogger.Write(("Failure adding user " + $CurrentUser + " to the " + $LocalGroup + " group. Please manually add this user to this group then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information."),"Error")
                $Return = $false
            }
        }
        # Return
        return $Return
    }
    # METHODS: Create VM switch method
    Hidden [Boolean] CreateVMSwitch($InternalIP,$InternalSwitchName,$PrefixLength,$Subnet) {
        # Control variable
        [Boolean] $Return = $true
        # Determine if the Get-VMSwitch cmdlet is available
        If ([Boolean](Get-Command -Name Get-VMSwitch -ErrorAction SilentlyContinue) -eq $true) {
            # Get-VMSwtich cmdlet is available; determine if the NAT switch does not already exist
            If ([Boolean](Get-VMSwitch -Name $InternalSwitchName -ErrorAction SilentlyContinue) -eq $false) {
                # NAT switch does not already exist; try to create it and set the IP address
                Try {
                    New-VMSwitch -SwitchName $InternalSwitchName -SwitchType Internal -ErrorAction Stop | Out-Null
                    New-NetIPAddress -IPAddress $InternalIP -PrefixLength $PrefixLength -InterfaceIndex (Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Name -eq ("vEthernet (" + $InternalSwitchName + ")") }).ifIndex -ErrorAction Stop | Out-Null
                    # Success
                } Catch {
                    # Failure
                    $this.ozoLogger.Write(("Error creating the NAT switch with error " + $_ + ". You may need to log out and back in to refresh your group membership. If that does not resolve the issue, then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information."),"Error")
                    $Return = $false
                }
            }
            # Determine if the NAT network already exists
            If ([Boolean](Get-NetNat -Name $InternalSwitchName -ErrorAction SilentlyContinue) -eq $false) {
                # NAT network does not already exist; try to create it
                Try {
                    New-NetNat -Name $InternalSwitchName -InternalIPInterfaceAddressPrefix ($Subnet + "/" + $PrefixLength.ToString()) -ErrorAction Stop | Out-Null
                    # Success
                } Catch {
                    # Failure
                    $this.ozoLogger.Write(("Error creating the NAT network with error " + $_ + ". You may need to manually create this network, then run this script again to continue."),"Error")
                    $Return = $false
                }
            }
        } Else {
            # Get-VMSwitch cmdlet is not available
            $Return = $false
        }
        # Return
        return $Return
    }
    # METHODS: ISOs exist method
    Hidden [Boolean] ISOsExist($OZOADLabISOs) {
        # Control variable
        [Boolean] $Return = $true
        # Iterate over the list of required ISOs
        ForEach ($ISO in $OZOADLabISOs) {
            # Determine if the ISO exists
            If ([Boolean](Test-Path -Path $ISO -ErrorAction SilentlyContinue) -eq $false) {
                $this.ozoLogger.Write(("ISO not found: " + $ISO),"Error")
                $Return = $false
            }
        }
        # Return
        return $Return
    }
}

# MAIN
[Main]::new($FeatureName,$InternalIP,$InternalSwitchName,$LocalGroup,$OZOADLabISOs,$PrefixLength,$Subnet) | Out-Null
