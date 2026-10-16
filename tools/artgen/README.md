# tools/artgen — local art generation and clean-up

Setup (once, needs an NVIDIA GPU with 12+ GB VRAM):

```powershell
python -m venv tools/artgen/.venv
tools/artgen/.venv/Scripts/python -m pip install torch --index-url https://download.pytorch.org/whl/cu124
tools/artgen/.venv/Scripts/python -m pip install diffusers transformers accelerate safetensors peft huggingface_hub pillow numpy scipy
```

Model weights (about 7 GB) download into `tools/artgen/models` on first run. Everything under
`.venv/`, `models/` and `out/` is git-ignored.

Workflow and tool list: docs/VISUAL_PROGRESS.md. Standards: docs/ART_STYLE_GUIDE.md.

Sprite golfers (v4, every roster character) are built with the `g4_*` tools, see
docs/SPRITE_PIPELINE.md and docs/CHARACTER_CONVERSION.md. Rebuild one from committed art (no GPU):

```powershell
tools/artgen/.venv/Scripts/python tools/artgen/g4_build.py process rex     # art/characters/rex/v4/raw -> frames
tools/artgen/.venv/Scripts/python tools/artgen/g4_build.py build rex       # frames -> client/assets/characters/rex
tools/artgen/.venv/Scripts/python tools/artgen/g4_portrait.py reprocess rex
tools/artgen/.venv/Scripts/python tools/artgen/g4_portrait.py build rex
```

Rebuilding other game assets from committed picks needs no GPU:

```powershell
tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py meadow
tools/artgen/.venv/Scripts/python tools/artgen/build_fx.py
```
