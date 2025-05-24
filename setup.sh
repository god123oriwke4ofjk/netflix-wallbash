#!/usr/bin/env bash

# Script to set up Netflix theming with Wallbash 
# Creates or overwrites netflix.dcol, netflix.sh, and updates main.js
# With -remove, reverts all changes to restore fresh Netflix state

set -e

WALLBASH_ALWAYS_DIR="$HOME/.config/hyde/wallbash/always"
WALLBASH_SCRIPTS_DIR="$HOME/.config/hyde/wallbash/scripts"
NETFLIX_DCOL="$WALLBASH_ALWAYS_DIR/netflix.dcol"
NETFLIX_SH="$WALLBASH_SCRIPTS_DIR/netflix.sh"
NETFLIX_CSS="$HOME/.cache/hyde/wallbash/netflix-current.css"
MAIN_JS="/opt/Netflix/main.js"
MAIN_JS_BACKUP="/opt/Netflix/main.js.bak"
COLORS_FILE="$HOME/.config/hypr/themes/colors.conf"
COLORS_DIR="$HOME/.config/hypr/themes"

if [[ "$1" == "-remove" ]]; then
  echo "Removing Netflix theming setup..."

  if [[ -f "$NETFLIX_DCOL" ]]; then
    echo "Removing $NETFLIX_DCOL..."
    rm "$NETFLIX_DCOL"
  else
    echo "$NETFLIX_DCOL does not exist, skipping..."
  fi

  if [[ -f "$NETFLIX_SH" ]]; then
    echo "Removing $NETFLIX_SH..."
    rm "$NETFLIX_SH"
  else
    echo "$NETFLIX_SH does not exist, skipping..."
  fi

  if [[ -f "$NETFLIX_CSS" ]]; then
    echo "Removing $NETFLIX_CSS..."
    rm "$NETFLIX_CSS"
  else
    echo "$NETFLIX_CSS does not exist, skipping..."
  fi

  if [[ -f "$MAIN_JS_BACKUP" ]]; then
    echo "Restoring $MAIN_JS from $MAIN_JS_BACKUP..."
    sudo mv "$MAIN_JS_BACKUP" "$MAIN_JS"
  else
    echo "$MAIN_JS_BACKUP does not exist, cannot restore main.js..."
  fi

  echo "Removal complete! Netflix setup has been reverted."
  exit 0
fi

if [[ $EUID -eq 0 ]]; then
  echo "This script should not be run as root. It will use sudo for operations requiring root access."
  exit 1
fi

mkdir -p "$WALLBASH_ALWAYS_DIR"
mkdir -p "$WALLBASH_SCRIPTS_DIR"
mkdir -p "$(dirname "$NETFLIX_CSS")"

echo "Creating or overwriting $NETFLIX_DCOL..."
cat > "$NETFLIX_DCOL" << 'EOF'
${HOME}/.cache/hyde/wallbash/netflix.css|${WALLBASH_SCRIPTS}/netflix.sh
.bd.dark-background, .profile-gate, .mainView, .account-section, .profile-gate-container, .main-header, .list-profiles-container, .service-page, .global-header.light-theme, .global-page-footer, .global-page-footer.light-theme, .container.search-focus, .search-intro.container, .global-content, .page-home-redesign .global-content, .manage-profiles, .profile-management, .js-focus-visible body, body, html, [style*="position: fixed"], [style*="position: sticky"] {
  background: <wallbash_pry1> !important;
}
h1, h2, h3, p, a, .title, .button, span, .text, .label, .profile-name, .profile-link, .choose-profile, .nf-flat-button, .profile-icon, .profile-link-text, .global-header *, .global-page-footer *, .container.search-focus *, .global-content *, .manage-profiles *, .profile-management * {
  color: <wallbash_txt1> !important;
}
::selection {
  background: <wallbash_pry1> !important;
  color: <wallbash_txt1> !important;
}
EOF

echo "Creating or overwriting $NETFLIX_SH..."
cat > "$NETFLIX_SH" << 'EOF'
#!/usr/bin/env bash
netflix_css="${HOME}/.cache/hyde/wallbash/netflix.css"
netflix_current_css="${HOME}/.cache/hyde/wallbash/netflix-current.css"
if [[ -f "${netflix_css}" ]]; then
  cp "${netflix_css}" "${netflix_current_css}"
  echo "Copied ${netflix_css} to ${netflix_current_css} for debugging"
else
  echo "Error: ${netflix_css} not found"
fi
EOF
chmod +x "$NETFLIX_SH"

if [[ -f "$MAIN_JS" ]]; then
  echo "Backing up $MAIN_JS to $MAIN_JS_BACKUP..."
  sudo cp "$MAIN_JS" "$MAIN_JS_BACKUP"
else
  echo "Warning: $MAIN_JS not found, creating new file..."
fi

echo "Updating $MAIN_JS..."
sudo tee "$MAIN_JS" > /dev/null << 'EOF'
const { app, components, BrowserWindow, shell, globalShortcut } = require('electron');
const path = require('path');
const fs = require('fs');
const https = require('https');
const os = require('os');

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

  function applyColors(isSplash = false) {
    let bgColor = '#ffffff'; // Default background color
    let textColor = '#000000'; // Default text color
    const colorsFile = path.join(os.homedir(), '.config', 'hypr', 'themes', 'colors.conf');
    try {
      if (!fs.existsSync(colorsFile)) {
        console.error(`Colors file does not exist: ${colorsFile}`);
      } else {
        const colorsContent = fs.readFileSync(colorsFile, 'utf8');
        console.log(`Reading colors from: ${colorsFile}`);
        const pryMatch = colorsContent.match(/\$wallbash_pry1\s*=\s*(?:0x|#)?([0-9a-fA-F]{6})/);
        if (pryMatch) {
          bgColor = `#${pryMatch[1]}`;
          console.log(`Background color set to: ${bgColor}`);
        } else {
          console.error('wallbash_pry1 not found or invalid in colors.conf');
        }
        const txtMatch = colorsContent.match(/\$wallbash_txt1\s*=\s*(?:0x|#)?([0-9a-fA-F]{6})/);
        if (txtMatch) {
          textColor = `#${txtMatch[1]}`;
          console.log(`Text color set to: ${textColor}`);
        } else {
          console.error('wallbash_txt1 not found or invalid in colors.conf');
        }
      }
    } catch (err) {
      console.error('Error reading Wallbash colors:', err);
    }

    if (isSplash) {
      mainWindow.webContents.insertCSS(`
        body {
          background: ${bgColor} !important;
        }
        .dot-pulse, .dot-pulse::before, .dot-pulse::after {
          background-color: ${textColor} !important;
          color: ${textColor} !important;
        }
      `);
    } else {
      mainWindow.webContents.insertCSS(`
        .bd.dark-background, .profile-gate, .mainView, .account-section, .profile-gate-container, .main-header, .list-profiles-container, .service-page, .global-header.light-theme, .global-page-footer, .global-page-footer.light-theme, .container.search-focus, .search-intro.container, .global-content, .page-home-redesign .global-content, .manage-profiles, .profile-management, .js-focus-visible body, body, html, [style*="position: fixed"], [style*="position: sticky"] {
          background: ${bgColor} !important;
        }
        h1, h2, h3, p, a, .title, .button, span, .text, .label, .profile-name, .profile-link, .choose-profile, .nf-flat-button, .profile-icon, .profile-link-text, .global-header *, .global-page-footer *, .container.search-focus *, .global-content *, .manage-profiles *, .profile-management * {
          color: ${textColor} !important;
        }
        ::selection {
          background: ${bgColor} !important;
          color: ${textColor} !important;
        }
      `);
    }
  }

  mainWindow.loadFile('splash.html');
  mainWindow.webContents.on('did-finish-load', () => {
    applyColors(true); // Apply colors to splash screen
  });

  setTimeout(() => {
    mainWindow.loadURL('https://www.netflix.com/browse');
    mainWindow.webContents.on('did-finish-load', () => {
      applyColors(false); // Apply colors to Netflix

      const colorsDir = path.join(os.homedir(), '.config', 'hypr', 'themes');
      if (fs.existsSync(colorsDir)) {
        fs.watch(colorsDir, { persistent: true }, (eventType, filename) => {
          console.log(`Directory watch event: ${eventType}, filename: ${filename}`);
          if (filename === 'colors.conf' && fs.existsSync(colorsFile)) {
            console.log(`Detected ${eventType} for colors.conf, updating colors...`);
            applyColors(mainWindow.webContents.getURL().includes('splash.html'));
          }
        });
      } else {
        console.error(`Cannot watch ${colorsDir}: directory does not exist`);
      }
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

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', function () {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});
EOF

echo "Verifying created files..."
ls -l "$NETFLIX_DCOL" || echo "$NETFLIX_DCOL not found"
ls -l "$NETFLIX_SH" || echo "$NETFLIX_SH not found"
sudo ls -l "$MAIN_JS" || echo "$MAIN_JS not found"

if sudo grep -q "openDevTools" "$MAIN_JS"; then
  echo "Warning: $MAIN_JS contains openDevTools. Ensuring it is commented out..."
  sudo sed -i 's/mainWindow\.webContents\.openDevTools()/\/\/ mainWindow.webContents.openDevTools()/' "$MAIN_JS"
fi

if [[ -f "$COLORS_FILE" ]]; then
  for var in wallbash_pry1 wallbash_txt1; do
    if grep -q "$var" "$COLORS_FILE"; then
      echo "$var defined in colors.conf"
    else
      echo "Warning: $var not defined in colors.conf, may cause theming issues"
    fi
  done
fi

echo "To reload wallbash: hyprctl reload"
echo "To remove all changes: $0 -remove"
