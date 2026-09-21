# OZO AD Lab Implement Installation Prerequisites

## Description
An interactive script that automates [part](https://onezeroone.dev/active-directory-lab-part-iii-installation-prerequisites/) of a One Zero One [series](https://onezeroone.dev/active-directory-lab-part-i-introduction/) illustrating how to automate the process of deploying an AD Lab. It has no parameters.

## Installation
This script is published to [PowerShell Gallery](https://learn.microsoft.com/en-us/powershell/scripting/gallery/overview?view=powershell-5.1). Ensure your system is configured for this repository then execute the following in an _Administrator_ PowerShell:

```powershell
Install-Script ozo-ad-lab-implement-installation-prerequisites
```

## Usage
```powershell
ozo-ad-lab-implement-installation-prerequisites
    [-FeatureName]
    [-InternalIP]
    [-InternalSwitchName]
    [-LocalGroup]
    [-OZOADLabISOs]
    [-PrefixLength]
    [-Subnet]
```

## Parameters
|Parameter|Description|
|---------|-----------|
|`FeatureName`|The name of the Windows feature to install. Default is _Microsoft-Hyper-V-All_.|
|`InternalIP`|The internal IP address for the lab network. Default is `172.16.1.1`.|
|`InternalSwitchName`|The name of the internal virtual switch. Default is _OZO AD Lab NAT_.|
|`LocalGroup`|The local group to which the current user should be added. Default is _Hyper-V Administrators_.|
|`OZOADLabISOs`|An array of ISO filenames for the lab environment. Default is `OZO-AD-Lab-Client.iso` and `OZO-AD-Lab-Server.iso` in the user's Downloads folder.|
|`PrefixLength`|The prefix length for the lab network subnet. Default is 24.|
|`Subnet`|The subnet for the lab network. Default is `172.16.1.0`.|

## Examples
```powershell
ozo-ad-lab-implement-installation-prerequisites
```
## Notes
Run this script in an _Administrator_ PowerShell.

## Acknowledgements
Special thanks to my employer, [Sonic Healthcare USA](https://sonichealthcareusa.com), who supports the growth of my PowerShell skillset and enables me to contribute portions of my work product to the PowerShell community.
