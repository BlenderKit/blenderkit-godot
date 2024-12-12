# BlenderKit for Godot

Simple yet effective add-on which enables direct import of models from BlenderKit.com into a Godot project.
Add the add-on and then just select the models you need in the BlenderKit.com online gallery and send them directly into your Godot project.


## Developing

1. Clone this repository somewhere outside Godot project.
2. Make the changes needed.
3. Build the plugin with command: `python dev.py --client-build <path-to-client-build-directory> --install-at <path-to-godot-project-for-testing>`, e.g.: `python dev.py --client-build /Users/ag/devel/blenderkit/blenderkit/out/blenderkit/client/v1.2.1 --install-at /Users/ag/devel/blenderkit/BKit-Godot/addons`
4. Start Godot/Reload the plugin in running Godot instance
5. .zip file for distribution is located in `./out/blenderkit.zip`
