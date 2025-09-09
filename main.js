// main.js
const { app, BrowserWindow, ipcMain, nativeTheme, powerSaveBlocker } = require('electron');
const path = require('path');

let mainWindow;
let psbId = null; // powerSaveBlocker id

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 820,
    minWidth: 900,
    minHeight: 700,
    backgroundColor: nativeTheme.shouldUseDarkColors ? '#0f172a' : '#111827',
    show: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),   // <<< add preload
      contextIsolation: true,
      sandbox: true
    }
  });

  mainWindow.loadFile('index.html');

  // Optional: open devtools if you want.
  // mainWindow.webContents.openDevTools();
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });

// ---------- WAKE LOCK (desktop) ----------
ipcMain.handle('wake-lock:start', () => {
  if (psbId !== null && powerSaveBlocker.isStarted(psbId)) return psbId;
  psbId = powerSaveBlocker.start('prevent-display-sleep');
  return psbId;
});

ipcMain.handle('wake-lock:stop', () => {
  if (psbId !== null) {
    try { powerSaveBlocker.stop(psbId); } catch {}
    psbId = null;
  }
  return true;
});
