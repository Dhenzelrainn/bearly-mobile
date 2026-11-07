import 'package:bearly_mobile/core/widgets/product_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing or unsafe image URLs show the Bearly placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            ProductThumbnail(imageUrl: null),
            ProductThumbnail(imageUrl: 'http://private.example/image.jpg'),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.image_outlined), findsNWidgets(2));
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('secure product image URLs use a sized network image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProductThumbnail(
          imageUrl: 'https://images.bearly.test/product.jpg',
          size: 64,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 64);
    expect(image.height, 64);
  });
}
