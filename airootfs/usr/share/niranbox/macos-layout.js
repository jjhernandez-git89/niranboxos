// Layout tipo macOS para NiranBoxOS Modo Escritorio: barra delgada arriba
// (menu, reloj, bandeja) + dock de iconos abajo, centrado, autoocultable.
// API real de scripting de Plasma (ver develop.kde.org/docs/plasma/scripting).
//
// Se corre una sola vez con: plasmashell --script macos-layout.js
// (ver /usr/local/bin/niranbox-apply-layout.sh)

// Quita los paneles que Plasma haya creado por defecto antes de armar los
// nuestros, para no terminar con paneles duplicados.
var existing = panels();
for (var i = 0; i < existing.length; i++) {
    existing[i].remove();
}

// --- Barra superior (tipo menu bar de macOS) ---
var topBar = new Panel;
topBar.location = "top";
topBar.height = Math.round(gridUnit * 1.6);

var launcher = topBar.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "/usr/share/pixmaps/niranbox-logo-small.png");

var appMenu = topBar.addWidget("org.kde.plasma.appmenu");

topBar.addWidget("org.kde.plasma.panelspacer");

topBar.addWidget("org.kde.plasma.systemtray");

var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");

// --- Dock inferior (tipo Dock de macOS: iconos, centrado, se esconde) ---
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3);
dock.alignment = "center";
dock.hiding = "autohide";

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("showOnlyCurrentDesktop", "false");
tasks.writeConfig("showOnlyCurrentActivity", "false");
