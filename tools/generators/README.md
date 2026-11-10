# Generators (Python 3)

Scripts that (re)generate project files. Run from this folder with the project root as argument:

    python gen_materials.py ../..   # prefabs/materials/*.tres
    python gen_prefabs.py ../..     # prefabs/{nature,props,interiors,buildings}/*.tscn
    python gen_world.py ../..       # scenes/world/world.tscn (test map, built from prefabs)
    python gen_leaves.py            # leaf texture (needs Pillow)

Hand edits to generated files are overwritten when a generator runs again.
