"""Render the app's typographic brand mark into native launcher resources."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parent.parent
image=Image.new('RGB',(1024,1024),'#1b1c1c')
d=ImageDraw.Draw(image)
font=ImageFont.truetype(str(root/'assets/fonts/JetBrainsMono-Regular.ttf'),660)
d.text((130,60),'@',font=font,fill='#fbf9f8')
d.ellipse((755,745,835,825),fill='#e78760')
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    image.resize((size,size),Image.Resampling.LANCZOS).save(root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
for icon in (root/'ios/Runner/Assets.xcassets/AppIcon.appiconset').glob('*.png'):
    size=Image.open(icon).size
    image.resize(size,Image.Resampling.LANCZOS).save(icon)
image.save(root/'windows/runner/resources/app_icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
print('Rendered native launcher icons.')
