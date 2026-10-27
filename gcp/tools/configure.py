#!/usr/bin/env python3
"""コピー済み教材の個人設定だけを反映する。コピー・Terraform実行は行わない。"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FIELDS = {
    "project_id": ("プロジェクトID", r"[a-z][a-z0-9-]{4,28}[a-z0-9]"),
    "user_name": ("ユーザ名（小文字英数字・ハイフン）", r"[a-z][a-z0-9-]*[a-z0-9]"),
    "bucket": ("作成済みのtfstate用GCSバケット名（gs://不要）", r"[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]"),
}


def assignment(text, key, value):
    pattern = rf'(?m)^(\s*{key}\s*=\s*)"[^"\n]*"'
    result, count = re.subn(pattern, lambda m: m[1] + json.dumps(value, ensure_ascii=False), text)
    if count != 1:
        raise ValueError(f'{key} の文字列設定が1件必要です（検出: {count}件）。')
    return result


def render(common, tfvars, profile):
    # backend以外のbucket属性や、回ごとのprefixは変更しない。
    pattern = r'(backend\s+"gcs"\s*\{)([^{}]*)(\})'
    matches = list(re.finditer(pattern, common))
    if len(matches) != 1:
        raise ValueError('common.tf にGCS backendが1件必要です。')
    m = matches[0]
    backend = assignment(m[2], 'bucket', profile['bucket'])
    common = common[:m.start(2)] + backend + common[m.end(2):]
    for key in ('project_id', 'user_name'):
        tfvars = assignment(tfvars, key, profile[key])
    return common, tfvars


def write_private(path, text):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(text)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--edit', action='store_true', help='保存した個人設定を入力し直す')
    args = parser.parse_args()
    work = Path.cwd().resolve()
    if work == ROOT or ROOT in work.parents:
        raise ValueError('教材リポジトリ内では実行できません。コピー先の作業ディレクトリで実行してください。')
    files = [work / 'common.tf', work / 'terraform.tfvars']
    if any(p.is_symlink() or not p.is_file() for p in files):
        raise ValueError('作業ディレクトリに通常ファイルの common.tf と terraform.tfvars が必要です。')
    original = [p.read_text(encoding='utf-8') for p in files]
    config = Path(os.environ.get('INFRA_STUDY_CONFIG', '~/.config/infra-study/profile.json')).expanduser()
    if config.resolve() == ROOT or ROOT in config.resolve().parents:
        raise ValueError('個人設定の保存先は教材リポジトリの外にしてください。')
    profile = json.loads(config.read_text()) if config.exists() else {}
    if not isinstance(profile, dict):
        raise ValueError('保存済みの個人設定はJSONオブジェクトである必要があります。')
    if args.edit or not config.exists():
        for key, (label, _) in FIELDS.items():
            default = profile.get(key, '')
            if key == 'bucket' and not default:
                default = f"{profile['project_id']}-tfstate-{profile['user_name']}"
            value = input(f'{label}' + (f' [{default}]' if default else '') + ': ').strip()
            profile[key] = value or default
    for key, (_, pattern) in FIELDS.items():
        if not isinstance(profile.get(key), str) or not re.fullmatch(pattern, profile[key]):
            raise ValueError(f'{key} の形式が不正です。--edit で再設定してください。')
    # 両方のファイルを検査してから書き込む。構文の不一致時には変更しない。
    updated = render(*original, profile)
    write_private(config, json.dumps({k: profile[k] for k in FIELDS}, ensure_ascii=False, indent=2) + '\n')
    for path, old, new in zip(files, original, updated):
        if old != new:
            write_private(path, new)
    print(f"反映先: {work}")
    for key in FIELDS:
        print(f"  {key} = {profile[key]}")
    print(f'次回も使う設定: {config}（変更する場合は --edit）')
    print('prefix・その他の変数・stateは変更していません。各回固有の値を確認し、terraform planで差分を確認してください。')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, EOFError) as exc:
        print(f'設定を反映できませんでした: {exc}', file=sys.stderr)
        sys.exit(1)
