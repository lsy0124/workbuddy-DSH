"""Check publish tree without opening any live credential store."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
errors = []
binary = ROOT / 'binaries' / 'WorkBuddyHelper.exe'
lock = json.loads((ROOT / 'dependencies.lock.json').read_text(encoding='utf-8-sig'))
if hashlib.sha256(binary.read_bytes()).hexdigest() != lock['helper']['windowsAmd64Sha256']:
    errors.append('Helper binary checksum mismatch')
for path in ROOT.rglob('*'):
    if not path.is_file() or '.git' in path.relative_to(ROOT).parts:
        continue
    rel = path.relative_to(ROOT)
    if path.name.lower() in {'state.bin', 'key.bin', '.env'} or path.suffix.lower() in {'.log', '.lnk'}:
        errors.append(f'Forbidden data file: {rel}')
    if path.suffix.lower() in {'.exe', '.png', '.jpg', '.jpeg', '.webp', '.ico', '.gif', '.woff2'}:
        continue
    try:
        text = path.read_text(encoding='utf-8-sig')
    except UnicodeError:
        continue
    if re.search(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}', text):
        errors.append(f'Potential GitHub token: {rel}')
    if re.search(r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----', text):
        errors.append(f'Potential private key: {rel}')
    # Upstream tests intentionally contain synthetic JWT fixtures; inspect local
    # integration files strictly and retain untouched upstream source provenance.
    if rel.parts[0] != 'vendor' and re.search(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}', text):
        errors.append(f'Potential real JWT: {rel}')
    if rel.parts[0] != 'vendor' and re.search(r'[A-Za-z]:\\Users\\(?!Public(?:\\|$))', text):
        errors.append(f'Personal absolute Windows path: {rel}')
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: binary checksum, forbidden data files and credential patterns checked.')
