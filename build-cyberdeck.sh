#!/usr/bin/env bash
# ============================================================
#  CYBERDECK — live-дистрибутив на базе Arch Linux
#  Интерфейс в стиле киберпанк-терминалов: жёлтый / циан / красный на чёрном.
#
#  Запуск (ТОЛЬКО на Arch Linux или в виртуалке с Arch, нужен интернет):
#     sudo pacman -S --needed archiso
#     sudo bash build-cyberdeck.sh
#  Готовый образ появится в ./cyberdeck-build/out/*.iso
# ============================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Запусти через sudo: sudo bash $0"; exit 1; }
command -v mkarchiso >/dev/null || { echo "Нет archiso. Выполни: sudo pacman -S archiso"; exit 1; }

ROOT="$(pwd)/cyberdeck-build"
PROFILE="$ROOT/profile"
A="$PROFILE/airootfs"
SKEL="$A/etc/skel"

rm -rf "$ROOT"
mkdir -p "$ROOT"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# ---------- 1. Имя дистрибутива ----------
sed -i 's/^iso_name=.*/iso_name="cyberdeck"/'              "$PROFILE/profiledef.sh"
sed -i 's/^iso_application=.*/iso_application="CYBERDECK Live"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_label=.*/iso_label="CYBERDECK_$(date +%Y%m)"/'   "$PROFILE/profiledef.sh"

# ---------- 2. Пакеты ----------
cat >> "$PROFILE/packages.x86_64" <<'EOF'
xorg-server
xorg-xinit
xorg-xrandr
xorg-setxkbmap
xf86-input-libinput
mesa
openbox
lightdm
lightdm-gtk-greeter
polybar
picom
rofi
kitty
feh
librsvg
thunar
firefox
pavucontrol
pipewire
pipewire-pulse
wireplumber
lxappearance
gnome-themes-extra
adwaita-icon-theme
ttf-jetbrains-mono
noto-fonts
noto-fonts-emoji
fastfetch
sudo
EOF

# ---------- 3. Права и автологин ----------
sed -i '/^file_permissions=(/a\  ["/etc/sudoers.d/g_wheel"]="0:0:440"\n  ["/usr/local/bin/cyberdeck-firstboot"]="0:0:755"' "$PROFILE/profiledef.sh"

mkdir -p "$A/etc/sudoers.d" "$A/usr/local/bin" "$A/etc/lightdm/lightdm.conf.d" "$A/etc/systemd/system/multi-user.target.wants"
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > "$A/etc/sudoers.d/g_wheel"

# Пользователь создаётся при загрузке: логин cyber, пароль cyber
cat > "$A/usr/local/bin/cyberdeck-firstboot" <<'EOF'
#!/bin/bash
groupadd -rf autologin
if ! id cyber &>/dev/null; then
  useradd -m -G wheel,audio,video,storage,autologin -s /bin/bash cyber
fi
echo 'cyber:cyber' | chpasswd
EOF

cat > "$A/etc/systemd/system/cyberdeck-firstboot.service" <<'EOF'
[Unit]
Description=CYBERDECK: create live user
Before=display-manager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/cyberdeck-firstboot

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/cyberdeck-firstboot.service "$A/etc/systemd/system/multi-user.target.wants/cyberdeck-firstboot.service"

# Графический режим + LightDM
ln -sf /usr/lib/systemd/system/graphical.target "$A/etc/systemd/system/default.target"
ln -sf /usr/lib/systemd/system/lightdm.service  "$A/etc/systemd/system/display-manager.service"

# Звук (pipewire для пользователя)
mkdir -p "$A/etc/systemd/user/sockets.target.wants" "$A/etc/systemd/user/default.target.wants"
ln -sf /usr/lib/systemd/user/pipewire.socket       "$A/etc/systemd/user/sockets.target.wants/pipewire.socket"
ln -sf /usr/lib/systemd/user/pipewire-pulse.socket "$A/etc/systemd/user/sockets.target.wants/pipewire-pulse.socket"
ln -sf /usr/lib/systemd/user/wireplumber.service   "$A/etc/systemd/user/default.target.wants/wireplumber.service"

cat > "$A/etc/lightdm/lightdm.conf.d/50-cyberdeck.conf" <<'EOF'
[Seat:*]
autologin-user=cyber
autologin-session=openbox
user-session=openbox
EOF

cat > "$A/etc/lightdm/lightdm-gtk-greeter.conf" <<'EOF'
[greeter]
background=#0a0a0f
theme-name=Adwaita-dark
font-name=JetBrains Mono Bold 11
EOF

# ---------- 4. Конфиги интерфейса (попадают в домашнюю папку cyber) ----------
mkdir -p "$SKEL/.config/openbox" "$SKEL/.config/polybar" "$SKEL/.config/picom" \
         "$SKEL/.config/rofi" "$SKEL/.config/kitty" "$SKEL/.config/gtk-3.0" \
         "$SKEL/.config/cyberdeck" "$SKEL/.themes/Cyberdeck/openbox-3"

# --- Обои (SVG, рисуются в PNG при входе) ---
cat > "$SKEL/.config/cyberdeck/wallpaper.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#05050a"/><stop offset="1" stop-color="#14101c"/>
    </linearGradient>
    <pattern id="grid" width="60" height="60" patternUnits="userSpaceOnUse">
      <path d="M60 0H0V60" fill="none" stroke="#fcee09" stroke-opacity="0.07" stroke-width="1"/>
    </pattern>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#grid)"/>
  <!-- срезанная угловая рамка -->
  <polygon points="80,60 1700,60 1860,220 1860,1020 300,1020 60,780 60,80"
           fill="none" stroke="#fcee09" stroke-width="3" stroke-opacity="0.85"/>
  <polygon points="100,80 1690,80 1840,230 1840,1000 310,1000 80,775"
           fill="none" stroke="#00f0ff" stroke-width="1" stroke-opacity="0.35"/>
  <!-- заголовок с глитчем -->
  <g font-family="JetBrains Mono, monospace" font-weight="800" font-size="150" letter-spacing="14">
    <text x="296" y="506" fill="#ff003c" opacity="0.8">CYBERDECK</text>
    <text x="288" y="498" fill="#00f0ff" opacity="0.8">CYBERDECK</text>
    <text x="292" y="502" fill="#fcee09">CYBERDECK</text>
  </g>
  <rect x="292" y="540" width="900" height="6" fill="#fcee09"/>
  <rect x="1192" y="540" width="120" height="6" fill="#ff003c"/>
  <g font-family="JetBrains Mono, monospace" font-size="26" fill="#00f0ff" opacity="0.9">
    <text x="292" y="600">SYS://BOOT ........ OK</text>
    <text x="292" y="640">NET://UPLINK ...... STANDBY</text>
    <text x="292" y="680">USER://CYBER ...... AUTHORIZED</text>
  </g>
  <rect x="292" y="900" width="14" height="14" fill="#ff003c"/>
  <text x="322" y="913" font-family="JetBrains Mono, monospace" font-size="22" fill="#fcee09" opacity="0.8">ARCH LINUX CORE // INTERFACE v1.0</text>
</svg>
EOF

# --- Автозапуск Openbox ---
cat > "$SKEL/.config/openbox/autostart" <<'EOF'
setxkbmap -layout us,ru -option grp:alt_shift_toggle &
picom --config "$HOME/.config/picom/picom.conf" -b &
( rsvg-convert -w 1920 -h 1080 "$HOME/.config/cyberdeck/wallpaper.svg" -o /tmp/cyberdeck-wall.png \
  && feh --bg-fill /tmp/cyberdeck-wall.png ) &
polybar cyber &
EOF

# --- Меню правой кнопки ---
cat > "$SKEL/.config/openbox/menu.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="CYBERDECK">
    <item label="TERMINAL"><action name="Execute"><command>kitty</command></action></item>
    <item label="BROWSER"><action name="Execute"><command>firefox</command></action></item>
    <item label="FILES"><action name="Execute"><command>thunar</command></action></item>
    <item label="APPLICATIONS"><action name="Execute"><command>sh -c "rofi -show drun -theme $HOME/.config/rofi/cyber.rasi"</command></action></item>
    <separator/>
    <item label="LOG OUT"><action name="Exit"/></item>
    <item label="REBOOT"><action name="Execute"><command>systemctl reboot</command></action></item>
    <item label="SHUTDOWN"><action name="Execute"><command>systemctl poweroff</command></action></item>
  </menu>
</openbox_menu>
EOF

# --- Настройки Openbox + горячие клавиши ---
cat > "$SKEL/.config/openbox/rc.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <resistance><strength>10</strength><screen_edge_strength>20</screen_edge_strength></resistance>
  <focus><focusNew>yes</focusNew><followMouse>no</followMouse><raiseOnFocus>no</raiseOnFocus></focus>
  <placement><policy>Smart</policy></placement>
  <theme>
    <name>Cyberdeck</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>no</animateIconify>
    <font place="ActiveWindow"><name>JetBrains Mono</name><size>9</size><weight>Bold</weight><slant>Normal</slant></font>
    <font place="InactiveWindow"><name>JetBrains Mono</name><size>9</size><weight>Bold</weight><slant>Normal</slant></font>
    <font place="MenuItem"><name>JetBrains Mono</name><size>10</size><weight>Bold</weight><slant>Normal</slant></font>
    <font place="MenuHeader"><name>JetBrains Mono</name><size>10</size><weight>Bold</weight><slant>Normal</slant></font>
    <font place="OnScreenDisplay"><name>JetBrains Mono</name><size>10</size><weight>Bold</weight><slant>Normal</slant></font>
  </theme>
  <desktops><number>4</number><firstdesk>1</firstdesk><names><name>01</name><name>02</name><name>03</name><name>04</name></names></desktops>
  <keyboard>
    <keybind key="W-Return"><action name="Execute"><command>kitty</command></action></keybind>
    <keybind key="W-d"><action name="Execute"><command>sh -c "rofi -show drun -theme $HOME/.config/rofi/cyber.rasi"</command></action></keybind>
    <keybind key="W-f"><action name="Execute"><command>firefox</command></action></keybind>
    <keybind key="W-e"><action name="Execute"><command>thunar</command></action></keybind>
    <keybind key="W-q"><action name="Close"/></keybind>
    <keybind key="A-F4"><action name="Close"/></keybind>
    <keybind key="W-Up"><action name="ToggleMaximize"/></keybind>
    <keybind key="A-Tab"><action name="NextWindow"/></keybind>
    <keybind key="W-1"><action name="GoToDesktop"><to>1</to></action></keybind>
    <keybind key="W-2"><action name="GoToDesktop"><to>2</to></action></keybind>
    <keybind key="W-3"><action name="GoToDesktop"><to>3</to></action></keybind>
    <keybind key="W-4"><action name="GoToDesktop"><to>4</to></action></keybind>
  </keyboard>
  <mouse>
    <context name="Frame">
      <mousebind button="A-Left" action="Press"><action name="Focus"/><action name="Raise"/></mousebind>
      <mousebind button="A-Left" action="Drag"><action name="Move"/></mousebind>
      <mousebind button="A-Right" action="Drag"><action name="Resize"/></mousebind>
    </context>
    <context name="Titlebar">
      <mousebind button="Left" action="Press"><action name="Focus"/><action name="Raise"/></mousebind>
      <mousebind button="Left" action="Drag"><action name="Move"/></mousebind>
      <mousebind button="Left" action="DoubleClick"><action name="ToggleMaximize"/></mousebind>
    </context>
    <context name="Client">
      <mousebind button="Left" action="Press"><action name="Focus"/><action name="Raise"/><action name="ForwardMousePress"/></mousebind>
    </context>
    <context name="Top"><mousebind button="Left" action="Drag"><action name="Resize"><edge>top</edge></action></mousebind></context>
    <context name="Bottom"><mousebind button="Left" action="Drag"><action name="Resize"><edge>bottom</edge></action></mousebind></context>
    <context name="Left"><mousebind button="Left" action="Drag"><action name="Resize"><edge>left</edge></action></mousebind></context>
    <context name="Right"><mousebind button="Left" action="Drag"><action name="Resize"><edge>right</edge></action></mousebind></context>
    <context name="BRCorner"><mousebind button="Left" action="Drag"><action name="Resize"/></mousebind></context>
    <context name="Iconify"><mousebind button="Left" action="Click"><action name="Iconify"/></mousebind></context>
    <context name="Maximize"><mousebind button="Left" action="Click"><action name="ToggleMaximize"/></mousebind></context>
    <context name="Close"><mousebind button="Left" action="Click"><action name="Close"/></mousebind></context>
    <context name="Root">
      <mousebind button="Right" action="Press"><action name="ShowMenu"><menu>root-menu</menu></action></mousebind>
    </context>
  </mouse>
</openbox_config>
EOF

# --- Тема окон Openbox ---
cat > "$SKEL/.themes/Cyberdeck/openbox-3/themerc" <<'EOF'
border.width: 2
padding.width: 8
padding.height: 4
window.handle.width: 0
window.client.padding.width: 0

window.active.border.color: #fcee09
window.inactive.border.color: #4a4a14
window.active.title.separator.color: #fcee09
window.inactive.title.separator.color: #4a4a14
window.active.client.color: #fcee09
window.inactive.client.color: #4a4a14

window.active.title.bg: flat solid
window.active.title.bg.color: #fcee09
window.inactive.title.bg: flat solid
window.inactive.title.bg.color: #14141c
window.active.label.bg: parentrelative
window.inactive.label.bg: parentrelative
window.active.label.text.color: #0a0a0f
window.inactive.label.text.color: #8a8a3a
window.label.text.justify: left

window.active.handle.bg: flat solid
window.active.handle.bg.color: #fcee09
window.inactive.handle.bg: flat solid
window.inactive.handle.bg.color: #4a4a14
window.active.grip.bg: flat solid
window.active.grip.bg.color: #fcee09
window.inactive.grip.bg: flat solid
window.inactive.grip.bg.color: #4a4a14

window.active.button.unpressed.bg: flat solid
window.active.button.unpressed.bg.color: #fcee09
window.active.button.unpressed.image.color: #0a0a0f
window.active.button.hover.bg: flat solid
window.active.button.hover.bg.color: #00f0ff
window.active.button.hover.image.color: #0a0a0f
window.active.button.pressed.bg: flat solid
window.active.button.pressed.bg.color: #ff003c
window.active.button.pressed.image.color: #0a0a0f
window.inactive.button.unpressed.bg: flat solid
window.inactive.button.unpressed.bg.color: #14141c
window.inactive.button.unpressed.image.color: #8a8a3a
window.inactive.button.hover.bg: flat solid
window.inactive.button.hover.bg.color: #00f0ff
window.inactive.button.hover.image.color: #0a0a0f
window.inactive.button.pressed.bg: flat solid
window.inactive.button.pressed.bg.color: #ff003c
window.inactive.button.pressed.image.color: #0a0a0f

menu.border.width: 2
menu.border.color: #fcee09
menu.overlap: 0
menu.title.bg: flat solid
menu.title.bg.color: #fcee09
menu.title.text.color: #0a0a0f
menu.title.text.justify: left
menu.items.bg: flat solid
menu.items.bg.color: #0a0a0f
menu.items.text.color: #fcee09
menu.items.disabled.text.color: #4a4a14
menu.items.active.bg: flat solid
menu.items.active.bg.color: #fcee09
menu.items.active.text.color: #0a0a0f
menu.separator.color: #00f0ff
menu.separator.width: 1

osd.border.width: 2
osd.border.color: #00f0ff
osd.bg: flat solid
osd.bg.color: #0a0a0f
osd.label.bg: flat solid
osd.label.bg.color: #0a0a0f
osd.label.text.color: #00f0ff
osd.hilight.bg: flat solid
osd.hilight.bg.color: #fcee09
osd.unhilight.bg: flat solid
osd.unhilight.bg.color: #14141c
EOF

# --- Панель Polybar ---
cat > "$SKEL/.config/polybar/config.ini" <<'EOF'
[colors]
bg = #e60a0a0f
fg = #fcee09
cyan = #00f0ff
red = #ff003c
dim = #6b6b1f

[bar/cyber]
width = 100%
height = 32
background = ${colors.bg}
foreground = ${colors.fg}
border-bottom-size = 2
border-bottom-color = ${colors.fg}
font-0 = JetBrains Mono:style=Bold:size=10;2
padding = 2
module-margin = 1
modules-left = xworkspaces xwindow
modules-center = date
modules-right = cpu memory network pulseaudio
enable-ipc = true

[module/xworkspaces]
type = internal/xworkspaces
label-active = [%name%]
label-active-foreground = ${colors.cyan}
label-occupied = %name%
label-occupied-padding = 1
label-empty = %name%
label-empty-foreground = ${colors.dim}
label-empty-padding = 1

[module/xwindow]
type = internal/xwindow
label = // %title:0:50:...%
label-foreground = ${colors.cyan}

[module/date]
type = internal/date
interval = 1
date = %H:%M:%S  %d.%m.%Y
label = %{F#ff003c}SYS//TIME%{F-}  %date%

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = "CPU// "
format-prefix-foreground = ${colors.red}
label = %percentage:2%%

[module/memory]
type = internal/memory
interval = 3
format-prefix = "MEM// "
format-prefix-foreground = ${colors.red}
label = %percentage_used%%

[module/network]
type = internal/network
interface-type = wired
interval = 3
format-connected-prefix = "NET// "
format-connected-prefix-foreground = ${colors.red}
label-connected = ONLINE
label-disconnected = OFFLINE
format-disconnected-prefix = "NET// "
format-disconnected-prefix-foreground = ${colors.red}
label-disconnected-foreground = ${colors.dim}

[module/pulseaudio]
type = internal/pulseaudio
format-volume-prefix = "VOL// "
format-volume-prefix-foreground = ${colors.red}
label-volume = %percentage%%
label-muted = MUTE
label-muted-foreground = ${colors.dim}
EOF

# --- Прозрачность/анимации ---
cat > "$SKEL/.config/picom/picom.conf" <<'EOF'
backend = "xrender";
vsync = true;
fading = true;
fade-in-step = 0.08;
fade-out-step = 0.08;
shadow = false;
corner-radius = 0;
EOF

# --- Меню запуска приложений ---
cat > "$SKEL/.config/rofi/cyber.rasi" <<'EOF'
* {
    bg: #0a0a0fee;
    fg: #fcee09;
    cyan: #00f0ff;
    red: #ff003c;
    background-color: transparent;
    text-color: @fg;
    font: "JetBrains Mono Bold 11";
}
window {
    background-color: @bg;
    border: 2px;
    border-color: @fg;
    width: 560px;
    location: center;
}
mainbox { padding: 14px; children: [inputbar, listview]; }
inputbar {
    children: [prompt, entry];
    padding: 8px;
    spacing: 10px;
    border: 0 0 2px 0;
    border-color: @cyan;
}
prompt { text-color: @red; }
entry { text-color: @cyan; }
listview { lines: 8; margin: 12px 0 0 0; scrollbar: false; }
element { padding: 6px 10px; }
element selected.normal { background-color: @fg; text-color: #0a0a0f; }
EOF

# --- Терминал ---
cat > "$SKEL/.config/kitty/kitty.conf" <<'EOF'
font_family JetBrains Mono
font_size 11
background #0a0a0f
background_opacity 0.93
foreground #fcee09
cursor #00f0ff
selection_background #fcee09
selection_foreground #0a0a0f
window_padding_width 10
confirm_os_window_close 0
color0  #0a0a0f
color8  #4a4a14
color1  #ff003c
color9  #ff3d6a
color2  #00f0ff
color10 #7dfaff
color3  #fcee09
color11 #fff56b
color4  #3d7bff
color12 #7da4ff
color5  #d400ff
color13 #e87dff
color6  #00f0ff
color14 #7dfaff
color7  #d8d8c0
color15 #ffffff
EOF

# --- GTK (Thunar, Firefox-диалоги и т.д.) ---
cat > "$SKEL/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=JetBrains Mono 10
gtk-application-prefer-dark-theme=1
EOF

cat > "$SKEL/.config/gtk-3.0/gtk.css" <<'EOF'
@define-color theme_selected_bg_color #fcee09;
@define-color theme_selected_fg_color #0a0a0f;
@define-color theme_bg_color #0a0a0f;
@define-color theme_base_color #101018;
@define-color theme_fg_color #fcee09;
@define-color theme_text_color #fcee09;
@define-color borders #fcee09;

button { border-radius: 0; border: 1px solid #fcee09; background-image: none; background-color: #14141c; color: #fcee09; }
button:hover { background-color: #fcee09; color: #0a0a0f; }
entry { border-radius: 0; border: 1px solid #00f0ff; background-color: #101018; color: #00f0ff; }
EOF

# --- Bash: промпт и приветствие ---
cat > "$SKEL/.bashrc" <<'EOF'
[[ $- != *i* ]] && return
PS1='\[\e[1;33m\]\u\[\e[0m\]@\[\e[1;36m\]cyberdeck\[\e[0m\] \[\e[1;31m\]»\[\e[0m\] '
alias ls='ls --color=auto'
alias ll='ls -lah'
command -v fastfetch >/dev/null && fastfetch
EOF

# ---------- 5. Сборка ISO ----------
echo ">>> Собираю ISO (это займёт 10–30 минут)..."
mkarchiso -v -w "$ROOT/work" -o "$ROOT/out" "$PROFILE"

echo
echo "ГОТОВО. Образ:"
ls -lh "$ROOT"/out/*.iso
echo "Логин/пароль: cyber / cyber (автологин включён)."
