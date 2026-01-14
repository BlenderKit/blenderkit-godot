# BlenderKit for Godot

Simple yet effective add-on which enables direct import of models from BlenderKit.com into a Godot project.
Add the add-on and then just select the models you need in the BlenderKit.com online gallery and send them directly into your Godot project.


## Directory Structure

- `addons/blenderkit/` - Godot plugin sources (standard Godot addon path)
- `BlenderKit/` - BlenderKit client sources (cloned from upstream repo)
- `out/` - Build output directory (generated)


## Building

Full build (fetches client sources, builds client, packages plugin):

```sh
./dev.py build
```

The distributable ZIP will be at `out/blenderkit-godot_vX.Y.Z.zip`.


## Development

1. Clone this repository
2. Get the BlenderKit client sources:
   ```sh
   ./dev.py get-client-src
   ```
3. Make changes to plugin in `addons/blenderkit/`
4. Build and test:
   ```sh
   ./dev.py build
   ```
5. Copy `out/addons/blenderkit/` to your Godot project's `addons/` directory

### Available Commands

| Command | Description |
|---------|-------------|
| `build` | Full build: client + plugin |
| `get-client-src` | Clone/update BlenderKit client repository |
| `build-client` | Build only the Go client |
| `build-plugin` | Package plugin with existing client binaries |

Run `./dev.py <command> --help` for command-specific options.
