import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageGallery extends StatelessWidget {
  final Map? flight;
  final ApiService apiService = ApiService();

  ImageGallery(this.flight, {super.key});

  @override
  Widget build(BuildContext context) {
    List<dynamic> pictures = flight!['Pictures'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Images from flight'),
      ),
      body: GridView.builder(
        itemCount: pictures.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // number of grid columns
          childAspectRatio: 1.0,
          mainAxisSpacing: 4.0,
          crossAxisSpacing: 4.0,
        ),
        itemBuilder: (BuildContext context, int index) {
          String imageUrl =
              apiService.getImageUrl(pictures[index]['namePicture']);
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageDetailPage(imageUrl),
                ),
              );
            },
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          );
        },
      ),
    );
  }
}

class ImageDetailPage extends StatelessWidget {
  final String imageUrl;

  const ImageDetailPage(this.imageUrl, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
    );
  }
}
