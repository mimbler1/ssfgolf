# tools/artgen — local art generation and clean-up

Setup (once, needs an NVIDIA GPU with 12+ GB VRAM):

```powershell
python -m venv tools/artgen/.venv
tools/artgen/.venv/Scripts/python -m pip install torch --index-url https://download.pytorch.org/whl/cu124
tools/artgen/.venv/Scripts/python -m pip install diffusers transformers accelerate safetensors peft huggingface_hub pillow numpy
```

Model weights (about 7 GB) download into `tools/artgen/models` on first run. Everything under
`.venv/`, `models/` and `out/` is git-ignored.

Workflow and tool list: docs/VISUAL_PROGRESS.md. Standards: docs/ART_STYLE_GUIDE.md.

Rebuilding game assets from committed picks needs no GPU:

```powershell
tools/artgen/.venv/Scripts/python tools/artgen/build_stage.py meadow
tools/artgen/.venv/Scripts/python tools/artgen/build_golfer.py rex Rex art/characters/painted/rex.png
tools/artgen/.venv/Scripts/python tools/artgen/build_fx.py
```
