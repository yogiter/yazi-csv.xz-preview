#!/usr/bin/env bash
# yazi CSV 预览一键安装（在 Rocky 机器上执行）
#   bash install.sh         表格化预览：纯 CSV + .csv.xz/.gz/.bz2（推荐）
#   bash install.sh text    仅最小修复，用内置 code 预览器（不支持压缩文件）
set -euo pipefail

command -v python3 >/dev/null 2>&1 || { echo "需要 python3（Rocky 8/9/10 默认自带）"; exit 1; }

MODE="${1:-table}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"
CFG_FILE="$CFG/yazi.toml"

case "$MODE" in
  table)
    mkdir -p "$CFG/plugins/csv.yazi"
    cat > "$CFG/plugins/csv.yazi/main.lua" <<'LUA'
-- yazi CSV previewer: aligned table for plain / xz / gzip / bzip2 CSV
-- Handles UTF-8 BOM, GB18030, Big5, Latin-1; East-Asian width aware.
-- Compressed files are streamed (same idea as `xzcat file.csv.xz | head`):
-- only the first 8 MiB is decompressed, in-process, no temp file.
-- Install: ~/.config/yazi/plugins/csv.yazi/main.lua
-- Enable:  prepend_previewers = [
--             { url = "*.{csv,tsv}", run = "csv" },
--             { url = "*.{csv.xz,csv.gz,csv.bz2,tsv.xz,tsv.gz,tsv.bz2}", run = "csv" },
--           ]
-- Requires: python3 (Rocky 8/9/10 默认自带); xz 文件优先用标准库 lzma,
--           缺 _lzma 时自动回退到 xzcat 命令。

local M = {}

-- 用带等号的长字符串定界符，避免内嵌 Python 代码里的双右方括号提前截断字符串
local SCRIPT = [=[
import csv, io, sys, unicodedata

path, skip, limit = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
lower = path.lower()
LIMIT = 8 * 1024 * 1024

base, kind, label = lower, "", ""
for suffix, name, desc in ((".xz", "xz", "xzcat/lzma"),
                           (".gz", "gz", "gzip"),
                           (".bz2", "bz2", "bzip2")):
    if lower.endswith(suffix):
        base, kind, label = lower[:-len(suffix)], name, desc
        break

delimiter = "\t" if base.endswith(".tsv") else ","

def read_raw(p, n):
    if kind == "xz":
        try:
            import lzma
        except ImportError:
            # 等价于 `xzcat <p> | head -c 8M`：流式，只读前 n 字节
            import subprocess
            proc = subprocess.Popen(["xzcat", p], stdout=subprocess.PIPE)
            try:
                return proc.stdout.read(n)
            finally:
                proc.stdout.close()
                proc.terminate()
                proc.wait()
        with lzma.open(p, "rb") as f:
            return f.read(n)
    elif kind == "gz":
        import gzip
        with gzip.open(p, "rb") as f:
            return f.read(n)
    elif kind == "bz2":
        import bz2
        with bz2.open(p, "rb") as f:
            return f.read(n)
    else:
        with open(p, "rb") as f:
            return f.read(n)

try:
    raw = read_raw(path, LIMIT)
except Exception as e:
    print("读取/解压失败: %s" % e)
    sys.exit(0)

# 大文件按 8 MiB 截断时，丢掉末尾半行
if len(raw) == LIMIT:
    cut = raw.rfind(b"\n")
    if cut > 0:
        raw = raw[:cut]

text = None
for enc in ("utf-8-sig", "gb18030", "big5", "latin-1"):
    try:
        text = raw.decode(enc)
        break
    except UnicodeDecodeError:
        pass
if text is None:
    text = raw.decode("utf-8", "replace")

# 只解析预览窗口需要的行，避免为 8 MiB / 百万行数据做全量 csv 解析
wanted = skip + max(1, limit - 2) + 1
try:
    rows = []
    for i, r in enumerate(csv.reader(io.StringIO(text), delimiter=delimiter)):
        if i >= wanted:
            break
        rows.append(r)
except csv.Error:
    lines = text.splitlines()[:wanted]
    rows = [line.split(delimiter) for line in lines]

row_count = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
total_rows = max(0, row_count - 1)
truncated_rows = len(rows) >= wanted

if not rows:
    print("(empty file)")
    sys.exit(0)

cols = max(len(r) for r in rows)
for r in rows:
    r.extend([""] * (cols - len(r)))

def cw(c):
    return 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1

def dw(s):
    return sum(cw(c) for c in s)

widths = [min(max(dw(r[i]) for r in rows), 40) or 1 for i in range(cols)]

def fit(s, w):
    s = s.replace("\t", " ").replace("\r", "").replace("\n", " ")
    out, used, truncated = [], 0, False
    for c in s:
        k = cw(c)
        if used + k > w:
            truncated = True
            break
        out.append(c)
        used += k
    r = "".join(out)
    if truncated and w >= 3:
        while dw(r) > w - 2:
            r = r[:-1]
        r += ".."
        used = dw(r)
    return r + " " * max(0, w - used)

header = rows[0]
data = rows[1:]
selected = data[skip:skip + max(1, limit - 2)]

out = [" | ".join(fit(header[i], widths[i]) for i in range(cols))]
out.append("-+-".join("-" * w for w in widths))
for r in selected:
    out.append(" | ".join(fit(r[i], widths[i]) for i in range(cols)))
out.append("")
status = "[%s%d rows x %d cols, showing %d-%d]" % (
    "~" if truncated_rows else "", total_rows, cols, skip + 1, skip + len(selected))
if kind:
    status += "  [stream: %s, first %d MiB]" % (label, LIMIT // 1024 // 1024)
out.append(status)
print("\n".join(out))
]=]

function M:peek(job)
	local path = tostring(job.file.path)
	local output, err = Command("python3")
		:arg({ "-c", SCRIPT, path, tostring(job.skip), tostring(job.area.h) })
		:output()

	if not output or not output.stdout or output.stdout == "" then
		return require("empty").msg(job, "CSV preview failed: " .. tostring(err))
	end

	ya.preview_widget(job, ui.Text(output.stdout):area(job.area))
end

function M:seek(job) require("code"):seek(job) end
function M:spot(job) require("file"):spot(job) end

return M
LUA
    RULE='  { url = "*.{csv,tsv}", run = "csv" },
  { url = "*.{csv.xz,csv.gz,csv.bz2,tsv.xz,tsv.gz,tsv.bz2}", run = "csv" },'
    echo "已安装插件: $CFG/plugins/csv.yazi/main.lua"
    ;;
  text)
    RULE='  { url = "*.{csv,tsv,psv}", run = "code" },'
    echo "提示: code 预览器读不了 .csv.xz，压缩文件请用 bash install.sh"
    ;;
  *)
    echo "用法: bash install.sh [table|text]"; exit 2
    ;;
esac

python3 - "$CFG_FILE" "$RULE" <<'PY'
import sys
from pathlib import Path

p, rule = Path(sys.argv[1]), sys.argv[2]
if not p.exists():
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("[plugin]\nprepend_previewers = [\n" + rule + "\n]\n")
    print("已创建:", p)
elif "prepend_previewers" in p.read_text():
    print("[需手动] 已有 prepend_previewers，未改动。把以下规则合并进数组:")
    print(rule)
    print("    若 *.csv 原来用的是 code，表格版需改成 csv")
else:
    s = p.read_text()
    bak = p.with_name(p.name + ".bak")
    bak.write_text(s)
    lines = s.splitlines()
    idx = next((i for i, l in enumerate(lines) if l.strip() == "[plugin]"), None)
    if idx is None:
        out = s.rstrip("\n") + "\n\n[plugin]\nprepend_previewers = [\n" + rule + "\n]\n"
    else:
        lines[idx + 1:idx + 1] = ["prepend_previewers = [", rule, "]"]
        out = "\n".join(lines) + "\n"
    p.write_text(out)
    print("已更新:", p, "(原文件备份:", bak, ")")
PY

echo
echo "完成。重开 yazi，光标移到 .csv / .csv.xz 看预览；按 Tab 可查看 Mimetype / Previewer。"
