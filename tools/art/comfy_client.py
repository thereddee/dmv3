"""Tiny ComfyUI API client for the character art first pass (Z-Image Turbo)."""
import json
import os
import time
import urllib.error
import urllib.request

HOST = "http://127.0.0.1:8189"
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "comfy_out")
INPUT_DIR = os.path.expandvars(r"%LOCALAPPDATA%\Comfy-Desktop\ComfyUI-Installs\ComfyUI\ComfyUI\input")

STYLE = ("2D game character art, clean thick black outlines, cel shaded, flat colours, limited palette, "
         "simple cartoon style, front view, full body, standing straight, arms slightly away from the body, "
         "centered, plain flat pure white background, no shadow on the ground, no text")


def _post(path, payload):
    req = urllib.request.Request(HOST + path, data=json.dumps(payload).encode("utf-8"),
                                 headers={"Content-Type": "application/json"})
    try:
        return json.loads(urllib.request.urlopen(req).read())
    except urllib.error.HTTPError as error:
        raise RuntimeError(error.read().decode("utf-8", "replace")[:1500]) from None


def _get(path):
    return json.loads(urllib.request.urlopen(HOST + path).read())


def run(workflow, timeout=900):
    """Queues a workflow, waits for it, returns the saved image paths."""
    prompt_id = _post("/prompt", {"prompt": workflow})["prompt_id"]
    start = time.time()
    while time.time() - start < timeout:
        history = _get("/history/" + prompt_id)
        if prompt_id in history:
            entry = history[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(json.dumps(status.get("messages", []))[:2000])
            paths = []
            for node in entry.get("outputs", {}).values():
                for image in node.get("images", []):
                    paths.append(os.path.join(OUT_DIR, image.get("subfolder", ""), image["filename"]))
            return paths, time.time() - start
        time.sleep(1.0)
    raise TimeoutError(prompt_id)


def _base(prompt, seed, steps, prefix):
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": "default"}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["unet", 0], "shift": 3.0}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "lumina2", "device": "cpu"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": prompt}},
        "neg": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["pos", 0]}},
        "sample": {"class_type": "KSampler", "inputs": {
            "model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0],
            "seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": prefix}},
    }


def txt2img(prompt, seed, prefix, width=512, height=768, steps=9):
    wf = _base(prompt, seed, steps, prefix)
    wf["latent"] = {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}}
    return run(wf)


def inpaint(prompt, seed, prefix, image_name, mask_name, denoise=1.0, steps=9):
    """Repaints only the white area of `mask_name` (both files live in ComfyUI's input folder)."""
    wf = _base(prompt, seed, steps, prefix)
    wf["image"] = {"class_type": "LoadImage", "inputs": {"image": image_name}}
    wf["mask_image"] = {"class_type": "LoadImage", "inputs": {"image": mask_name}}
    wf["mask"] = {"class_type": "ImageToMask", "inputs": {"image": ["mask_image", 0], "channel": "red"}}
    wf["encode"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["image", 0], "vae": ["vae", 0]}}
    wf["latent"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["encode", 0], "mask": ["mask", 0]}}
    wf["sample"]["inputs"]["denoise"] = denoise
    return run(wf)
