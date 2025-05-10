#!/usr/bin/env bash

# Script to set up Netflix theming with Wallbash (dynamic color updates)
# Creates or overwrites netflix.dcol, netflix.sh, and updates main.js

set -e

WALLBASH_ALWAYS_DIR="$HOME/.config/hyde/wallbash/always"
WALLBASH_SCRIPTS_DIR="$HOME/.config/hyde/wallbash/scripts"
NETFLIX_DCOL="$WALLBASH_ALWAYS_DIR/netflix.dcol"
NETFLIX_SH="$WALLBASH_SCRIPTS_DIR/netflix.sh"
MAIN_JS="/opt/Netflix/main.js"
MAIN_JS_BACKUP="/opt/Netflix/main.js.bak"
COLORS_FILE="/home/kot/.config/hypr/themes/colors.conf"

if [[ $EUID -eq 0 ]]; then
  echo "This script should not be run as root. It will use sudo for operations requiring root access."
  exit 1
fi

mkdir -p "$WALLBASH_ALWAYS_DIR"
mkdir -p "$WALLBASH_SCRIPTS_DIR"

echo "Creating or overwriting $NETFLIX_DCOL..."
cat > "$NETFLIX_DCOL" << 'EOF'
${XDG_CACHE_HOME}/hyde/wallbash/netflix.css|${WALLBASH_SCRIPTS}/netflix.sh
.bd.dark-background {
  background: <wallbash_pry1> !important;
}
h1, h2, h3, p, a, .title, .button, span, .text, .label {
  color: <wallbash_txt1> !important;
}
EOF

echo "Creating or overwriting $NETFLIX_SH..."
cat > "$NETFLIX_SH" << 'EOF'
#!/usr/bin/env bash
# Optional: Copy netflix.css for debugging or fallback
netflix_css="${XDG_CACHE_HOME}/hyde/wallbash/netflix.css"
if [[ -f "${netflix_css}" ]]; then
  cp "${netflix_css}" "${HOME}/.cache/hyde/wallbash/netflix-current.css"
fi
EOF
chmod +x "$NETFLIX_SH"

if [[ -f "$MAIN_JS" ]]; then
  echo "Backing up $MAIN_JS to $MAIN_JS_BACKUP..."
  sudo cp "$MAIN_JS" "$MAIN_JS_BACKUP"
fi

echo "Updating $MAIN_JS..."
sudo tee "$MAIN_JS" > /dev/null << 'EOF'
const { app, components, BrowserWindow, shell, globalShortcut } = require('electron');
const path = require('path');
const fs = require('fs');
const https = require('https');

// Dynamically import electron-context-menu (default export)
import('electron-context-menu').then((contextMenuModule) => {
  const contextMenu = contextMenuModule.default;

  contextMenu({
    prepend: (defaultActions, parameters, browserWindow) => [
      {
        label: 'Search Google for “{selection}”',
        visible: parameters.selectionText.trim().length > 0,
        click: () => {
          shell.openExternal(`https://google.com/search?q=${encodeURIComponent(parameters.selectionText)}`);
        }
      }
    ]
  });
});

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 1360,
    height: 765,
    icon: __dirname + '/icon.png',
    backgroundColor: '#ffffff',
    webPreferences: {
      contextIsolation: true,
      preload: path.join(app.getAppPath(), 'preload.js')
    }
  });

  // Function to read and apply colors
  function applyColors() {
    let bgColor = '#ffffff'; // Default background color
    let textColor = '#000000'; // Default text color
    const colorsFile = '/home/kot/.config/hypr/themes/colors.conf';
    try {
      if (!fs.existsSync(colorsFile)) {
        console.error(`Colors file does not exist: ${colorsFile}`);
      } else {
        const colorsContent = fs.readFileSync(colorsFile, 'utf8');
        console.log(`Reading colors from: ${colorsFile}`);
        // Extract wallbash_pry1 for background
        const pryMatch = colorsContent.match(/\$wallbash_pry1\s*=\s*([0-9a-fA-F]{6})/);
        if (pryMatch) {
          bgColor = `#${pryMatch[1]}`;
          console.log(`Background color set to: ${bgColor}`);
        } else {
          console.error('wallbash_pry1 not found in colors.conf');
        }
        // Extract wallbash_txt1 for text
        const txtMatch = colorsContent.match(/\$wallbash_txt1\s*=\s*([0-9a-fA-F]{6})/);
        if (txtMatch) {
          textColor = `#${txtMatch[1]}`;
          console.log(`Text color set to: ${textColor}`);
        } else {
          console.error('wallbash_txt1 not found in colors.conf');
        }
      }
    } catch (err) {
      console.error('Error reading Wallbash colors:', err);
    }

    // Apply CSS to Netflix
    mainWindow.webContents.insertCSS(`
      .bd.dark-background {
        background: ${bgColor} !important;
      }
      h1, h2, h3, p, a, .title, .button, span, .text, .label {
        color: ${textColor} !important;
      }
    `);
  }

  // Load the splash screen
  mainWindow.loadFile('splash.html');

  // Load Netflix website after 3 seconds and apply initial colors
  setTimeout(() => {
    mainWindow.loadURL('https://www.netflix.com/browse');
    mainWindow.webContents.on('did-finish-load', () => {
      applyColors(); // Initial color application

      // Watch colors.conf for changes
      fs.watch('/home/kot/.config/hypr/themes/colors.conf', (eventType, filename) => {
        if (eventType === 'change') {
          console.log(`Detected change in colors.conf, updating colors...`);
          applyColors();
        }
      });
    });
  }, 3000);

  mainWindow.maximize();
  mainWindow.setMenuBarVisibility(false);
  mainWindow.setMenu(null);
  mainWindow.show();
}

app.whenReady().then(async () => {
  await components.whenReady();
  console.log('components ready:', components.status());
  createWindow();
});

// Quit when all windows are closed
app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', function () {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

// Unregister global shortcuts when the app quits
app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});
EOF

echo "Verifying created files..."
ls -l "$NETFLIX_DCOL"
ls -l "$NETFLIX_SH"
sudo ls -l "$MAIN_JS"

echo "Setup complete! Please test the Netflix app and wallpaper changes."
echo "To test, run: netflix"
echo "To change wallpaper: ~/.config/hyde/scripts/swwwallbash.sh /path/to/wallpaper.png"
