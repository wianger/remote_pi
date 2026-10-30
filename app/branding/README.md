# Baya artwork

`baya-mark.svg` is the portable colored tile. Its background, bird, crown and
thread use separate layers, directional color and restrained edge highlights.
The Flutter `AppMarkPainter` renders the same composition; high contrast and
untiled glyphs keep the flat treatment for clarity.

Run `python app/branding/sync_android_icons.py` from the repository root to
export the Android vectors and transparent `baya-foreground.svg` /
`baya-monochrome.svg` layers. Android applies its own mask to the full-bleed
background. Foreground artwork remains scaled into the central safe circle.
The matching density PNGs are fallback renders of these transparent SVGs.

This is original vector artwork adapted to Android. It takes inspiration from
Apple's layered icon direction without using Apple's Icon Composer runtime,
platform effects or assets. The monochrome version relies on Android's tint.

Reference: https://developer.apple.com/design/human-interface-guidelines/app-icons
