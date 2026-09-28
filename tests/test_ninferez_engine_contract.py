"""Host-only contract smoke tests for NInferEZ Engine executables."""

from __future__ import annotations

import json
import subprocess
import sys


def run_json(*command: str, expected_code: int = 0) -> dict:
    completed = subprocess.run(command, check=False, capture_output=True, text=True)
    assert completed.returncode == expected_code, completed.stderr
    return json.loads(completed.stdout)


def main() -> None:
    server, inspector = sys.argv[1:3]

    version = run_json(server, "--version-json")
    assert version["product"] == "NInferEZ Engine"
    assert version["contractVersion"] == 1
    assert version["cudaArchitecture"].startswith("sm")

    capabilities = run_json(server, "--capabilities-json")
    assert capabilities["contractVersion"] == version["contractVersion"]
    assert capabilities["serving"]["openAIResponses"] is True
    assert "rk8v4" in capabilities["kvFormats"]

    failure = run_json(inspector, "--model", "does-not-exist.ninfer", "--json", expected_code=1)
    assert failure["valid"] is False
    assert failure["error"]["code"] == "artifact_invalid"


if __name__ == "__main__":
    main()
