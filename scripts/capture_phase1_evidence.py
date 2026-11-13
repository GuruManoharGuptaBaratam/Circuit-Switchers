#!/usr/bin/env python3
"""Reproduce component evidence; never treat stub elaboration as system testing."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
from datetime import datetime
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / 'results/logs'
WAVES = ROOT / 'results/waveforms'
LOGS.mkdir(parents=True, exist_ok=True)

# Ensure Homebrew path is in PATH if needed
env = dict(os.environ)
if '/opt/homebrew/bin' not in env.get('PATH', ''):
    env['PATH'] = f"/opt/homebrew/bin:{env.get('PATH', '')}"

def run(args, logfile=None):
    result = subprocess.run(args, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if logfile:
        (LOGS / logfile).write_text('$ ' + ' '.join(args) + '\n' + result.stdout + f'\nEXIT STATUS: {result.returncode}\n')
    return result

records = []
for script, log in [('run_address_decoder_test.sh', 'address_decoder_audit_final.log'),
                    ('run_cache_storage_test.sh', 'cache_storage_audit_final.log'),
                    ('run_cache_lookup_test.sh', 'cache_lookup_audit_final.log'),
                    ('check_cache_top.sh', 'cache_top_audit_final.log')]:
    result = run(['bash', 'scripts/' + script], log)
    print(result.stdout)
    records.append({'command': 'bash scripts/' + script, 'exit_status': result.returncode, 'log': 'results/logs/' + log})
    if result.returncode:
        raise SystemExit(result.returncode)

for name in ['address_decoder', 'cache_storage', 'cache_lookup']:
    source = WAVES / (name + '.vcd')
    if not source.is_file() or source.stat().st_size == 0:
        raise SystemExit('Missing waveform: ' + str(source))
    shutil.copyfile(source, WAVES / (name + '_final.vcd'))

args = ['iverilog', '-g2012', '-Wall', '-s', 'cache_top', '-o', 'build/cache_top_without_stubs']
args += [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'rtl').glob('*.v'))]
integrated = run(args, 'cache_top_without_stubs_final.log')
print(integrated.stdout)
files = sorted((ROOT / 'rtl').glob('*.v')) + sorted((ROOT / 'tb').rglob('*.v'))
files += sorted(WAVES.glob('*_final.vcd'))
manifest = {
    'captured_at': datetime.now(ZoneInfo('Asia/Kolkata')).isoformat(),
    'source_commit': run(['git', 'rev-parse', 'HEAD']).stdout.strip(),
    'iverilog': run(['iverilog', '-V']).stdout.splitlines()[0],
    'vvp': run(['vvp', '-V']).stdout.splitlines()[0],
    'component_runs': records,
    'without_stubs_exit_status': integrated.returncode,
    'without_stubs_log': 'results/logs/cache_top_without_stubs_final.log',
    'integrated_functional_tests': 'NOT RUN: no system testbench or complete cache RTL',
    'scope': 'Unit tests and stub-assisted port elaboration only. No measured hit rate, AMAT, synthesis area or Fmax.',
    'sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
}
(ROOT / 'results/phase1_evidence.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Saved component logs, selected final VCDs and results/phase1_evidence.json')
