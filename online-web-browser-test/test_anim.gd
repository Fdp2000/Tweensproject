extends SceneTree
func _init():
    var scene = load("res://scenes/UIScenes/ShenaniganCop.tscn")
    var inst = scene.instantiate()
    var ap = inst.find_child("AnimationPlayer", true, false)
    if ap:
        print("ANIMATIONS: ", ap.get_animation_list())
    else:
        print("NO ANIMATION PLAYER FOUND")
    quit()
