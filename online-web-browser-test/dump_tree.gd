extends SceneTree
func _init():
    var main = load("res://scenes/Networking scenes/main.tscn").instantiate()
    print("CHILDREN IN SpawnedObjects:")
    var so = main.get_node("SpawnedObjects")
    for c in so.get_children():
        print(c.name)
    quit()

