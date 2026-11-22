# Vazirmatn (SIL OFL 1.1)

Before running Flutter locally for the first time, execute:

```bash
python3 tool/fetch_local_fonts.py
```

The script downloads Regular (400), Medium (500), Bold (700) and ExtraBold
(800) from a pinned commit of the official `rastikerdar/vazirmatn` project,
verifies each file's Git blob SHA-1, and stores the real TTF files in this
folder. The same step runs in GitHub Actions **before** `flutter pub get`, so
these fonts are embedded in the APK and do not require a network connection
at runtime. The font's full `OFL.txt` license is included by the script.
