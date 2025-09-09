# 12‑Round Boxing Timer — PWA + Electron
- Open `index.html` over HTTPS or localhost to use as a PWA. Install via browser menu.
- Register service worker is already included.
- Electron desktop: `npm install` then `npm start`.

Android install tips:
- Host these files on HTTPS (GitHub Pages / Netlify / Vercel).
- Visit the URL on Android Chrome → use ⋮ → Install app / Add to Home screen.

🔄 The Workflow

Edit files locally

index.html, service-worker.js, manifest.json → affect your PWA/mobile build.

package.json, main.js, preload.js, build/icon.ico → affect your Electron/desktop build.

Shared files (like icons, license, README) are common to both.

Test locally

PWA: open index.html in a browser.

Desktop: run npm start to launch Electron, or rebuild with npm run dist.

Commit & push to GitHub

git add .
git commit -m "Describe the change"
git push


That saves the exact change history in GitHub.
GitHub is now the “source of truth.” You can always pull the repo onto another computer and rebuild.

⚡ How updates flow to devices

Desktop app:
Every time you rebuild (npm run dist), you get a fresh Setup.exe. That installer packages whatever is in your repo at that moment.

PWA / Pixel:
Every time you bump CACHE_VERSION in service-worker.js, your phone sees it as a “new release.”
The SW fetches fresh files, installs, and then activates on the next reload.
That’s why we bumped to v10 — you can treat it like a release version.

🛠️ Things you should know

.gitignore
You already have one. It prevents heavy/generated files (node_modules, dist, etc.) from being uploaded to GitHub. That’s correct — those can always be rebuilt.

Branching (optional, later)
If you want to experiment, you can make a dev branch:

git checkout -b dev


Make changes, test, then merge back into main. For now, sticking with main is totally fine.

Versioning discipline

Bump APP_VERSION for human-readable UI changes.

Bump CACHE_VERSION so PWAs refresh.

Bump package.json → version when you want to cut a new desktop installer.

Rebuilding locally after pull
If you clone the repo on another PC:

npm install
npm start        # test
npm run dist     # rebuild installer


That recreates node_modules and dist that are intentionally not in GitHub.

Daily flow

Edit → Test → Commit → Push → (Re)Install or Reload

# 1) Make sure you’re in the repo folder
cd "C:\Users\beall\OneDrive\Documents\Exercise\Boxing\Timer"

# 2) Pull latest before you start (stay in sync)
git pull origin main

# 3) Do your edits (index.html, service-worker.js, etc.)

# 4) Stage & commit
git add .
git commit -m "Describe what changed"

# 5) Push to GitHub
git push

PWA (Android/Chrome) release

Bump the visible app version (optional but nice):

// index.html
const APP_VERSION = "v11";   // whatever’s next


Must bump the SW cache to force update:

// service-worker.js
const CACHE_VERSION = 'v11';


Commit & push (see daily flow).

On the phone: open app → Reload once → close → reopen from home screen.

If stubborn: Chrome → Site settings for your URL → Clear storage → reload online.

Desktop (Windows/Electron) release

Optional: bump installer version:

// package.json
"version": "1.0.11"


Build:

npm install
npm run dist


Find installers in dist\:

Boxing Timer Setup x.y.z.exe → shows installer UI (creates Start Menu/Desktop shortcuts)

win-unpacked\Boxing Timer.exe → portable, no install

Quick Testing
# PWA: just open index.html in Chrome
# Electron app (dev)
npm.cmd start

Common files & what they do

index.html — UI/logic (works for both PWA & Electron)

service-worker.js — offline + update rules (PWA)

manifest.json — PWA install metadata

package.json — Electron app config & build scripts

main.js (+ optional preload.js) — Electron main process

build/icon.ico — installer/app icon (Electron)

icon-192.png, icon-512.png — PWA icons

Versioning: when to bump what

PWA update: bump CACHE_VERSION (required), bump APP_VERSION (optional/visible).

Desktop installer: bump "version" in package.json, then npm run dist.

New machine setup (clone & run)
cd "C:\where\you\want"
git clone https://github.com/bealljamesp/Timer.git
cd .\Timer
npm install
npm start           # run dev Electron
npm run dist        # make installer

Handy Git tricks
git status                          # what changed?
git restore --staged .              # unstage if needed
git checkout -- .                   # discard local changes (careful)
git log --oneline --graph --decorate --all
git reset --hard origin/main        # hard reset to remote (careful)

Windows quirks & fixes

PowerShell blocks npm/npx scripts: use npm.cmd ... (you already are).

CRLF warnings (harmless). To silence:

git config core.autocrlf true


OneDrive lock errors: if a file refuses to delete, close apps (incl. AV/preview), then:

git clean -fd          # remove untracked, no ignores
git clean -fdx         # remove EVERYTHING untracked (careful)

PWA “it won’t update!” checklist

Did you bump CACHE_VERSION in service-worker.js?

Reload once online; then fully close & reopen.

If still stale: Chrome → Site settings → Storage → Clear → Reload.

Make sure manifest.json has your correct start_url/scope for where it’s hosted.

Electron “no .exe” checklist

devDependencies include "electron" and "electron-builder".

package.json has a build section with "win": { "target": ["nsis","portable"] }.

Use Admin PowerShell if you ever see symlink/code-sign cache errors during build.

What to commit vs. ignore

✅ Commit: source files (html/js/json), build/icon.ico, docs, license.

🚫 Ignore (already in .gitignore): node_modules/, dist/, win-unpacked/, logs, OS junk.

Bump commands - 
	powershell -ExecutionPolicy Bypass -File .\bump-version.ps1 -NewVersion v11
	or
	Set-ExecutionPolicy -Scope Process Bypass
	.\bump-version.ps1 -NewVersion v11

	git add .
	git commit -m "Bump version to v11"
	git push
