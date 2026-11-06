# Intro images

Images for the splash, onboarding and welcome screens. The ones here are doodles drawn
by `tool/intro_doodles.py` (run `python tool/intro_doodles.py` to draw them again).
Replace any of them with your own image under the same name. If a file is missing, the
app shows a gray box with its file name in its place.

The file names are set in `lib/screens/intro/intro_content.dart`; change them there
if you use other names.

| File | Where |
|---|---|
| `slide1_main.png`, `slide2_main.png`, `slide3_main.png` | Main illustration of each onboarding slide |
| `slide1_float1.png` … `slide1_float4.png` | Small floating images, slide 1 |
| `slide2_float1.png` … `slide2_float3.png` | Small floating images, slide 2 |
| `slide3_float1.png` … `slide3_float4.png` | Small floating images, slide 3 |
| `welcome_item1.png` … `welcome_item6.png` | Scrolling row on the welcome screen |

The splash logo is `assets/icons/logo.png`. It is drawn as a single color (white, then
the theme's text color), so use a PNG with a transparent background.
