import 'package:flutter/widgets.dart';

// Scan photos can be several megapixels. Decoding them at the size they are
// shown (cacheWidth) keeps lists smooth and memory low.

// Pixels for a picture shown [logicalWidth] wide, on this screen
int thumbnailPixels(BuildContext context, double logicalWidth) {
  return (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();
}

// Pixels for a picture as wide as the screen
int screenWidthPixels(BuildContext context) {
  return thumbnailPixels(context, MediaQuery.sizeOf(context).width);
}
