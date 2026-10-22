# Usage: python3 tool/check_jni_runtime.py build/app/outputs/flutter-apk/app-release.apk $ANDROID_HOME/build-tools/<v>/dexdump
# Fails if a class or member the Dart jni runtime needs is missing from the
# release APK. NEEDED mirrors package:jni lib/src/kotlin.dart.
# Verifies the JVM names that the Dart `jni` runtime and jni_flutter look up.
import re, subprocess, sys, zipfile, tempfile
apk, dexdump = sys.argv[1:3]
NEEDED = [  # (class, kind, name, signature); kind: class|field|method
    ('Lkotlin/coroutines/intrinsics/CoroutineSingletons;', 'class', '', ''),
    ('Lkotlin/Result$Failure;', 'field', 'exception', 'Ljava/lang/Throwable;'),
    ('Lkotlin/Result$Failure;', 'method', '<init>', '(Ljava/lang/Throwable;)V'),
    ('Lkotlin/Result;', 'field', 'value', 'Ljava/lang/Object;'),
    ('Lkotlin/coroutines/intrinsics/IntrinsicsKt;', 'method', 'getCOROUTINE_SUSPENDED', '()Ljava/lang/Object;'),
    ('Lkotlin/Unit;', 'field', 'INSTANCE', 'Lkotlin/Unit;'),
    ('Lkotlin/coroutines/Continuation;', 'method', 'resumeWith', '(Ljava/lang/Object;)V'),
    ('Lcom/github/dart_lang/jni/PortProxyBuilder;', 'class', '', ''),
    ('Lcom/github/dart_lang/jni_flutter/JniFlutterPlugin;', 'class', '', ''),
]
tmp = tempfile.mkdtemp()
with zipfile.ZipFile(apk) as z:
    dexes = [z.extract(n, tmp) for n in z.namelist() if re.fullmatch(r'classes\d*\.dex', n)]
classes = {}  # descriptor -> {'super': ..., 'fields': set, 'methods': set}
cur = section = None
for d in dexes:
    for line in subprocess.run([dexdump, d], capture_output=True, text=True).stdout.splitlines():
        if m := re.search(r"Class descriptor\s*:\s*'([^']+)'", line):
            cur = classes.setdefault(m.group(1), {'super': None, 'interfaces': [], 'fields': set(), 'methods': set()})
            section = None; name = None; continue
        if cur is None: continue
        if m := re.search(r"Superclass\s*:\s*'([^']+)'", line): cur['super'] = m.group(1); continue
        if re.search(r"(Static|Instance) fields", line): section = 'fields'; continue
        if re.search(r"(Direct|Virtual) methods", line): section = 'methods'; continue
        if m := re.search(r"^\s+#\d+\s*:\s*'([^']+)'", line): cur['interfaces'].append(m.group(1)) if section is None else None
        if m := re.search(r"^\s+name\s*:\s*'([^']+)'", line): name = m.group(1); continue
        if (m := re.search(r"^\s+type\s*:\s*'([^']+)'", line)) and section and name:
            cur[section].add((name, m.group(1))); name = None
def resolve(cls, kind, member):
    seen = set()
    stack = [cls]
    while stack:
        c = stack.pop()
        if c in seen or c not in classes: continue
        seen.add(c)
        if member in classes[c][kind]: return c
        stack += [classes[c]['super']] + classes[c]['interfaces']
    return None
bad = 0
for cls, kind, name, sig in NEEDED:
    if cls not in classes:
        ok, where = False, 'class missing'
    elif kind == 'class':
        ok, where = True, ''
    else:
        found = resolve(cls, kind + 's', (name, sig))
        ok, where = found is not None, (f'via {found}' if found and found != cls else '' if found else 'member missing')
    bad += not ok
    print(('ok      ' if ok else 'MISSING '), cls, name, sig, where)
sys.exit(1 if bad else 0)
