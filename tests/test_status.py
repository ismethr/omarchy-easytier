import importlib.machinery
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader("easytierctl", str(Path(__file__).parents[1] / "scripts/easytierctl"))
spec = importlib.util.spec_from_loader(loader.name, loader)
ctl = importlib.util.module_from_spec(spec)
loader.exec_module(ctl)


class StatusTest(unittest.TestCase):
    def service(self, state="active"):
        return SimpleNamespace(stdout=f"LoadState=loaded\nActiveState={state}\nUnitFileState=enabled\n")

    def test_status_never_exposes_core_configuration(self):
        node = {"ipv4_addr": "10.42.0.2/24", "version": "2.6.4", "proxy_cidrs": ["192.168.50.0/24"],
                "config": {"network_secret": "PRIVATE-TEST-SECRET", "network_name": "PRIVATE-NETWORK"},
                "stun_info": {"public_ip": "PRIVATE-PUBLIC-ADDRESS"}}
        with patch.object(ctl, "invoke", return_value=self.service()), patch.object(ctl, "rpc", side_effect=lambda *args: node if args[0] == "node" else []):
            data = ctl.status()
        serialized = json.dumps(data)
        for secret in ["PRIVATE-TEST-SECRET", "PRIVATE-NETWORK", "PRIVATE-PUBLIC-ADDRESS"]:
            self.assertNotIn(secret, serialized)
        self.assertTrue(data["rpc"])
        self.assertEqual(data["ip"], "10.42.0.2")

    def test_local_peer_not_counted_and_invalid_latency_not_emitted(self):
        peers = ctl.normalize_peers([
            {"ipv4": "10.42.0.2", "cost": "Local"},
            {"ipv4": "10.42.0.1", "cost": "p2p", "lat_ms": "NaN"},
            {"ipv4": "10.42.0.4", "cost": "relay(2)", "lat_ms": "-"},
        ])
        self.assertEqual(len(peers), 2)
        self.assertEqual([p["kind"] for p in peers], ["direct", "relay"])
        json.dumps(peers, allow_nan=False)

    def test_off_state_does_not_query_rpc_or_show_old_peers(self):
        with patch.object(ctl, "invoke", return_value=self.service("inactive")), patch.object(ctl, "rpc") as rpc:
            data = ctl.status()
        rpc.assert_not_called()
        self.assertFalse(data["running"])
        self.assertEqual(data["peers"], [])
        self.assertTrue(data["autostart"])

    def test_unavailable_rpc_does_not_claim_service_is_off(self):
        with patch.object(ctl, "invoke", return_value=self.service()), patch.object(ctl, "rpc", return_value=None):
            data = ctl.status()
        self.assertTrue(data["running"])
        self.assertFalse(data["rpc"])
        self.assertFalse(data["peers_ready"])

    def test_arbitrary_actions_never_reach_systemctl(self):
        with patch.object(ctl, "invoke") as invoke:
            self.assertFalse(ctl.action("disable sshd.service")["ok"])
        invoke.assert_not_called()


if __name__ == "__main__":
    unittest.main()
