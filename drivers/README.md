# Network Drivers for WinPE

This folder is for network drivers that need to be injected into WinPE for systems that don't have built-in driver support.

## Quick Fix for Lenovo ThinkCentre Tiny

### Option 1: Download from Lenovo (Recommended)

1. Go to https://pcsupport.lenovo.com
2. Enter your Lenovo model (e.g., "ThinkCentre M720q Tiny")
3. Go to **Drivers & Software** → **Manual Update**
4. Find **Networking: LAN (Ethernet)**
5. Download the driver package
6. Extract the ZIP file
7. Copy the **entire extracted folder** to `fog-automation-tools\drivers\network\`

Look for these specific drivers:
- **Intel I219-V** Gigabit Network Connection
- **Realtek PCIe GBE** Family Controller
- **Intel Ethernet Connection I219-LM**

### Option 2: Use Windows Driver Store (Quick but less reliable)

If you have a working Lenovo PC with network drivers installed:

1. On the Lenovo PC, open PowerShell as Administrator
2. Run this command:

```powershell
$driverPath = "C:\Lenovo_Network_Drivers"
mkdir $driverPath
Export-WindowsDriver -Online -Destination $driverPath | Where-Object {$_.ClassName -eq "Net"}
```

3. Copy the `C:\Lenovo_Network_Drivers` folder to this `drivers\network\` folder
4. Look for folders containing `.inf` files related to network adapters

### Option 3: Use Intel/Realtek Generic Drivers

**Intel Ethernet Drivers:**
- Download: https://www.intel.com/content/www/us/en/download/15084/intel-network-adapter-driver-for-windows-10.html
- Look for **PRO/1000 adapters** or **I219** series

**Realtek Ethernet Drivers:**
- Download: https://www.realtek.com/en/component/zoo/category/network-interface-controllers-10-100-1000m-gigabit-ethernet-pci-express-software
- Look for **PCIe GBE Family Controller**

## Folder Structure

Your folder should look like this:

```
drivers/
└── network/
    ├── Intel_I219/
    │   ├── e1d68x64.inf
    │   ├── e1d68x64.sys
    │   └── (other files)
    └── Realtek/
        ├── rt640x64.inf
        ├── rt640x64.sys
        └── (other files)
```

## After Adding Drivers

Run this command:

```powershell
.\add-network-drivers.ps1
```

Then rebuild your USB sticks:

```powershell
.\create-usb-simple.ps1 -DiskNumber 1 -DriveLetter D
```

## Troubleshooting

### Driver not found?
Make sure you downloaded the **Windows 10/11 x64** version, not Windows 7 or 32-bit.

### Which driver do I need?
Boot the Lenovo into Windows, open Device Manager, and check:
- Network adapters → Right-click → Properties → Details → Hardware IDs
- Look for `VEN_8086` (Intel) or `VEN_10EC` (Realtek)

### Still no network?
Some Lenovo models need **Intel Management Engine** drivers too. Download those from Lenovo support.
