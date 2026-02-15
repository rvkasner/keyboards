# Kasner Keyboard Layout

Kasner is a unified, polyglot-first keyboard layout designed for programmers and writers who work extensively with multiple languages (English, Russian, Ukrainian).

It solves the fundamental problem of standard layouts: inconsistent symbol placement.

## The Problem

For a polyglot developer, standard layouts (QWERTY/ЙЦУКЕН) are inefficient and frustrating:

1. **Symbol Shifting:** The period (`.`) and comma (`,`) move to completely different physical keys when switching between English and Russian/Ukrainian.

1. **Pinky Overload:** Special characters used in coding are often pushed to hard-to-reach corners due to the larger size of the Cyrillic alphabet.

1. **Muscle Memory Breakers:** Switching languages breaks the flow of typing punctuation and syntax.

## The Solution

### One muscle memory for all languages

The Kasner layout is built on the principle of **Symbol Unification**. Regardless of whether you are typing code in Python, documentation in English, or a message in Ukrainian, **all punctuation and syntax symbols remain in the exact same physical location**.

### Core Philosophy

- **Dvorak-Based English:** The English layer is based on Dvorak to maximize ergonomic efficiency and hand alternation.

- **Unified Symbols:** The symbol keys defined in the English layer are "locked" in place. The Cyrillic (RU/UA/BY) and German layers are built around these fixed symbols.

- **Polyglot Optimized:** Designed specifically for users switching between EN, RU, UA, BY, and DE daily.

## The Layout

This is the foundational map. All other language variations respect the symbol placement defined here.

### Visual Map of Layouts

#### ANSI 104

> English - EN/US

![English ANSI Layout](./Visualizations/keyboard-layout-editor/Kasner-En-Us-104-ANSI/kasner-en(us)-2026.png)

> Russian - RU/RU

![Russian ANSI Layout](./Visualizations/keyboard-layout-editor/Kasner-Ru-Ru-104-ANSI/kasner-ru(ru)-2026.png)

> Ukrainian - UK/UA

![Ukrainian ANSI Layout](./Visualizations/keyboard-layout-editor/Kasner-Uk-Ua-104-ANSI/kasner-uk(ua)-2026.png)

#### Alice

> English EN/US - Keychron Q14 Max

![English Alice Layout](./Visualizations/keyboard-layout-editor/Kasner-En-Us-Keychron-Q14/kasner-en(us)-alice-keychron-q14.png)

## Installation

Choose your operating system to view specific installation instructions:

### Linux

Full support via XKB (X11 & Wayland).

- **Setup:** [Installation Guide for Linux](./OperationSystems/Linux/Gnome_Xkb/ReadMe.md)

- **Supported:** Fedora, Ubuntu, Arch, Debian, and others.

### macOS

- **Setup:** [Installation Guide for macOs](./OperationSystems/macOS/ReadMe.md)

- **Supported:** via `.bundle` with `.keylayout` and Karabiner-Elements.

### Windows

- **Setup:** 🚧 *To be done*

- **Supported:**  via Microsoft Keyboard Layout Creator (MSKLC).

## License

Distributed under the `MIT License`. See `LICENSE` for more information.
