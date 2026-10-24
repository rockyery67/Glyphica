"""Original synthetic test fixtures alongside public scikit-image photographs."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
target = root / 'test/fixtures'
font = ImageFont.truetype(str(root / 'assets/fonts/Geist.ttf'), 150)
logo = Image.new('RGB', (600,400), 'white')
d=ImageDraw.Draw(logo)
d.rounded_rectangle((55,60,245,250), 40, fill='#111111')
d.text((80,58), '@', fill='white', font=font)
d.text((280,130), 'G', fill='#111111', font=font)
logo.save(target/'logo.png')
line = Image.new('RGB',(600,400),'white')
d=ImageDraw.Draw(line)
d.line([(40,340),(170,80),(300,340),(430,80),(560,340)],fill='black',width=6)
d.ellipse((220,100,380,260),outline='black',width=4)
line.save(target/'line.png')
transparent = Image.new('RGBA',(600,400),(255,0,255,0))
d=ImageDraw.Draw(transparent)
d.ellipse((150,50,450,350),fill=(0,0,0,255))
d.ellipse((215,130,255,170),fill=(255,255,255,255))
d.ellipse((345,130,385,170),fill=(255,255,255,255))
d.arc((235,175,365,275),0,180,fill=(255,255,255,255),width=12)
transparent.save(target/'transparent.png')
portrait = Image.open(target/'portrait.png').convert('RGB')
portrait.point(lambda value: int(value*.20)).save(target/'dark.png')
portrait.resize((320,320)).save(target/'format.webp',quality=90)
print('Created original logo, line, transparency, dark, and WebP fixtures.')
