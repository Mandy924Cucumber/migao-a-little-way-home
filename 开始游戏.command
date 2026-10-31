#!/bin/zsh
cd -- "${0:A:h}"
for godot_binary in "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" "/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$godot_binary" ]]; then
    exec "$godot_binary" --path "$PWD"
  fi
done
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD"
fi
print '未找到 Godot。请用 Godot 4 导入这个文件夹中的 project.godot，然后按 F5。'
read -k 1 '?按任意键退出…'
