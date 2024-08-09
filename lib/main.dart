import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:io';
import 'drawing_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ImagePickerScreen(),
    );
  }
}

class ImagePickerScreen extends StatefulWidget {
  final bool? readOnly;
  final String? url;

  ImagePickerScreen({this.readOnly, this.url});

  @override
  _ImagePickerScreenState createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  File? _image;
  bool _isHoveringImage01 = false;
  bool _isHoveringImage02 = false;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.url != null) {
      _loadImageFromUrl(widget.url!);
    }
  }

  Future<void> _loadImageFromUrl(String url) async {
    final file = await downloadImage(url);
    setState(() {
      _image = file;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      selectedImage = File(pickedFile.path);
      final savedImagePath = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditorScreen(
            image: selectedImage!,
            imageName: 'annotated_image',
          ),
        ),
      );
      print('this is $savedImagePath.toString()');
      if (savedImagePath != null) {
        setState(() {
          _image = File(savedImagePath);
        });
      }
    }
  }

  Future<void> _transparentImage() async {
    final directory = Directory.systemTemp;
    final transparentImagePath = '${directory.path}/transparent_image.png';
    final transparentImageFile = File(transparentImagePath);
    transparentImageFile.createSync();

    final savedImagePath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorScreen(
          image: transparentImageFile,
          imageName: 'transparent_image',
        ),
      ),
    );

    if (savedImagePath != null) {
      setState(() {
        _image = File(savedImagePath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Display Screen'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image == null
                ? Text('')
                : Expanded(
                    child: Image.file(_image!),
                  ),
            SizedBox(height: 20),
            if (widget.readOnly == null || widget.readOnly == false)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: MouseRegion(
                          onEnter: (_) => setState(() {
                            _isHoveringImage01 = true;
                          }),
                          onExit: (_) => setState(() {
                            _isHoveringImage01 = false;
                          }),
                          child: Image.asset(
                            'assets/image01.png',
                            width: 30,
                            height: 30,
                            color: _isHoveringImage01 ? Colors.blue : null,
                          ),
                        ),
                      ),
                      Text(
                        'Upload Image',
                        style: TextStyle(
                          color:
                              _isHoveringImage01 ? Colors.blue : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      width: 80), // Increase the spacing between the images
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _transparentImage,
                        child: MouseRegion(
                          onEnter: (_) => setState(() {
                            _isHoveringImage02 = true;
                          }),
                          onExit: (_) => setState(() {
                            _isHoveringImage02 = false;
                          }),
                          child: Image.asset(
                            'assets/image02.png',
                            width: 30,
                            height: 30,
                            color: _isHoveringImage02 ? Colors.blue : null,
                          ),
                        ),
                      ),
                      Text(
                        'Transparent Image',
                        style: TextStyle(
                          color:
                              _isHoveringImage02 ? Colors.blue : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Future<File> downloadImage(String url) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = path.basename(url);
      final filePath = path.join(directory.path, fileName);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}
