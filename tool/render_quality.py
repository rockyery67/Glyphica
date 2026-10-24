"""Render engine-produced text without reflow, for visual QA (Pillow)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parent.parent
manifest=json.loads((root/'docs/quality/manifest.json').read_text())
font=ImageFont.truetype(str(root/'assets/fonts/JetBrainsMono-Regular.ttf'),12)
dots=ImageFont.truetype(str(root/'assets/fonts/GlyphicaDots.ttf'),12)
label=ImageFont.truetype(str(root/'assets/fonts/Geist.ttf'),18)
for name in dict.fromkeys(row['name'] for row in manifest):
    rows=[row for row in manifest if row['name']==name]
    width=750
    cell_height=840
    sheet=Image.new('RGB',(width*3,cell_height*2),'#f2f0ed')
    for index,row in enumerate(rows):
        x=(index+1)%3*width
        y=(index+1)//3*cell_height
        d=ImageDraw.Draw(sheet)
        d.text((x+20,y+16),row['look']+' · '+str(row['characters'])+' characters',font=label,fill='#202020')
        text=(root/row['text']).read_text(encoding='utf-8')
        chosen=dots if row['look']=='braille' else font
        for line_index,line in enumerate(text.split('\n')):
            d.text((x+15,y+55+line_index*14.4),line,font=chosen,fill='#141817',stroke_width=0)
    source=Image.open(root/rows[0]['source']).convert('RGBA')
    background=Image.new('RGBA',source.size,'white'); background.alpha_composite(source)
    background.thumbnail((700,560))
    sheet.paste(background.convert('RGB'),(20,60))
    ImageDraw.Draw(sheet).text((20,16),name+' · source',font=label,fill='#202020')
    sheet.save(root/'docs/quality'/f'{name}-comparison.jpg',quality=92)
print('Rendered comparison contact sheets.')
