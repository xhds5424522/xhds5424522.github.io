#!/data/data/com.termux/files/usr/bin/bash
# 发布一篇文章到 GitHub Pages
# 用法：bash publish.sh 文章.md
set -euo pipefail

OWNER="xhds5424522"
REPO="xhds5424522.github.io"
API="https://api.github.com/repos/$OWNER/$REPO"
TOKEN="${GH_TOKEN:-$(cat "$HOME/.gh_token" 2>/dev/null || true)}"

if [ -z "$TOKEN" ]; then
  echo "缺少 token：写入 \$HOME/.gh_token，或导出 GH_TOKEN" >&2
  exit 1
fi

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "用法：bash publish.sh 文章.md" >&2
  exit 1
fi

DATE=$(date +%Y-%m-%d)
SLUG=$(date +%Y-%m-%d-%H%M)
TITLE=$(head -n 1 "$SRC" | sed -n 's/^#[[:space:]]*//p')
[ -n "$TITLE" ] || TITLE=$(basename "$SRC" .md)

# 上传单个文件（存在则更新）
put_file() {
  local path="$1" file="$2" msg="$3" sha body
  sha=$(curl -sS -m 20 \
          -H "Authorization: Bearer $TOKEN" \
          -H "Accept: application/vnd.github+json" \
          "$API/contents/$path" 2>/dev/null \
        | python3 -c 'import sys,json
try:
    d = json.load(sys.stdin)
    print(d.get("sha", "") if isinstance(d, dict) else "")
except Exception:
    print("")')

  body=$(python3 -c '
import base64, json, sys
path, f, msg, sha = sys.argv[1:5]
data = {"message": msg, "content": base64.b64encode(open(f, "rb").read()).decode(), "branch": "main"}
if sha:
    data["sha"] = sha
print(json.dumps(data))
' "$path" "$file" "$msg" "$sha")

  curl -sS -m 60 -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "$body" "$API/contents/$path" \
  | python3 -c 'import sys,json
d = json.load(sys.stdin)
if "content" in d:
    print("  ok   " + d["content"]["path"])
else:
    sys.exit("  失败  " + str(d.get("message")))'
}

echo "发布：$TITLE"
put_file "posts/$SLUG.md" "$SRC" "post: $TITLE"

# 取远端目录，插入新条目
curl -sS -m 20 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "$API/contents/posts/index.json" \
| python3 -c 'import sys,json,base64
d = json.load(sys.stdin)
sys.stdout.write(base64.b64decode(d["content"]).decode())' > "$HOME/.idx.json"

python3 - "$HOME/.idx.json" "$SLUG" "$TITLE" "$DATE" "$SRC" <<'PY'
import json, re, sys

idx_path, slug, title, date, src = sys.argv[1:6]
idx = json.load(open(idx_path, encoding='utf-8'))
text = open(src, encoding='utf-8').read()

body = re.sub(r'^#[^\n]*\n', '', text).strip()
summary = ''
for line in body.split('\n'):
    line = line.strip()
    if not line or line.startswith(('#', '```', '>', '-', '*', '|')):
        continue
    if re.match(r'^\d+[.)]\s', line):
        continue
    summary = re.sub(r'[`*_\[\]()!]', '', line).strip()
    break
summary = summary[:80]

posts = [p for p in idx.get('posts', []) if p.get('slug') != slug]
posts.insert(0, {'slug': slug, 'title': title, 'date': date, 'summary': summary})
posts.sort(key=lambda p: (p.get('date', ''), p.get('slug', '')), reverse=True)
idx['posts'] = posts
json.dump(idx, open(idx_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
PY

put_file "posts/index.json" "$HOME/.idx.json" "index: $TITLE"
rm -f "$HOME/.idx.json"

echo ""
echo "地址：https://$OWNER.github.io/post.html?p=$SLUG"
echo "Pages 约 30 秒后更新。"
