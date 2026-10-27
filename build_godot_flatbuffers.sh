#/bin/bash

set -e

git clone --recursive https://github.com/enetheru/godot-flatbuffers.git godot_flatbuffers || echo "Repo already exists, continuing..."

cd godot_flatbuffers
#git reset --hard
mkdir build || echo "Build folder already exists"
cd build

cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DGODOTCPP_TARGET:STRING=editor -DGODOT_PROJECT_PATH=../../ ..
ninja install
