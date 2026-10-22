# Usage: python3 tool/check_jni_bindings.py <plugin>/lib/src/<x>.jni.dart build/app/outputs/flutter-apk/app-release.apk $ANDROID_HOME/build-tools/<v>/dexdump
# Fails if a method a jnigen binding looks up is missing from the release APK
# (renamed or removed by R8). See android/app/proguard-rules.pro.
# Checks every JNI method lookup in a jnigen binding against an APK's dex.
import re, subprocess, sys, zipfile, tempfile, os
binding, apk, dexdump = sys.argv[1:4]
src = open(binding).read()
# Pair each class with its method lookups: _class = ...forName(r'pkg/Cls') ... methodId(r'name', r'sig')
# Class paths by simple name, from every forName(r'pkg/Cls') in the binding.
paths = {c.split('/')[-1]: c for c in re.findall(r"forName\(\s*r'([^']+)'", src)}
wanted = []
for owner, kind, a, b in re.findall(
        r"(\w+)\._class\.(\w*[mM]ethodId|constructorId)\(\s*r'([^']+)'(?:\s*,\s*r'([^']+)')?", src):
    name, sig = ('<init>', a) if kind == 'constructorId' else (a, b)
    wanted.append(('L' + paths[owner] + ';', name, sig))
tmp = tempfile.mkdtemp()
with zipfile.ZipFile(apk) as z:
    dexes = [z.extract(n, tmp) for n in z.namelist() if re.fullmatch(r'classes\d*\.dex', n)]
have, cls, name = set(), None, None
for d in dexes:
    out = subprocess.run([dexdump, d], capture_output=True, text=True).stdout
    for line in out.splitlines():
        m = re.search(r"Class descriptor\s*:\s*'([^']+)'", line)
        if m: cls = m.group(1); continue
        m = re.search(r"^\s+name\s*:\s*'([^']+)'", line)
        if m: name = m.group(1); continue
        m = re.search(r"^\s+type\s*:\s*'(\(.*)'", line)
        if m and name: have.add((cls, name, m.group(1))); name = None
missing = [w for w in wanted if w not in have]
print(f"{len(wanted)} JNI lookups checked, {len(missing)} missing")
for c, n, s in missing: print("  MISSING", c, n, s)
sys.exit(1 if missing else 0)
