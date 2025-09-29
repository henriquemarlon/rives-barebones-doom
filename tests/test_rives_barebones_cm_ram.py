import pytest
import json
import os

from cartesapp.utils import bytes2hex, hex2str, hex2bytes
from cartesapp.testclient import TestClient

from model import *

###
# Tests

# test application setup
@pytest.fixture(scope='module')
def app_client() -> TestClient:
    os.environ['MACHINE_CONFIG'] = '{"ram_length":"24Mi"}'
    client = TestClient()
    yield client
    del os.environ['MACHINE_CONFIG']

# test payload
@pytest.fixture()
def nop_gameplay_payload() -> Payload:
    return Payload(
        outhash=NOP_GAMEPLAY_OUTHASH,
        gameplay_log=NOP_GAMEPLAY_LOG
    )

###
# tests receive

# test mutation
def test_should_fail_ram(
        app_client: TestClient,
        nop_gameplay_payload: Payload):

    hex_payload = bytes2hex(abi.encode_model(nop_gameplay_payload,True))

    last_notice_n = len(app_client.rollup.notices)
    last_report_n = len(app_client.rollup.reports)
    app_client.send_advance(hex_payload=hex_payload)

    assert app_client.rollup.status # No reverts
    assert len(app_client.rollup.notices) == last_notice_n
    assert len(app_client.rollup.reports) == last_report_n + 1

    report = app_client.rollup.reports[-1]['data']['payload']
    report_json = json.loads(hex2str(report))
    report_model = ErrorReport.parse_obj(report_json)
    assert report_model.error.code == STATUS_VERIFICATION_ERROR
