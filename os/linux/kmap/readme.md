# Kasner Keyboard Layout for Linux without GUI (kmap)

> `.kmap` is the Linux console format for keyboard layout

This guide is specifically designed for **minimal Debian Linux installations without a GUI (headless / TTY-only)**. Because graphical environments (X11/Wayland) handle keyboards differently than the raw Linux console, installing custom layouts requires specific steps.

You can choose between two installation methods depending on which format you prefer to use:

1. **Method 1:** Download a pre-compiled `kasner.kmap` file and apply it directly.
2. **Method 2:** Download the XKB layout, compile it locally, and apply it.

## Method 1: Install from Pre-compiled `kasner.kmap` file

The compiled keyboard layout `kasner.kmap` file hosted in this repository. This is the fastest and safest method for install this keyboard to the systems without GUI.

*(`kasner.kmap` file is located at `os/linux/kmap/kasner.kmap` in the repository)*

### Option A: Automated script ot install the keyboard layout in kmap formant

Run the following commands as the `root` user:

```bash
   wget -O install_kasner.sh https://raw.githubusercontent.com/rvkasner/keyboards/main/os/linux/kmap/install_kasner.sh
   less install_kasner.sh
   chmod +x install_kasner.sh
   ./install_kasner.sh --help
   sudo ./install_kasner.sh --method kmap
```

Safety tips:

- Prefer `less install_kasner.sh` before running it as `root`.
- To revert changes (best-effort): `sudo ./install_kasner.sh --uninstall`
- To revert and remove installed files: `sudo ./install_kasner.sh --uninstall --purge`
- Consider pinning the download URL to a specific commit SHA once the layout is stable.

### Option B: Manual installation the keyboard layout in kmap formant

Run these commands as `root`:

1. **Install required tools:**

   ```bash
      apt update
      apt install -y wget
   ```

2. **Download the compiled `kasner.kmap` file directly to the system config folder:**

   ```bash
      mkdir -p /etc/console-setup
      wget -O /etc/console-setup/kasner.kmap "https://raw.githubusercontent.com/rvkasner/keyboards/main/os/linux/kmap/kasner.kmap"
   ```

3. **Configure the system to load the keymap:**

   Open `/etc/default/keyboard` using `nano` and ensure the `KMAP` variable points to the downloaded file:

   ```ini
      KMAP="/etc/console-setup/kasner.kmap"
   ```

4. **Apply changes system-wide:**

   ```bash
      setupcon
      update-initramfs -u
   ```

## Method 2: Install from XKB Format (Compiled Locally)

This method takes kasner custom XKB layout, compiles it into the Linux console format (`.kmap`) using Debian's built-in tools, and forces the system to load it.

**Target File:** [`os/linux/xkb/kasner`](https://github.com/rvkasner/keyboards/blob/main/os/linux/xkb/kasner)

### Option A: Automated script ot install the keyboard layout in xkb formant

You can install the XKB layout completely automatically using the provided bash script.

Run the following commands as the `root` user:

```bash
   wget -O install_kasner.sh https://raw.githubusercontent.com/rvkasner/keyboards/main/os/linux/kmap/install_kasner.sh
   less install_kasner.sh
   chmod +x install_kasner.sh
   ./install_kasner.sh --help
   sudo ./install_kasner.sh --method xkb
```

Safety tips:

- Prefer `less install_kasner.sh` before running it as `root`.
- To revert changes (best-effort): `sudo ./install_kasner.sh --uninstall`
- To revert and remove installed files: `sudo ./install_kasner.sh --uninstall --purge`
- Consider pinning the download URL to a specific commit SHA once the layout is stable.

### Option B: Manual installation the keyboard layout in xkb formant

If you prefer to see exactly what is changing in your system, run these commands as `root`:

1. **Install required packages:**

   ```bash
      apt update
      apt install -y wget
   ```

2. **Download the XKB layout file:**

   ```bash
      wget -O /usr/share/X11/xkb/symbols/kasner "https://raw.githubusercontent.com/rvkasner/keyboards/main/os/linux/xkb/kasner"
   ```

3. **Compile the XKB file to a TTY keymap:**

   ```bash
      mkdir -p /etc/console-setup
      ckbcomp kasner > /etc/console-setup/kasner.kmap
   ```

4. **Configure the system to load the compiled map:**
   Open `/etc/default/keyboard` in a text editor (like `nano`) and add/modify the `KMAP` line at the end of the file:

   ```ini
      KMAP="/etc/console-setup/kasner.kmap"
   ```

5. **Apply changes system-wide:**

   ```bash
      setupcon
      update-initramfs -u
   ```
