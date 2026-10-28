#!/usr/bin/env python3
"""第3〜8回の開始構成・管理名を検証する。クラウド操作は行わない。"""
from pathlib import Path
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def check_lb_firewall_activation():
    step = ROOT / 'gcp/lesson3/2. loadbalancer'
    declaration = 'resource "google_compute_firewall" "allow_lb_to_web"'
    assert not (step / 'firewall_lb.tf').exists(), 'Step2のFirewallが最初から有効です'
    assert declaration in (step / 'firewall_lb.tf.example').read_text()
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for source in step.iterdir():
            if source.is_file() and (source.name.endswith(('.tf', '.tf.json', '.tf.example'))):
                shutil.copyfile(source, work / source.name)

        def active_text():
            return '\n'.join(p.read_text() for p in work.iterdir()
                             if p.name.endswith(('.tf', '.tf.json')))

        assert 'allow_lb_to_web' not in active_text(), '最初の構成にLB用Firewallが含まれています'
        (work / 'firewall_lb.tf.example').rename(work / 'firewall_lb.tf')
        assert active_text().count(declaration) == 1, '名前変更後のLB用Firewallが不正です'

    for name in ('3. dns', '4. ssl', 'syukudai1', 'syukudai2', 'syukudai3'):
        assert declaration in (step.parent / name / 'firewall_lb.tf').read_text(), f'後続のFirewallがありません: {name}'
    print('成功: Step2のFirewallが名前変更後にのみ読み込み対象となり、後続構成で保持されることを確認しました。')


def check():
    check_lb_firewall_activation()
    count = 0
    for n in range(3, 9):
        lesson = ROOT / f'gcp/lesson{n}'
        base = (lesson / '0. before/before.tf').read_text()
        assert not (lesson / 'start').exists(), f'第{n}回にstartが残っています'
        dirs = [d for d in sorted(lesson.iterdir()) if d.is_dir() and (d / 'common.tf').exists()]
        for d in dirs:
            assert (d / 'before.tf').exists(), f'開始構成がありません: {d}'
            assert (d / 'before.tf').read_text() == base, f'開始構成が不一致: {d}'
            all_text = '\n'.join(f.read_text() for f in d.glob('*.tf'))
            assert 'module.before.' not in all_text, f'旧参照が残っています: {d}'
            definitions = re.findall(r'^resource "([^"]+)" "([^"]+)"', all_text, re.M)
            assert len(definitions) == len(set(definitions)), f'リソースの重複: {d}'
            count += 1

    print(f'成功: {count}構成の開始リソースの保持・管理名の重複がないことを確認しました。')


if __name__ == '__main__':
    check()
