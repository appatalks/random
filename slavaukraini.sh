#!/usr/bin/env bash
# For 2014 - Slava Ukraini in Binary
set -euo pipefail

# --- repo over SSH instead of HTTPS ---
REPO_URL="git@github.com:OWNER/REPO.git"

WORK_DIR="$(mktemp -d)"
git clone "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR"

# create / switch to the art branch for 2014
touch billboard.txt
git add billboard.txt
git commit --allow-empty -m "📊 start 2014 binary art"

python3 <<'PY'
# --- paste into a python3 <<'PY' … PY block ---
import datetime, subprocess, os

rows, cols = 7, 53
grid = [[0]*cols for _ in range(rows)]
L, R = 2, 2          # 2-column padding each side
line1 = "010100110100110001000001010101100100000101010101"
line2 = "010010110101001001000001010010010100111001001001"

for i,b in enumerate(line1):
    if b == "1": grid[2][L+i] = 1
for i,b in enumerate(line2):
    if b == "1": grid[4][L+i] = 1

base = datetime.date(2013,12,29)   # Sunday before 2014

def commit_at(day):
    ts = f"{day}T12:00:00"
    env = dict(os.environ, GIT_AUTHOR_DATE=ts, GIT_COMMITTER_DATE=ts)
    subprocess.run("git commit --allow-empty -m pixel", shell=True, env=env, check=True)

for x in range(cols):
    for y in range(rows):
        if grid[y][x]:
            d = base + datetime.timedelta(days=x*7+y)
            commit_at(d)
PY

git push -u origin main
echo "Done.  Ready to view 2014 contributions."
