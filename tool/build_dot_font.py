"""Build Glyphica's original fixed-cell Braille fallback font (fontTools).
Each advance is 600 units in a 1200-unit line: the preview's 0.5 cell aspect.
"""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

root = Path(__file__).resolve().parent.parent
font = FontBuilder(1000, isTTF=True)
names = ['.notdef'] + [f'uni{cp:04X}' for cp in range(0x2800, 0x2900)]
font.setupGlyphOrder(names)
font.setupCharacterMap({cp: f'uni{cp:04X}' for cp in range(0x2800, 0x2900)})
glyphs, metrics = {}, {}
for name in names:
    pen = TTGlyphPen(None)
    bits = int(name[3:], 16) - 0x2800 if name != '.notdef' else 0
    for index, (x, y) in enumerate([(150,850),(150,550),(150,250),(450,850),(450,550),(450,250),(150,-50),(450,-50)]):
        if bits & (1 << index):
            r = 73
            pen.moveTo((x+r, y))
            pen.qCurveTo((x+r,y+r), (x,y+r))
            pen.qCurveTo((x-r,y+r), (x-r,y))
            pen.qCurveTo((x-r,y-r), (x,y-r))
            pen.qCurveTo((x+r,y-r), (x+r,y))
            pen.closePath()
    glyphs[name] = pen.glyph()
    metrics[name] = (600, 0)
font.setupGlyf(glyphs)
font.setupHorizontalMetrics(metrics)
font.setupHorizontalHeader(ascent=1000, descent=-200)
font.setupNameTable({'familyName':'GlyphicaDots', 'styleName':'Regular', 'uniqueFontIdentifier':'GlyphicaDots 1.0',
                    'fullName':'GlyphicaDots Regular', 'psName':'GlyphicaDots-Regular', 'version':'Version 1.0',
                    'licenseDescription':'Original Glyphica dot geometry. Licensed under the MIT License.'})
font.setupOS2(sTypoAscender=1000, sTypoDescender=-200, usWinAscent=1000, usWinDescent=200)
font.setupPost(isFixedPitch=1)
font.save(root / 'assets/fonts/GlyphicaDots.ttf')
print('Built all 256 Braille cells.')
