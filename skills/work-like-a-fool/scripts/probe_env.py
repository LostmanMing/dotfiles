#!/usr/bin/env python3
"""探测当前机器的真实环境，供 AI 把课程锚定到实际可跑的东西上。

用法： probe_env.py [--extra "自定义命令1" --extra "自定义命令2"]
输出精简、面向 LLM。探测失败的项标 "-"，不报错。
"""
import argparse
import os
import shutil
import subprocess

CHECKS = [
    ("OS", "uname -sr"),
    ("CPU", "nproc"),
    ("MEM", "free -g 2>/dev/null | awk 'NR==2{print $2\" GB\"}'"),
    ("python3", "python3 -V"),
    ("pip", "python3 -m pip --version 2>/dev/null | cut -d' ' -f1-2"),
    ("node", "node -v"),
    ("gcc/g++", "g++ --version | head -1"),
    ("cmake", "cmake --version | head -1"),
    ("git", "git --version"),
    ("docker", "docker --version"),
    ("GPU", "nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader"),
    ("CUDA 目录", "ls -d /usr/local/cuda* 2>/dev/null | tr '\\n' ' '"),
    ("nvcc", "nvcc --version 2>/dev/null | tail -2 | head -1"),
    ("nsys(PATH)", "nsys --version 2>/dev/null | head -1"),
    ("nsys(全部)", "ls -d /opt/nvidia/nsight-systems/* 2>/dev/null | tr '\\n' ' '"),
    ("ncu", "ls /usr/local/cuda*/bin/ncu 2>/dev/null | tr '\\n' ' '"),
    ("java", "java -version 2>&1 | head -1"),
    ("go", "go version"),
    ("rustc", "rustc --version"),
]

PY_PKGS = ["torch", "numpy", "vllm", "transformers", "jax", "tensorflow",
           "pandas", "fastapi", "django", "flask", "pytest"]


def run(cmd):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=20)
        out = (r.stdout or r.stderr).strip().splitlines()
        v = out[0].strip() if out and out[0].strip() else "-"
        low = v.lower()
        if any(k in low for k in ("not found", "no such file", "command not found",
                                  "modulenotfounderror", "traceback")):
            return "-"
        return v
    except Exception:
        return "-"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--extra", action="append", default=[], help="额外探测命令，可重复")
    ap.add_argument("--python", default="python3", help="用于查包的 python 解释器")
    a = ap.parse_args()

    print("== 环境 ==")
    for name, cmd in CHECKS:
        v = run(cmd)
        if v != "-":
            print(f"  {name:<14} {v}")

    print(f"== Python 包（解释器 {a.python}）==")
    found = []
    for p in PY_PKGS:
        v = run(f'{a.python} -c "import {p};print({p}.__version__)"')
        if v != "-":
            found.append(f"{p}=={v}")
    print("  " + (", ".join(found) if found
                  else "（未检测到常见包；若项目用 venv，加 --python /path/to/venv/bin/python 重跑）"))
    venvs = run("ls -d ./.venv/bin/python ../.venv/bin/python /workspace/*/bin/python 2>/dev/null | tr '\\n' ' '")
    if venvs != "-":
        print(f"  发现候选解释器: {venvs}")

    print("== 网络 ==")
    for name, url in [("pypi 官方", "https://pypi.org/simple/"),
                      ("阿里云镜像", "https://mirrors.aliyun.com/pypi/simple/"),
                      ("清华镜像", "https://pypi.tuna.tsinghua.edu.cn/simple/")]:
        v = run(f'curl -sS -m 6 -o /dev/null -w "%{{http_code}} %{{speed_download}}B/s" {url}')
        print(f"  {name:<12} {v}")

    if a.extra:
        print("== 自定义 ==")
        for c in a.extra:
            print(f"  $ {c}\n    {run(c)}")

    print("\n提示: 把上面结果写进站点首页的「本机环境」，并据此决定课程里的实验能不能真跑。")
    print("      凡是版本/路径有歧义的（如多个 nsys、多个 CUDA），课程里必须写明用哪一个。")


if __name__ == "__main__":
    main()
