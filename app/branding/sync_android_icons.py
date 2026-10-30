"""Export Android vectors and portable SVG layers from baya-mark.svg.

Only Python's standard library is required. Android applies its own launcher
mask, so the in-app tile rim is intentionally omitted from its background.
"""
from copy import deepcopy
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
RES = ROOT.parent / 'android/app/src/main/res/drawable'
SVG = 'http://www.w3.org/2000/svg'
ANDROID = 'http://schemas.android.com/apk/res/android'
AAPT = 'http://schemas.android.com/aapt'
ET.register_namespace('', SVG)
ET.register_namespace('android', ANDROID)
ET.register_namespace('aapt', AAPT)
source = ET.parse(ROOT / 'baya-mark.svg').getroot()
defs = source.find(f'{{{SVG}}}defs')
bird = source.find(f"{{{SVG}}}g[@id='baya-bird']")
gradients = {item.attrib['id']: item for item in defs if item.tag.endswith('linearGradient')}


def color(value, opacity=1):
    digits = value.removeprefix('#')
    if len(digits) == 3:
        digits = ''.join(char * 2 for char in digits)
    return f'#{round(float(opacity) * 255):02X}{digits.upper()}'


def paint(path, attribute, value):
    if value.startswith('url(#'):
        gradient = gradients[value[5:-1]]
        holder = ET.SubElement(path, f'{{{AAPT}}}attr', {'name': f'android:{attribute}'})
        shader = ET.SubElement(holder, 'gradient', {
            f'{{{ANDROID}}}type': 'linear',
            **{f'{{{ANDROID}}}{target}': gradient.attrib[key] for key, target in
               [('x1', 'startX'), ('y1', 'startY'), ('x2', 'endX'), ('y2', 'endY')]},
        })
        for stop in gradient:
            ET.SubElement(shader, 'item', {
                f'{{{ANDROID}}}offset': stop.get('offset', '0'),
                f'{{{ANDROID}}}color': color(stop.get('stop-color'), stop.get('stop-opacity', '1')),
            })
    else:
        path.set(f'{{{ANDROID}}}{attribute}', '@android:color/transparent' if value == 'none' else color(value))


def path_to_vector(parent, element):
    transform = element.get('transform')
    if transform:
        match = re.fullmatch(r'translate\(([-.\d]+)[ ,]+([-.\d]+)\)', transform)
        if not match:
            raise ValueError(f'Unsupported path transform: {transform}')
        parent = ET.SubElement(parent, 'group', {
            f'{{{ANDROID}}}translateX': match[1], f'{{{ANDROID}}}translateY': match[2],
        })
    path = ET.SubElement(parent, 'path', {f'{{{ANDROID}}}pathData': element.attrib['d']})
    for key, target in [('fill', 'fillColor'), ('stroke', 'strokeColor')]:
        if key in element.attrib:
            paint(path, target, element.attrib[key])
    for key, target in [('fill-rule', 'fillType'), ('stroke-width', 'strokeWidth'),
                        ('stroke-linecap', 'strokeLineCap'), ('stroke-linejoin', 'strokeLineJoin'),
                        ('stroke-opacity', 'strokeAlpha')]:
        if key in element.attrib:
            path.set(f'{{{ANDROID}}}{target}', element.attrib[key].replace('evenodd', 'evenOdd'))
    if 'opacity' in element.attrib:
        path.set(f'{{{ANDROID}}}fillAlpha', element.attrib['opacity'])


def vector():
    return ET.Element('vector', {f'{{{ANDROID}}}width': '108dp', f'{{{ANDROID}}}height': '108dp',
                                f'{{{ANDROID}}}viewportWidth': '108', f'{{{ANDROID}}}viewportHeight': '108'})


def safe_group(parent, svg=False):
    return ET.SubElement(parent, f'{{{SVG}}}g' if svg else 'group',
                         {'transform': 'translate(11.88 11.88) scale(.78)'} if svg else {
                             f'{{{ANDROID}}}pivotX': '54', f'{{{ANDROID}}}pivotY': '54',
                             f'{{{ANDROID}}}scaleX': '.78', f'{{{ANDROID}}}scaleY': '.78'})


def write(root, target):
    ET.indent(root, space='  ')
    ET.ElementTree(root).write(target, encoding='utf-8', xml_declaration=True)


foreground = vector()
group = safe_group(foreground)
for element in bird:
    path_to_vector(group, element)
write(foreground, RES / 'ic_launcher_foreground.xml')

background = vector()
for d, fill in [('M0 0H108V108H0Z', 'url(#base)')]:
    path_to_vector(background, ET.Element('path', {'d': d, 'fill': fill}))
write(background, RES / 'baya_icon_background.xml')

svg = ET.Element(f'{{{SVG}}}svg', {'viewBox': '0 0 108 108'})
svg.append(deepcopy(defs))
safe_group(svg, svg=True).append(deepcopy(bird))
write(svg, ROOT / 'baya-foreground.svg')

mono_paths = []
for element in bird:
    if element.get('fill') in ['url(#body)', 'url(#gold)']:
        attrs = {'d': element.attrib['d'], 'fill': '#FFFFFF'}
        if element.get('fill-rule'):
            attrs['fill-rule'] = element.get('fill-rule')
        mono_paths.append(ET.Element(f'{{{SVG}}}path', attrs))
    elif element.get('stroke') == 'url(#thread)':
        mono_paths.append(ET.Element(f'{{{SVG}}}path', {
            'd': element.attrib['d'], 'fill': 'none', 'stroke': '#FFFFFF',
            'stroke-width': '3.4', 'stroke-linecap': 'round'}))
mono_svg = ET.Element(f'{{{SVG}}}svg', {'viewBox': '0 0 108 108'})
mono_group = safe_group(mono_svg, svg=True)
mono = vector()
mono_vector_group = safe_group(mono)
for element in mono_paths:
    mono_group.append(deepcopy(element))
    path_to_vector(mono_vector_group, element)
write(mono_svg, ROOT / 'baya-monochrome.svg')
write(mono, RES / 'ic_launcher_monochrome.xml')
print('Exported Android color, background and monochrome vectors plus SVG layers.')
