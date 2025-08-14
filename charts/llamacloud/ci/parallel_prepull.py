#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Tuple


def run(cmd: List[str]) -> Tuple[int, str]:
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        return result.returncode, (result.stdout + result.stderr).strip()
    except Exception as exc:  # let outer caller decide how to handle
        return 1, str(exc)


def list_nodes(cluster: str) -> List[str]:
    code, out = run(["kind", "get", "nodes", "--name", cluster])
    if code != 0:
        return []
    return [n for n in out.splitlines() if n.strip()]


def image_present_on_node(node: str, image: str) -> bool:
    code, _ = run(["docker", "exec", node, "sh", "-lc", "command -v crictl >/dev/null 2>&1"])
    if code != 0:
        return False
    code, _ = run(["docker", "exec", node, "crictl", "inspecti", image])
    return code == 0


def image_present_on_all_nodes(cluster: str, image: str) -> bool:
    nodes = list_nodes(cluster)
    if not nodes:
        return False
    for n in nodes:
        if not image_present_on_node(n, image):
            return False
    return True


def pull_to_all_nodes(image: str, cluster: str, states: Dict[str, str], lock: threading.Lock) -> Tuple[str, bool, str]:
    nodes = list_nodes(cluster)
    if not nodes:
        with lock:
            states[image] = "failed"
        return image, False, "no kind nodes found"

    with lock:
        if states.get(image) == "pending":
            states[image] = "pulling"

    # If present on all nodes, mark loaded
    try:
        if image_present_on_all_nodes(cluster, image):
            with lock:
                states[image] = "loaded"
            return image, True, "already present"
    except Exception:
        pass

    # Pull on each node via crictl with retries
    per_node_fail: List[Tuple[str, str]] = []
    attempts = [2, 5, 10]
    for node in nodes:
        # Skip if already present
        if image_present_on_node(node, image):
            continue
        ok = False
        last_err = ""
        for delay in attempts:
            code, out = run(["docker", "exec", node, "crictl", "pull", image])
            if code == 0:
                ok = True
                break
            last_err = out
            time.sleep(delay)
        if not ok:
            per_node_fail.append((node, last_err))

    if per_node_fail:
        with lock:
            states[image] = "failed"
        nodes_list = ", ".join(f"{n}: {e.splitlines()[-1] if e else 'error'}" for n, e in per_node_fail)
        return image, False, f"crictl pull failed for nodes -> {nodes_list}"

    with lock:
        states[image] = "loaded"
    return image, True, ""


def verify(cluster: str, images: List[str]) -> List[Tuple[str, str]]:
    code, out = run(["kind", "get", "nodes", "--name", cluster])
    if code != 0:
        return [("kind", f"failed to list nodes: {out}")]
    nodes = [n for n in out.splitlines() if n.strip()]

    failures: List[Tuple[str, str]] = []
    for node in nodes:
        for image in images:
            # Prefer crictl
            code, _ = run(["docker", "exec", node, "sh", "-lc", "command -v crictl >/dev/null 2>&1"])
            if code == 0:
                code, _ = run(["docker", "exec", node, "crictl", "inspecti", image])
                if code != 0:
                    failures.append((node, image))
            else:
                code, out = run(["docker", "exec", node, "ctr", "-n", "k8s.io", "images", "ls", "-q"])
                if code != 0 or image not in set(out.splitlines()):
                    failures.append((node, image))
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Parallel pre-pull and load images into kind cluster")
    parser.add_argument("--cluster-name", default=os.environ.get("KIND_CLUSTER", "chart-testing"))
    parser.add_argument("--max-jobs", type=int, default=int(os.environ.get("MAX_JOBS", "16")))
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--images-file", type=str, default=None, help="File with one image per line; omit to read from stdin")
    args = parser.parse_args()

    if args.images_file:
        with open(args.images_file, "r", encoding="utf-8") as f:
            images = [line.strip() for line in f if line.strip()]
    else:
        images = [line.strip() for line in sys.stdin if line.strip()]

    if not images:
        print("No images provided", file=sys.stderr)
        return 0

    total = len(images)
    failures: List[Tuple[str, str]] = []

    # State tracking for richer progress: pending -> pulling -> loaded/failed
    states: Dict[str, str] = {img: "pending" for img in images}
    states_lock = threading.Lock()
    stop_progress = threading.Event()

    def progress_printer() -> None:
        last_line = ""
        while not stop_progress.is_set():
            with states_lock:
                counts: Dict[str, int] = {k: 0 for k in ["pending", "pulling", "loaded", "failed"]}
                for st in states.values():
                    counts[st] = counts.get(st, 0) + 1
                pulling_list = [i for i, st in states.items() if st == "pulling"]
                loaded = counts.get("loaded", 0)
                failed = counts.get("failed", 0)
                pending = counts.get("pending", 0)
                pulling = counts.get("pulling", 0)
            line = (
                f"Progress: loaded={loaded}/{total}, pulling={pulling}, pending={pending}, failed={failed}"
            )
            if line != last_line:
                print(line)
                last_line = line
            # Show a short list of currently pulling images for visibility
            if pulling_list:
                sample = pulling_list[:3]
                print("  pulling:", ", ".join(sample) + (" ..." if pulling > len(sample) else ""))
            time.sleep(1.0)

    t = threading.Thread(target=progress_printer, daemon=True)
    t.start()

    try:
        with ThreadPoolExecutor(max_workers=max(1, args.max_jobs)) as executor:
            futures = {executor.submit(pull_to_all_nodes, image, args.cluster_name, states, states_lock): image for image in images}
            for fut in as_completed(futures):
                image, ok, err = fut.result()
                if not ok:
                    failures.append((image, err))
    finally:
        stop_progress.set()
        t.join(timeout=2.0)

    # Final summary
    with states_lock:
        loaded = sum(1 for s in states.values() if s == "loaded")
        failed = sum(1 for s in states.values() if s == "failed")
    print(f"Completed: loaded={loaded}/{total}, failed={failed}")

    if failures:
        print("Some image pulls/loads failed:", file=sys.stderr)
        for image, reason in failures:
            print(f"  {image}: {reason}", file=sys.stderr)

    if args.verify:
        vfail = verify(args.cluster_name, images)
        if vfail:
            print("Verification: missing images detected:", file=sys.stderr)
            for node, image in vfail:
                print(f"  {node}: {image}", file=sys.stderr)

    # Do not hard-fail on failures; leave install step to retry/pull as needed
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


