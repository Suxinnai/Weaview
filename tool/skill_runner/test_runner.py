from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import runner


class SkillRunnerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.skills_dir = self.root / "installed"
        self.source = self.root / "x-tweet-fetcher"
        (self.source / "scripts").mkdir(parents=True)
        (self.source / "SKILL.md").write_text(
            "# X Tweet Fetcher\n\nFetch tweets from X/Twitter.\n",
            encoding="utf-8",
        )
        (self.source / "scripts" / "fetch_tweet.py").write_text(
            "\n".join(
                [
                    "import argparse, json",
                    "parser = argparse.ArgumentParser()",
                    "parser.add_argument('--url')",
                    "args = parser.parse_args()",
                    "print(json.dumps({'text': 'tweet:' + args.url}))",
                ]
            ),
            encoding="utf-8",
        )
        self.skills_patch = mock.patch.object(runner, "SKILLS_DIR", self.skills_dir)
        self.skills_patch.start()
        self.addCleanup(self.skills_patch.stop)

    def test_install_parses_skill_markdown(self) -> None:
        manifest = runner.install_skill(str(self.source))

        self.assertEqual(manifest["id"], "x-tweet-fetcher")
        self.assertEqual(manifest["name"], "X Tweet Fetcher")
        self.assertEqual(manifest["entrypoints"][0]["id"], "fetch_tweet")

    def test_run_fetch_tweet_uses_allowlisted_script(self) -> None:
        manifest = runner.install_skill(str(self.source))

        result = runner.run_skill(
            manifest["id"],
            "看看 https://x.com/example/status/123",
            "fetch_tweet",
        )

        self.assertTrue(result["ok"])
        self.assertEqual(result["text"], "tweet:https://x.com/example/status/123")
        self.assertEqual(
            result["json"],
            {"text": "tweet:https://x.com/example/status/123"},
        )

    def test_run_requires_url(self) -> None:
        manifest = runner.install_skill(str(self.source))

        with self.assertRaises(ValueError):
            runner.run_skill(manifest["id"], "没有链接", "fetch_tweet")

    def test_non_allowlisted_skill_is_rejected(self) -> None:
        other = self.root / "other-skill"
        other.mkdir()
        (other / "SKILL.md").write_text("# Other\n\nDo something.\n", encoding="utf-8")
        manifest = runner.install_skill(str(other))

        with self.assertRaises(ValueError):
            runner.run_skill(manifest["id"], "https://example.com", "default")


if __name__ == "__main__":
    unittest.main()
