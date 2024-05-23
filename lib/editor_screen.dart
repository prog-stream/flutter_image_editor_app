import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_signature_pad/flutter_signature_pad.dart';
import 'package:image/image.dart' as img;

class EditorScreen extends StatefulWidget {
  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  File? _imageFile;
  final _picker = ImagePicker();
  final _signaturePadKey = GlobalKey<SignatureState>();
  final _textController = TextEditingController();
  bool _isDrawing = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _toggleDrawing() {
    setState(() {
      _isDrawing = !_isDrawing;
    });
  }

  Future<void> _addTextToImage() async {
    if (_imageFile == null) return;
    final image = img.decodeImage(_imageFile!.readAsBytesSync());
    if (image == null) return;

    final drawImage = img.drawString(image, img.arial_48, 0, 0, _textController.text, color: img.getColor(255, 0, 0));
    final editedImageFile = File('${_imageFile!.path}_edited.png')
      ..writeAsBytesSync(img.encodePng(drawImage));

    setState(() {
      _imageFile = editedImageFile;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Editor'),
      ),
      body: Column(
        children: [
          if (_imageFile != null)
            Expanded(
              child: Image.file(_imageFile!),
            ),
          if (_isDrawing)
            Expanded(
              child: Signature(
                color: Colors.black,
                key: _signaturePadKey,
                onSign: () {},
                backgroundPainter: null,
              ),
            ),
          if (!_isDrawing && _imageFile != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: 'Enter text to add',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Pick Image'),
              ),
              if (_imageFile != null)
                ElevatedButton(
                  onPressed: _toggleDrawing,
                  child: Text(_isDrawing ? 'Stop Drawing' : 'Start Drawing'),
                ),
              if (!_isDrawing && _imageFile != null)
                ElevatedButton(
                  onPressed: _addTextToImage,
                  child: Text('Add Text'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
