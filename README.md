# BlenderKit for Godot

Simple yet effective [Godot Engine](https://godotengine.org/) 4 editor plugin
which enables direct import of assets from
[BlenderKit](https://blenderkit.com) into a Godot project.

Add this BlenderKit add-on to your Godot project and then just select models /
materials you need in the [BlenderKit.com](https://blenderkit.com) online
gallery in your browser and send them directly into your Godot project with a
single click on the **Send to Godot** button.

Assets get downloaded into a directory of your choice in your Godot project,
`bk_assets/` by default.

You can process assets as you see fit, possibly building your own workflow /
pipeline on top of this simple mechanism.

This project is Free and Open Source Software under GPLv2.

[Contributions](#contributing) are highly encouraged and welcome 🤝

⭐ Star this repo to show support and interest in continued development, thanks!


## Status

### alpha

BlenderKit Godot plugin is in **active early development** focusing on polishing
fundamentals (building, testing, integration) in order to provide a robust
user and developer experience, including distribution and installation.

As of now, please consider this software **experimental** 🧪

It's a great time to test and [contribute](#contributing) so that the
plugin is useful for you and everyone else.

**IMPORTANT:** Godot Blender imports are relatively young and many `.blend` files can
import incorrectly or not import at all with ample amount of warnings and errors
printed to Godot Output. As of Godot 4.5.1, Blender 3 is required while Blender
5 has been out for some time.

This plugin will get increasingly useful as native Blender -> Godot import
improves.

Alongside this upstream effort, we at [BlenderKit](https://blenderkit.com) are
experimenting with our own **GLTF** export as it's Godot's intended default
import format where highest degree of compatibility should be expected.

Once **GLTF** export support matures, the BlenderKit plugin might provide an option to
prefer `.gltf` / `.glb` over `.blend`, possibly on by default.


## Requirements

BlenderKit Godot Plugin requires:

- Godot Engine: **4.X**
- OS: **Linux**, **MacOS**, **Windows**
- Architectures: **x86_64**, **arm64**
- Web browser
- [BlenderKit.com](https://blenderkit.com) account (free, no payment or credit card required)


## Installation

The Plugin needs to be installed for each Godot project:

1. **Download** `blenderkit-godot-vX.Y.Z.zip` from [GitHub Releases](https://github.com/BlenderKit/blenderkit-godot/releases)
    - or [build](#building) your own from sources.
2. **Extract** the ZIP into your Godot project root directory (where `project.godot` is located)
    - **DO NOT** copy `addons/` or `addons/blenderkit/` from this repo without
    [building](#building) Client binaries first.
3. Open your project in **Godot Editor**, go to **Project → Project Settings... → Plugins** tab
4. Check **Enabled** for **BlenderKit**

If installation succeeded, you should see a new **BlenderKit** tab in the right
panel dock (next to **Inspector**) as well as `BlenderKit:` messages in editor
Output.


## Usage

After BlenderKit Godot plugin is installed and enabled in your Godot project,
you should see a new **BlenderKit** tab in the right panel dock (next to
**Inspector**) of the Godot Editor.

You need to login to [BlenderKit.com](https://blenderkit.com) in a web browser.
Free and Paid plans are supported. You don't need a credit card to get free
assets, but you can access paid assets should you decide to support artists.

You can now browse assets from [BlenderKit.com](https://blenderkit.com) in your
browser and download them into your Godot project with a single click on the **Send
to Godot** button right on the asset page.

For example after downloading two models and one material:

```
bk_assets
├── material
│   └── resolution_4K_dbec842e-9f6e-43c8-ace4-9f815d3bd997.blend
└── model
    ├── resolution_2K_af103cc0-ffb5-46f1-b877-9a72b71d8c59.blend
    └── resolution_4K_d110f837-ae04-4fee-b287-a7110ac44be4.blend
```

Better naming and even converting to Godot native formats might get implemented
in the future, but for now we're focusing on the foundation - one click
to get an asset into your Godot project reliably.


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


## Development

This repository is set up as a Godot project, so you can open it directly in
Godot Editor for development and testing.

1. Clone this repository
2. Build (fetches client sources and builds everything):
   ```sh
   ./dev.py build
   ```
3. Open the project in Godot Editor
4. Make changes to the plugin in `addons/blenderkit/`
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

This project is Free and Open Source Software under GPLv2.

**Contributions are highly encouraged and welcome 🤝**

If you hit a bug or you wish something worked better, simply open a GitHub
[Issue](https://github.com/BlenderKit/blenderkit-godot/issues).

The better you describe the problem, the easier it will be to fix.
