"""Small ADB inspection helper used for the documented emulator smoke test."""
import json
import subprocess
import sys
import xml.etree.ElementTree as ET

subprocess.run(['adb','shell','uiautomator','dump','/sdcard/glyphica-ui.xml'],capture_output=True,check=True)
xml=subprocess.check_output(['adb','shell','cat','/sdcard/glyphica-ui.xml']).decode()
nodes=[n.attrib for n in ET.fromstring(xml).iter('node') if n.get('text') or n.get('content-desc')]
for node in nodes:
    for key in ['text', 'content-desc']:
        if len(node.get(key,'')) > 220:
            node[key]=node[key][:140]+' ... [long artwork/description omitted]'
print(json.dumps([{k:n.get(k) for k in ['text','content-desc','bounds','clickable']} for n in nodes],ensure_ascii=True,indent=2))
