#!/usr/bin/env python3
"""Gera as artes do jogo no ComfyUI local e publica em `assets/generated/`.

Um caminho, tres artes desta fatia (ticket 9): um cenario de arena, um painel de
Reviravolta e um retrato. Para cada arte:

1. monta o prompt com o template verbatim da skill `rrn:pixel-art` (o prompt
   negativo tambem vem de la, sem alteracao);
2. roda `tools/comfy/workflows/pixelart_bg.json` pelo cliente HTTP
   `tools/comfy/scripts/run_workflow.py` (ComfyUI 0.36.0 local, SD 1.5),
   usando o tamanho e os passos que estao no proprio workflow;
3. pos-processa com `tools/comfy/postprocess.py` (426x240, nearest, <= 32 cores);
4. grava `assets/generated/<tipo>/<slug>.png` + `<slug>.json` de metadados
   (prompt, seed, workflow, modelo, licenca e URL de origem);
5. reescreve `assets/generated/CREDITS.md` com o que foi publicado.

Nada de pessoa real, simbolo real ou referencia religiosa (ADR 0004): os
sujeitos sao paisagem, uma silhueta generica sem insígnia e uma figura do
folclore.

Uso:
    python3 tools/comfy/generate.py                 # gera tudo
    python3 tools/comfy/generate.py --only saci-portrait
    python3 tools/comfy/generate.py --verify        # so valida o que ja esta publicado
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / "tools" / "comfy" / "workflows" / "pixelart_bg.json"
RAW_DIR = pathlib.Path("/tmp/peleja-comfy-raw")
GENERATED_ROOT = REPO_ROOT / "assets" / "generated"
CREDITS = GENERATED_ROOT / "CREDITS.md"
RUNNER = REPO_ROOT / "tools" / "comfy" / "scripts" / "run_workflow.py"
POSTPROCESS = REPO_ROOT / "tools" / "comfy" / "postprocess.py"

MODEL = "v1-5-pruned-emaonly.safetensors"
MODEL_LICENSE = "CreativeML Open RAIL-M"
MODEL_SOURCE_URL = (
    "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5"
    "/resolve/main/v1-5-pruned-emaonly.safetensors"
)
MODEL_CARD_URL = "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5"
GENERATED_WITH = "ComfyUI 0.36.0 local (Apple M4, 16 GB unificados, backend MPS)"

# Template do prompt, verbatim da skill rrn:pixel-art. Só os campos entre
# chaves sao substituidos.
PROMPT_TEMPLATE = """A detailed 16-bit retro pixel art illustration in {PROPORCAO} aspect ratio.
Visual Style:
Aesthetic: Crisp 16-bit arcade / Super Nintendo style pixel art.
Pixel Grid: Strictly uniform pixel-to-canvas ratio across all elements (character, foreground, background, and UI/text elements). No sub-pixel alignment, no mixed resolution, no modern smooth gradients or vector filters.
Linework & Shading: Clean dark pixel outlines, vibrant color palette, retro dithering for sky/texture gradients, and sharp localized shading.
Input Context:
Mode: {MODO}
Subject Details: {SUJEITO}
Pose/Action: {POSE}
Environment:
Setting: {CENARIO}
Background Elements: {ELEMENTOS}
Mood/Lighting: {MOOD}, nostalgic retro video game atmosphere.
UI Elements: {UI}"""

NEGATIVE_PROMPT = (
    "antialiasing, smooth vector shapes, 3D render, photorealism, mixed pixel resolutions, "
    "blurry pixels, watermark, signature, text artifacts, jpeg compression noise"
)

NO_UI = "None, keep the scene clean with no UI or text"
# Licao de campo (medida com sweep de seeds, nao suposta): pedir "no picture
# frame / no border / flat solid shapes" no prompt positivo faz o SD 1.5 desenhar
# a moldura, e "plain solid background" vira xadrez de transparencia. Os campos
# abaixo descrevem so o que deve aparecer na imagem.
ARTS: list[dict] = [
    {
        "slug": "forest-arena",
        "kind": "backgrounds",
        "role": "Cenario da arena: clareira na mata, chao de terra batida",
        "seed": 42,
        "fields": {
            "PROPORCAO": "16:9 widescreen",
            "MODO": "DESCRIÇÃO",
            "SUJEITO": (
                "Environment only, no characters: a wide side-view fighting game stage, a "
                "clearing of packed dirt in the middle framed by a dense green treeline and "
                "big leafy plants in the foreground"
            ),
            "POSE": "None, fixed side view, the stage stands empty",
            "CENARIO": "a dense forest",
            "ELEMENTOS": "layered mountains and trees",
            "MOOD": "Bright, clean, colorful daylight",
            "UI": NO_UI,
        },
        "field_notes": {
            "CENARIO": "opcao literal do questionario (floresta)",
            "ELEMENTOS": "opcao literal do questionario (montanhas + arvores)",
            "MOOD": "opcao literal do questionario (dia claro nostalgico)",
            "UI": "opcao literal do questionario (sem UI)",
            "SUJEITO": "campo livre: a arte e so ambiente, nao ha personagem (ADR 0004)",
        },
    },
    {
        "slug": "reviravolta-panel",
        "kind": "panels",
        "role": "Painel da Reviravolta: a mata toma a cena",
        "seed": 7,
        "fields": {
            "PROPORCAO": "16:9 widescreen",
            "MODO": "DESCRIÇÃO",
            "SUJEITO": (
                "One full-bleed illustration: giant green leaves and thick wooden vines "
                "filling the whole frame, golden sunlight breaking through the dense forest "
                "canopy"
            ),
            "POSE": "the vines surge upward and take over the frame, camera looking up",
            "CENARIO": "a dense forest",
            "ELEMENTOS": "layered mountains and trees, a big pixelated sun and chunky clouds",
            "MOOD": "Golden hour sunset light with warm dithering",
            "UI": NO_UI,
        },
        "field_notes": {
            "CENARIO": "opcao literal do questionario (floresta)",
            "ELEMENTOS": "opcoes literais do questionario (montanhas + arvores, sol + nuvens)",
            "MOOD": "opcao literal do questionario (por do sol dourado)",
            "UI": "opcao literal do questionario (sem UI)",
            "SUJEITO": "campo livre: a mata tomando a cena, sem pessoa, simbolo ou religiao (ADR 0004)",
        },
    },
    {
        "slug": "saci-portrait",
        "kind": "portraits",
        "role": "Retrato do Saci (folclore brasileiro)",
        "seed": 42,
        "fields": {
            "PROPORCAO": "16:9 widescreen",
            "MODO": "DESCRIÇÃO",
            "SUJEITO": (
                "Character: a mischievous dark-skinned boy, wearing a bright red pointed cap "
                "and a red scarf, big grin, arms crossed, bust portrait from the shoulders up"
            ),
            "POSE": "standing still in a heroic front-facing pose",
            "CENARIO": "a dense forest",
            "ELEMENTOS": "layered mountains and trees",
            "MOOD": "Golden hour sunset light with warm dithering",
            "UI": NO_UI,
        },
        "field_notes": {
            "POSE": "opcao literal do questionario (pose heroica parada, de frente)",
            "CENARIO": "opcao literal do questionario (floresta)",
            "ELEMENTOS": "opcao literal do questionario (montanhas + arvores)",
            "MOOD": "opcao literal do questionario (por do sol dourado)",
            "UI": "opcao literal do questionario (sem UI)",
            "SUJEITO": "campo livre: figura do folclore, nenhuma pessoa real (ADR 0004)",
        },
    },
]


def workflow_settings() -> dict:
    """Tamanho, passos e sampler lidos do workflow versionado.

    Assim a arte publicada nao pode divergir do workflow revisado no PR: o que
    esta no JSON e o que roda.
    """
    workflow = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    sampler = next(
        node for node in workflow.values() if node.get("class_type") == "KSampler"
    )["inputs"]
    latent = next(
        node for node in workflow.values() if node.get("class_type") == "EmptyLatentImage"
    )["inputs"]
    return {
        "width": int(latent["width"]),
        "height": int(latent["height"]),
        "steps": int(sampler["steps"]),
        "cfg": float(sampler["cfg"]),
        "sampler_name": sampler["sampler_name"],
        "scheduler": sampler["scheduler"],
        "checkpoint": next(
            node for node in workflow.values() if node.get("class_type") == "CheckpointLoaderSimple"
        )["inputs"]["ckpt_name"],
    }


def build_prompt(art: dict) -> str:
    """Prompt final: o template com os campos da arte substituidos."""
    prompt = PROMPT_TEMPLATE
    for key, value in art["fields"].items():
        prompt = prompt.replace("{" + key + "}", value)
    if "{" in prompt:
        raise SystemExit(f"placeholder nao substituido em {art['slug']}")
    return prompt


def _postprocess(raw: pathlib.Path, final: pathlib.Path) -> dict:
    result = subprocess.run(
        [sys.executable, str(POSTPROCESS), "--input", str(raw), "--output", str(final)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(f"pos-processamento falhou para {raw}:\n{result.stdout}{result.stderr}")
    return json.loads(result.stdout)


def generate(art: dict) -> dict:
    """Roda o workflow, pos-processa e grava metadados de uma arte."""
    prompt = build_prompt(art)
    settings = workflow_settings()
    final = GENERATED_ROOT / art["kind"] / f"{art['slug']}.png"
    run = subprocess.run(
        [
            sys.executable,
            str(RUNNER),
            "--workflow",
            str(WORKFLOW),
            "--prompt",
            prompt,
            "--negative",
            NEGATIVE_PROMPT,
            "--seed",
            str(art["seed"]),
            "--filename-prefix",
            art["slug"],
            "--output-dir",
            str(RAW_DIR / art["slug"]),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if run.returncode != 0:
        raise SystemExit(f"geracao falhou para {art['slug']}:\n{run.stdout}{run.stderr}")
    summary = json.loads(run.stdout)
    if not summary["files"]:
        raise SystemExit(f"ComfyUI nao devolveu arquivo para {art['slug']}: {summary}")
    report = _postprocess(pathlib.Path(summary["files"][0]), final)
    metadata = {
        "slug": art["slug"],
        "kind": art["kind"],
        "role": art["role"],
        "asset": f"res://assets/generated/{art['kind']}/{art['slug']}.png",
        "prompt": prompt,
        "prompt_fields": art["fields"],
        "prompt_field_notes": art.get("field_notes", {}),
        "negative_prompt": NEGATIVE_PROMPT,
        "prompt_source": "skill rrn:pixel-art (template e prompt negativo verbatim)",
        "seed": summary["seed"],
        "generation": {
            "width": summary["width"],
            "height": summary["height"],
            "steps": settings["steps"],
            "cfg": settings["cfg"],
            "sampler_name": settings["sampler_name"],
            "scheduler": settings["scheduler"],
            "workflow": "tools/comfy/workflows/pixelart_bg.json",
            "prompt_id": summary["prompt_id"],
            "host": summary["host"],
            "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        },
        "model": settings["checkpoint"],
        "model_license": MODEL_LICENSE,
        "model_source_url": MODEL_SOURCE_URL,
        "model_card_url": MODEL_CARD_URL,
        "generated_with": GENERATED_WITH,
        "postprocess": {
            "script": "tools/comfy/postprocess.py",
            "size": report["size"],
            "colors": report["colors"],
            "max_colors": report["max_colors"],
            "resample": report["resample"],
            "palette": "assets/palettes/peleja.json",
            "sha256": report["sha256"],
        },
        "policy": "sem pessoa real, sem simbolo real e sem referencia religiosa (ADR 0004)",
    }
    final.with_suffix(".json").write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps({"slug": art["slug"], **report, "prompt_id": summary["prompt_id"]}, indent=2))
    return metadata


def write_credits(metadatas: list[dict]) -> None:
    """Reescreve CREDITS.md com modelo, licenca, URL de origem e cada arte."""
    lines = [
        "# Creditos da arte gerada",
        "",
        "Arte de cenario, paineis de Reviravolta e retratos gerada localmente para este",
        "projeto. Lutadores e oponentes nao passam por aqui: sao spritesheets codificados",
        "como dados (ADR 0005).",
        "",
        "## Modelo",
        "",
        f"- Checkpoint: `{MODEL}`",
        f"- Licenca: {MODEL_LICENSE} (modelo aberto, com as restricoes da licenca)",
        f"- URL de origem: {MODEL_SOURCE_URL}",
        f"- Model card: {MODEL_CARD_URL}",
        f"- Gerado com: {GENERATED_WITH}",
        "",
        "O checkpoint nao e versionado no repositorio (4 GB). Para reproduzir, baixe com",
        "`comfy model download --url \"<URL de origem>\" --relative-path models/checkpoints`.",
        "",
        "## Artes versionadas",
        "",
        "| Arte | Slug | Seed | Prompt ID | Tamanho | Cores | Licenca |",
        "|---|---|---|---|---|---|---|",
    ]
    for meta in metadatas:
        post = meta["postprocess"]
        lines.append(
            f"| `{meta['asset']}` | {meta['slug']} | {meta['seed']} | "
            f"{meta['generation']['prompt_id']} | {post['size'][0]}x{post['size'][1]} | "
            f"{post['colors']} | {meta['model_license']} |"
        )
    lines += [
        "",
        "## Terceiros",
        "",
        "Nenhum arquivo de terceiros (fonte, textura ou trilha) entra neste repositorio",
        f"nesta fatia. O unico insumo externo e o checkpoint acima, sob {MODEL_LICENSE}.",
        "",
        "Os metadados completos de cada arte (prompt, prompt negativo, seed, workflow,",
        "modelo e licenca) ficam no `.json` ao lado do `.png`.",
        "",
    ]
    CREDITS.write_text("\n".join(lines), encoding="utf-8")


def _existing_metadatas() -> list[dict]:
    metadatas = []
    for path in sorted(GENERATED_ROOT.glob("*/*.json")):
        metadatas.append(json.loads(path.read_text(encoding="utf-8")))
    return metadatas


def verify() -> int:
    """Valida o que esta publicado: 426x240, <= 32 cores e metadados completos."""
    failures = 0
    for art in ARTS:
        png = GENERATED_ROOT / art["kind"] / f"{art['slug']}.png"
        meta_path = png.with_suffix(".json")
        if not png.exists() or not meta_path.exists():
            print(f"FALHA ausente: {png} / {meta_path}")
            failures += 1
            continue
        result = subprocess.run(
            [sys.executable, str(POSTPROCESS), "--verify", str(png)], check=False
        )
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        for field in ("prompt", "seed", "model", "model_license", "model_source_url"):
            if not meta.get(field):
                print(f"FALHA metadado ausente em {meta_path}: {field}")
                failures += 1
        failures += result.returncode
    return 1 if failures else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", action="append", help="gera so estes slugs")
    parser.add_argument("--verify", action="store_true", help="nao gera: valida o publicado")
    args = parser.parse_args(argv)

    if args.verify:
        return verify()

    targets = [art for art in ARTS if not args.only or art["slug"] in args.only]
    if not targets:
        known = [art["slug"] for art in ARTS]
        raise SystemExit(f"nenhum slug conhecido em {args.only}; conhecidos: {known}")
    metadatas = [generate(art) for art in targets]
    write_credits(_existing_metadatas())
    print(json.dumps({"generated": [meta["slug"] for meta in metadatas]}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
