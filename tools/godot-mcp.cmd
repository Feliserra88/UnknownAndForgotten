@echo off
REM Cursor on Windows often ignores mcp.json "env"; set GODOT_PATH here instead.
set "GODOT_PATH=C:\sw\Godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe"
set "PATH=C:\sw\nodejs\node-v26.4.0-win-x64;%PATH%"
set "DEBUG=true"
"C:\sw\nodejs\node-v26.4.0-win-x64\node.exe" "C:\Users\serranosf\AppData\Local\npm-cache\_npx\6e568f649a25892d\node_modules\@coding-solo\godot-mcp\build\index.js"
