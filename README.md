yazi-csv/xz.csv-preview
================================================================================
yazi-csv-preview —— 给 yazi 补上 CSV/TSV 表格化预览的插件，纯文本与
xz/gz/bz2 压缩文件都按表格显示内容。

解决的问题
  yazi 默认只对 text/* 做文本预览，CSV 常被 libmagic 判为 application/*，
  落到 file 兜底只显示"文件类型"；.csv.xz 的 MIME 是 application/x-xz，
  会被 archive 预览器接管，只列出压缩包内文件名。本项目用
  prepend_previewers 的 url 规则抢先命中，交给 csv 插件渲染。

能力
  - 按列对齐的表格，中文按东亚显示宽度对齐；支持带引号的逗号、TSV、翻页
  - 覆盖 .csv/.tsv/.psv 及 .xz/.gz/.bz2 压缩版；流式只读前 8 MiB、
    不落临时文件（优先 Python lzma，缺 _lzma 回退 xzcat）
  - 自动识别 UTF-8 BOM / GB18030 / Big5 / Latin-1；损坏的压缩包给出
    错误提示而非崩溃
  - 依赖仅 python3；在 Rocky Linux 8/9/10 + yazi v26.9.1 上验证

文件
  install.sh              一键安装，内嵌插件，自动合并 yazi.toml 并备份；
                          bash install.sh 表格版，bash install.sh text 仅最小修复
  yazi.toml.snippet       预览器规则片段
  plugins/csv.yazi/main.lua   预览插件
  ReadMe.txt              本文件

用法
  bash install.sh

  重开 yazi，光标移到 .csv / .csv.xz 即可看到表格；按 Tab 可确认
  Previewer 为 csv。


--------------------------------------------------------------------------------
yazi-csv-preview — a yazi plugin that renders CSV/TSV files as aligned
tables, for both plain files and xz/gzip/bzip2-compressed ones.

Why
  yazi only previews text/* by MIME. libmagic often classifies CSV as
  application/*, so it falls through to the file previewer and shows just
  the file type; .csv.xz is application/x-xz and gets claimed by the
  archive previewer, which merely lists the file name inside. This plugin
  adds prepend_previewers URL rules that match first and hand the file to
  the csv previewer.

Features
  - Aligned columns with East-Asian width handling, quoted commas, TSV,
    and paging
  - .csv/.tsv/.psv plus .xz/.gz/.bz2 variants; streams only the first
    8 MiB with no temp files (Python lzma first, xzcat fallback when
    _lzma is missing)
  - Auto-detects UTF-8 BOM / GB18030 / Big5 / Latin-1; corrupt archives
    produce a readable error instead of crashing
  - Only dependency is python3; verified on Rocky Linux 8/9/10 with
    yazi v26.9.1

Contents
  install.sh              One-shot installer with the plugin embedded;
                          merges yazi.toml and keeps a backup.
                          "bash install.sh" for table preview,
                          "bash install.sh text" for the minimal fix
  yazi.toml.snippet       Previewer rules
  plugins/csv.yazi/main.lua   The previewer
  ReadMe.txt              This file

Usage
  bash install.sh

  Restart yazi and move the cursor onto a .csv or .csv.xz; press Tab to
  confirm Previewer is csv.
