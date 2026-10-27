#!/usr/bin/env python3
"""第3〜8回の開始構成・管理名・展開時の個人設定保持を検証する。クラウド操作は行わない。"""
from pathlib import Path
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PREPARE = ROOT / 'gcp/tools/prepare-step.sh'


def check():
    count = 0
    with tempfile.TemporaryDirectory(prefix='infra-step-check-') as tmp:
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

            work_root = Path(tmp) / str(n)
            env = dict(os.environ, INFRA_STUDY_WORK_ROOT=str(work_root))
            work = work_root / f'lesson{n}'

            def prepare(step):
                subprocess.run(['bash', str(PREPARE), str(n), step], env=env, check=True, capture_output=True)

            prepare('0. before')
            assert not (work / '0. before').exists(), 'ディレクトリではなく中身を展開する必要があります'
            preserved = {'common.tf': '// 個人のbackend設定\n', 'terraform.tfvars': 'user_name = "test-user"\n', 'terraform.tfstate': '{"検証用": true}\n'}
            for name, text in preserved.items():
                (work / name).write_text(text)
            (work / '.terraform').mkdir()
            (work / '.terraform/keep').write_text('初期化済みデータ')
            for d in dirs:
                if not re.match(r'[1-9]\d*\. ', d.name):
                    continue
                prepare(d.name)
                for name, text in preserved.items():
                    assert (work / name).read_text() == text, f'個人設定が上書きされました: {name}'
                assert (work / '.terraform/keep').read_text() == '初期化済みデータ'
                assert (work / 'terraform.tfvars.example').read_text() == (d / 'terraform.tfvars').read_text()
            # 前のステップへ戻す操作は、余分な定義を残したまま成功してはいけない。
            (work / 'unexpected.tf').write_text('// 手元の追加ファイル\n')
            before = {str(p.relative_to(work)): p.read_bytes() for p in work.rglob('*') if p.is_file()}
            rejected = subprocess.run(['bash', str(PREPARE), str(n), '0. before'], env=env, capture_output=True)
            assert rejected.returncode != 0
            after = {str(p.relative_to(work)): p.read_bytes() for p in work.rglob('*') if p.is_file()}
            assert before == after, '停止時にファイルが変更されました'
    print(f'成功: {count}構成の管理名・移行宣言と、6回分の設定/state保持を確認しました。')


if __name__ == '__main__':
    check()
