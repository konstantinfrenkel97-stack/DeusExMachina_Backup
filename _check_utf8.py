import os

godot_dir = 'd:/dOCS/test/.godot'
bad_files = []

for root, dirs, files in os.walk(godot_dir):
    for fname in files:
        fpath = os.path.join(root, fname)
        try:
            with open(fpath, 'rb') as f:
                data = f.read()
        except:
            continue
        # Check for broken UTF-8 (d0/d1 lead bytes without valid continuation)
        i = 0
        found = False
        while i < len(data):
            b = data[i]
            if b in (0xd0, 0xd1):
                if i + 1 < len(data) and not (0x80 <= data[i+1] <= 0xbf):
                    found = True
                    break
                i += 2
            else:
                i += 1
        if found:
            bad_files.append(fpath)

for f in sorted(bad_files):
    print(f)
print(f"Total bad files in .godot: {len(bad_files)}")
