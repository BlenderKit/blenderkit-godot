# Copyright (C) 2024 BlenderKit
#
# ##### BEGIN GPL LICENSE BLOCK #####
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software Foundation,
#  Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# ##### END GPL LICENSE BLOCK #####

import argparse
import os
import shutil


def copy_client_binaries(binaries_path: str, addon_build_dir: str):
    if not os.path.exists(binaries_path):
        print(f"Client binaries path {binaries_path} does not exist, exiting.")
        exit(1)
    if not os.path.isdir(binaries_path):
        print(f"Client binaries path {binaries_path} is not a directory, exiting.")
        exit(1)

    client_version = os.path.basename(os.path.normpath(binaries_path))
    target_dir = os.path.join(addon_build_dir, "client", client_version)
    os.makedirs(target_dir)

    files = os.listdir(binaries_path)
    client_files = [f for f in files if f.startswith("blenderkit-client")]
    for file_name in client_files:
        source_file = os.path.join(binaries_path, file_name)
        target_file = os.path.join(target_dir, file_name)
        shutil.copy2(source_file, target_file)
        print(f"Copied {source_file} to {target_file}")

    print(f"BlenderKit-Client {client_version} binaries copied from {binaries_path} to {target_dir}")


def do_build(client_binaries_path: str, install_at: str="", clean_dir: str=""):
    """Build the plugin by copying relevant files to ./out/blenderkit directory. Create zip in ./out/blenderkit-godot.zip.
    - client_binaries_path: select directory (e.g. v1.2.1) containing Client (signed) binaries for all platforms
    - install_at: also copy the build to install location if specified, e.g. godot-project/addons/blenderkit directory.
    - include_tests: include test files into .zip file, so tests can be run with this .zip
    - clean_dir: if specified, clean that directory before building the add-on, e.g. clean client bin in blenderkit_data: "/Users/username/blenderkit_data/client/bin"
    """

    out_dir = os.path.abspath("out")
    addon_build_dir = os.path.join(out_dir, "blenderkit")
    shutil.rmtree(out_dir, True)

    copy_client_binaries(client_binaries_path, addon_build_dir)

    ignore_files = [
        ".gitignore",
        "dev.py",
        "README.md",
        ".DS_Store",
        ".mypy_cache"
    ]

    for item in os.listdir():
        if os.path.isdir(item):
            continue  # if needed, use shutil.copytree() before this loop
        if item in ignore_files:
            continue
        shutil.copy(item, f"{addon_build_dir}/{item}")

    # CREATE ZIP
    print("Creating ZIP archive.")
    shutil.make_archive("out/blenderkit", "zip", "out", "blenderkit")

    if install_at is not None:
        print(f"Copying to {install_at}/blenderkit")
        shutil.rmtree(f"{install_at}/blenderkit", ignore_errors=True)
        shutil.copytree("out/blenderkit", f"{install_at}/blenderkit")
    if clean_dir is not None:
        print(f"Cleaning directory {clean_dir}")
        shutil.rmtree(clean_dir, ignore_errors=True)

    print("BlenderKit Godot plugin build DONE!")


### COMMAND LINE INTERFACE

parser = argparse.ArgumentParser()
parser.add_argument(
    "command",
    default="build",
    choices=["build"],
    help="""
  BUILD = copy relevant files into ./out/blenderkit.
  """,
)
parser.add_argument(
    "--install-at",
    type=str,
    default=None,
    help="If path is specified, then builded addon will be also copied to that location.",
)
parser.add_argument(
    "--clean-dir",
    type=str,
    default=None,
    help="Specify path to global_dir/client/bin or other dir which should be cleaned.",
)
parser.add_argument(
    "--client-build",
    type=str,
    default=None,
    help="Specify path client_builds/vX.Y.Z. Binaries in this directory will be used instead of building new ones.",
)
args = parser.parse_args()

if args.command == "build":
    do_build(
        client_binaries_path=args.client_build,
        install_at=args.install_at,
        clean_dir=args.clean_dir,
    )
else:
    parser.print_help()
