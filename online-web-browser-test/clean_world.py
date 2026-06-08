import re

filepath = r"c:\Users\fedef\Documents\GitHub\Online Web Browser test\online-web-browser-test\scenes\LevelScenes\World.tscn"

with open(filepath, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
removed_count = 0

for line in lines:
    if re.match(r'^surface_material_override/\d+\s*=\s*null', line.strip()):
        removed_count += 1
        continue
    new_lines.append(line)

with open(filepath, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print(f"Successfully removed {removed_count} null material overrides from World.tscn!")
