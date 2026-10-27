"""個人設定の再利用・変更範囲・不正入力時の非更新を検証する。"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('configure.py')
ROOT = SCRIPT.resolve().parents[2]
spec = importlib.util.spec_from_file_location('configure', SCRIPT)
configure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(configure)


class ConfigureTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.work = Path(self.tmp.name) / 'work'
        self.work.mkdir()
        self.config = Path(self.tmp.name) / 'settings/profile.json'
        self.env = dict(os.environ, INFRA_STUDY_CONFIG=str(self.config))
        self.copy(ROOT / 'gcp/lesson3/0. before')

    def copy(self, source):
        for name in ('common.tf', 'terraform.tfvars'):
            shutil.copyfile(source / name, self.work / name)

    def run_script(self, *args, stdin='', cwd=None):
        return subprocess.run([sys.executable, str(SCRIPT), *args], input=stdin,
                              text=True, capture_output=True, cwd=cwd or self.work, env=self.env)

    def test_first_run_reuse_and_edit(self):
        result = self.run_script(stdin='example-project\ntest-user\n\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        dirs = sorted(p.parent for p in (ROOT / 'gcp').glob('lesson[3-8]/*/common.tf'))
        for d in dirs:
            with self.subTest(directory=str(d)):
                self.copy(d)
                old_common = (self.work / 'common.tf').read_text()
                old_vars = (self.work / 'terraform.tfvars').read_text()
                (self.work / 'terraform.tfstate').write_text('stateの検証用')
                result = self.run_script()
                self.assertEqual(result.returncode, 0, result.stderr)
                profile = json.loads(self.config.read_text())
                # 反映対象を元の値へ戻せば、ファイル全体が一致する。
                import re
                old = {key: re.search(rf'(?m)^\s*{key}\s*=\s*"([^"]*)"', text)[1]
                       for key, text in [('bucket', old_common), ('project_id', old_vars), ('user_name', old_vars)]}
                actual = configure.render((self.work / 'common.tf').read_text(),
                                          (self.work / 'terraform.tfvars').read_text(), old)
                self.assertEqual(actual, (old_common, old_vars))
                self.assertIn(profile['project_id'], (self.work / 'terraform.tfvars').read_text())
                self.assertEqual((self.work / 'terraform.tfstate').read_text(), 'stateの検証用')
                snapshot = [(self.work / f).read_bytes() for f in ('common.tf', 'terraform.tfvars')]
                self.assertEqual(self.run_script().returncode, 0)
                self.assertEqual(snapshot, [(self.work / f).read_bytes() for f in ('common.tf', 'terraform.tfvars')])
        result = self.run_script('--edit', stdin='other-project\nother-user\nother-state-bucket\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.config.read_text())['user_name'], 'other-user')

    def test_invalid_input_or_missing_assignment_does_not_write(self):
        original = [(self.work / f).read_bytes() for f in ('common.tf', 'terraform.tfvars')]
        result = self.run_script(stdin='bad"input\ntest-user\nexample-state\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.config.exists())
        self.assertEqual(original, [(self.work / f).read_bytes() for f in ('common.tf', 'terraform.tfvars')])
        (self.work / 'terraform.tfvars').write_text('user_name = "test-user"\n')
        result = self.run_script(stdin='example-project\ntest-user\nexample-state\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.work / 'common.tf').read_bytes(), original[0])
        self.assertFalse(self.config.exists())

    def test_repository_and_symlink_are_rejected(self):
        self.assertNotEqual(self.run_script(cwd=ROOT / 'gcp/lesson3/0. before').returncode, 0)
        (self.work / 'common.tf').unlink()
        (self.work / 'common.tf').symlink_to(ROOT / 'gcp/lesson3/0. before/common.tf')
        self.assertNotEqual(self.run_script().returncode, 0)

    def test_copy_keeps_step_directories_and_shared_backend(self):
        # 検証用教材には個人設定だけを複製し、実環境のキャッシュやstateは読み込まない。
        sources = Path(self.tmp.name) / 'sources'
        works = Path(self.tmp.name) / 'works'
        for n in range(3, 9):
            parent = works / f'lesson{n}'
            parent.mkdir(parents=True)
            for common in sorted((ROOT / f'gcp/lesson{n}').glob('*/common.tf')):
                step = common.parent.name
                source = sources / f'lesson{n}' / step
                source.mkdir(parents=True)
                for name in ('common.tf', 'terraform.tfvars'):
                    shutil.copyfile(common.parent / name, source / name)
                subprocess.run(['cp', '-rf', str(source), './'], cwd=parent, check=True)
                target = parent / step
                self.assertTrue((target / 'common.tf').is_file())
                self.assertFalse((parent / 'common.tf').exists())
                result = self.run_script(cwd=target, stdin='example-project\ntest-user\nexample-state\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                text = (target / 'common.tf').read_text()
                self.assertIn('bucket = "example-state"', text)
                self.assertIn(f'prefix = "lesson{n}"', text)
                # 同じディレクトリをもう一度コピーしても、余分な階層を作らない。
                subprocess.run(['cp', '-rf', str(source), './'], cwd=parent, check=True)
                self.assertFalse((target / step).exists())


if __name__ == '__main__':
    unittest.main()
