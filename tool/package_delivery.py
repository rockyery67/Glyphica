"""Package reproducible source and the complete Windows release directory."""
from pathlib import Path
import hashlib
import shutil
import zipfile

root=Path(__file__).resolve().parent.parent
target=root/'dist'
target.mkdir(exist_ok=True)
shutil.copy2(root/'build/app/outputs/flutter-apk/app-release.apk',target/'glyphica-1.0.0.apk')
native=root/'build/windows/x64/runner/Release'
with zipfile.ZipFile(target/'glyphica-windows-1.0.0.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for file in native.rglob('*'):
        if file.is_file(): archive.write(file,Path('Glyphica')/file.relative_to(native))
roots=['lib','assets','android','ios','windows','test','integration_test','tool','docs']
excluded_parts={'.dart_tool','.gradle','.cxx','build','ephemeral','.plugin_symlinks','__pycache__'}
excluded_names={'local.properties','GeneratedPluginRegistrant.java','GeneratedPluginRegistrant.h','GeneratedPluginRegistrant.m',
                'Generated.xcconfig','flutter_export_environment.sh','.DS_Store','key.properties'}
with zipfile.ZipFile(target/'glyphica-project-1.0.0.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for name in ['pubspec.yaml','pubspec.lock','analysis_options.yaml','README.md','LICENSE','.gitignore','.metadata']:
        file=root/name
        if file.exists(): archive.write(file,Path('glyphica')/name)
    for folder in roots:
        for file in (root/folder).rglob('*'):
            if file.is_file() and not (excluded_parts & set(file.relative_to(root).parts)) and file.name not in excluded_names:
                if file.suffix not in {'.jks','.keystore','.log','.pyc'}:
                    archive.write(file,Path('glyphica')/file.relative_to(root))
with (target/'SHA256SUMS.txt').open('w',encoding='ascii') as out:
    for file in sorted(target.iterdir()):
        if file.suffix in {'.apk','.zip'}:
            digest=hashlib.sha256(file.read_bytes()).hexdigest()
            out.write(f'{digest}  {file.name}\n')
            print(f'{file.name}: {file.stat().st_size:,} bytes')
