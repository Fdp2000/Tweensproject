import re

def add_script_to_scene(filepath, script_path, ext_id='1_script'):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    ext_resource_str = f'[ext_resource type="Script" path="{script_path}" id="{ext_id}"]\n'
    
    match = list(re.finditer(r'\[ext_resource.*?\]\n', content))
    if match:
        last_match = match[-1]
        insert_pos = last_match.end()
        content = content[:insert_pos] + ext_resource_str + content[insert_pos:]
    else:
        insert_pos = content.find('\n') + 1
        content = content[:insert_pos] + '\n' + ext_resource_str + content[insert_pos:]

    node_match = re.search(r'\[node name=".*?" type=".*?".*?\]', content)
    if node_match:
        node_str = node_match.group(0)
        new_node_str = node_str[:-1] + f' script=ExtResource("{ext_id}")]'
        content = content.replace(node_str, new_node_str, 1)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

add_script_to_scene('c:/Users/fedef/Documents/GitHub/Online Web Browser test/online-web-browser-test/scenes/UIScenes/ShenaniganCop.tscn', 'res://scripts/UI/MenuWanderer.gd', '1_script')
add_script_to_scene('c:/Users/fedef/Documents/GitHub/Online Web Browser test/online-web-browser-test/scenes/UIScenes/ShenaniganThief.tscn', 'res://scripts/UI/MenuWanderer.gd', '1_script')
print("Done")
