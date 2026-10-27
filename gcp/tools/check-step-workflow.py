#!/usr/bin/env python3
"""第3〜8回の開始構成・管理名を検証する。クラウド操作は行わない。"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def check():
    count = 0
    for n in range(3, 9):
        lesson = ROOT / f'gcp/lesson{n}'
        base = (lesson / '0. before/before.tf').read_text()
        addresses = set(re.findall(r'^resource "([^"]+)" "([^"]+)"', base, re.M))
        assert not (lesson / 'start').exists(), f'第{n}回にstartが残っています'
        dirs = [d for d in sorted(lesson.iterdir()) if d.is_dir() and (d / 'before.tf').exists()]
        for d in dirs:
            assert (d / 'before.tf').read_text() == base, f'開始構成が不一致: {d}'
            all_text = '\n'.join(f.read_text() for f in d.glob('*.tf') if f.name != 'before_moved.tf')
            assert 'module.before.' not in all_text, f'旧参照が残っています: {d}'
            definitions = re.findall(r'^resource "([^"]+)" "([^"]+)"', all_text, re.M)
            assert len(definitions) == len(set(definitions)), f'リソースの重複: {d}'
            moved = (d / 'before_moved.tf').read_text()
            for kind, name in addresses:
                assert f'from = module.before.{kind}.{name}' in moved
                assert f'to   = {kind}.{name}' in moved
            count += 1

    print(f'成功: {count}構成の管理名・移行宣言を確認しました。')


if __name__ == '__main__':
    check()
