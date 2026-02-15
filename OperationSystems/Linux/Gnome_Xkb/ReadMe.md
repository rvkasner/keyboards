# Kasner Keyboard Layout for Linux (XKB)

This directory contains the Kasner keyboard layout implementation for Linux systems using the X Keyboard Extension (XKB). This implementation integrates deeply with the operating system, ensuring seamless functionality across all applications, terminal emulators, and desktop environments (GNOME, KDE, XFCE, etc.) without the need for third-party background daemons.

## 📂 Contents

- `kasner`: The core XKB symbols file defining the key mappings. This text file contains the complete logic for the key layers and modifier behaviors specific to the Linux environment.

- `README.md`: Technical documentation, installation instructions, and troubleshooting for Linux systems.

## 🚀 Installation

You can install this layout manually or use the provided shell commands for a quick setup. Both methods achieve the same result: copying the symbol file to the system directory and registering it in the X11 configuration rules so it appears in your GUI settings.

### Prerequisites

- Root (`sudo`) access to write to system directories.

- A Linux distribution using X11 or Wayland (Fedora, Ubuntu, Arch, Debian, etc.).

- Desktop Environment: GNOME, KDE Plasma, XFCE, or a Window Manager (i3, Sway).

### Manual Installation

If you prefer to understand every change made to your system or need to debug the installation:

1. **Copy the layout file:**

    Place the definition file into the X11 symbols directory.

    ```bash
    sudo cp kasner /usr/share/X11/xkb/symbols/
    ```

2. **Edit the rules file:**

    Open the XKB rules registry. This file tells the system which layouts exist and what languages they belong to.

    ```bash
    sudo nano /usr/share/X11/xkb/rules/evdev.xml
    ```

3. **Add the configuration block:**

    Scroll down to the `<layoutList>` section (usually near the end of the file). Add the following entry inside it, ensuring it is placed before the closing `</layoutList>` tag:

    ```xml
    <layout>
        <configItem>
            <name>kasner</name>
            <shortDescription>kas</shortDescription>
            <description>English (Kasner)</description>
            <languageList>
                <iso639Id>eng</iso639Id>
            </languageList>
        </configItem>
    </layout>
    ```

4. **Clear Cache:**

    Remove compiled keymaps to ensure the new file is read immediately.

    ```bash
    sudo rm -rf /var/lib/xkb/*.xkm
    ```


5. **(Optional) Ubuntu: Editing the `evdev.lst` File** (Additional Step if needed)

    Although GNOME primarily relies on `.xml` files, some system components still reference the `.lst` file. If the layout is still not appearing in the settings, you should register it here as well.
    
    5.1. Open the file for editing:
    
    ```bash
    sudo nano /usr/share/X11/xkb/rules/evdev.lst
    ```
    
    5.2. Locate the section starting with `! layout`.
    
    5.3. Add a new line at the end of this section (following the format: `filename description`):
    
    ```text
    kasner         Kasner (English)
    ```
    
    5.4. Save the file.

6. **Please restart your session or reboot to apply changes.**

## ⚙️ Activation

After installation, the layout is registered but not yet active. You must add it to your user's input sources via your desktop environment settings.

### GNOME (Fedora, Ubuntu)

1. Open **Settings** > **Keyboard**.
1. Under the "Input Sources" section, click the + button.
1. Click on the three dots (Vertical ellipsis) > **Other** (or filter by "English" if your system language is English).
1. Search for English (Kasner).
1. Select it and click **Add**. You can now switch to it using `Super` + `Space`.

### KDE Plasma

1. Open **System Settings** > **Input Devices** > **Keyboard**.
1. Go to the **Layouts** tab.
1. Click **Add Layout**.
1. Select "English" as the language.
1. In the "Layout" or "Variant" dropdown, look for **Kasner**.

### Command Line (Temporary / X11)

To test the layout immediately without configuring GUI settings (useful for testing or minimal window managers like i3):

```bash
setxkbmap -layout kasner
```

> Note: This change is not persistent across reboots.

## ⚠️ Important Notes

- **System Updates**: On some distributions (especially rolling releases like Arch), updates to the `xkeyboard-config` package might overwrite `/usr/share/X11/xkb/rules/evdev.xml`. If your layout disappears from the settings menu after a system update, you may need to re-add the XML block (Step 2 of installation). The symbol file `symbols/kasner` usually remains untouched.

- **Wayland vs X11**: This layout is compatible with both display servers. However, Wayland compositors (like Mutter in GNOME) handle input strictly. A logout/login is almost always required after installation for the compositor to reload the XKB rules.

## 🛠 Troubleshooting

### Layout not showing in list

- **Syntax Check**: Ensure `evdev.xml` has valid XML syntax. If you accidentally deleted a closing tag, the settings menu might fail to load the list.

- **Restart**: Restart your Desktop Environment (Log out and log back in). GNOME reads the rules file only on session start.

### Changes not applying

- **Cache**: Clear the cache again: `sudo rm -rf /var/lib/xkb/*.xkm`.

- **Verification**: If using GNOME, you can verify if the system sees your layout by running:

    ```bash
    gsettings get org.gnome.desktop.input-sources sources
    ```

    It should output something containing `('xkb', 'kasner')`.

- **Typographical Errors**: Double-check the filename in `/usr/share/X11/xkb/symbols/` matches the `<name>` tag in `evdev.xml` exactly.
