#!/usr/bin/env python3
"""启动本地静态服务，并打印针对当前环境的访问指引（含远程转发方式）。

用法： serve.py --dir ./mysite [--port 8080]
以后台方式启动；重复调用会先检测端口占用。
"""
import argparse
import os
import socket
import subprocess
import sys


def port_busy(p):
    with socket.socket() as s:
        s.settimeout(0.4)
        return s.connect_ex(("127.0.0.1", p)) == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--port", type=int, default=8080)
    a = ap.parse_args()
    root = os.path.abspath(a.dir)
    if not os.path.isdir(root):
        print(f"FAIL: 目录不存在 {root}")
        return 1

    if port_busy(a.port):
        print(f"端口 {a.port} 已被占用（可能服务已在跑）")
    else:
        subprocess.Popen(
            ["setsid", sys.executable, "-m", "http.server", str(a.port), "--bind", "0.0.0.0"],
            cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL, start_new_session=True)
        import time
        for _ in range(20):
            time.sleep(0.2)
            if port_busy(a.port):
                break
        print(f"已启动: {root} → http://127.0.0.1:{a.port}"
              if port_busy(a.port) else "FAIL: 服务未起来")

    # 访问指引
    ip = None
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 53))
            ip = s.getsockname()[0]
    except OSError:
        pass
    ssh_conn = os.environ.get("SSH_CONNECTION", "")
    print("\n访问方式：")
    print(f"  本机浏览器      http://localhost:{a.port}")
    if ssh_conn:
        host = ssh_conn.split()[2] if len(ssh_conn.split()) > 2 else (ip or "<host>")
        print(f"  远程（推荐）    在你的电脑上执行：ssh -L {a.port}:127.0.0.1:{a.port} <用户名>@{host}")
        print(f"                  然后开 http://localhost:{a.port}（保持该 ssh 窗口不关）")
    if ip:
        print(f"  直连（若可路由）http://{ip}:{a.port}")
    print(f"  纯静态拷回      scp -r <用户名>@{ip or '<host>'}:{root} ~/Desktop/ 后直接开 index.html")
    print("  VS Code/Cursor Remote-SSH 会自动转发端口，直接开 localhost 即可")
    return 0


if __name__ == "__main__":
    sys.exit(main())
