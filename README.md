# WinToDisk – Install Windows to Another Disk

> **Automated deployment tool for UEFI/GPT and BIOS/MBR partitioning.**

---

## Overview

This script simplifies the process of installing Windows onto a secondary physical disk. It is designed for technicians, homelab enthusiasts, and power users who need a clean deployment without the standard Windows Setup overhead.

**Key Features:**

* **Automated Partitioning:** Handles both UEFI (GPT) and legacy BIOS (MBR) layouts.
* **Image Application:** Applies `install.wim` or `install.esd` files directly via DISM.
* **Boot Configuration:** Automatically configures boot files (BCDBOOT).
* **Recovery Environment:** Sets up and configures the Windows Recovery Environment (WinRE).

---

## How It Works

1. **Admin Elevation:** If not run as administrator, the script requests administrator privileges.
2. **Drive Letter Check:** Ensures temporary letters (ESP, Windows, Recovery) aren't already in use.
3. **Image Detection:** Locates the source image from user input and prompts for the Windows edition index.
4. **Safety First:** Lists available disks but **protects the system disk** from accidental selection.
5. **Deployment:** Runs `DiskPart`, applies the image using `DISM`, sets up the Bootloader and Recovery.
6. **Cleanup:** Removes temporary drive letters once the process is complete.

---

## Configuration

You can customize the script behavior by editing the following sections within the file:

### Section 2.1 – Drive Letters

Change these if the default letters conflict with your existing drives.

* `set "ESP=Y"` — Boot partition
* `set "WIN=W"` — Windows partition
* `set "REC=U"` — Recovery partition

### Section 2.2 – Partition Sizes (MB)

| Partition | Variable | Default | Mode |
| --- | --- | --- | --- |
| **EFI System** | `ESP_SIZE` | 300 | UEFI |
| **MSR** | `MSR_SIZE` | 16 | UEFI |
| **Recovery** | `REC_SIZE` | 1026 | Both |
| **System Reserved** | `SRP_SIZE` | 500 | BIOS |

*Note: The Windows partition automatically expands to fill the remaining disk space.*

---

## UEFI vs BIOS

* **UEFI (GPT):** Recommended for modern PCs. Supports Secure Boot and disks larger than 2TB. Creates ESP, MSR, Windows, and Recovery partitions.
* **BIOS (MBR):** For legacy systems. Limited to 2TB disks. Creates System Reserved, Windows, and Recovery partitions.

---

## Quick Start Guide

### 1. Prepare the Windows Image

1. Download a Windows ISO from Microsoft.
2. **Mount the ISO** (Right-click > Mount).
3. Locate `install.wim` or `install.esd` inside the `sources` folder.
* *Example:* If the ISO is mounted as `E:`, the path is `E:\sources\install.wim`.

*Note: You can also specify the path to your custom Windows Image (install.wim or install.esd).*

### 2. Run the Script

1. Right-click the script and select **Run as Administrator**.
2. Follow the prompts to:
* Provide the image path (e.g., `E:` or `C:\Images\install.wim`).
* Select the Windows Edition index.
* Choose the target disk and boot mode (UEFI/BIOS).



### 3. Verification

Once the script says `Installation SUCCESSFUL`, boot from the target disk. To verify the recovery environment, run:

```cmd
reagentc /info
```

---

## Important Notes

* **Data Loss:** The target disk is **completely wiped**. Ensure you have backups.
* **Protection:** The script will not allow you to select the disk currently running Windows.
* **Recovery:** WinRE is enabled automatically if `Winre.wim` is detected in the source.

---

## Troubleshooting

| Error | Solution |
| --- | --- |
| **Drive letter X: in use** | Change the letters in Section 2.1 of the script. |
| **No .wim or .esd found** | Ensure the ISO is mounted or the path provided is correct. |
| **DISM failed** | Check for image corruption or insufficient space on the target disk. |
| **BCDBOOT failed** | Ensure the ESP was created. |

> **Pro Tip:** If Recovery (WinRE) is disabled after boot, run `reagentc /enable` in an elevated Command Prompt.

*Note:*
*To correctly configure the Windows Recovery Environment (WinRE) on the target Windows system, this script will first disable WinRE on the current system and then re‑enable it later. Although I don’t particularly like this approach, it was the only reliable method I found to ensure proper configuration.*

*Otherwise, WinRE may end up disabled or incorrectly linked to the Windows partition (partition 3) instead of the dedicated recovery partition (partition 4) on a GPT layout, for example.*

*Technically, WinRE will still function if linked to partition 3, provided that winre.wim exists in the recovery folder. However, this is not ideal, since the system already has a separate recovery partition intended for that purpose.*
