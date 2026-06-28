---
title: "The Omarchy Manual"
author: "DHH"
url: "https://learn.omacom.io/2/the-omarchy-manual"
---

# Welcome to Omarchy!

Omarchy is an [omakase](https://manuals.omamix.org/3/omacom/76/omakase-computing) Linux distribution based on [Arch](https://archlinux.org/) and the tiling window manager [Hyprland](https://hypr.land/). It ships with everything a modern software developer needs to be productive immediately from [Neovim](https://neovim.io/) (btw) to Spotify, Chromium to [Typora](https://typora.io/), and [Alacritty](https://alacritty.org/) to LibreOffice. Hell, even Zoom is there!

This isn't just a grab bag of preinstalled packages, though. It's a complete system designed with both aesthetics and productivity in mind. Because a _beautiful_ system is a _motivating_ system, and productivity has always been [downstream from motivation](https://world.hey.com/dhh/beautiful-motivations-6fef7c73). There's zero bloat here: Just everything I use.

It's true that developing an eye for the beauty of a TUI-heavy, theme-delighted, tiling-window-managed system like Omarchy can be an acquired taste. But that's why you're here, isn't it? To experience something a little outside of your comfort zone? To embark on a little bit of an adventure into a new way of working with computers? I hope so.

Omarchy isn't like Windows and it's not like macOS either. It's not trying to be as familiar as possible. It's trying to be beautiful and _better_. Embrace the Linux-ness of it all. Manually editing some config files, sure. Heavy on the terminal, definitely.

Let's get started with the basics.

The Basics

# Getting Started

Omarchy is installed using an ISO. It's designed for a dedicated drive, so dual-booting requires two disks in your machine (unless you do a [manual install](/2/the-omarchy-manual/96/manual-installation) to work around this). The installation will wipe the selected drive and use full-disk encryption, so be sure to take a backup before using an existing drive!

[Download the Omarchy ISO](https://omarchy.org/) first, put it on a USB stick (use [balenaEtcher](https://etcher.balena.io/) on Mac/Windows or [caligula](https://github.com/ifd3f/caligula) on Linux), and boot off the stick.

_You must turn off Secure Boot and/or TPM in the BIOS. You have to turn these off to be able to install Omarchy. They're Microsoft security schemes meant for Windows and Microsoft-affiliated Linux distributions._

Then answer the configuration questions, and confirm them like this:

 ![omarchy-install.png](/u/omarchy-install-k5Iksv.png) 

Then select a drive for your installation, and sit back and watch the installation show go. It takes between 2-10 minutes, depending on the speed of your computer.

 ![omarchy-installed.png](/u/omarchy-installed-NR1wu1.png) 

Now you're ready to Omarchy!

---

### Use a wired or 2.4ghz keyboard!

The full-disk encryption won't allow you to enter the password from a Bluetooth keyboard at startup. Just like you can't use a Bluetooth keyboard to enter the BIOS on a PC. You'll need a keyboard that either uses a 2.4ghz dongle or a cable (which is much nicer for latency anyway!). I personally love the [Lofree Flow84](https://www.lofree.co/products/lofree-flow-the-smoothest-mechanical-keyboard)! 

---

### No-encryption installations

Omarchy is installed with encryption by default. It's the safe, reasponsible choice for any computer that can possibly be lost or stolen. You don't want anyone with access to your hardware to be able to get your data!

But in special circumstances, like remote Omarchy installs on protected computers or for throw-away installations without sensitive data, you may want to install without encryption. You can hit `Ctrl + U` on the disk formatting confirmation to switch to an encryption-less installation.

---

### Help if you're stuck

If you get stuck, you can usually find someone willing to help in the _#omarchy-help_ channel on [the community Discord](https://omarchy.org/discord).

---

### Use manual installation for special needs

If you have special needs, like installing Omarchy onto M-Series MacBooks [Asahi Alarm](https://asahi-alarm.org/) or because you want to try dual-booting on a single drive, you should follow [the instructions for a manual installation](/2/the-omarchy-manual/96/manual-installation).

# Navigation

Everything in Omarchy happens via the keyboard — _EVERYTHING!_ When the system first starts, you literally can't do a thing with the mouse alone. But you can hit `Super + Space` to reveal the application launcher and `Super + Alt + Space` to open the Omarchy Menu. These two commands allow you to do just about everything.

But the application launcher is not intended to be the main way to operate the system most of the time. We can get faster than that! All the most important applications are bound directly to individual hotkeys. You start the terminal with `Super + Return` and a browser with `Super + Shift + Return`. Try doing one after the other, and you'll see the magic of Hyprland's tiling in action:

 ![browser+terminal.png](https://manual.omakub.org/u/browser-terminal-yCV75f.png) 

You can then hit `Super + J` to stack them horizontally instead of vertically:

 ![stacked.png](/u/stacked-sswEJE.png) 

Hit `Super + J` again to return them to horizontal positions. Then try `Super + Shift + Arrow Right` while on the browser to swap the windows.

Now try `Super + Ctrl + T` to start the Activity monitor. That'll appears as a floating window. You can tile it using `Super + T` (and hit that again to make it floating again). Now press `Super + Shift + F` to open the files manager. You'll have a neat four-way setup:

 ![fourway-tiling.png](/u/fourway-tiling-SHbfzO.png) 

You navigate between the window you want to be active with `Super + Arrow`. This will switch focus and move the cursor to the center of the new application.

If you hit `Super + Shift + 2`, you'll move the current focused application onto the second workspace. `Super + Shift + 1` moves it back. (And `Super + Shift + Alt + 2` will move the current focused application onto the second workspace without switching to it).

If you hold down `Super` and use the mouse to click on a window, you'll be able to rearrange where it sits. If you hold `Super` and use the right button on the mouse, you can freely resize the window.

You close a window on `Super + W` (and close all windows on `Ctrl + Alt + Delete`).

You can also go full screen with `Super + F` or even just full-width (keeping the top bar) with `Super + Alt + F` or full-screen within a window with `Super + Ctrl + F` (good for YouTube!).

---

### Dwindle vs scrolling layout

Omarchy's default layout is called dwindle. It keeps all the windows you open on a single workspace visible at all time, even if it has to shrink them down.

 ![dwindle-layout.png](/u/dwindle-layout-BNU9qb.png) 

But you can also choose to turn a workspace into the scrolling layout where windows are lined up side-by-side, beyond the visible edge of the display. You turn a single workspace into this layout via `Super + L`.

 ![niri-layout.png](/u/niri-layout-LvV25i.png) 

If you wish to ue the scrolling layout as the default, you can set that in `~/.config/hypr/looknfeel.conf` under `general { layout = scrolling }`.

---

### Grouping windows

Windows can be grouped using `Super + G`. Once you're in a group, every window you start while that's active will belong to the group. You can move between these grouped windows using `Super + Ctrl + Arrows` or `Super + Alt + 1/2/3/4` to go directly to grouped window in order. 

You can move a window out of the grouping with `Super + Alt + G` or disassemble the entire group by hitting `Super + G` again. Finally, you can move windows outside the group into it with `Super + Alt + Arrows`.

---

### Popping windows

You can pop a window out of its workspace allocation with `Super + O`. That'll pin it as a floating window that follows you on whatever workspace you go to. Great for video players and the like.

 ![popped-window.jpg](/u/popped-window-L8N3dk.jpg) 

---

### Scratchpad workspace

Finally, there's a special scratchpad workspace that overlays on whatever workspace you're currently on. You access what's on that using `Super + S` and you place windows there using `Super + Alt + S`. 

It works well for controls or perhaps a terminal that you quickly want to interact with in an overlay without leaving the current workspace. If you want to move a window off the scratchpad, you just move it directly to another workspace with something like `Super + Shift + 1` to move it to workspace 1.

---

### It takes some getting used to!

It takes a little while to get used to navigating your desktop like this, but once you do, it'll be hard to go back to a traditional mouse-driven desktop experience!

# Themes

Omarchy comes with nineteen beautiful themes. You can select between them via _Style > Theme_ in the Omarchy Menu (`Super + Alt + Space`) or hop directly to the theme selector using `Super + Ctrl + Shift + Space`. 

Each theme styles the desktop, terminal, neovim, activity screen (btop), notifications (mako), top bar (waybar), application launcher (walker), and the lock screen (hyprlock). (For Obsidian, you must manually select the Omarchy theme via _Appearance > Themes_ inside the app).

Themes have a set of background images that you can pick between using `Super + Ctrl + Space`.

You can find even more themes on [the extra themes page](/2/the-omarchy-manual/90/extra-themes) or even [make your own theme](/2/the-omarchy-manual/92/making-your-own-theme).

 ![tokyo-night.png](/u/tokyo-night-yN9jzd.png)
_Tokyo Night_

 ![catppuccin.png](/u/catppuccin-DEGjke.png) 
_Catppuccin_

 ![preview.png](/u/preview-LFlhHZ.png) 
_Lumon_

 ![preview.png](/u/preview-bAfGjN.png) 
_Ethereal_

 ![everforest.png](/u/everforest-VTw7rC.png) 
_Everforest_

 ![gruvbox.png](/u/gruvbox-zTUJ1I.png) 
_Gruvbox_

 ![preview.png](/u/preview-9laZfK.png)
_Miasma_



 ![hackerman-6k-tc.png](/u/hackerman-6k-tc-9s09Op.png) 
_Hackerman_

 ![osaka-jade.jpg](/u/osaka-jade-15wLcY.jpg) 
_Osaka Jade_

 ![kanagawa.png](/u/kanagawa-qNhehU.png) 
_Kanagawa_

 ![nord.png](/u/nord-Rd2Y6y.png) 
_Nord_

 ![2025-07-15-193947_hyprshot.png](/u/2025-07-15-193947_hyprshot-b4lj4R.png) 
_Matte Black_

 ![preview.png](/u/preview-sQ8537.png) 
_Vantablack_

 ![ristretto-theme.png](/u/ristretto-theme-c99Sux.png)
_Ristretto_

 ![preview.png](/u/preview-Owc1Dr.png) 
_Retro 82_

 ![flexoki-theme.png](/u/flexoki-theme-YaATok.png) 
_Flexoki Light_

 ![omarchy-rose-pine.png](/u/omarchy-rose-pine-MUH6hH.png) 
_Rose Pine_

 ![catppuccin-latte-theme.png](/u/catppuccin-latte-theme-1-jrWCjt.png) 
_Catppuccin Latte_

 ![preview.png](/u/preview-Vkqw3x.png)
_White_

---

### Unlocks

Themes can also have a custom unlock design, which is used for the boot decryption process. You can select one of these under _Style > Unlock_. They look like this:

 ![preview-unlock.png](/u/preview-unlock-f99Qj5.png) 
_Catppuccin_

 ![preview-unlock.png](/u/preview-unlock-YKXUd2.png) 
_Catppuccin Latte_

 ![preview-unlock.png](/u/preview-unlock-bGBH8Q.png) 
_Ethereal_

 ![preview-unlock.png](/u/preview-unlock-FlHgXd.png) 
_Everforest_

 ![preview-unlock.png](/u/preview-unlock-BhGaEN.png) 
_Flexoki Light_

 ![preview-unlock.png](/u/preview-unlock-olzWHR.png) 
_Gruvbox_

 ![preview-unlock.png](/u/preview-unlock-Tuon1J.png) 
_Hackerman_

 ![preview-unlock.png](/u/preview-unlock-gocOzZ.png) 
_Kanagawa_

 ![preview-unlock.png](/u/preview-unlock-6q3QpH.png) 
_Lumon_

 ![preview-unlock.png](/u/preview-unlock-nl4qCr.png) 
_Matte Black_

![preview-unlock.png](/u/preview-unlock-1eSMmK.png) 
_Miasma_
 
 ![preview-unlock.png](/u/preview-unlock-GTK6ej.png) 
_Nord_

 ![preview-unlock.png](/u/preview-unlock-fYJ662.png) 
_Osaka Jade_

 ![preview-unlock.png](/u/preview-unlock-To0aVk.png) 
_Retro 82_

 ![preview-unlock.png](/u/preview-unlock-VRxFRi.png) 
_Ristretto_

![preview-unlock.png](/u/preview-unlock-H96PoE.png)
_Rose Pine_

 ![preview-unlock.png](/u/preview-unlock-EuHzFS.png) 
_Tokyo Night_

 ![preview-unlock.png](/u/preview-unlock-GDGhfQ.png) 
_Vantablack_

 ![preview-unlock.png](/u/preview-unlock-5kJYE8.png) 
_White_



# Hotkeys

You can see all the main keyboard bindings with `Super + K`.

## Navigating

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + Space`           | Application launcher    |
| `Super + Alt + Space` | Omarchy control menu |
| `Super + Escape` | System menu (suspend, restart, etc)  |
| `Super + Ctrl + L` | Lock computer |
| `Super + W`               | Close window             |
| `Ctrl + Alt + Del` | Close all windows |
| `Super + T`               | Toggle window between tiling/floating             |
| `Super + J` | Toggle window position (horizontal/vertical) |
| `Super + O`               | Toggle popping window into sticky'n'floating |
| `Super + L`               | Toggle between dwindle and scrolling layout |
| `Super + P`               | Toggle pseudo window style (natural v stretch) |
| `Super + F`                 | Go full screen              |
| `Super + Alt + F`                 | Go full width              |
| `Super + Ctrl + F`                 | Go full screen inside window              |
| `Super + 1/2/3/4`         | Jump to specific workspace     |
| `Super + Tab` | Jump to next workspace |
| `Super + Shift + Tab` | Jump to previous workspace |
| `Super + Ctrl + Tab` | Jump to former workspace |
| `Super + Shift + 1/2/3/4` | Move window to workspace |
| `Super + Shift + Alt + 1/2/3/4` | Move window to workspace without following |
| `Super + Shift + Alt + Arrows` | Move workspaces to directional monitor |
| `Super + Arrow`  | Move focus to window in direction of arrow              |
| `Super + Shift + Arrow`  | Swap window with another in direction of arrow     |
| `Super + Equal` | Grow windows to the left |
| `Super + Minus` | Grow windows to the right |
| `Super + Shift + Equal` | Grow windows to the bottom |
| `Super + Shift + Minus` | Grow windows to the top |
| `Super + Left Mouse` | Drag window around |
| `Super + Right Mouse` | Resize window |
| `Super + Scroll Wheel` | Scroll through workspaces |
| `Super + G`               | Toggle window grouping      |
| `Super + Alt + G`               | Move window out of grouping      |
| `Super + Alt + Tab`               | Cycle between windows in grouping      |
| `Super + Alt + 1/2/3/4`               | Jump to specific window in grouping      |
| `Super + Alt + Arrow`  | Move window into grouping in direction of arrow  |
| `Super + Ctrl + Arrow`  | Move between windows inside a tiling group |
| `Super + S` | Show scratchpad workspace overlay |
| `Super + Alt + S` | Move window to scratchpad workspace |
| `Super + Ctrl + Z` | Zoom in on screen (repeat for more zoom) |
| `Super + Ctrl + Alt + Z` | Zoom fully out from screen |
| `Super + /` | Cycle forward through monitor scaling options |
| `Super + Alt + /` | Cycle backward through monitor scaling options |
| `Alt + Tab` | Cycle forward through windows on the active workspace |
| `Alt + Shift + Tab` | Cycle backward through windows on the active workspace |
| `Ctrl + Alt + Tab`| Cycle focus forward through monitors |
| `Ctrl + Alt + Shift + Tab`| Cycle focus backwards through monitors | 

---

## System controls

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + Ctrl + A`           | Audio controls (wiremix)    |
| `Super + Ctrl + B`           | Bluetooth controls (bluetui)    |
| `Super + Ctrl + W`           | Wifi controls (impala)    |
| `Super + Ctrl + S` | Share menu (via LocalSend) |
| `Super + Ctrl + T`           | Activity (btop)    |
| `Super + Ctrl + C` | Capture controls (screenshot/-recording/picker) |
| `Super + Ctrl + O` | Toggle menu |
| `Super + Ctrl + H` | Hardware menu |
| `Super + Ctrl + .` | Transcoding menu |

---

## Adjustments

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Shift + Brightness Up` | Maximum screen brightness |
| `Shift + Brightness Up` | Minimum screen brightness |
| `Alt + Brightness Up/Down` | Precise 1% brightness changes |
| `Alt + Volume Up/Down` | Precise 1% volume changes |

---

## Launching apps

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + Return`           | Terminal    |
| `Super + Alt + Return` | Tmux terminal |
| `Super + Shift + Return`           | Browser    |
| `Super + Shift + Alt + B`           | Browser (private/incognito)    |
| `Super + Shift + F`           | File manager    |
| `Super + Shift + Alt + F`           | File manager in cwd of terminal    |
| `Super + Shift + M`           | Music (Spotify)    |
| `Super + Shift + Alt + M`           | Music (cliamp)    |
| `Super + Shift + /`           | Password manager (1password)    |
| `Super + Shift + N`           | Neovim  |
| `Super + Shift + C`           | Calendar ([HEY](https://hey.com/))  |
| `Super + Shift + E`           | Email ([HEY](https://hey.com/))  |
| `Super + Shift + A`           | AI (ChatGPT)  |
| `Super + Shift + Alt + A`           | AI (Grok)  |
| `Super + Shift + G`           | Messenger (Signal)  |
| `Super + Shift + P`           | Google Photos  |
| `Super + Shift + Alt + G`           | Messenger (WhatsApp)  |
| `Super + Shift + Ctrl + G`           | Messenger (Google)  |
| `Super + Shift + D`           | Docker (LazyDocker)  |
| `Super + Shift + O`           | Obsidian  |
| `Super + Shift + W`           | Writing (Typora)  |
| `Super + Shift + X`           | X |
| `Super + Shift + Alt + X`           | X Compose |
| `Super + Shift + Y`           | YouTube |

Change/add bindings in `~/.config/hypr/bindings.conf`.

---

## Universal clipboard

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + C`           | Copy    |
| `Super + X`           | Cut (not in terminal)    |
| `Super + V`           | Paste    |
| `Super + Ctrl + V`           | Clipboard manager    |

Usually on Linux, you need `Ctrl + Shift + C/V` to copy'n'paste in the terminal and `Ctrl + C/V` to do it everywhere else. These Omarchy unified clipboard hotkeys work everywhere (except the file manager). 

---

## Capture

| Hotkey              | Function                       |
| ------------------- | ------------------------------ |
| `Super + Ctrl + C` | Capture menu (for keyboards w/o PrintScr button) |
| `Print Screen`            | Screenshot                      |
| `Alt + Print Screen`            | Screenrecord                     |
| `Super + Print Screen` | Color picker |
| `Super + Ctrl + Print Screen` | Text extraction to clipboard |
| `Alt + Shift + L` | Copy current URL from webapp or Chromium |
| `Super + Ctrl + X` | Start/stop dictation (requires _Install > AI > Dictation_) |
| `F9` | Push-to-talk dictation (requires _Install > AI > Dictation_) |

With screenrecordings, hit the hotkey to start, hit it again to stop.

All capture options are also accessible under _Capture_ in the Omarchy menu (`Super + Alt + Space`).

---

## Notifications

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + ,` | Dismiss latest notification  |
| `Super + Shift + ,` | Dismiss all notifications |
| `Super + Ctrl + ,` | Toggle silencing notifications  |
| `Super + Alt + ,` | Invoke most recent notification  |

---

## Style

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + Ctrl + Shift + Space` | Pick a new theme  |
| `Super + Ctrl + Space` | Pick theme background |
| `Super + Backspace` | Toggle transparency on a window |
| `Super + Ctrl + Backspace` | Toggle single-window square aspect |

Extra background images live in `~/.config/omarchy/current/backgrounds`. Also available via _Install > Background_ in the Omarchy menu.

All style options are also accessible under _Style_ in the Omarchy menu (`Super + Alt + Space`).

---

## Toggles

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + Ctrl + I` | Toggle idle/sleep prevention |
| `Super + Ctrl + N` | Toggle nightlight display temperature |
| `Super + Ctrl + Delete` | Toggle laptop display on/off |
| `Super + Ctrl + Alt + Delete` | Toggle laptop display mirroring |
| `Super + Shift + Space` | Toggle the top bar  |
| `Super + Mute` | Switch to next audio output |
| `Super + Shift + Backspace` | Toggle window gaps |

---

## Reminders

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + Ctrl + R` | Set a reminder  |
| `Super + Ctrl + Alt + R` | See all reminders  |
| `Super + Ctrl + Shift + R` | Clear all reminders  |

---

## Notices

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Super + Ctrl + Alt + T` | Show time as notification  |
| `Super + Ctrl + Alt + B` | Show battery as notification  |
| `Super + Ctrl + Alt + W` | Show weather as notification  |

---


## Tmux

The prefix key is `Ctrl + Space` (`Ctrl + B` also works). You can change these bindings in `~/.config/tmux/tmux.conf`.

### Panes

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Prefix + v` | Split pane beside (vertical) |
| `Prefix + h` | Split pane below (horizontal) |
| `Prefix + x` | Kill pane |
| `Prefix + z` | Toggle pane zoom (fullscreen) |
| `Ctrl + Alt + Arrows` | Move between panes |
| `Ctrl + Alt + Shift + Arrows` | Resize panes |

### Windows

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Prefix + c` | New window |
| `Prefix + k` | Kill window |
| `Prefix + r` | Rename window |
| `Alt + 1-9` | Go to specific window |
| `Alt + Arrow Left/Right` | Move between windows |

### Sessions

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Prefix + C` | New session |
| `Prefix + K` | Kill session |
| `Prefix + R` | Rename session |
| `Prefix + N` | Next session |
| `Prefix + P` | Previous session |
| `Alt + Arrow Up/Down` | Move between sessions |
| `Prefix + s` | List sessions |
| `Prefix + d` | Detach from session |

### Copy mode (vi-style)

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Prefix + [` | Enter copy mode |
| `v` | Begin selection (in copy mode) |
| `y` | Copy selection (in copy mode) |

### General

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Prefix + q` | Reload config |
| `Prefix + :` | Command prompt |

### Tmux layout functions

These functions must be run inside a Tmux session.

| Command | Function |
| ------- | -------- |
| `tdl <ai> [<second_ai>]` | Create dev layout with editor, AI, and terminal |
| `tdlm <ai> [<second_ai>]` | Create dev layout per subdirectory |
| `tsl <count> <command>` | Create multi-pane swarm layout |

---

## Ghostty Terminal

Ghostty terminal is installed using _Install > Terminal_ via the Omarchy menu.

| Hotkey                  | Function              |
| ----------------------- | --------------------- |
| `Ctrl + Shift + E` | New split below |
| `Ctrl + Shift + O` | New split besides |
| `Ctrl + Alt + Arrows` | Move between splits |
| `Super + Ctrl + Shift + Arrows` | Resize split by 10 lines |
| `Super + Ctrl + Shift + Alt + Arrows` | Resize split by 100 lines |
| `Ctrl + Shift + T` | New tab  |
| `Ctrl + Shift + Arrows` | Move between tabs tab |
| `Alt + Numbers` | Go to specific tab |
| `Shift + Pg Up/Down` | Scroll the history |
| `Ctrl + Left mouse` | Open link in browser |

---

## File Manager

| Hotkey              | Function                       |
| ------------------- | ------------------------------ |
| `Ctrl + L`            | Go to path                     |
| `Space`               | Preview file (arrows navigate) |
| `Backspace`      | Go back one folder             |

---

## Neovim (w/ lazyvim)

### Navigation

| Hotkey                   | Function                        |
| ------------------------ | ------------------------------- |
| `Space`                    | Show command options            |
| `Space Space`              | Open file via fuzzy search      |
| `Space E`                  | Toggle sidebar                  |
| `Space G G`                | Show git controls               |
| `Space S G`                | Search file content             |
| `Ctrl + W W`               | Jump between sidebar and editor |
| `Ctrl + Left/right arrow`  | Change size of sidebar          |
| `Shift + H`                      | Go to left file tab             |
| `Shift + L`                      | Go to right file tab            |
| `Space B D`                | Close file tab                  |

### While in sidebar

| Hotkey                   | Function                        |
| ------------------------ | ------------------------------- |
| `A`                        | Add new file in parent dir      |
| `Shift + A`                | Add new subdir in parent dir    |
| `D`                        | Delete highlighted file/dir     |
| `M`                        | Move highlighted file/dir       |
| `R`                        | Rename highlighted file/dir     |
| `?`                        | Show help for all commands      |

[See all the Neovim hotkeys configured by LazyVim](https://www.lazyvim.org/keymaps).

---

## Quick Emojis

You can use `Super + Ctrl + E` to show a complete emoji picker that'll put the selection on the clipboard or you can use these quick access options.

| Hotkey       | EM | Clue       |
| ------------ | -- | ---------- |
| `CapsLock M S` | 😄 | smile      |
| `CapsLock M C` | 😂 | cry        |
| `CapsLock M L` | 😍 | love       |
| `CapsLock M V` | ✌️ | victory    |
| `CapsLock M H` | ❤️ | heart      |
| `CapsLock M Y` | 👍 | yes        |
| `CapsLock M N` | 👎 | no         |
| `CapsLock M F` | 🖕 | fuck       |
| `CapsLock M W` | 🤞 | wish       |
| `CapsLock M R` | 🤘 | rock       |
| `CapsLock M K` | 😘 | kiss       |
| `CapsLock M E` | 🙄 | eyeroll    |
| `CapsLock M P` | 🙏 | pray |
| `CapsLock M D` | 🤤 | drool      |
| `CapsLock M M` | 💰 | money      |
| `CapsLock M X` | 🎉 | xellebrate |
| `CapsLock M 1` | 💯 | 100%       |
| `CapsLock M T` | 🥂 | toast      |
| `CapsLock M O` |👌 | ok |
| `CapsLock M G` |👋 | greeting |
| `CapsLock M A` |💪 | arm |
| `CapsLock M B` |🤯 | blowing |

## Quick Completions
| Hotkey       | Completion       |
| ------------ |  ---------- |
| `CapsLock Space Space` | — (mdash)   |
| `CapsLock Space N` | Your name (as entered on setup)  |
| `CapsLock Space E` | Your email (as entered on setup)  |

You can add more of your own by editing `~/.XCompose`, then running `omarchy-restart-xcompose` in the terminal to get the changes picked up.

# Unified Clipboard & History

Usually on Linux, you need `Ctrl + Shift + C/V` to copy'n'paste in the terminal and `Ctrl + C/V` to do it everywhere else. That's hard to get used to for anyone who hasn't been born and bred on Linux! So too is the switch from super to ctrl, if you're coming from the Mac.

Omarchy tackles both problems with unified clipboard hotkeys that work (almost) everywhere. They are:

| Hotkey | Command |
| ------- | ----------- |
| Super + C | Copy |
| Super + X | Cut |
| Super + V | Paste |
| Super + Ctrl + V | Clipboard history |

_The two exceptions to this uniformity is the file manager (Nautilus) and AI Agent CLIs (OpenCode, Claude Code). There you'll unfortunately have to make do with `Ctrl + C/X/V` for clipboard operations._

---

### Clipboard history

The clipboard history is provided by Walker and works for both text and images. You trigger it by `Super + Ctrl + V`, select your entry with return, and then that'll be placed on the clipboard ready to paste on `Super + V`.

 ![clipbord-history.png](/u/clipbord-history-soxtYp.png)

You can also search the history just by starting to type:

 ![clipboard-history-search.png](/u/clipboard-history-search-S0PjCI.png) 

# Reminders

Omarchy has a built-in way to set simple reminders based on a countdown timer and with a message. You can do this via `Super + Ctrl + R`, seeing all the ones set via `Super + Ctrl + Alt + R`, and clearing all via `Super + Ctrl + Shift + R`. Everything also accessible via _Trigger > Reminder_. You can also use the cli with `omarchy reminder 7 'Tea ready'`.

 ![screenrecording-2026-05-08_14-35-22-720p.gif](/u/screenrecording-2026-05-08_14-35-22-720p-3g9dVE.gif) 

# Notices

You can quickly access the date and time, battery status, and current weather using the hotkey notices.

### Date & Time

`Super + Ctrl + At + T`

 ![datetime-notice.png](/u/datetime-notice-dnB5VT.png) 

### Weather

`Super + Ctrl + Alt + W`

 ![weather-notice.png](/u/weather-notice-MV7Jj1.png) 

### Battery

`Super + Ctrl + Alt + B`

 ![battery-notice.png](/u/battery-notice-jyKv9S.png) 

# Text Extraction & Dictation

### Text Extraction

Hit `Super + Ctrl + PrtScr` to select a region on the screen for text extraction. The tesseract open source OCR model will then quickly convert that selection into text and place it on the clipboard. Then you just hit `Super + V` to paste.

This is very helpful for grabbing addresses out of image footers or phone numbers embedded in website headlines.

 ![text-extraction.png](/u/text-extraction-1x3Oe3.png) 

### Dictation

Omarchy offers AI dictation via [Voxtype](https://voxtype.io/). You install it via _Install > AI > Dictation_ through the Omarchy menu. By default, it'll load a base English model that takes up 150MB. But you can tweak which model you'd like to use by running `voxtype setup model` in the terminal. And you can tweak all the settings via `~/.config/voxtype/config.toml`.

Once installed, you dictate by holding down `F9` or by toggling with `Super + Ctrl + X`, and the dictated text will appear in the focused input area.



# Omarchy CLI

Omarchy is usually controlled through the hotkeys and the Omarchy menu (`Super + Alt + Space`). But you can also control it through the `omarchy` CLI. This is particularly helpful when you're having an AI agent work with you on customization or configuration.

The CLI has access to all the internal tooling that is used both via the menu and otherwise. You can see everything that's available by running `omarchy` in the terminal.

It looks something like this:

```
~ ❯ omarchy
Omarchy command center

Usage:
  omarchy <command> [args...]
  omarchy commands [--all] [--json] [--check]
  omarchy <group> --help
  omarchy <group> <command> --help

Common commands:
  omarchy update              Update Omarchy and system packages
  omarchy theme list          List available themes
  omarchy theme set <name>    Apply a theme
  omarchy font list           List available fonts
  omarchy screenshot          Take a screenshot
  omarchy debug               Print debugging information

Groups:
  ac             AC power detection
  battery        Battery status helpers
  branch         Omarchy git branch management
  brightness     Display and keyboard brightness
  capture        Screenshots and screen recording
  channel        Omarchy release channel management
  cmd            Command and shortcut helpers
  config         System configuration helpers
  debug          Diagnostics and support logs
  dev            Omarchy development tools
  drive          Drive selection and encryption
  font           Font management
```

And you can dive deeper on every group:

```
~ ❯ omarchy capture
Capture commands — Screenshots and screen recording:
  omarchy capture screenrecording [--with-desktop-audio] [--with-microphone-audio] [--with-webcam] [--webcam-device=<device>] [--resolution=<size>] [--stop-recording]  Start or stop screen recording
  omarchy capture screenshot [smart|region|windows|fullscreen] [slurp|copy] [--editor=<name>]                                                                           Take a screenshot
  omarchy capture text extraction                                                                                                                                       Extract text from a screenshot region with OCR
```

The Applications

# Terminal

[Alacritty](https://alacritty.org/) is the default terminal for Omarchy. It's fast, beautiful, and compatible with even old computers. It does not, however, support native tabs, splits, or image rendering. 

If you use Tmux, you may not mind, but if not, we fully support _Ghostty_, _Foot_, and _Kitty_ as options as well. Pick your preference under _Install > Terminal_ in the Omarchy menu.

You start a new terminal using `Super + Return`. (This binding will automatically point to whichever Terminal you've installed via _Install > Terminal_.)

## Tmux

Tmux provides a consistent, programmable interface for panes, windows (aka tabs), and resumable sessions regardless of your terminal. It even works on remote hosts, so when you're SSH'ing into a server, you can use the same approach.

You start a new Tmux session in a fresh terminal using `Super + Alt + Return`, and because Tmux is a persistent process, you can resume your session even if you close that terminal. Just hit `Ctrl + Space` (called the prefix key) then `s` to see all your active sessions.

Omarchy ships with an ergonomically-optimized Tmux configuration, which has a lot of keybindings to learn, so keep [the cheatsheet handy](https://learn.omacom.io/2/the-omarchy-manual/53/hotkeys#tmux).

## Tmux layout functions

Because Tmux is programmable, we can use functions to create layouts. Omarchy ships with three different functions for common developer layouts.

`tdl [agent]` starts a three-way split IDE-like interface with the `$EDITOR` on the left, your chosen AI agent on the right (like `c` for opencode or `cx` for Claude or `codex` for OpenAI), and then a terminal at the bottom. 

So `tdl c` would start this (or just `ic`):

 ![tmux-tdl-x.png](/u/tmux-tdl-x-dxhZe9.png) 

You can also start a second agent with `tdl c cx` (opencode + claude) (or just `icx`):

 ![tmux-tdl2-x.png](/u/tmux-tdl2-x-5FoPqh.png) 

You can also start this layout configuration for every subdirectory in the current directory using `tdlm [agent]`, then navigate using `alt + 1/2/3/5/6/...`:

 ![tdlm-x.png](/u/tdlm-x-RPg6sr.png) 

Finally, you can start a swarm of agents using `tsl [panes] [command]`. So `tsl 4 c` will give you a four-way grid of opencode agents:

 ![tsl-x.png](/u/tsl-x-SFzDeo.png) 


# Neovim

[Neovim](https://neovim.io/) is a modern implementation of [the vi editor](<https://en.wikipedia.org/wiki/Vi_(text_editor)>) created by Bill Joy all the way back in 1976. It's a modal editor where insert mode and command mode are separated, and it's a bit of a superpower once you learn even just a subset of the incredibly deep key command set. But it's also quite the learning curve!

If you're totally new to vim-style editing, I recommend you checkout [ThePrimeagen's Vim As Your Editor series](https://www.youtube.com/watch?v=X6AR2RMB5tE&list=PLm323Lc7iSW_wuxqmKx_xxNtJC_hJbQ7R) on YouTube. That'll teach you the basics. Just know that unlike more similar mainstream editors, it's going to take you longer to get basic proficiency with vim. But once you do, the payoff is also larger.

Now Neovim is basically infinitely configurable. If you really want to go nuts, you can create your own Neovim configuration from scratch. There's a great course from [Typecraft on setting up Neovim from scratch](https://www.youtube.com/watch?v=zHTeCSVAFNY). And [ThePrimegean has one as well](https://www.youtube.com/watch?v=w7i4amO_zaE).

But Omarchy ships with a complete Neovim setup that's been lovingly tuned to showcase the best of what's possible out of the box. Without you having to write a single line of configuration! It's called [LazyVim](https://www.lazyvim.org/), and it's a distribution of Neovim plugins and configurations. It's awesome.

## LazyVim Basics

As mentioned, I'm not going to teach you vim in this short introduction, but I can show you a few basics of LazyVim, and how to get around.

First, Neovim has the idea of the leader key. That's basically the gateway to all the commands. LazyVim has set that to `Space`. So just press that, wait a second, and you'll see a bunch of options explained inline like this:

Here are some basic commands I use all the time:

- `Space Space` - Fuzzy-find any file in the current directory.
- `Space S G` - Search all files using grep with a preview.
- `Space E` - Toggle the file tree on/off.
- `Ctrl + W W` - Hop from the file tree to the editor and back.
- `Shift + H` - Move left between the open tabs (vim calls them buffers).
- `Shift + L` - Move right between the open tabs.
- `Space B D` - Close a tab.
- `Space B O` - Close all other tabs but the current.
- `Space G G` - Launch LazyGit in a floating pane from the current directory.
- `Space U W` - Toggle soft wrap.

While you're in the file tree (`Space E` to reveal, `Ctrl + W W` to hop over there), you can add a new file with `a` or a new directory with `A`. Press `?` while in the tree to see all commands.

If you want to pickup the basic vim language, I've written about [the three-part syntax](https://world.hey.com/dhh/wonderful-vi-a1d034d3) and how to pull off those sick combo moves!

You can see all the possible commands on [the LazyVim Keymaps page](https://www.lazyvim.org/keymaps).

## Starting Neovim

You can start Neovim using `Super + Shift + N`, but it's usually easier to drive it from the terminal by navigating to the directory you wish to work in and typing `n`. The `n` is the alias for `nvim`, which will use the the present directory to open by default. You can open a single file with `n myfile.txt`.

## Using Neovim for sudo edits

If you need to edit files that you can only change as a super user, you can use neovim with all your plugins setup by running `sudoedit /etc/sudoers.d/00-sudo-only-file`.

# AI

Omarchy ships with [OpenCode](https://opencode.ai/) and [Claude Code](https://code.claude.com/docs/en/overview) as the default agent harnesses for programmers. OpenCode lets you use models from all the major commercial providers as well as the rapidly improving open-weight models. 

The best way to use OpenCode is by going to the directory you're going to work on in the terminal, then invoke the `c` alias to start OpenCode within that directory. Claude Code let's you use Anthropic's models with their proprietary subscriptions, and can be started in danger mode using the `cx` alias.

### Alternative agent CLIs

Beyond the default `c` (OpenCode) and `cx` (Claude Code) aliases, Omarchy ships pre-wired lazy-loaded launchers for every major coding-agent CLI. The launchers themselves are tiny shell stubs in `~/.local/bin/`, so on first run, each one fetches its npm package through npx against a mise-managed node@latest, so nothing is downloaded until you actually invoke it. Run any of these and authenticate when prompted:

| Command  | Package                       | Provider                              |
|----------|-------------------------------|---------------------------------------|
| `codex`    | @openai/codex                 | [OpenAI Codex](https://github.com/openai/codex) |
| `gemini`   | @google/gemini-cli            | [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) |
| `copilot`  | @github/copilot               | [GitHub Copilot CLI](https://github.com/github/copilot-cli) |
| `pi`       | @mariozechner/pi-coding-agent | [Mario Zechner's Pi](https://github.com/badlogic/pi-mono) |

To wrap an additional npm-published CLI the same way, run `omarchy-npx-install <package> [command-name]`.

### Local LLMs

Omarchy recommends two ways of running local LLM models: LM Studio and Ollama. LM Studio provides a GUI interface for finding open-weight models, installing them, and running them. It's a great way to get going easily. Ollama offers a CLI for doing so similarly. But if you're new to local models, I'd start with LM Studio. You can install either under _Install > AI_ in the Omarchy Menu.

### The Omarchy Skill

Agent skills help AI use specific tools in a specific way, and Omarchy ships with a default skill for tailoring the system. Like making changes to waybar or even creating a new theme from scratch. It's automatically configured in OpenCode (and Claude Code and any other harness that supports `~/.claude/skills`).

But you should treat this skill as experimental. Different models will use it to different effect. It's best to run in plan mode first, so you have an idea of what the agent would like to change. And then be ready to rollback changes or even invoking `omarchy reinstall configs`, if the agent makes a mess of everything.




# Development Tools

## Alternative Editors

Omarchy ships with [Neovim](https://neovim.io/) by default, but if you'd like something a bit more mainstream and familiar, you can run the Omarchy Menu (`Super + Alt + Space`) and see the options under _Install > Editor_. We have VSCode, Cursor, Zed, Sublime Text, and Helix listed there. If you don't find what you're looking for, checkout _Install > Package_, and see if it isn't in an Arch package (and if not, try _Install > AUR_ to check the AUR).

Theme matching is offered for `VSCode`, `Cursor`, `VSCodium`, `Helix`, and `Zed`.

You can set the system-wide default editor under `Setup > Defaults > Editor`. 

## Environment

Omarchy supports setting up a whole host of development environments through the _Install > Development_ section of the Omarchy Menu (`Super + Alt + Space`). You'll of course find _Ruby on Rails_, but also all three major runtimes for JavaScript (Node.js, bun, Deno), as well as popular PHP frameworks like Laravel and Symfony. Oh, and there's .NET, OCamal, Zig, and Elixir too. It's a very broad selection! 

The majority of these environments are managed by [Mise](https://mise.jdx.dev/). It's a tool that lets you install and run multiple versions of a programming language on the same machine. It's like rbenv or rvm for Ruby or virtualenv for Python, but it works for a bunch of different environments.

To install, say, Ruby, you'd run `mise use -g ruby`, which will both install Ruby and set it as the global default. Or, if your project has a .ruby-version file, you can just run `mise i` in the root of that project.

## Docker

[Docker](https://www.docker.com/) hardly needs any introduction. It allows you to run isolated containers, and Omarchy installs everything needed to run it well. This includes Docker itself, [Docker Compose](https://docs.docker.com/compose/), and the user group changes needed for you to run Docker as the normal user and not as root.

Remember to checkout the Lazydocker command to manage your containers in a cool TUI using `Super + Shift + D`.

You can setup the common databases for local development in Docker using _Install > Development > Docker DB_ in the Omarchy menu.

## GitHub CLI

[The GitHub CLI](https://cli.github.com/) let's you authenticate with your GitHub account and clone private repositories using it. To authenticate, run `gh auth login`. Then you can checkout private repositories using `gh repo clone org/repo`.

You can also perform a bunch of other GitHub operations using this command. Just run `gh` to see everything that's possible.

There's a lazy-installing stub for `ghui` for managing your pull requests in a TUI too.

# Shell Tools

In addition to the standard Linux tools, Omarchy also ships with a bunch of enhanced shell tools. Here are the key ones.

## fzf

[fzf](https://junegunn.github.io/fzf/) gives you fuzzy finding of files via the `ff` alias. Go to any directory, type `ff`, and you'll be able to fuzzy find your way to any file in that tree, while seeing a preview of the files you're narrowing down on the right-hand side.

You can use `Ctrl + R` to use fzf to fuzzy find through your command history.

This tool is also used by Neovim when you type `Space Space`.

The full manual can be found via `man fzf`.

## Zoxide

[Zoxide](https://github.com/ajeetdsouza/zoxide) is a replacement for cd. It remembers the directories you've been in, so you can more easily jump to them next time. Say you do `cd ~/.local/share/omarchy` once. Next time, you can just do `cd omarchy` (or even just `cd oma`), and Zoxide will take you directly there.

The full manual can be found via `man zoxide`.

## ripgrep

[ripgrep](https://github.com/BurntSushi/ripgrep) searches the contents of files by using `rg <pattern> <path>`, like `rg Controller app/` to find all mentions of `Controller` in the directory app.

This tool is also used by Neovim when you type `Space S G`.

The full manual can be found via `man rg`.

## eza

[eza](https://eza.rocks/) is a replacement for ls. It gives you directory listings with more information, color, and icons. By default, eza has been aliased as ls. You can also use `lt` to get a listing of two-deep levels of nesting. `lsa` gives you a listing including hidden files. And `lta` a nested listing with hidden files.

The full manual can be found via `man eza`.

## fd

[fd](https://github.com/sharkdp/fd) is an easier to use replacement for `find`. Use `fd person.rb` to find a file called `person.rb` within the current tree. `fd person.rb /` will search the entire file system. `fd person.rb / -H` searches the entire file system, including hidden directories.

The full manual can be found via `man fd`.

## try

[try](https://github.com/tobi/try) makes it easy to manage programming experiments with date-stamped directories. All experiments live in `~/Work/tries` and you can access them via `try`.

# Shell Functions

Omarchy comes with a set of shell functions to simplify common tasks and encapsulate convoluted parameter calls.

## Compression

- `compress [file/dir]`: Create a tar.gz archive from the file/dir.
- `decompress [file.tar.gz]`: Expand a tar.gz file.

## Drives

-  `iso2sd [image.iso]`: Create a bootable drive on an SD card using the referenced iso file and picking the drive interactively.
- `format-drive`: Select an entire disk to format with a single exFAT partition (which works on Windows and macOS too). Be careful!

## SSH Portforwarding

Ideal for doing web development with localhost secure-context privileges against a remote box.

- `fip`: Forward one or more ports from a remote host to localhost via SSH.
- `dip`: Disconnect one or more forwarded ports.
- `lip`: List all active SSH port forwards.

Say you start a dev server on port `3000` on a machine accessible as `nyc-dev`, then you can run `fip nyc-dev 3000` to forward that port, so `localhost:3000` actually reaches `nyc-dev:3000`, but without the need for SSL certificates to establish the secure context needed for testing web sockets or the like.

# TUIs

## Lazygit

[Lazygit](https://github.com/jesseduffield/lazygit) is a delightful alternative to something like the GitHub Desktop application, and it runs inside the terminal. 

You can run it directly, by going to any directory managed by git and running `lazygit`. Or you can run it inside Neovim where it can be started with `Space G G`.

You hop between the different panes using `Tab`. In the Files pane, you select files for staging using `Space`, and then you can create a new commit using `c`. You can see all the commands available using `?`.

## Lazydocker

[Lazydocker](https://github.com/jesseduffield/lazydocker) is made in the same spirit like Lazygit, and also gives you a terminal interface for managing your containers and images. 

You can start it with `Super + Shift + D`.

You stop a container using `s` or start/restart it using `r`. See all commands using `?`.

## Btop

[Btop](https://github.com/aristocratos/btop) is a beautiful resource manager that shows memory, CPU, disk, and network usage. It also lists all active processes, and allows you to manage them.

Omarchy has added an app for it called Activity, which you can start from the application launcher. But it's quicker to just hit `Super + Shift + T`.

## Impala

[Impala](https://github.com/pythops/impala) is a TUI for managing your Wi-Fi connection. You hop between sections on tab, then select a network with space. If a password is needed, just input and hit return. It's available by clicking the Wi-Fi icon in the top menu bar. 

## BlueTUI

[BlueTUI](https://github.com/pythops/bluetui) is a TUI for managing your Bluetooth connections. It's made by the same creator as Impala and works the same way.

## Fastfetch

[Fastfetch](https://github.com/fastfetch-cli/fastfetch) shows system information, like kernel version, uptime, theme, CPU, memory, and more. It's a successor to the popular neofetch tool.

Omarchy has packaged this as _About_ in the Omarchy menu (`Super + Alt + Space`).

## Cliamp

[Cliamp](https://www.cliamp.stream/) is a retro terminal music player inspired by Winamp 2.x," letting you play built-in radio stations for low-fi Launch it with `Super + Shift + Alt + M`, or from the Omarchy menu under _Apps_. Press `?` for the full keybinding list.


# GUIs

## Obsidian

[Obsidian](https://obsidian.md/) is a free and highly extensible note taking application that uses simple Markdown files for storage. 

Obsidian is free for all purposes, including personal, commercial, and non-profit use.

Obsidian also offers a [commercial add-on for syncing](https://obsidian.md/sync) with mobile apps on iOS and Android. (https://obsidian.md/pricing).

You start Obsidian with `Super + Shift + O`. To use theme syncing, you must select the `Omarchy` theme under settings.

## Pinta

[Pinta](https://www.pinta-project.com/) is a basic image editing tool that's great for cropping, resizing, and other basic manipulations. Just don't expect a Photoshop alternative. But it's still got a Magic Wand and layers!

You start Pinta via the application launcher (`Super + Space`).

## LocalSend

[LocalSend](https://localsend.org/) lets you send files to other devices on the same network running the app, like Apple's AirDrop. It's cross-platform, though, so you can send files to and from Windows, macOS, Android, iOS, and of course Linux.

You can open the LocalSend menu on `Super + Ctrl + S` or under _Trigger > Share_ in the Omarchy menu.

## LibreOffice

[LibreOffice](https://www.libreoffice.org/) is a complete office package with word processor, spreadsheet, presentations, drawing application, and more. It's compatible with files from Microsoft Office, so this is a great way to be able to open those Word documents.

You start LibreOffice via the application launcher (`Super + Space`).

## Signal

[Signal](https://signal.org/) is the pioneer of E2E encrypted messaging, and a great communication option for anyone who'd prefer not to go through one of the big tech conglomerates.

You start Signal with `Super + Shift + G`.

## mpv

[mpv](https://mpv.io/) is a simple, fast media player that'll play almost anything from any source. Great for watching videos. 

You start mpv via the application launcher (`Super + Space`) or just double-click on a video in the file manager.
 
## OBS Studio

[OBS Studio](https://obsproject.com/) lets you record or stream video from multiple inputs. You can mix a screencast with a webcam with a microphone input. It's what was used to record the Omarchy screencasts.

You start OBS Studio via the application launcher (`Super + Space`).

## Kdenlive

[Kdenlive](https://kdenlive.org/) is an excellent video editor. Perfect for working on video that comes out of OBS Studio before sharing it.

You start Kdenlive via the application launcher (`Super + Space`).

# Commercial apps/services

Omarchy is mostly focused on providing free, open source software, but it's not religious about it. Sometimes the best solution is a commercial offering, and that's just fine. Here are some of the options we provide an easy installation for.

## 1Password

Keeping your passwords in a password manager is a best practice. Doubly so if you're working with a team. And [1password](https://1password.com/) is a great solution, which also comes with a command line tool for integrating key lookups in scripts.

You start 1Password with `Super + Shift + /`.

## Typora

[Typora](https://typora.io/) is a minimal, distraction-free writing tool in the same spirit as iA Writer for the Mac and Windows. Like Obsidian, it uses Markdown for formatting, but in a way that's focused on writing individual pieces or essays and very little else.

Best used in full screen mode (F11) for that totally immersive nothing-but-words look.

It comes with a 15-day free trial, and is then a $15 one-time cost.

You start Typora using `Super + Shift + W`.

## Spotify

[Spotify](https://spotify.com/) is the world's most popular streaming music service. And the Linux application provides everything you'd expect, including offline playing.

You start Spotify using `Super + Shift + M`.

## Dropbox

[Dropbox](https://www.dropbox.com/) is a great way to sync files between machines while keeping a backup in the cloud. To set it up, select _Install > Service > Dropbox_ from the Omarchy menu. 

## Tailscale

[Tailscale](https://tailscale.com/) is a mesh VPN that makes getting access to all your computers and servers over the internet securely super simple way. To set it up, select _Install > Service > Tailscale_ from the Omarchy menu.

## NordVPN

[NordVPN](https://nordvpn.com/) is a standard VPN service that lets you exit your traffic from most regions around the world. To set it up, select _Install > Service > NordVPN_ from the Omarchy menu.

# Web Apps

You can add your own web apps using _Install > Web App_ in the Omarchy menu (`Super + Alt + Space`). It'll ask you for the app name, app URL, and the icon URL, if it can't retrieve it via favicon. You can get great PNG icons for many popular web apps on [Dashboard Icons](https://dashboardicons.com).

They'll then be accessible through the app launcher (`Super + Space`), and use the beautiful frameless web-app window.

If you wish to remove a web app, just go to _Remove > Web App_ in the Omarchy menu.

It's best if you log into all your accounts using a regular browser before using the web app shortcuts. The thin wrapper frame doesn't work well with 1password, so just easier to be logged in directly first.

All the keyboard hotkeys for these web apps can be changed in `~/.config/hypr/bindings.conf`.

When you're in a web app, you can copy the current URL to the clipboard using `Shift + Alt + L`.

By default, Omarchy already ships with an assortment of default apps:

## HEY

[HEY](https://www.hey.com/) is an email and calendar service that serves as a great alternative to people tired of Gmail, Outlook, or Apple Mail. It's made by [37signals](https://37signals.com/) where Omarchy originated.

You can start HEY Email using `Super + Shift + E` and HEY Calendar using `Super + Shift + C`.

## Basecamp

[Basecamp](https://basecamp.com/) is a project management service that helps small teams move faster and make more progress. Instead of patching together a mishmash of Trello, Slack, Asana, Notion, or whatever, you can have it all in one place with Basecamp. It's made by [37signals](https://37signals.com/) where Omarchy originated.

You can start Basecamp using the application launcher (`Super + Space`)

## ChatGPT

[ChatGPT](https://chatgpt.com) is the most popular AI chat bot in the world.

You can start ChatGPT using `Super + Shift + A`.

## WhatsApp

[WhatsApp](https://www.whatsapp.com/) is one of the most popular messaging services in the world, and the web version is a great option for Linux.

You can start WhatsApp using `Super + Ctrl + G`.

## X

X is where news break.

You can start X using `Super + Shift + X` and go straight to writing a new post with `Super + Shift + Alt + X`.

## YouTube

[YouTube](https://youtube.com/) is the most popular video platform in the world.

You can start YouTube using `Super + Shift + Y`.

## Zoom

[Zoom](https://zoom.us/) is the most popular video chat system used in the US. Great connections across the world. And 40-minute meetings can be held without a paying account.

You start Zoom using the application launcher (`Super + Space`).

# Gaming

Omarchy isn't just for _pRoDUcTiVItY_, it's also for having fun, and what's more fun than gaming? Omarchy ships with a whole suite of gaming options — Steam and RetroArch for native and retro play, Lutris and Heroic for non-Steam stores, Moonlight for PC streaming, Xbox Cloud Gaming + NVIDIA GeForce NOW for cloud, plus the evergreen Minecraft.

Thanks to Valve's incredible work on [the proton compatibility layer](https://en.wikipedia.org/wiki/Proton_(software)), there are now tens of thousands of playable modern games on Linux. Oh, and did you know that the [Steam Deck](https://store.steampowered.com/steamdeck/) actually runs Arch!

All gaming installers live under _Install > Gaming_ in the Omarchy menu (`Super + Alt + Space`). If you ever want to undo one, use _Install > Gaming > Remove_.

---

## Steam

Install [Steam](https://store.steampowered.com/) by selecting _Install > Gaming > Steam_ from the Omarchy menu (`Super + Alt + Space`).

After you've installed it, you'll be able to launch Steam with `Super + Space`.

Note that Steam can take 10-20 seconds to start up, and it's not going to provide any visual feedback that it's loading.

 ![steam.png](/u/steam-tC5srj.png) 

---

## RetroArch

Install [RetroArch](https://www.retroarch.com/) by selecting _Install > Gaming > RetroArch_ from the Omarchy menu (`Super + Alt + Space`).

RetroArch is fully preconfigured with the beautiful CRT Royale shader for that perfect retro look.

To get going:

1. Drop your BIOS and ROM files into `~/Games`.
2. Launch RetroArch with `Super + Space` and typing `retro`.
3. Scan the `~/Games` directory and you're ready to play.

 ![retroarch.jpg](/u/retroarch-wd6cuZ.jpg) 

---

## Xbox Cloud Gaming

Install the Xbox Cloud Gaming web app by selecting _Install > Gaming > Xbox Cloud Gaming_ from the Omarchy menu (`Super + Alt + Space`). It's "just" a web app for the service, but it's quick to start and runs great at 1080p.

If you already have Xbox Game Pass, this is a solid way to play Fortnite and other titles you can't run natively on Linux.

 ![xbox-cloud.jpg](/u/xbox-cloud-vEuyin.jpg) 

---

## NVIDIA GeForce Now

Install the cloud-gaming service [NVIDIA GeForce NOW](https://www.nvidia.com/en-us/geforce-now/) by selecting _Install > Gaming > NVIDIA GeForce Now_ from the Omarchy menu (`Super + Alt + Space`). Another great way to play titles that aren't available natively on Linux.

 ![screenshot-2026-05-05_09-00-11-medium.jpg](/u/screenshot-2026-05-05_09-00-11-medium-tSjM9x.jpg) 

---

## Minecraft

Install Minecraft by selecting _Install > Gaming > Minecraft_ from the Omarchy menu (`Super + Alt + Space`).

Like Steam, note that it can take a while after logging in or starting up for the next screen to appear, and you're not going to get any feedback while you're waiting.

 ![screenshot-2026-05-05_09-02-39-medium.jpg](/u/screenshot-2026-05-05_09-02-39-medium-Vapoct.jpg) 

---

## Xbox Controllers

Install support for Bluetooth Xbox controllers by selecting _Install > Xbox Controllers_ from the Omarchy menu (`Super + Alt + Space`). Pair the controllers via Bluetooth and they'll work in all your games. You don't need this if you're just hardwiring your controller with a USB-C cable.

---

## Moonlight (Game streaming from a PC)

Install the [Moonlight client](https://github.com/moonlight-stream/moonlight-qt) by selecting _Install > Gaming > Moonlight_ from the Omarchy menu (`Super + Alt + Space`). Moonlight streams games from a Windows PC running [Sunshine](https://app.lizardbyte.dev/Sunshine/).

If both your Omarchy machine and the remote gaming PC are hardwired, the experience is indistinguishable from playing locally. Crank the resolution up to native, set the refresh to 120Hz, and max the bitrate — this is the best way to play competitive shooters like Fortnite on Linux.

---

## Lutris (Battle.net games)

Install [Lutris](https://lutris.net/) by selecting _Install > Gaming > Lutris_ from the Omarchy menu (`Super + Alt + Space`). Lutris is the way to play [Battle.net](https://eu.shop.battle.net/en-us) titles like Diablo, Starcraft, and World of Warcraft on Linux.

Installation is a little janky and looks like nothing is happening at times — just be patient, it's working in the background.

 ![starcraft.png](/u/starcraft-WU9zw7.png) 

---

## Heroic Launcher (Epic Games)

Install the [Heroic Launcher](https://heroicgameslauncher.com/) by selecting _Install > Gaming > Heroic Launcher_ from the Omarchy menu (`Super + Alt + Space`). Heroic lets you run Epic Games titles, like OddSparks, that don't rely on anti-cheat. Sadly, that means no Fortnite and no Rocket League — until Tim Sweeney comes to Linux, this is as close as it gets.

Like Lutris, it can feel slow and janky while installing games. Give it time.


# Filling out PDFs

Omarchy ships with a nice, basic PDF viewer called Document Viewer. This is the program that'll open any PDFs you just double click on.

But you can only use Document Viewer to fill out PDFs that have been setup as forms. If you need to fill out PDFs that haven't, or you need to sign a PDF, you'll have to right-click the file, select _Open With..._, and pick Xournal++.

Xournal++ will let you write anywhere on a PDF using the T tool. If you need to sign a document, you'll need an image of your signature, and you can use the Image tool to insert this signature and resize it.

When you're done filling out the PDF, use _File > Export as PDF_ to save the final version.

# Windows VM

Omarchy offers an easy way to run Windows through a Docker VM. You can install it using _Install > Windows_ from the Omarchy menu (`Super + Alt + Space`). It takes a while, but you can follow the progress in the browser.

When the installation is complete, you can launch Windows using the app launcher, and that'll give you a RDP connection to your installation. There's no GPU passthrough with this setup, so it's not suitable for gaming or video editing, but it's a great way to run apps like Microsoft Office or whatever else if you absolutely must have that.

The directory `~/Windows` in your home directory is automatically shared with this Windows VM. So you put files there if you want to make them accessible to Windows. The VM does not have access to any other files on your system, so you're safe from malware or viruses on the Linux side.

You can change the resource allocation by editing `~/.config/windows/docker-compose.yml`. You can also edit this file to mount USB devices. See all the options on [the Dockur Windows project](https://github.com/dockur/windows).

The version of Windows installed is 11 Pro. It's unactivated. You will need to activate with your own license key to use all gated features.

 ![windows.png](/u/windows-bhXSXL.png) 

# Other Packages

Arch has an amazing wealth of packages available for almost any type of software between the official repository and the Arch User Repository (AUR). 

It couldn't be easier to use either. You install a new Arch package by going to _Install > Package_ in the Omarchy menu (`Super + Alt + Space`) and typing the package you want. It'll automatically fuzzy filter the list of all packages. (You can also do it manually using with `omarchy pkg add [package]` in the terminal).

You can do the same with AUR, just use _Install > AUR_. Just remember that the AUR isn't vetted by the Arch team. It's like RubyGems or npm. Anyone can upload.

If you want to remove a package, you can use _Remove > Package_ from the Omarchy menu. It'll remove package, config files, and dependencies. (You can also do it manually using `omarchy pkg drop [package]`).

Configuration

# Updates

Omarchy and your packages are kept up to date via _Update > Omarchy_ in the Omarchy menu (`Super + Alt + Space`). 

This pulls [the latest Omarchy code and configs](https://github.com/basecamp/omarchy/releases), runs any pending migrations to get your system in sync with the latest, and updates all system packages from the [Omarchy Arch Mirror](https://github.com/omacom-io/omarchy-mirror), [Omarchy Package Repository](https://github.com/omacom-io/omarchy-pkgs), and [AUR](https://aur.archlinux.org/) (if you have installed any AUR packages).

When new releases are made, a circle arrow icon will appear to the right of your clock. Click it and the update process will start. 

![screenshot-2025-09-28_19-06-08.png](https://learn.omacom.io/u/screenshot-2025-09-28_19-06-08-yZI06N.png)

---

### Four channels

Omarchy is updated along four channels: stable, RC, edge, and dev. New installations start on the stable channel, which tracks the [official releases](https://github.com/basecamp/omarchy/releases/), as well as the [stable Omarchy Arch mirror](https://github.com/omacom-io/omarchy-mirror) that's running one month behind the latest, so we can catch any new incompatibilities that require config changes before they cause problems for people.

But if you'd like to help spot those potential issues, you can run on the edge channel. That'll keep your Omarchy code tracking official releases, but lets you update to the latest Arch packages as soon as they're available. You should only do this if you're experienced with Linux, and know how to recover a system that has problems.

Before any new major release, we'll be doing final validation using the RC channel. If you're interested in helping with final polishing, come hang out in #omarchy-release-candidates on the Discord.

Finally, there's the dev channel, which gives you the very latest Omarchy code changes and the edge packages. You should only use this channel if you're an experienced Linux user, working directly on Omarchy, and willing to tolerate breakage.

You can switch between channels using _Update > Channel_ from the Omarchy menu.

---

### Warning about direct pacman/yay updates

If you're already familiar with Arch, you might be tempted to just run `pacman -Syu` or `yay -Syu` yourself, but if you do that, you run the risk that you'll miss updates to the configuration files needed to support newer versions of libraries or tools. So it's best to stick with `Update > Omarchy`, so you're sure that any migrations are run together with new packages.

---

### Rolling back bad updates

If you ever have a problem after doing an update, you can rollback your system to the snapshot taken before the update. Just restart and pick the snapshot in the boot loading menu from before you started the update.

![omarchy-bootloader.png](/u/omarchy-bootloader-EVTCUU.png) 

If somehow your configuration files have been corrupted, you can also perform an Omarchy reinstall using `omarchy reinstall` in the terminal. This will restore your Omarchy installation to the latest release, put you on stable and downgrade any packages, and reset all the configuration files. Note that all your user config changes to the Omarchy defaults will be overwritten doing this!

# Dotfiles

Omarchy is primarily configured through the so-called dotfiles that live in `~/.config`. Those are considered your files for your changes. The files that live in `~/.local/share/omarchy` belong to Omarchy itself, and you ideally shouldn't be messing with those. If you need to change anything in `~/.local/share/omarchy`, you should be overwriting the value in `~/.config` instead.

Almost everything can be edited through _Setup > Configs > [process]_ through the Omarchy menu (`Super + Alt + Space`). When you do it this way, any process that needs restarting after config edits automatically will be after you quit the Neovim editor (`:wq`, remember!).

Here's a list of the key files in `~/.config` and what they control:

| File                  | Purpose              |
| ----------------------- | --------------------- |
| `~/.config/hypr/hyprland.conf` | Controls keybindings, default apps, and everything Hyprland. [Learn more about Hyprland configs](https://wiki.hypr.land/Configuring/).  |
| `~/.config/hypr/monitors.conf` | Controls your monitors, resolution, and position. |
| `~/.config/hypr/hypridle.conf` | Controls your idle/sleep settings. Shouldn't need touching. |
| `~/.config/hypr/hyprlock.conf` | Controls your lock screen, but this is symlinked to your theme for styling.  |
| `~/.config/waybar/config.jsonc` | Controls your top bar that's run with waybar.  [Learn more about Waybar configs](https://github.com/Alexays/Waybar/wiki/Configuration). |
| `~/.config/waybar/style.css` | Controls your top bar design, but it's symlinked to your theme. |
| `~/.config/walker/config.toml` | Controls your launcher that's run with Walker. |
| `~/.config/alacritty/alacritty.toml` | Controls your terminal. |
| `~/.config/uwsm/default` | Controls your default $EDITOR. Requires relaunching Hyprland when changed. |
| `~/.XCompose` | Defines your quick-access emoji and name/email autocomplete. Make sure to run `omarchy-restart-xcompose` after making changes. | 

If you end up making a lot of changes to tweak your own setup, it's a good idea to backup all these dotfiles. [Stow is a great way to do that](https://www.youtube.com/watch?v=NoFiYOqnC4o).

---

### Adding your own shell exports, functions, and aliases

Omarchy ships with a bunch of ergonomic aliases and helpful functions, but it's very common to want to add your own. You should add both aliases, functions, and exports in `~/.bashrc`. This file will not be overwritten on updates. If you want to change any of the Omarchy defaults, you can also safely add them here.

---

### Changing internal Omarchy files

Look, this is your computer. You can do whatever you want with it, but I would advise against making changes to the files in `~/.local/share/omarchy` directly. It'll make it harder for you to upgrade in the future. You're better off just overwriting any default values you don't like in the `~/.config/*` folder instead.

You can change just about everything that way, like the default keybindings. Just edit `~/.config/hypr/hyprland.conf` to, say, replace [Obsidian](https://obsidian.md/) with [Joplin](https://joplinapp.org/) (install with `yay -S joplin-bin`):

```
bind = SUPER SHIFT, O, exec, joplin
```

If you insist on changing internal Omarchy files, you'll need to commit your changes before you can use `omarchy update`. You can do that with `gcam "Look ma! I'm breaking the rules!"` from inside the `~/.local/share/omarchy` directory. Ain't nobody here to tell you what to do!

---

### Resetting any changes

If you end up making a mess of the configurations, you can always revert them to the defaults via _Update > Config_ in the Omarchy menu. Or by running `omarchy reinstall configs` to reset everything.

# Monitors

Omarchy assumes you're running on a 2x-capable retina-class display by default. This is what you need to get those nice, crisp programmer fonts. It's what almost all new premium laptops with high-resolution screens are optimized for. It's what you'd want to run on a 27" 5K [Apple Studio Display](https://www.apple.com/studio-display/)/[ProArt PA27JCV](https://www.asus.com/us/displays-desktops/monitors/proart/proart-display-5k-pa27jcv/)/[Samsung S9](https://www.samsung.com/us/computing/monitors/5k/27-viewfinity-s9-5k-monitor-with-thunderbolt-4-matte-display-and-smart-features-ls27c900panxza/)/[Kuycon G27P](https://kuycon.us/monitors/G27P/) or 32" 6K [Apple XDR](https://www.apple.com/pro-display-xdr/)/[ProArt PA32QCV](https://www.asus.com/displays-desktops/monitors/proart/proart-display-6k-pa32qcv/)/[Kuycon G32P](https://kuycon.us/monitors/G32P/).

But if you're not running a display with a PPI of 218 or above, you'll want to change the monitor settings. For example, if you have a 27" or 32" 4K, you can use fractional scaling by opening `~/.config/hypr/monitors.conf` and switching to the recommendation for that combo:

```
env = GDK_SCALE,1.75
monitor=,preferred,auto,1.666667
```

If you're using a 1080p or 1440p display, you'll probably just want to use 1x scaling, so you can use:

```
env = GDK_SCALE,1
monitor=,preferred,auto,1
```

Changes to `GDK_SCALE` apply to applications started after the change. So make sure you quit the windows that you have that are oversized after the change (or close all windows with `Ctrl + Alt + Del`!).

You can also quickly cycle through the major monitor scaling ratios (1x, 1.6x, 2x, 3x) using `Super + /` to go higher and `Super + Alt + /` to go lower. If you have the default configuration, these changes will also persist past reboot.

---

### Extending and mirroring laptop displays

When you connect an external screen to your laptop, the display is automatically extended. But you can change that to mirroring instead using _Trigger > Hardware_ in the Omarchy menu or `Super + Ctrl + Alt + Delete`. This is especially helpful if that external screen is a projector, and you want to show something while working.

When you're extending, closing the lid on the laptop will automatically turn off the internal screen. Opening the lid will turn it back on. You can also control this manually using _Trigger > Hardware_ in the Omarchy menu or `Super + Ctrl + Delete`.

---

### Arranging multiple screens

Hyprland works great with multiple screens. Read more about how to lay them out in [the Hyprland monitor documentation](https://wiki.hypr.land/Configuring/Basics/Monitors/). You can [bind specific workspaces to specific monitors](https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/) as well.

You can also checkout [Hyprmon](https://github.com/erans/hyprmon/), if you'd like a TUI to help you with the positioning of multiple screens.

---

### Controlling brightness

Monitor brightness is controlled by the dedicated function keys for brightness up/down. If you hold down shift while pressing these, you'll go to maximum or minimum brightness.

---

### Apple Displays

If you're using an Apple display, the regular keyboard brightness keys will also automatically work, if you're focused on the Apple display. This is done through the `asdcontrol` command.

Note that if you're using an Apple 6K XDR display, you may see a phantom screen in your `hyprctl monitors` listing. You can turn this off with something like `monitor=DP-2,disable` via _Setup > Monitors_.

On Intel machines, you should be connecting to Apple displays using a regular Thunderbolt cable. On other machines without Thunderbolt, you'll typically have to use a [DP + USB-A -> USB-C cable](https://www.amazon.com/dp/B0BNX7MS6N) to make it work.

# Keyboard, Mouse, Trackpad

Hyprland let's you configure all your inputs in great detail. You can change the keyboard repeat to be supersonically fast or make the trackpad use natural scrolling. You change all of it in `~/.config/hypr/input.conf`, which you can also reach via _Setup > Input_ in the Omarchy menu (`Super + Alt + Space`).

Here's an example:

```
input {
  # Use multiple keyboard layouts and switch between them with Alt + Space
  kb_layout = us,dk
  kb_options = compose:caps,grp:alt_space_toggle

  # Change speed of keyboard repeat
  repeat_rate = 40
  repeat_delay = 600

  # Increase sensitity for mouse/trackpack (default: 0)
  sensitivity = 0.35


  touchpad {
    # Use natural (inverse) scrolling
    natural_scroll = true

    # Use two-finger clicks for right-click instead of lower-right corner
    clickfinger_behavior = true

    # Control the speed of your scrolling
    scroll_factor = 0.3
  }
}

# Scroll faster in the terminal
windowrule = scrolltouchpad 1.5, tag:terminal
```

You can [see all the input options](https://wiki.hypr.land/Configuring/Basics/Variables/#input) on the Hyprland wiki for inputs.

---

### Use ALT as SUPER

On some keyboards, it's not convenient to use the primary meta key (Windows/cmd key) as SUPER. You can change this to be ALT instead using this change:

```
input {
  kb_options = compose:caps,altwin:swap_alt_win
}
```

# System sleep

Omarchy enables suspend and hibernation by default, but if you're having issues with either on your machine, you can toggle them off.

### Toggle suspend

You toggle suspend under _Setup > System Sleep > Enable/Disable Suspend_. That just reveals/hides the option under _System_ (or `Super + Esc`), and then you can see if it works consistently on your system. If not, you can turn it off again using _Setup > System Sleep > Disable Suspend_.

### Toggle hibernation

You toggle hibernation under _Setup > System Sleep > Enable/Disable Hibernation_. Hibernation creates a /swap subvolume on your boot drive the size of our physical RAM allocation, so make sure you have plenty of room to spare. On a 32GB machine, you'll always need 32GB+ free for this volume.

When enabled, you'll see the hibernate option under _System_ (or `Super + Esc`), and then you can see if it works consistently on your system. If not, you can turn it off again using _Setup > System Sleep > Disable Hibernate_.

# Hardware authentication

### Fingerprint authentication

A lot of laptops come with a fingerprint sensor to do authentication. You can use this with Omarchy by running _Setup > Security > Fingerprint_ in the Omarchy menu (`Super + Alt + Space`). 

That'll install the fingerprint package, collect your print, verify it, and you'll be set to go using your fingerprint to unlock from the lock screen (which you can trigger with `Super + Escape`), enter sudo mode, and authorize system prompts.

If you've setup fingerprint authentication, but then need to work on an external keyboard that doesn't have it, just hit `CTRL + C`, when you're prompted for your fingerprint during `sudo`.

You can remove the fingerprint authentication under _Remove > Fingerprint_ in the Omarchy menu.

### Fido2 authentication

If you're using a Fido2 device, you can set it up for `sudo` authentication using _Setup > Security > Fido2_ in the Omarchy menu (`Super + Alt + Space`). It's only for `sudo`, though, not unlocking your computer.

You can remove the fido2 authentication under _Remove > Fido2_ in the Omarchy menu.

# Fonts

Omarchy uses JetBrainsMono Nerd Font as both the terminal and system font by default.

 ![jetbrainsmono.jpg](/u/jetbrainsmono-lhatXs.jpg) 

You can change this for the terminal through the _Style > Font_ menu in the Omarchy menu (`Super + Alt + Space`).

You can install other popular programming fonts via _Install > Style > Font_ in the Omarchy menu.

# Backgrounds

All the backgrounds for Omarchy live in `~/.config/omarchy/backgrounds/[theme]`. If you want to add an extra background image to, say, the nord theme, you just put the file in `~/.config/omarchy/backgrounds/nord`. 

You can do this most easily by going to _Install > Style > Background_ in the Omarchy Menu. That'll bring up the folder where the backgrounds for that theme is stored. Hit `Super + Shift + F` to start another file manager, find your background, copy it over.  Now it'll be included in the choices of backgrounds you can select between using `Super + Ctrl + Space`.

You can find a huge collection of cool curated backgrounds on https://github.com/dharmx/walls.

# Prompt

Omarchy ships with a minimal [Starship](https://starship.rs/) prompt by default. That's how I like to keep my prompt. I don't need to know the user, because it's always me, and I don't need to know the time, because it's always at the top.

 ![omarchy-prompt.png](/u/omarchy-prompt-J4UHpS.png)

If you want more information or style, you can change the [Starship.rs](https://starship.rs/) configuration in `~/.config/starship.toml`. There's a lot you can do. Just don't go overboard (or do go overboard, do whatever you want, it's your computer!)

# Branding

Omarchy allows you to set your company logo or personal image for both the boot unlock, the screensaver, and the about screen.

### Boot unlock

You can use `omarchy plymouth preview` to see what your custom logo and colors would look like. Then apply the setup with `omarchy plymouth set`. If you want to revert, you can use `omarchy plymouth reset`.

 ![shopify-plymouth.jpeg](/u/shopify-plymouth-AjqlgW.jpeg) 

### Screensaver

You can change the logo used for the screensaver under _Style > Screensaver_. It's an ASCII logo, so you can edit the text directly, but you can also upload a png or svg image, and we'll convert that to ASCII. It looks pretty cool.

 ![screensaver.gif](/u/screensaver-xDOE2Y.gif) 

### About screen

The same can be done with the _About_ screen accessible from the Omarchy menu. Same options as with the screensaver under _Style > About_.

 ![about.png](/u/about-wi4tkl.png) 

# Common tweaks

This is a collection of common tailorings to the Omarchy setup. Know that it might occasionally be necessary for system updates to restore certain configs to their original condition. If this happens, your changes won't be lost, but put in a `.bak` file in the same directory.

If you screw something up, you can restore individual configs to their original setup via _Update > Config_ in the Omarchy menu. If you _really_ screw everything up, you can reset all configs via `omarchy-reinstall`.

---

### Reveal all tray icons all the time

By default, tray icons, like Dropbox, 1password, or Steam, are hidden behind the tray expander icon. If you'd like to have them exposed all the time, you can change the `group/tray-expander` line to `tray` in Waybar's `~/.config/waybar/config.jsonc` (access via _Setup > Config > Waybar_).

---

### Rounded window corners

Omarchy's default design is one of square corners, but if you like to soften that up a bit, you can change `~/.config/hypr/looknfeel.conf` so rounding is no longer commented out:

```
decoration {
    # Use round window corners
    rounding = 8
}
```

---

### Remove window gaps

On laptop displays, some people prefer to not to waste any pixels on window gaps (or even a top bar, which you can toggle off with `Super + Shift + Space`). You can remove all gaps by removing the comments in this section of `~/.config/hypr/looknfeel.conf`:

```
general {
    # No gaps between windows or borders
    gaps_in = 0
    gaps_out = 0
    border_size = 0
}
```

# Extra themes

You can install any of these themes by copying the GitHub URL and selecting `Install > Style > Theme` via the Omarchy menu (`Super + Alt + Space`). If you want to remove it again, just use `Remove > Style > Theme` and select it there.

 ![aetheria.png](https://learn.omacom.io/u/aetheria-jaDcHN.png)
[Aetheria](https://github.com/JJDizz1L/aetheria)

 ![amberbyte.png](https://learn.omacom.io/u/amberbyte-gevf2N.png)
[Amberbyte](https://github.com/tahfizhabib/omarchy-amberbyte-theme)

 ![arc-blueberry.png](https://learn.omacom.io/u/arc-blueberry-e64rOP.png)
[Arc Blueberry](https://github.com/vale-c/omarchy-arc-blueberry)

 ![archwave.png](https://learn.omacom.io/u/archwave-ogNCX2.png)
[Archwave](https://github.com/davidguttman/archwave)

 ![ash-theme.png](/u/ash-theme-DnGpEy.png) 
[Ash](https://github.com/bjarneo/omarchy-ash-theme)

 ![artzen.png](https://learn.omacom.io/u/artzen-ddIz8i.png)
[Artzen](https://github.com/tahfizhabib/omarchy-artzen-theme)

 ![aura-theme.png](/u/aura-theme-LfFuUo.png) 
[Aura](https://github.com/bjarneo/omarchy-aura-theme)

 ![all-hallows-eve-theme.webp](/u/all-hallows-eve-theme-XQuTDB.webp) 
[All Hallow's Eve](https://github.com/guilhermetk/omarchy-all-hallows-eve-theme)

 ![atelier.png](https://learn.omacom.io/u/atelier-L2xcft.png)
[Atelier](https://github.com/atif-1402/omarchy-atelier-theme)

 ![ayaka.png](https://learn.omacom.io/u/ayaka-FcJ4UP.png) 
[Ayaka](https://github.com/abhijeet-swami/omarchy-ayaka-theme)

 ![azure-glow-theme.png](/u/azure-glow-theme-vLp53z.png) 
[Azure Glow](https://github.com/Hydradevx/omarchy-azure-glow-theme)

 ![batman.png](/u/batman-ec0yWD.png)
[Batman](https://github.com/OldJobobo/omarchy-batman-theme)

 ![batou.png](https://learn.omacom.io/u/batou-pCugc6.png)
[Batou](https://github.com/HANCORE-linux/omarchy-batou-theme)

 ![bauhaus.png](https://learn.omacom.io/u/bauhaus-ZDRJnD.png) 
[Bauhaus](https://github.com/somerocketeer/omarchy-bauhaus-theme)

 ![biscuit.png](https://learn.omacom.io/u/biscuit-5ZFemm.png)
[Biscuit de Mar Dark](https://github.com/OldJobobo/omarchy-biscuit-de-mar-dark-theme)

 ![black-arch.png](https://learn.omacom.io/u/black-arch-gveh1G.png)
[Black Arch](https://github.com/ankur311sudo/black_arch)

![black-gold.png](https://learn.omacom.io/u/black-gold-qUepi7.png)
[Black Gold](https://github.com/HANCORE-linux/omarchy-blackgold-theme)

 ![black-turq.png](https://learn.omacom.io/u/black-turq-YQQZhg.png) 
[Black Turq](https://github.com/HANCORE-linux/omarchy-blackturq-theme)

 ![bluedotrb.png](https://learn.omacom.io/u/bluedotrb-D9Cqtr.png) 
[bluedotrb](https://github.com/dotsilva/omarchy-bluedotrb-theme)

 ![blueridge-theme.png](/u/blueridge-theme-fkB0tl.png) 
[Blue Ridge Dark](https://github.com/hipsterusername/omarchy-blueridge-dark-theme)

 ![catppuccin-mocha-dark.png](https://learn.omacom.io/u/catppuccin-mocha-dark-mNVF5H.png)
[Catppuccin Mocha Dark](https://github.com/Luquatic/omarchy-catppuccin-dark)

 ![citrus-cynapse.png](https://learn.omacom.io/u/citrus-cynapse-9rtDDg.png)
[Citrus Cynapse](https://github.com/Grey-007/citrus-cynapse)

 ![city-783.png](https://learn.omacom.io/u/city-783-7xHciV.png)
[City-783](https://github.com/OldJobobo/omarchy-city-783-theme)

 ![cobalt2.png](https://learn.omacom.io/u/cobalt2-RGgNWQ.png)
[Cobalt2](https://github.com/hoblin/omarchy-cobalt2-theme)

 ![cpunk.png](https://learn.omacom.io/u/cpunk-hcNDrl.png)
[CpUnk](https://github.com/stannorbvb-cmd/cpunk)

 ![darcula.png](https://learn.omacom.io/u/darcula-boUMqL.png) 
[Darcula](https://github.com/noahljungberg/omarchy-darcula-theme)

 ![demon.png](https://learn.omacom.io/u/demon-b0AEYS.png)
[Demon](https://github.com/HANCORE-linux/omarchy-demon-theme)

 ![dotrb.png](https://learn.omacom.io/u/dotrb-Ev8dB3.png)
[Dotrb](https://github.com/dotsilva/omarchy-dotrb-theme)

 ![drac.png](https://learn.omacom.io/u/drac-jUSHEO.png)
[Drac](https://github.com/ShehabShaef/omarchy-drac-theme)

 ![dracula-theme.png](/u/dracula-theme-Rq2gWj.png) 
[Dracula](https://github.com/catlee/omarchy-dracula-theme)

 ![eldritch.png](https://learn.omacom.io/u/eldritch-6rfAov.png)
[Eldritch](https://github.com/eldritch-theme/omarchy)

 ![event-horizon.png](https://learn.omacom.io/u/event-horizon-c8ryZU.png)
[Event Horizon](https://github.com/OldJobobo/omarchy-event-horizon-theme)

 ![evergarden.png](https://learn.omacom.io/u/evergarden-euPINv.png)
[Evergarden](https://github.com/celsobenedetti/omarchy-evergarden)

 ![felix-theme.png](https://learn.omacom.io/u/felix-theme-vk8Fgx.png) 
[Felix](https://github.com/TyRichards/omarchy-felix-theme)

 ![fireside.png](https://learn.omacom.io/u/fireside-3NyKEj.png) 
[Fireside](https://github.com/bjarneo/omarchy-fireside-theme)

 ![flat-dracula.png](https://learn.omacom.io/u/flat-dracula-UDlJ2T.png)
[Flat Dracula](https://github.com/OldJobobo/omarchy-flat-dracula-theme)

 ![flexoki-dark-theme.png](/u/flexoki-dark-theme-meZCr4.png) 
[Flexoki Dark](https://github.com/euandeas/omarchy-flexoki-dark-theme)

 ![forest-green.png](https://learn.omacom.io/u/forest-green-hYkgXb.png)
[Forest Green](https://github.com/abhijeet-swami/omarchy-forest-green-theme)

 ![frost.png](https://learn.omacom.io/u/frost-zu4B6C.png) 
[Frost](https://github.com/bjarneo/omarchy-frost-theme)

 ![futurism-theme.png](/u/futurism-theme-2w6HZI.png) 
[Futurism](https://github.com/bjarneo/omarchy-futurism-theme)

 ![ghost-pastel.png](https://learn.omacom.io/u/ghost-pastel-ZgK0Ne.png)
[Ghost Pastel](https://github.com/row-huh/omarchy-ghost-pastel-theme)

![goldrush.png](https://learn.omacom.io/u/goldrush-bzSWXn.png) 
[Gold Rush](https://github.com/tahayvr/omarchy-gold-rush-theme)

 ![Golden-brown.png](/u/golden-brown-LcSn39.png)
[Golden Brown](https://github.com/atif-1402/omarchy-golden-brown-theme)

 ![thegreek.png](https://learn.omacom.io/u/thegreek-rPS5HB.png)
[The Greek](https://github.com/HANCORE-linux/omarchy-thegreek-theme)

 ![greek-noir.png](https://learn.omacom.io/u/greek-noir-u9xqyi.png)
[Greek Noir](https://github.com/HANCORE-linux/omarchy-greek-noir-theme)

![omarchy-lush-green.png](/u/omarchy-lush-green-fZgXeQ.png) 
[Green Garden](https://github.com/kalk-ak/omarchy-green-garden-theme)

 ![gruvu.png](https://learn.omacom.io/u/gruvu-wYS1LM.png)
[Gruvu](https://github.com/ankur311sudo/gruvu)

 ![harbor.png](https://learn.omacom.io/u/harbor-FYmTgs.png)
[Harbor](https://github.com/HANCORE-linux/omarchy-harbor-theme)

 ![harbor-dark.png](https://learn.omacom.io/u/harbor-dark-tLwJe3.png)
[Harbor Dark](https://github.com/HANCORE-linux/omarchy-harbordark-theme)

 ![hinterlands.png](https://learn.omacom.io/u/hinterlands-nh7aFP.png)
[Hinterlands](https://github.com/OldJobobo/omarchy-hinterlands-theme)

 ![infernium.png](https://learn.omacom.io/u/infernium-jTFC59.png)
[Infernium](https://github.com/RiO7MAKK3R/omarchy-infernium-dark-theme)

 ![inky-pink.png](https://learn.omacom.io/u/inky-pink-VoKwwC.png)
[Inky Pinky](https://github.com/HANCORE-linux/omarchy-inkypinky-theme)

 ![last-horizon.png](https://learn.omacom.io/u/last-horizon-YLrE41.png)
[Last Horizon](https://github.com/HANCORE-linux/omarchy-lasthorizon-theme)

 ![mapquest.png](https://learn.omacom.io/u/mapquest-WsJvyQ.png)
[Map Quest](https://github.com/ItsABigIgloo/omarchy-mapquest-theme)

 ![mars-theme.png](/u/mars-theme-r03GXm.png) 
[Mars](https://github.com/steve-lohmeyer/omarchy-mars-theme)

 ![mechanoonna.png](https://learn.omacom.io/u/mechanoonna-DNCESY.png)
[Mechanoonna](https://github.com/HANCORE-linux/omarchy-mechanoonna-theme)

 ![miasma.png](https://learn.omacom.io/u/miasma-FCluYv.png)
[Miasma](https://github.com/OldJobobo/omarchy-miasma-theme)

![midnight-theme.png](/u/midnight-theme-I5HKym.png)
[Midnight](https://github.com/JaxonWright/omarchy-midnight-theme)

 ![milkymatcha-theme.png](/u/milkymatcha-theme-JFT2X2.png) 
[Milky Matcha](https://github.com/hipsterusername/omarchy-milkmatcha-light-theme)

 ![monochrome-theme.png](/u/monochrome-theme-GwATD6.png) 
[Monochrome](https://github.com/Swarnim114/omarchy-monochrome-theme)

 ![monokai.png](https://learn.omacom.io/u/monokai-UoJwdC.png) 
[Monokai](https://github.com/bjarneo/omarchy-monokai-theme)

 ![moodpeak.png](/u/moodpeak-CCiNoe.png)
[Moodpeak](https://github.com/HANCORE-linux/omarchy-moodpeak-theme)

 ![nagai-poolside.png](https://learn.omacom.io/u/nagai-poolside-twaJTF.png) 
[Nagai Poolside](https://github.com/somerocketeer/omarchy-nagai-poolside-theme)

 ![neo-sploosh.png](https://learn.omacom.io/u/neo-sploosh-JWbVVa.png)
[Neo Sploosh](https://github.com/monoooki/omarchy-neo-sploosh-theme)

 ![neovoid.png](https://learn.omacom.io/u/neovoid-fVklHO.png)
[Neovoid](https://github.com/RiO7MAKK3R/omarchy-neovoid-theme)

 ![nes-theme.png](/u/nes-theme-1Z6uqG.png) 
[NES](https://github.com/bjarneo/omarchy-nes-theme)

 ![omacarchy.png](https://learn.omacom.io/u/omacarchy-QPQF1d.png)
[Omacarchy](https://github.com/RiO7MAKK3R/omarchy-omacarchy-theme)

 ![one-dark-pro.png](/u/one-dark-pro-lm5SO2.png) 
[One Dark Pro](https://github.com/sc0ttman/omarchy-one-dark-pro-theme)

 ![oxocarbon.png](https://learn.omacom.io/u/oxocarbon-3C2AtT.png)
[Oxo Carbon](https://github.com/HANCORE-linux/omarchy-oxocarbon-theme)

 ![pandora.png](https://learn.omacom.io/u/pandora-WwROvb.png)
[Pandora](https://github.com/imbypass/omarchy-pandora-theme)

 ![pina.png](https://learn.omacom.io/u/pina-0TNGvx.png) 
[Pina](https://github.com/bjarneo/omarchy-pina-theme)

 ![pink-blood.png](https://learn.omacom.io/u/pink-blood-Fh9voH.png)
[Pink Blood](https://github.com/ITSZXY/pink-blood-omarchy-theme)

 ![pulsar-theme.png](/u/pulsar-theme-DMUX7U.png) 
[Pulsar](https://github.com/bjarneo/omarchy-pulsar-theme)

 ![purple-moon.png](https://learn.omacom.io/u/purple-moon-S9IiCU.png)
[Purple Moon](https://github.com/Grey-007/purple-moon)

 ![purplewave.png](https://learn.omacom.io/u/purplewave-ZGiAbQ.png) 
[Purplewave](https://github.com/dotsilva/omarchy-purplewave-theme)

 ![rainynight.png](https://learn.omacom.io/u/rainynight-auQymU.png)
[Rainy Night](https://github.com/atif-1402/omarchy-rainynight-theme)

 ![red-monarch.png](https://learn.omacom.io/u/red-monarch-VYuVL2.png)
[Red Monarch](https://github.com/kamatealif/omarchy-red-monarch-theme)

 ![retro-82.png](https://learn.omacom.io/u/retro-82-pegjCg.png)
[Retro 82](https://github.com/OldJobobo/omarchy-retro-82-theme)

 ![retropc-theme.png](/u/retropc-theme-a24vKN.png) 
[RetroPC](https://github.com/rondilley/omarchy-retropc-theme)

 ![ristretto-light.png](/u/ristretto-light-IcJFUF.png)
[Ristretto Light](https://github.com/brokkoli71/omarchy-ristretto-light-theme)

 ![robzee84.png](https://learn.omacom.io/u/robzee84-N1hj0E.png)
[RobZee84](https://github.com/robzolkos/omarchy-robzee84-theme)

 ![rose-pine-dark.webp](/u/rose-pine-dark-pIMUcV.webp) 
[Rose Pine Dark](https://github.com/guilhermetk/omarchy-rose-pine-dark)

 ![rose-of-dune.png](https://learn.omacom.io/u/rose-of-dune-bX5Vhf.png)
[Rose of Dune](https://github.com/HANCORE-linux/omarchy-roseofdune-theme)

 ![ryu.png](/u/ryu-9OnK9B.png)
[Ryu](https://github.com/HANCORE-linux/omarchy-ryu-theme)

 ![sakura.png](https://learn.omacom.io/u/sakura-njsB9m.png) 
[Sakura](https://github.com/bjarneo/omarchy-sakura-theme)

 ![sakura-mochi.png](/u/sakura-mochi-Um17iV.png)
[Sakura Mochi](https://github.com/OldJobobo/omarchy-sakura-mochi-theme)

 ![saga.png](https://learn.omacom.io/u/saga-4taZZI.png)
[Saga](https://github.com/HANCORE-linux/omarchy-saga-theme)

 ![sapphire.png](https://learn.omacom.io/u/sapphire-tocQNg.png)
[Sapphire](https://github.com/HANCORE-linux/omarchy-sapphire-theme)

 ![shades-of-jade.png](https://learn.omacom.io/u/shades-of-jade-uSYodf.png)
[Shades of Jade](https://github.com/HANCORE-linux/omarchy-shadesofjade-theme)

 ![space-monkey-theme.jpg](/u/space-monkey-theme-UGmUHp.jpg) 
[Space Monkey](https://github.com/TyRichards/omarchy-space-monkey-theme/)

 ![snow-theme.png](/u/snow-theme-MDtvlu.png) 
[Snow](https://github.com/bjarneo/omarchy-snow-theme)

 ![snow-black.png](https://learn.omacom.io/u/snow-black-LXbCcU.png)
[Snow Black](https://github.com/ankur311sudo/snow_black)

 ![solarized-theme.png](/u/solarized-theme-9OhQ7Y.png) 
[Solarized](https://github.com/Gazler/omarchy-solarized-theme)

 ![solarized-light2.png](/u/solarized-light2-OTGWbc.png) 
[Solarized Light](https://github.com/dfrico/omarchy-solarized-light-theme)

 ![solarized-osaka-theme.png](/u/solarized-osaka-theme-9pnXgG.png) 
[Solarized Osaka](https://github.com/motorsss/omarchy-solarizedosaka-theme)

 ![solitude.png](https://learn.omacom.io/u/solitude-gJpmBW.png)
[Solitude](https://github.com/HANCORE-linux/omarchy-solitude-theme)

 ![sunset.png](https://learn.omacom.io/u/sunset-PsLG4m.png)
[Sunset](https://github.com/rondilley/omarchy-sunset-theme)

 ![sunsetdrive.png](https://learn.omacom.io/u/sunsetdrive-UV9Gss.png)
[Sunset Drive](https://github.com/tahayvr/omarchy-sunset-drive-theme)

 ![super-game-bro-theme.png](/u/super-game-bro-theme-2DNtSt.png) 
[Super Game Bro](https://github.com/TyRichards/omarchy-super-game-bro-theme)

![synthwave-theme.png](/u/synthwave-theme-7yHWFA.png) 
[Synthwave '84](https://github.com/omacom-io/omarchy-synthwave84-theme/)

 ![Temerald.png](https://learn.omacom.io/u/temerald-aTOeZ9.png)
[Temerald](https://github.com/Ahmad-Mtr/omarchy-temerald-theme)

 ![tokyo-night-oled.png](https://learn.omacom.io/u/tokyo-night-oled-nTsHOs.png)
[Tokyo Night OLED](https://github.com/Justin-De-Sio/omarchy-tokyoled-theme)

 ![tycho.png](https://learn.omacom.io/u/tycho-vTGePC.png)
[Tycho](https://github.com/leonardobetti/omarchy-tycho)

 ![waffle-cat.png](https://learn.omacom.io/u/waffle-cat-SSnrsG.png)
[Waffle Cat](https://github.com/OldJobobo/omarchy-waffle-cat-theme)

![waveform-theme.png](/u/waveform-theme-ZiWq97.png)
[Waveform Dark](https://github.com/hipsterusername/omarchy-waveform-dark-theme)

 ![whitegold.png](https://learn.omacom.io/u/whitegold-HGrllY.png)
[White Gold](https://github.com/HANCORE-linux/omarchy-whitegold-theme)

 ![windows-dark-mode.png](https://learn.omacom.io/u/windows-dark-mode-5MIFmi.png)
[Windows Dark Mode](https://github.com/oldjobobo/omarchy-windows-dark-mode-theme)

 ![van-gogh.png](https://learn.omacom.io/u/van-gogh-bwoogF.png)
[Van Gogh](https://github.com/Nirmal314/omarchy-van-gogh-theme)

 ![velvet-night.png](https://learn.omacom.io/u/velvet-night-tGkahY.png)
[Velvet Night](https://github.com/HANCORE-linux/omarchy-velvetnight-theme)

 ![vesper.png](https://learn.omacom.io/u/vesper-1tdScF.png)
[Vesper](https://github.com/thmoee/omarchy-vesper-theme)

 ![vhs80.png](https://learn.omacom.io/u/vhs80-8MnZ4x.png) 
[VHS 80](https://github.com/tahayvr/omarchy-vhs80-theme)

 ![void.png](https://learn.omacom.io/u/void-Q9aUIc.png) 
[Void](https://github.com/vyrx-dev/omarchy-void-theme)

# Making your own theme

You can add your own themes to `~/.config/omarchy/themes`. Just copy one of the existing ones as a base (look in `~/.local/share/omarchy/themes`), then tweak to your delight. As long as your theme is inside that folder, it'll be included in the theme selection menu.

The main file you have to tweak is `colors.toml`. That defines the color set that's then used to generate configurations for the terminal (Ghostty/Alacritty/Kitty), btop, Chromium, Hyprland, Hyprlock, Mako, SwayOSD, Walker, and Waybar. 

You can also use the included Aether application to create a new theme using a lovely GUI interface to play with colors and search for backgrounds. Just start it via the app launcher on `Super + Space`.

---

### Light mode

If you're making a light mode theme, drop an empty file called `light.mode` in the root of your theme. Then it'll automatically be paired with light mode for all the apps.

---

### Icon colors

If you'd like to color-match the file manager icons to your theme, add a file called `icons.theme` with the name of the icon set you want to you. By default, the options are: `Yaru Yaru-blue Yaru-dark Yaru-magenta Yaru-olive Yaru-prussiangreen Yaru-purple Yaru-red Yaru-sage Yaru-wartybrown Yaru-yellow`.

---

### Unlock image

Themes supplied with `unlock.png` and `preview-unlock.png` images will be listed under _Style > Unlock_. Your `unlock.png` should preferably be a transparent png. And you can create the preview image using `omarchy plymouth preview`.

---

### Distributing your theme

If you want to distribute your theme so others can use it, you need to put it on a public git server, like GitHub. Then people can install it using _Install > Theme_ in the Omarchy menu using that URL. It's recommended that you follow the naming convention of `omarchy-[themename]-theme`, as the theme will show correctly as just `[themename]` in the theme selection menu after installation.

You can have your theme added to [the extra themes page](https://manuals.omamix.org/2/the-omarchy-manual/90/extra-themes) by pinging @tahayvr on [the #omarchy Discord](https://discord.gg/tXFUdasqhY).

The Rest

# Manual installation

If you can't use the Omarchy ISO, you can do a manual installation using the vanilla arch ISO, archinstall, and following the steps in this guide. This is not something most people should attempt, but if you know what you're doing, and why you're doing it, this is how.

1. [Download the Arch Linux ISO](https://archlinux.org/download/#http-downloads), put it on a USB stick (use [balenaEtcher](https://etcher.balena.io/) on Mac/Windows), and boot off the stick (remember to turn off Secure Boot in the BIOS!).
2. If you're on wifi, start by running `iwctl`, then type `station wlan0 scan`, then `station wlan0 connect <tab>`, pick your network, and enter the password. If you're on ethernet, you don't need this.
3. Run `archinstall` and pick these options (and leave anything not mentioned as-is):

| Section | Option |
| -------- | ------ |
| Mirrors and repositories | Select regions > Your country |
| Disk configuration | Partitioning > Default partitioning layout > Select disk (with space + return) |
| Disk > File system | btrfs (default structure: yes + use compression) |
| Disk > Disk encryption | Encryption type: LUKS + Encryption password + Partitions (select the one) | 
| Hostname | Give your computer a name |
| Bootloader | Limine |
| Authentication > Root password | Set yours |
| Authentication > User account | Add a user > Superuser: Yes > Confirm and exit |
| Applications > Audio | pipewire |
| Network configuration | Copy ISO network config |
| Timezone | Set yours |

Beware that you _must setup disk encryption_ to use Omarchy as designed! The setup relies exclusively on disk encryption to secure your device, as it'll auto-login the user after the disk has been decrypted at boot.

Just note that this encryption setup won't allow you to enter the password from a Bluetooth keyboard at startup. Just like you can't use a Bluetooth keyboard to enter the BIOS on a PC. You'll need a keyboard that either uses a 2.4ghz dongle or a cable (which is much nicer for latency anyway!). I personally love the [Lofree Flow84](https://www.lofree.co/products/lofree-flow-the-smoothest-mechanical-keyboard)! 

Here's what the disk encryption setup should look like. You need to pick `LUKS`, then set the encryption password, then apply to the partition (this step is crucial or nothing gets encrypted!):

 ![arch-encryption.png](/u/arch-encryption-urjrDm.png)

Once Arch has been installed, pick reboot, login with the user you just setup, and now you're ready to install Omarchy by running:

`curl -fsSL https://omarchy.org/install | bash`

It'll first ask you to sudo, then shortly thereafter, it'll ask for your name and email address. Those credentials are used to preconfigure git (`git config --global user.name/email`) and set for auto-expansion on `CapsLock Space E` (email) and `CapsLock Space N` (name). After that, it'll run by itself for 5-30 minutes, depending on the speed of your internet connection. When it's all done, it'll ask for your permission to reboot the system.

Now you're ready to Omarchy!

# Mac support

As of Omarchy 3, there's built-in support for **Intel Macs**. There are a couple of known limitations at the moment, but as long as you're aware and OK with those; you can breathe some new life into your old Macs by loading Omarchy.

Please note that installing on an M-series Mac is not directly supported at this time. You can find out more about the state of this in #omarchy-on-other in our [Discord](https://discord.gg/tXFUdasqhY).

In a simple test, we were able to achieve 36% performance gains on a 2019 MacBook Pro just by installing Omarchy.

 ![G0-1NXRWQAAn_IH.jpeg](https://learn.omacom.io/u/g0-1nxrwqaan_ih-nOdzdG.jpeg) 

---

### Installing Omarchy on Mac

Omarchy only supports being the **only** OS installed at the moment. During the installation, the drive will be wiped and MacOS will no longer be bootable. 

You can still restore it later via Internet Recovery if you'd like.

For the sake of this part, we'll assume you've already reviewed [Getting Started](https://learn.omacom.io/2/the-omarchy-manual/50/getting-started) and have your USB drive ready. If you don't go ahead and do that now.

#### Disable Secure Boot

It is necessary to disable Apple's Secure Boot in order to boot the bootable USB, as well as the OS. To disable it, perform the following:

1. Turn off your Mac
2. Turn it on and _immediately_ press and hold Command-R until you see the loading screen appear
3. Select your user and enter your password if prompted
4. Once in the recovery screen, choose **Utilities > Startup Security Utility** from the menubar
5. Enter your password when prompted to authenticate
6. Choose "No Security" from the Secure Boot options
7. Choose "Allow booting from external or removable media" from the External Boot options

#### Start the Installation

1. Insert the USB drive
2. Restart your Mac and _immediately_ press and hold Option until you see a screen of boot devices
3. Select the orange EFI Boot device
4. Proceed with the [install as normal
](https://learn.omacom.io/2/the-omarchy-manual/50/getting-started)

---

### Known Limitations

Members of the community are constantly working on solutions to these challenges so if these are problematic for you, join #omarchy-on-other in our [Discord](https://discord.gg/tXFUdasqhY) and see if there's any up-to-date methods for resolving these.

#### Devices with T1 Chip

The Apple T1 chip was introduced in late 2016 and used exclusively in the first-generation MacBook Pro models with Touch Bar. 
- MacBook Pro 13-inch (2016, two Thunderbolt 3 ports) – Model: A1706
- MacBook Pro 13-inch (2016, four Thunderbolt 3 ports) – Model: A1708
- MacBook Pro 15-inch (2016) – Model: A1707

#### Known Issues

- Touch Bar is non-functional
- Sound is not functioning

#### Devices with T2 Chip

The Apple T2 Security Chip was introduced in 2017. The T2 chip was discontinued with the transition to Apple silicon (M-series chips) starting in 2020.

- iMac Pro (2017) – Model: A1862
- MacBook Pro 13-inch (2018, four Thunderbolt 3 ports) – Model: A1989
- MacBook Pro 15-inch (2018) – Model: A1990
- MacBook Air (Retina, 13-inch, 2018) – Model: A1932
- Mac mini (2018) – Model: A1998
- MacBook Pro 13-inch (2019, two Thunderbolt 3 ports) – Model: A2159
- MacBook Pro 13-inch (2019, four Thunderbolt 3 ports) – Model: A2178
- MacBook Pro 15-inch (2019) – Model: A1990
- MacBook Pro 13-inch (2020, two Thunderbolt 3 ports) – Model: A2265
- MacBook Pro 15-inch (2020) – Model: A1990

# Troubleshooting

### I broke my system with an update!

First try to [rollback your system](/2/the-omarchy-manual/101/system-snapshots) the version before your recent update. If that doesn't work, use `omarchy-debug` to share with your problem on #omarchy-help in the Discord. And if all that fails, you can reinstall the defaults configs and packages using `omarchy-reinstall`.

---

### Why are some apps so large on my display?

Omarchy assumes a 2x high-resolution display, which requires setting `GDK_SCALE` to 2 in `~/.config/hypr/hyprland.conf`. But if you're on a 1x display, you can change this to 1 (and then restart any app that's oversized). See [the manual on monitors](/2/the-omarchy-manual/86/monitors).

For Spotify, you can use `Ctrl + Minus` to shrink the UI (and `Ctrl + Plus` to make it bigger).

---

### Why isn't Caps Lock working?

In Omarchy, Caps Lock has been designated to be the xcompose key. That's how you get [quick emojis](https://manuals.omamix.org/2/the-omarchy-manual/53/hotkeys#quick-emojis) and [other autocompletions](https://manuals.omamix.org/2/the-omarchy-manual/53/hotkeys#quick-completions) done. If you really miss using Caps Lock, you can remape the xcompose key to something else by editing `~/.config/hypr/input.conf`, like setting it to the right alt key:

```
kb_options = compose:ralt
```

---

### Why are my external speakers not playing?

Probably because they're not set as the primary output. Click on the speaker in the top right of the waybar, and it'll launch the volume controls where you can select the primary speaker (designate it as default with "d").

---

### Why can't I login or sudo with my password?

You probably typed it wrong too many times and got locked out. If this is happening on the lock screen, you can hit `CTRL + ALT + F2` to start a new TTY where you can login as root, then run `faillock --reset --user [your-username]`. That'll reset the lockout, and you're good to go.

---

### Why isn't my 1Password authorization prompts for 1Password SSH Agent / CLI appearing?

This can happen for 2 reasons:

In order for the rich approval prompt to appear, Settings > Advanced > Use Hardware Acceleration must be turned on. _Note: This requires a reboot to begin working._

 ![1pw-hw-accel.png](/u/1pw-hw-accel-w6VzWp.png) 

Or if you haven't launched 1Password since booting up, the prompt will not appear. 

# FAQ


### How do I switch between keyboard layouts?

Edit your `~/.config/hypr/input.conf` file and add this to switch between layouts on `Left Alt + Right Alt`:

```
# Use multiple keyboard layouts and switch between them with Left Alt + Right Alt
input {
    kb_layout = us,fr
    kb_options = compose:caps,grp:alts_toggle
}
```

You can even [configure Waybar to showing your current keyboard layout in the top bar](https://github.com/basecamp/omarchy/discussions/111).

---

### How do I change the clock format to 12-hour?

Edit your `~/.config/waybar/config.jsonc` file and replace this:

```
  "clock": {
    "format": "{:%A %H:%M}",
```

with:

```
  "clock": {
    "format": "{:%A %I:%M %p}",
```

This will display Sunday 10:55 AM.

---

### How do I change where screenshots or screenrecordings are saved?

If you screenshots to be saved to `~/Pictures/Screenshots` instead of just `~/Pictures`, you can open _Setup > Defaults_ via the Omarchy menu and set this:

```
export OMARCHY_SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
```

You can do the same for screenrecordings using `OMARCHY_SCREENRECORD_DIR`.

Just remember to create the directoy you want to save to and restart Omarchy for this to take effect.

---

### How do I get the speakers + webcam working on my Apple Studio Display?

You'd think that it should all work just plugging in USB C, but unfortunately that isn't the case. The solution I've found to make it work reliably is using [the WJESOG DisplayPort + USB-A => USB-C cable](https://www.amazon.com/WJESOG-DisplayPort-Adapter-Converter-Thunderbolt/dp/B0BNX7MS6N/). Then speakers and webcam work like a charm.

Remember that you have built-in brightness control in Omarchy for the Apple Displays (both Studio and XDR) using the regular keyboard brightness buttons.

---

### How do I get rid of all the extra software?

If you don't want programs like Spotify or Obsidian or any of the other preinstalled stuff, you can very easily remove it. 

Run _Remove > Package_ to see every package that's installed. Then you can select any package you'd like to remove with tab, and start removing everything you've selected with return.

And you can use _Remove > Web App_ from the Omarchy menu to remove any of the preinstalled web apps you don't want. 

---

For errors and broken bits, see [the Troubleshooting section](/2/the-omarchy-manual/88/troubleshooting).

# System snapshots

We create snapshots automatically on every Omarchy update, but should you want to create your own, you can use `omarchy-snapshot create`.

To boot and restore a snapshot, you select it from the Limine boot loader. (If you're currently booting straight into the Omarchy decryption screen, you'll need to select Limine as a boot option via the BIOS first).

From that screen, choose the snapshot you'd like to boot into based on the date and version. The version of Omarchy at the time of the snapshot can be seen at the bottom left corner.

 ![omarchy-bootloader.png](/u/omarchy-bootloader-Qz7kQ1.png) 

When you arrive inside, a notification will popup notifying you that you're in a bootable snapshot and if you click it, will start the restoration process. Alternatively, you can utilize `omarchy-snapshot restore`.

 ![omarchy-restore-snapshot.png](/u/omarchy-restore-snapshot-2TrMhj.png) 

This will restore your `/root`, but not your `/home`. So it works for reverting a broken system update, but not for recovering lost personal files.

This also means that your `~/.config` directory is kept as-is. So if you're rolling back to an earlier version of a library or application that stores configuration files in a new format, you'll have to sort that out manually.

_Note: This feature is only available on installations using the Limine boot loader, which has been the default since Omarchy 2.0. It's not available if you're on GRUB or systemd-boot._

# Security

Omarchy takes security extremely seriously. This is meant to be an operating system that you can use to do _Real Work_ in the _Real World_. Where losing a laptop can't lead to a security emergency. So here's what we do:

1. *Full-disk encryption is mandatory*: This is the most important step to securing the physical protection of your data. If your computer is lost or stolen, the data is fully encrypted using standard LUKS (Linux Unified Key Setup). 
2. *Firewall is enabled by default*: All incoming traffic by default except for port 22 for ssh and port 53317 for [LocalSend](https://localsend.org/). We even lock down Docker access using the [ufw-docker](https://github.com/chaifeng/ufw-docker) setup to prevent that your containers are accidentally exposed to the world.
3. *Arch always have the latest updates*: Arch, the underlying distro that Omarchy is built on, is a rolling distribution. This means that any security vulnerability that's discovered and patched in any package is immediately available for install using `yay -Syu`. You're always running the latest, most secure versions of everything that way.
4. *Omarchy maintains its own packages and mirror*: Omarchy only relies on packages from Arch's own core/extra/multilib repositories and its own Omarchy Package Repository by default. You can install software directly from AUR, but Omarchy does not by default. Even for the optional installs.
5. *Cloudflare protects us from DDoS*: All the Omarchy distribution infrastructure — the ISOs, the Omarchy packages, the Arch mirror — is protected behind Cloudflare's formidable DDoS shield and hosted on their CDN. This provides superb availability. 


## Signing Keys
The public key for all ISO signatures and Omarchy repo package is `40DFB630FF42BCFFB047046CF0134EE680CAC571` ([verify at openpgp.org](https://keys.openpgp.org/search?q=pkgs%40omarchy.org)). The `omarchy/omarchy-keyring` package contains this as well and will be used to rollout any potential updates seamlessly.

You can find the signature for any ISO release by adding .sig to the URL. Like https://iso.omarchy.org/omarchy-x.x.x.iso.sig.


# Omarchy on...

### Apple M1/M2 chips

[Asahi Alarm](https://asahi-alarm.org/) is a version of Arch for Apple M1/M2 computers built on top of [Asahi Linux](https://asahilinux.org/). You can get Omarchy running on top of that with some effort. See [the user-driven guide](https://github.com/basecamp/omarchy/discussions/155).

### Apple Virtual Machine

You can also install Omarchy inside a Parallels VM. Quite the cumbersome process, but there's [a user-driven guide](https://github.com/basecamp/omarchy/discussions/452) for that too.

### VirtualBox

VirtualBox is a popular VM runner. [You can run Omarchy inside that too](https://github.com/basecamp/omarchy/discussions/176). But performance probably won't be great.

### VMware Workstation on Windows 11

Another popular VM runner for Windows. [Omarchy has been setup inside of that as well](https://github.com/basecamp/omarchy/discussions/572).

### Steam Deck

The Steam Deck runs on Arch, which means you can run Omarchy on your Steam Deck. Altynbek Orumbayev has [a full setup script and explanation on how to do it](https://github.com/aorumbayev/deckarchy). How cool is that!

### NixOS

Omarchy is really Arch + Hyprland, but Henry Sipp has [ported the essence of the setup to NixOS](https://github.com/henrysipp/omarchy-nix). So if you've been nix-pilled, here's a good starting point. It may or may not stay up-to-date with the latest Omarchy changes, but it's pretty cool none the less!

### Something else!

If you're trying to get Omarchy running on a configuration that isn't the default, you should join the #omarchy-on-other channel on [our community Discord](https://discord.gg/tXFUdasqhY).