#!/usr/bin/env sh
# Bake squircle.frag into squircle.frag.qsb.
#
# The .qsb is committed, so nobody using the component needs this —
# only somebody changing the shader does. qsb ships with Qt's shader
# tools: qt6-qtshadertools-devel on Fedora, qt6-shadertools-dev on
# Debian and Ubuntu.
#
# One file carries every backend Qt's RHI might pick: SPIR-V for
# Vulkan (qsb always emits it), GLSL for OpenGL, and HLSL and MSL so
# the same file works if the component ever leaves Linux. GLSL 300 es
# and 330 rather than anything older because the shader uses fwidth,
# which needs derivatives.
#
# After baking, restart the process that uses it. Qt caches compiled
# shader pipelines by URL for the life of the process, so a QML reload
# keeps drawing with the old .qsb — which looks exactly like the edit
# having had no effect.
set -eu
cd "$(dirname "$0")"

QSB="${QSB:-$(command -v qsb || echo /usr/lib64/qt6/bin/qsb)}"

"$QSB" --glsl "300 es,330" --hlsl 50 --msl 12 \
    -o squircle.frag.qsb squircle.frag

"$QSB" --dump squircle.frag.qsb | sed -n '1,12p'
