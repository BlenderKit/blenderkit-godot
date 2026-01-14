#!/usr/bin/env python3
import argparse
import configparser
import os
import re
import shutil
import subprocess
import sys


PLUGIN_SRC_DIR = "addons"
PLUGIN_DIR = "blenderkit"
CLIENT_DIR = "BlenderKit"
RESULT_DIR = "out"
ARCHIVE_BASE_NAME = "blenderkit-godot"


def build_all(client_dir=CLIENT_DIR, result_dir=RESULT_DIR):
    """Build BlenderKit Client and Plugin."""
    build_client(client_dir=client_dir)
    build_plugin(client_dir=client_dir, result_dir=result_dir)


def get_client_src():
    print("# Getting BlenderKit Client sources")
    if os.path.exists(CLIENT_DIR):
        print(f"Client Repo exists at {CLIENT_DIR}, updating...")
        subprocess.run(
            ["git", "-C", CLIENT_DIR, "pull"],
            check=True,
        )
    else:
        print(f"Cloning Client Repo to {CLIENT_DIR}...")
        subprocess.run(
            ["git", "clone", "https://github.com/BlenderKit/BlenderKit.git"],
            check=True,
        )


def build_client(client_dir=CLIENT_DIR):
    if client_dir == CLIENT_DIR:
        get_client_src()
    print("# Building BlenderKit Client with GO")
    subprocess.run(
        ["python3", "dev.py", "build"],
        cwd=client_dir,
        check=True,
    )


def copy_client_binaries(binaries_path: str, result_dir=RESULT_DIR):
    print(f"Copying Client binaries: {binaries_path} -> {result_dir}")
    if not os.path.exists(binaries_path):
        print(f"Client binaries path {binaries_path} does not exist, exiting.")
        exit(1)
    if not os.path.isdir(binaries_path):
        print(f"Client binaries path {binaries_path} is not a directory, exiting.")
        exit(1)

    client_version = os.path.basename(os.path.normpath(binaries_path))
    target_dir = os.path.join(result_dir, "client", client_version)
    os.makedirs(target_dir, exist_ok=True)

    files = os.listdir(binaries_path)
    if not files:
        print(f"No Client binaries found in {binaries_path}, exiting.")
        exit(1)

    client_files = [f for f in files if f.startswith("blenderkit-client")]
    for file_name in client_files:
        source_file = os.path.join(binaries_path, file_name)
        target_file = os.path.join(target_dir, file_name)
        shutil.copy2(source_file, target_file)
        print(f"Copied: {target_file}")

    print(
        f"{len(files)} BlenderKit-Client {client_version} binaries copied: {binaries_path} -> {target_dir}"
    )


def build_plugin(client_dir=CLIENT_DIR, result_dir=RESULT_DIR):
    print("# Building BlenderKit Plugin")

    plugin_out_dir = os.path.join(result_dir, PLUGIN_SRC_DIR)
    plugin_version = get_plugin_version()
    plugin_client_dir = os.path.join(plugin_out_dir, PLUGIN_DIR)
    client_bin_dir = find_client_bin_dir(client_dir)
    client_version = os.path.basename(os.path.normpath(client_bin_dir))
    archive_base_name = get_archive_base_name(plugin_version)
    archive_base_path = os.path.join(result_dir, archive_base_name)
    archive_path = archive_base_path + ".zip"

    print(f"Plugin dir: {PLUGIN_SRC_DIR}")
    print(f"Plugin version: {plugin_version}")
    print(f"Client dir: {client_dir}")
    print(f"Client binaries dir: {client_bin_dir}")
    print(f"Client version: {client_version[1:]}")
    print(f"Result dir: {result_dir}")
    print()

    os.makedirs(result_dir, exist_ok=True)
    shutil.rmtree(plugin_out_dir, ignore_errors=True)

    print(f"Copying Plugin sources: {PLUGIN_SRC_DIR} -> {plugin_out_dir}")
    shutil.copytree(PLUGIN_SRC_DIR, plugin_out_dir)

    copy_client_binaries(client_bin_dir, plugin_client_dir)

    print(f"Creating ZIP archive: {archive_path}")
    real_archive_path = shutil.make_archive(
        archive_base_path, "zip", result_dir, PLUGIN_SRC_DIR
    )
    if os.path.abspath(archive_path) != os.path.abspath(real_archive_path):
        raise RuntimeError(
            f"Archive path mismatch: expected {archive_path}, got {real_archive_path}"
        )

    print(f"✓ BlenderKit Godot plugin build DONE \\o/")
    print(f"Plugin files:  {plugin_out_dir}")
    print(f"ZIP archive:   {archive_path}")


def find_client_bin_dir(client_dir=CLIENT_DIR):
    base_dir = os.path.join(client_dir, "out", "blenderkit", "client")
    dirs = [
        d
        for d in os.listdir(base_dir)
        if d.startswith("v") and os.path.isdir(os.path.join(base_dir, d))
    ]
    if not dirs:
        raise FileNotFoundError(f"No client binaries found in {base_dir}")
    # sort desc in unlikely case there are multiple versions
    dirs.sort(reverse=True)
    return os.path.join(base_dir, dirs[0])


def get_archive_base_name(version: str) -> str:
    return f"{ARCHIVE_BASE_NAME}_v{version}"


def get_plugin_version() -> str:
    config_path = os.path.join(PLUGIN_SRC_DIR, "blenderkit", "plugin.cfg")
    config = configparser.ConfigParser()
    config.read(config_path)
    return config.get("plugin", "version").strip('"')


def set_plugin_version(version: str):
    config_path = os.path.join(PLUGIN_SRC_DIR, "blenderkit", "plugin.cfg")
    version = version.lstrip("v")
    print(f"# Setting version to {version} in {config_path}")

    with open(config_path, "r") as f:
        content = f.read()

    new_content = re.sub(
        r'^(version=)"[^"]*"', rf'\1"{version}"', content, flags=re.MULTILINE
    )

    with open(config_path, "w") as f:
        f.write(new_content)

    print(f"✓ Plugin version set to {version}")


### Command-Line Interface


# Show default argument values
class NiceHelpFormatter(
    argparse.RawTextHelpFormatter, argparse.ArgumentDefaultsHelpFormatter
):
    pass


parser = argparse.ArgumentParser(
    formatter_class=NiceHelpFormatter,
)
subparsers = parser.add_subparsers(
    title="commands",
    dest="command",
    help="Available commands",
)

# COMMAND: build
parser_build = subparsers.add_parser(
    "build",
    help="Build BlenderKit Godot Plugin including Client build.",
    description="Build BlenderKit Godot Plugin including Client build.",
    formatter_class=NiceHelpFormatter,
)
parser_build.set_defaults(func=build_all)

# COMMAND: get-client-src
parser_build = subparsers.add_parser(
    "get-client-src",
    help="Get BlenderKit Client sources.",
    description="Get BlenderKit Client sources.",
    formatter_class=NiceHelpFormatter,
)
parser_build.set_defaults(func=get_client_src)

# COMMAND: build-client
parser_build_client = subparsers.add_parser(
    "build-client",
    help="Build BlenderKit Client with GO.",
    description="Build BlenderKit Client with GO in-place.",
    formatter_class=NiceHelpFormatter,
)
parser_build_client.set_defaults(func=build_client)
parser_build_client.add_argument(
    "-c",
    "--client-dir",
    type=str,
    default=CLIENT_DIR,
    help="Path to BlenderKit Client sources.",
)

# COMMAND: build-plugin
parser_build_plugin = subparsers.add_parser(
    "build-plugin",
    help="Build BlenderKit Godot Plugin with existing Client.",
    description="Build BlenderKit Godot Plugin with existing Client.",
    formatter_class=NiceHelpFormatter,
)
parser_build_plugin.set_defaults(func=build_plugin)
parser_build_plugin.add_argument(
    "-c",
    "--client-dir",
    type=str,
    default=CLIENT_DIR,
    help="Path to BlenderKit Client sources.",
)
parser_build_plugin.add_argument(
    "-o",
    "--result-dir",
    type=str,
    default=RESULT_DIR,
    help="Path to BlenderKit Client sources.",
)

# COMMAND: set-version
parser_set_version = subparsers.add_parser(
    "set-version",
    help="Set the plugin version in plugin.cfg.",
    description="Set the plugin version in plugin.cfg.",
    formatter_class=NiceHelpFormatter,
)
parser_set_version.set_defaults(func=set_plugin_version)
parser_set_version.add_argument(
    "version",
    type=str,
    help="Version string (e.g., 1.2.3 or v1.2.3).",
)


def main():
    args = parser.parse_args()

    if args.command is None:
        # Print help when no command is given for convenience
        parser.print_help()
        sys.exit(1)

    # Process args to pass to command function
    kwargs = dict(vars(args))
    kwargs.pop("command")
    kwargs.pop("func")
    # Invoke function associated with the chosen command
    args.func(**kwargs)


if __name__ == "__main__":
    main()
