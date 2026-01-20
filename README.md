# BlenderKit for Godot

Simple yet effective [Godot Engine](https://godotengine.org/) add-on / plugin
which enables direct import of models from
[BlenderKit.com](https://blenderkit.com) into a Godot project.

Add the BlenderKit add-on to your Godot project and then just select the models
you need in the [BlenderKit.com](https://blenderkit.com) online gallery and send
them directly into your Godot project with a single click on the asset page.

★ Star this repo to show support and interest in continued development, thanks.

## Requirements

BlenderKit Godot Plugin requires:

- Godot Engine: **4.X**
- OS: **Linux**, **MacOS**, **Windows**
- Architectures: **x86_64**, **arm64**

## Installation

The Plugin needs to be installed for each Godot project:

1. **Download** `blenderkit-godot-vX.Y.Z.zip` from [GitHub Releases](https://github.com/BlenderKit/blenderkit-godot/releases)
    - or [build](#Building) your own from sources.
2. **Extract** the ZIP into your Godot project root directory (where `project.godot` is located)
    - **DO NOT** copy `addons/` or `addons/blenderkit/` from the repo **wihtout building Client binaries** first. See [Building](#building).
3. Open your project in **Godot Editor**, go to **Project → Project Settings... → Plugins** tab
4. Check **Enabled** for **BlenderKit**

If installation succeeded, you should see a new **BlenderKit** tab in the right
panel dock (next to **Inspector**) as well as `BlenderKit:` messages in editor
Output.


## Usage

After BlenderKit Godot plugin is installed and enabled in your Godot project,
you should see a new **BlenderKit** tab in the right panel dock (next to
**Inspector**) of the Godot Editor.

You can now browse and download assets from
[blenderkit.com](https://blenderkit.com) in your browser and download them into your Godot project with a single click on the asset page.


## Directory Structure

- `addons/blenderkit/` - Godot plugin sources (standard Godot addon path)
- `BlenderKit/` - BlenderKit client sources (cloned from upstream repo)
- `tests/` - pytest test suite
- `out/` - Build output directory (generated)
- `project.godot` - Godot project file for development and testing


## Building

You need the following requirements:

- **Go** for building the BlenderKit Client
- **Python 3** for running the `dev.py` build script
- **git** for cloning the sources

Clone the repo and do a full build:

```sh
git clone https://github.com/BlenderKit/blenderkit-godot.git
cd blenderkit-godot
python dev.py build
```

This does the following:

- fetches [BlenderKit Client](https://github.com/BlenderKit/BlenderKit)
sources into `BlenderKit/` (`./dev.py get-client-src`)
- builds the BlenderKit Client using Go (`./dev.py build-client`)
- copies client binaries into the plugin directory (`./dev.py build-plugin`)
- creates a distributable ZIP archive (`./dev.py build-archive`)

The distributable ZIP will be at `out/blenderkit-godot_vX.Y.Z.zip`.

**DO NOT** copy the `addons/` or `addons/blenderkit/` directly from the repo,
those are just sources without the needed Client binaries.

## Development

This repository is set up as a Godot project, so you can open it directly in
Godot Editor for development and testing.

1. Clone this repository
2. Build (fetches client sources and builds everything):
   ```sh
   ./dev.py build
   ```
3. Open the project in Godot Editor
4. Make changes to plugin in `addons/blenderkit/`
5. Test your changes directly in the editor

Run `python dev.py` for a list of all available commands.

| Command | Description |
|---------|-------------|
| `build` | Full build: client + plugin + archive |
| `get-client-src` | Clone/update BlenderKit client repository |
| `build-client` | Build only the Go client |
| `build-plugin` | Copy client binaries into plugin directory |
| `build-archive` | Create filtered ZIP archive of the plugin |
| `clean` | Remove build artifacts (`out/` and client binaries) |
| `set-version` | Set plugin version in `plugin.cfg` |
| `test` | Run pytest tests |

Run `./dev.py <command> --help` for command-specific options.


## Testing

Run the test suite with:

```sh
./dev.py test
```

Tests use pytest with fixtures for running Godot in headless editor mode.
Use `-v` for verbose output or `-k <pattern>` to filter tests.


## Releasing

Releases are automated via GitHub Actions. To create a new release:

```sh
git tag v1.0.0
git push origin v1.0.0
```

This will:
1. Update the version in `plugin.cfg` to match the tag
2. Build the plugin with the BlenderKit client
3. Create a GitHub release with the ZIP attached

## Contributing

Contributions are most welcome! Feel free to open an Issue or submit a Pull Request or drop a comment <3
