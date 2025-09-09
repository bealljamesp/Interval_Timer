// preload.js
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopWakeLock', {
  start: () => ipcRenderer.invoke('wake-lock:start'),
  stop: () => ipcRenderer.invoke('wake-lock:stop'),
});