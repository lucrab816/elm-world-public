import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bridge"))
import subscription_probe as probe

WORLD = json.loads((probe.ROOT / "world.sample.json").read_text())
GOOD = {"world_revision": 1, "action": "move", "target": "bench",
        "duration_seconds": 30, "reason": "前往长椅。"}


class DecisionValidation(unittest.TestCase):
    def test_valid_decision(self):
        self.assertEqual(probe.validate(GOOD, WORLD), GOOD)

    def test_reject_impossible_or_stale_decisions(self):
        changes = [
            {"world_revision": 0}, {"action": "execute_shell"}, {"action": []},
            {"target": "outside_world"}, {"duration_seconds": True},
            {"duration_seconds": 301}, {"reason": "x" * 181},
            {"action": "rest", "target": "bench"}, {"extra": "field"},
        ]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                probe.validate(dict(GOOD, **change), WORLD)

    def test_cli_missing_stays_local(self):
        with patch.object(probe.shutil, "which", return_value=None):
            result = probe.run_probe(WORLD)
        self.assertEqual(result["status"], "cli_missing")
        self.assertEqual(result["source"], "local_fallback")

    def test_login_failure_does_not_start_request(self):
        with patch.object(probe.shutil, "which", return_value="fake"), \
             patch.object(probe, "auth_is_subscription", return_value=False), \
             patch.object(probe.subprocess, "Popen") as start:
            self.assertEqual(probe.run_probe(WORLD)["status"], "subscription_login_required")
            start.assert_not_called()

    def fake_probe(self, body, timeout=3):
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / "fake-codex"
            fake.write_text("#!" + sys.executable + "\nimport sys,json,time\n"
                            "if 'login' in sys.argv:\n print('Logged in using ChatGPT'); sys.exit(0)\n"
                            + body)
            fake.chmod(0o755)
            with patch.object(probe.shutil, "which", return_value=str(fake)):
                return probe.run_probe(copy.deepcopy(WORLD), timeout=timeout)

    def test_invalid_response_falls_back(self):
        result = self.fake_probe("from pathlib import Path\nPath(sys.argv[sys.argv.index('-o')+1]).write_text('not json')\n")
        self.assertEqual(result["status"], "invalid_decision")

    def test_tool_activity_rejected(self):
        result = self.fake_probe("print(json.dumps({'type':'item.completed','item':{'type':'command_execution'}}))\n")
        self.assertEqual(result["status"], "unexpected_tool_activity")

    def test_timeout_stops_child_and_falls_back(self):
        result = self.fake_probe("time.sleep(10)\n", timeout=1)
        self.assertEqual(result["status"], "timeout")
        self.assertLess(result["metrics"]["elapsed_seconds"], 5)

    def test_successful_result_and_usage(self):
        result = self.fake_probe("from pathlib import Path\n"
                                 "Path(sys.argv[sys.argv.index('-o')+1]).write_text(" + repr(json.dumps(GOOD)) + ")\n"
                                 "print(json.dumps({'type':'turn.completed','usage':{'input_tokens':5,'output_tokens':2}}))\n")
        self.assertEqual(result["decision"], GOOD)
        self.assertEqual(result["metrics"]["token_usage"]["input_tokens"], 5)


class ChatValidation(unittest.TestCase):
    def fake_chat(self, body, timeout=3, cancel=None, world=None):
        world = world or {"_chat":True,"message":"你好","context":{"activity":"休息"}}
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp)/"fake-codex"
            fake.write_text("#!"+sys.executable+"\nimport sys,json,time\nif 'login' in sys.argv:\n print('Logged in using ChatGPT');sys.exit(0)\n"+body)
            fake.chmod(0o755)
            return probe.run_probe(world,timeout,cancel_file=cancel,cli_path=str(fake))

    def test_chat_success(self):
        result=self.fake_chat("from pathlib import Path\nPath(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'你好，我正在休息。'}))\n")
        self.assertEqual(result['source'],'codex_subscription')
        self.assertIn('休息',result['reply'])

    def test_rest_experience_is_supplied_with_caution(self):
        world = {"_chat": True, "message": "你喜欢在哪里休息？", "context": {
            "rest_experience": {"completed_in_recent_window": 2, "window_limit": 8,
                                "bench_count": 1, "shade_count": 1,
                                "observed_tendency": "尚不确定"}}}
        body = ("from pathlib import Path\n"
                "prompt=sys.stdin.read()\n"
                "assert 'rest_experience' in prompt and '尚不确定' in prompt\n"
                "assert '不要断言喜欢某地' in prompt and '不是全部经历' in prompt\n"
                "Path(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'我还没有明显的地点倾向。'}))\n")
        result = self.fake_chat(body, world=world)
        self.assertEqual(result['source'], 'codex_subscription')
        self.assertIn('没有明显', result['reply'])

    def test_chat_invalid_replies(self):
        for value in [{'reply':''},{'reply':'x'*1201},{'reply':3},{'reply':'ok','action':'move'}]:
            result=self.fake_chat("from pathlib import Path\nPath(sys.argv[sys.argv.index('-o')+1]).write_text("+repr(json.dumps(value))+")\n")
            self.assertEqual(result['status'],'invalid_decision')

    def test_chat_cancel_stops_group(self):
        import threading
        with tempfile.TemporaryDirectory() as tmp:
            cancel=Path(tmp)/'cancel'
            timer=threading.Timer(0.5,cancel.touch)
            timer.start()
            result=self.fake_chat("time.sleep(10)\n",cancel=cancel)
            timer.join()
        self.assertEqual(result['status'],'cancelled')
        self.assertLess(result.get('metrics',{}).get('elapsed_seconds',0),5)

    def test_chat_failure_diagnostic(self):
        result=self.fake_chat("sys.stderr.write('usage limit');sys.exit(1)\n")
        self.assertEqual(result['diagnostic'],'usage_limit')


class ProposalValidation(unittest.TestCase):
    fake_chat = ChatValidation.fake_chat
    # Reuse the isolated fake CLI, not a real subscription invocation.
    WORLD = {"_chat":True,"kind":"decision","decision_token":"a"*32,"message":"要不要歇一会儿？","context":{"activity":"看周围"}}
    def emit(self, value):
        return self.fake_chat("from pathlib import Path\nPath(sys.argv[sys.argv.index('-o')+1]).write_text("+repr(json.dumps(value))+")\n",world=self.WORLD)
    def test_allowed_proposal(self):
        value = {"reply":"想去歇一会儿。","proposal":"rest_in_shade","decision_token":"a"*32}
        result = self.emit(value)
        self.assertEqual(result["proposal"],"rest_in_shade")
        self.assertEqual(result["decision_token"],"a"*32)
    def test_choose_none(self):
        result = self.emit({"reply":"我想先看看周围。","proposal":"none","decision_token":"a"*32})
        self.assertEqual(result["proposal"],"none")
    def test_bad_fields_and_values(self):
        good = {"reply":"休息。","proposal":"rest_in_shade","decision_token":"a"*32}
        for mutation in [{"proposal":"run_shell"},{"proposal":[]},{"target":"home"},{"duration_seconds":999},{"reply":""},{"decision_token":"b"*32}]:
            with self.subTest(mutation=mutation):
                self.assertEqual(self.emit(dict(good,**mutation))["status"],"invalid_decision")
    def test_wrong_nonce_rejected_before_start(self):
        with patch.object(probe.subprocess,"Popen") as start:
            result = probe.run_probe(dict(self.WORLD,decision_token="invalid"))
        self.assertEqual(result["status"],"invalid_decision")
        start.assert_not_called()
    def test_plant_decision_has_separate_bounded_choices(self):
        world = dict(self.WORLD, kind="plant_decision", message="你想看看盆栽吗？")
        body = ("from pathlib import Path\n"
                "schema=json.loads(Path(sys.argv[sys.argv.index('--output-schema')+1]).read_text())\n"
                "assert schema['properties']['proposal']['enum']==['none','visit_plant']\n"
                "prompt=sys.stdin.read()\n"
                "assert 'visit_plant或none' in prompt and '不要求总是去' in prompt\n"
                "token=schema['properties']['decision_token']['enum'][0]\n"
                "Path(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'我去看看。','proposal':'visit_plant','decision_token':token}))\n")
        result = self.fake_chat(body, world=world)
        self.assertEqual(result['proposal'], 'visit_plant')

    def test_proposal_schema_has_only_allowed_fields(self):
        body = ("from pathlib import Path\n"
                "s=json.loads(Path(sys.argv[sys.argv.index('--output-schema')+1]).read_text())\n"
                "assert s['additionalProperties'] is False\n"
                "assert set(s['required'])=={'reply','proposal','decision_token'}\n"
                "assert s['properties']['proposal']['enum']==['none','rest_in_shade']\n"
                "token=s['properties']['decision_token']['enum'][0]\n"
                "Path(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'先不去。','proposal':'none','decision_token':token}))\n")
        self.assertEqual(self.fake_chat(body,world=self.WORLD)["proposal"],"none")


class SelfArrangementValidation(unittest.TestCase):
    fake_chat = ChatValidation.fake_chat
    def test_low_frequency_prompt_preserves_authorization_source(self):
        world = {"_chat": True, "kind": "self_arrangement", "decision_token": "c" * 32,
                 "context": {"allowed_choices": ["none"], "opportunity_source": "low_frequency"}}
        body = ("from pathlib import Path\n"
                "prompt=sys.stdin.read()\n"
                "assert '用户已授权的低频安排机会' in prompt\n"
                "assert '用户手动触发的有限决定' not in prompt\n"
                "Path(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'先继续日常。','proposal':'none','decision_token':'" + "c" * 32 + "'}))\n")
        self.assertEqual(self.fake_chat(body, world=world)["proposal"], "none")

    def test_self_arrangement_schema_and_choice(self):
        world = {"_chat": True, "kind": "self_arrangement", "message": "自己安排一次", "decision_token": "c" * 32,
                 "context": {"allowed_choices": ["none", "rest_in_shade", "visit_plant"], "energy": 80}}
        for choice in world["context"]["allowed_choices"]:
            body = ("from pathlib import Path\n"
                    "schema=json.loads(Path(sys.argv[sys.argv.index('--output-schema')+1]).read_text())\n"
                    "assert schema['properties']['proposal']['enum']==['none','rest_in_shade','visit_plant']\n"
                    "prompt=sys.stdin.read()\n"
                    "assert '没有指定具体活动' in prompt and 'allowed_choices' in prompt\n"
                    "token=schema['properties']['decision_token']['enum'][0]\n"
                    "Path(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'我想慢慢选一件小事。','proposal':" + repr(choice) + ",'decision_token':token}))\n")
            self.assertEqual(self.fake_chat(body, world=world)["proposal"], choice)

    def test_unavailable_choice_is_excluded_from_schema(self):
        world = {"_chat": True, "kind": "self_arrangement", "message": "自己安排一次", "decision_token": "c" * 32,
                 "context": {"allowed_choices": ["none", "rest_in_shade"]}}
        body = ("from pathlib import Path\n"
                "schema=json.loads(Path(sys.argv[sys.argv.index('--output-schema')+1]).read_text())\n"
                "assert schema['properties']['proposal']['enum']==['none','rest_in_shade']\n"
                "Path(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'想去看花。','proposal':'visit_plant','decision_token':'" + "c" * 32 + "'}))\n")
        self.assertEqual(self.fake_chat(body, world=world)["status"], "invalid_decision")

    def test_worker_accepts_one_off_kind(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            fake = base / "fake-codex"
            fake.write_text("#!" + sys.executable + "\nimport sys,json\nfrom pathlib import Path\n"
                            "if 'login' in sys.argv:\n print('Logged in using ChatGPT'); sys.exit(0)\n"
                            "s=json.loads(Path(sys.argv[sys.argv.index('--output-schema')+1]).read_text())\n"
                            "t=s['properties']['decision_token']['enum'][0]\n"
                            "Path(sys.argv[sys.argv.index('-o')+1]).write_text(json.dumps({'reply':'先继续日常。','proposal':'none','decision_token':t}))\n")
            fake.chmod(0o755)
            source = base / "input.json"
            output = base / "output.json"
            source.write_text(json.dumps({"kind": "self_arrangement", "message": "自己安排一次", "decision_token": "c" * 32,
                                          "context": {"allowed_choices": ["none"]}}))
            result = probe.subprocess.run([sys.executable, str(probe.ROOT / "chat_worker.py"), "--input", str(source), "--output", str(output),
                                           "--cancel", str(base / "cancel"), "--cli", str(fake)], capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(json.loads(output.read_text())["proposal"], "none")

    def test_invalid_choice_set_sends_nothing(self):
        for choices in [[], ["build_house"], ["none", "none"], ["none", 3]]:
            world = {"_chat": True, "kind": "self_arrangement", "decision_token": "c" * 32,
                     "context": {"allowed_choices": choices}}
            with patch.object(probe.subprocess, "Popen") as start:
                self.assertEqual(probe.run_probe(world)["status"], "invalid_decision")
            start.assert_not_called()


if __name__ == "__main__":
    unittest.main()
