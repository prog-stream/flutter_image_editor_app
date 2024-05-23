import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scribble/scribble.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';

class DrawingScreen extends StatefulWidget {
  final File? image;

  DrawingScreen({this.image});

  @override
  _DrawingScreenState createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final ScribbleNotifier _scribbleNotifier = ScribbleNotifier();
  File? _image;
  bool _isDrawingMode = true;
  bool _isTextMode = false;
  bool _isShapeMode = false;
  String _currentShape = 'line';
  Color _currentColor = Colors.black;
  double _strokeWidth = 3.0;

  List<_DrawnText> _texts = [];
  List<_DrawnShape> _shapes = [];
  _DrawnText? _selectedText;
  _DrawnShape? _currentShapeInstance;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  void _activateDrawingMode() {
    setState(() {
      _isDrawingMode = true;
      _isTextMode = false;
      _isShapeMode = false;
      _currentShapeInstance = null; // Stop adjusting shapes
      _scribbleNotifier.setColor(_currentColor);
      _scribbleNotifier.setStrokeWidth(_strokeWidth);
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _currentColor,
              onColorChanged: (color) {
                setState(() {
                  _currentColor = color;
                  _scribbleNotifier.setColor(_currentColor);
                  if (_selectedText != null) {
                    _selectedText!.color = _currentColor;
                  }
                  if (_currentShapeInstance != null) {
                    _currentShapeInstance!.color = _currentColor;
                  }
                });
              },
              showLabel: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAnnotatedImage() async {
    final annotationImage = await _scribbleNotifier.renderImage();
    if (_image != null) {
      final decodedImage = img.decodeImage(await _image!.readAsBytes());
      if (decodedImage != null) {
        final annotation = img.decodeImage(annotationImage.buffer.asUint8List());

        if (annotation != null) {
          final resizedBackground = img.copyResize(decodedImage, width: 1690, height: 1075);
          final resizedAnnotation = img.copyResize(annotation, width: 1690, height: 1075);

          // Combine the resized background and annotation
          img.copyInto(resizedBackground, resizedAnnotation, blend: true);

          // Add text entries to the image
          for (var textEntry in _texts) {
            img.drawString(
              resizedBackground,
              img.arial_24,
              (textEntry.position.dx * (1690 / decodedImage.width)).toInt(),
              (textEntry.position.dy * (1075 / decodedImage.height)).toInt(),
              textEntry.text,
              color: img.getColor(textEntry.color.red, textEntry.color.green, textEntry.color.blue),
            );
          }

          // Add shape entries to the image
          for (var shape in _shapes) {
            shape.paintShape(
              resizedBackground,
              img.getColor(shape.color.red, shape.color.green, shape.color.blue),
              1690 / decodedImage.width,
              1075 / decodedImage.height,
            );
          }

          final directory = await getApplicationDocumentsDirectory();
          final imagePath = '${directory.path}/annotated_image.png';
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(img.encodePng(resizedBackground));

          // Show success message or handle the saved image as needed
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: Text('Annotated image saved successfully!'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  Future<void> _saveTransparentImage() async {
    final annotationImage = await _scribbleNotifier.renderImage();
    final canvas = img.Image(1690, 1075, channels: img.Channels.rgba);

    if (_image != null) {
      final decodedImage = img.decodeImage(await _image!.readAsBytes());
      if (decodedImage != null) {
        // Draw annotations onto the canvas
        final annotation = img.decodeImage(annotationImage.buffer.asUint8List());
        if (annotation != null) {
          img.copyInto(canvas, annotation);
        }

        // Draw text entries onto the canvas
        for (var textEntry in _texts) {
          img.drawString(
            canvas,
            img.arial_24,
            (textEntry.position.dx * (1690 / decodedImage.width)).toInt(),
            (textEntry.position.dy * (1075 / decodedImage.height)).toInt(),
            textEntry.text,
            color: img.getColor(textEntry.color.red, textEntry.color.green, textEntry.color.blue),
          );
        }

        // Draw shape entries onto the canvas
        for (var shape in _shapes) {
          shape.paintShape(
            canvas,
            img.getColor(shape.color.red, shape.color.green, shape.color.blue),
            1690 / decodedImage.width,
            1075 / decodedImage.height,
          );
        }

        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/transparent_image.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(img.encodePng(canvas));

        // Show success message or handle the saved image as needed
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('Transparent image saved successfully!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _toggleDrawEraseMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
      if (_isDrawingMode) {
        _scribbleNotifier.setColor(_currentColor);
        _scribbleNotifier.setStrokeWidth(_strokeWidth);
      } else {
        _scribbleNotifier.setColor(Colors.transparent); // Erase by setting color to transparent
      }
    });
  }

  void _pickStrokeWidth() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick stroke width'),
          content: Slider(
            value: _strokeWidth,
            min: 1.0,
            max: 10.0,
            divisions: 9,
            label: _strokeWidth.round().toString(),
            onChanged: (value) {
              setState(() {
                _strokeWidth = value;
                _scribbleNotifier.setStrokeWidth(_strokeWidth);
                if (_currentShapeInstance != null) {
                  _currentShapeInstance!.strokeWidth = _strokeWidth;
                }
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _undo() {
    setState(() {
      if (_texts.isNotEmpty) {
        _texts.removeLast();
      } else if (_shapes.isNotEmpty) {
        _shapes.removeLast();
      } else {
        _scribbleNotifier.undo();
      }
    });
  }

  void _showSaveOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Save As'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _saveAnnotatedImage();
              },
              child: Text('Annotated Image'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _saveTransparentImage();
              },
              child: Text('Transparent Image'),
            ),
          ],
        );
      },
    );
  }

  void _addText(Offset position) {
    setState(() {
      _texts.add(_DrawnText(
        text: "New Text",
        color: _currentColor,
        position: position, // Default position
        size: Size(200, 50), // Default size
      ));
    });
  }

  void _editText(_DrawnText text) {
    TextEditingController textController = TextEditingController(text: text.text);
    String selectedFontFamily = text.fontFamily;
    double selectedFontSize = text.fontSize;

    List<String> germanFonts = [
      'Anton',
      'Bangers',
      'Fredericka the Great',
      'Gochi Hand',
      'Lobster',
      'Playfair Display',
      'Roboto',
      'Satisfy',
      'Tangerine',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Text'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: InputDecoration(hintText: "Enter text"),
              ),
              DropdownButton<String>(
                value: selectedFontFamily,
                onChanged: (value) {
                  setState(() {
                    selectedFontFamily = value!;
                  });
                },
                items: germanFonts.map((String font) {
                  return DropdownMenuItem<String>(
                    value: font,
                    child: Text(font),
                  );
                }).toList(),
              ),
              DropdownButton<double>(
                value: selectedFontSize,
                onChanged: (value) {
                  setState(() {
                    selectedFontSize = value!;
                  });
                },
                items: [16.0, 18.0, 20.0, 24.0, 30.0, 36.0, 48.0].map((double size) {
                  return DropdownMenuItem<double>(
                    value: size,
                    child: Text(size.toString()),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  text.text = textController.text;
                  text.fontFamily = selectedFontFamily;
                  text.fontSize = selectedFontSize;
                });
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _texts.remove(text);
                });
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _addShape(String shape, Offset startPosition) {
    setState(() {
      _currentShape = shape;
      _currentShapeInstance = _DrawnShape(
        shape: shape,
        color: _currentColor,
        startPosition: startPosition, // Default start position
        endPosition: startPosition,   // Default end position
        strokeWidth: _strokeWidth,
      );
      _shapes.add(_currentShapeInstance!);
    });
  }

  void _clearAll() {
    setState(() {
      _scribbleNotifier.clear();
      _texts.clear();
      _shapes.clear();
    });
  }

  void _onTapOutside() {
    setState(() {
      _currentShapeInstance = null; // Stop adjusting shapes when clicking outside
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTapOutside, // Call this method when tapping outside
      child: Scaffold(
        appBar: AppBar(
          title: Text('Drawing Screen'),
          actions: [
            IconButton(
              icon: Icon(Icons.color_lens),
              tooltip: 'Pick Color',
              onPressed: _pickColor,
            ),
            IconButton(
              icon: Icon(Icons.brush),
              tooltip: 'Brush',
              onPressed: _activateDrawingMode, // Set drawing mode
            ),
            IconButton(
              icon: Icon(Icons.line_weight),
              tooltip: 'Stroke Width',
              onPressed: _pickStrokeWidth,
            ),
            IconButton(
              icon: Icon(Icons.text_fields),
              tooltip: 'Text',
              onPressed: () {
                setState(() {
                  _isTextMode = true;
                  _isDrawingMode = false;
                  _isShapeMode = false;
                  _currentShapeInstance = null; // Stop adjusting shapes
                });
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.crop_square),
              tooltip: 'Shapes',
              onSelected: (value) {
                setState(() {
                  _isShapeMode = true;
                  _isDrawingMode = false;
                  _isTextMode = false;
                  _currentShape = value;
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'line',
                  child: Text('Line'),
                ),
                PopupMenuItem(
                  value: 'circle',
                  child: Text('Circle'),
                ),
                PopupMenuItem(
                  value: 'rectangle',
                  child: Text('Rectangle'),
                ),
                PopupMenuItem(
                  value: 'square',
                  child: Text('Square'),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.clear),
              tooltip: 'Clear All',
              onPressed: _clearAll,
            ),
            IconButton(
              icon: Icon(Icons.undo),
              tooltip: 'Undo',
              onPressed: _undo,
            ),
            IconButton(
              icon: Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _showSaveOptions,
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_image != null)
              Center(child: Image.file(_image!)),
            Scribble(
              notifier: _scribbleNotifier,
            ),
            if (_isTextMode || _isShapeMode)
              GestureDetector(
                onPanStart: (details) {
                  if (_isShapeMode) {
                    _addShape(_currentShape, details.localPosition);
                  }
                },
                onPanUpdate: (details) {
                  if (_isShapeMode && _currentShapeInstance != null) {
                    setState(() {
                      _currentShapeInstance!.endPosition = details.localPosition;
                    });
                  }
                },
                onTapUp: (details) {
                  if (_isTextMode) {
                    _addText(details.localPosition);
                  }
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ..._texts.map((text) => Positioned(
              left: text.position.dx,
              top: text.position.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    text.position = Offset(
                      text.position.dx + details.delta.dx,
                      text.position.dy + details.delta.dy,
                    );
                  });
                },
                onTap: () => _editText(text),
                child: Container(
                  width: text.size.width,
                  height: text.size.height,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            text.text,
                            style: GoogleFonts.getFont(
                              text.fontFamily,
                              color: text.color,
                              fontSize: text.fontSize,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              text.size = Size(
                                text.size.width + details.delta.dx,
                                text.size.height + details.delta.dy,
                              );
                            });
                          },
                          child: Icon(
                            Icons.open_with,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
            ..._shapes.map((shape) => Positioned(
              left: shape.startPosition.dx,
              top: shape.startPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    shape.endPosition = Offset(
                      shape.endPosition.dx + details.delta.dx,
                      shape.endPosition.dy + details.delta.dy,
                    );
                  });
                },
                onTap: () {
                  setState(() {
                    _currentShapeInstance = shape;
                  });
                },
                child: CustomPaint(
                  painter: ShapePainter(shape),
                  child: _currentShapeInstance == shape
                      ? Stack(
                    children: List.generate(4, (index) {
                      final offset = _getCornerOffset(shape, index);
                      return Positioned(
                        left: offset.dx - 5,
                        top: offset.dy - 5,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _resizeShape(shape, index, details.delta);
                            });
                          },
                          child: Container(
                            width: 10,
                            height: 10,
                            color: Colors.blue,
                          ),
                        ),
                      );
                    }),
                  )
                      : Container(),
                ),
              ),
            )),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _pickImage,
          tooltip: 'Pick Image',
          child: Icon(Icons.image),
        ),
      ),
    );
  }

  Offset _getCornerOffset(_DrawnShape shape, int cornerIndex) {
    switch (cornerIndex) {
      case 0:
        return shape.startPosition;
      case 1:
        return Offset(shape.endPosition.dx, shape.startPosition.dy);
      case 2:
        return shape.endPosition;
      case 3:
        return Offset(shape.startPosition.dx, shape.endPosition.dy);
      default:
        return shape.startPosition;
    }
  }

  void _resizeShape(_DrawnShape shape, int cornerIndex, Offset delta) {
    switch (cornerIndex) {
      case 0:
        shape.startPosition += delta;
        break;
      case 1:
        shape.endPosition = Offset(shape.endPosition.dx + delta.dx, shape.startPosition.dy + delta.dy);
        break;
      case 2:
        shape.endPosition += delta;
        break;
      case 3:
        shape.endPosition = Offset(shape.startPosition.dx + delta.dx, shape.endPosition.dy + delta.dy);
        break;
    }
  }
}

class _DrawnText {
  String text;
  Color color;
  Offset position;
  Size size;
  String fontFamily;
  double fontSize;

  _DrawnText({
    required this.text,
    required this.color,
    required this.position,
    required this.size,
    this.fontFamily = 'Roboto', // Default font family
    this.fontSize = 24.0, // Default font size
  });
}

class _DrawnShape {
  String shape;
  Color color;
  Offset startPosition;
  Offset endPosition;
  double strokeWidth;

  _DrawnShape({
    required this.shape,
    required this.color,
    required this.startPosition,
    required this.endPosition,
    required this.strokeWidth,
  });

  get rect => Rect.fromPoints(startPosition, endPosition);

  void paintShape(img.Image image, int color, double scaleX, double scaleY) {
    final rect = Rect.fromLTRB(
      this.rect.left * scaleX,
      this.rect.top * scaleY,
      this.rect.right * scaleX,
      this.rect.bottom * scaleY,
    );

    int centerX = rect.center.dx.toInt();
    int centerY = rect.center.dy.toInt();
    int radius = (rect.width / 2).toInt();
    int scaledStartX = rect.left.toInt();
    int scaledStartY = rect.top.toInt();
    int scaledEndX = rect.right.toInt();
    int scaledEndY = rect.bottom.toInt();

    for (int i = 0; i < strokeWidth.toInt(); i++) {
      switch (shape) {
        case 'line':
          img.drawLine(image, scaledStartX + i, scaledStartY + i, scaledEndX + i, scaledEndY + i, color);
          break;
        case 'circle':
          img.drawCircle(image, centerX, centerY, radius + i, color);
          break;
        case 'rectangle':
          img.drawRect(image, scaledStartX + i, scaledStartY + i, scaledEndX - i, scaledEndY - i, color);
          break;
        case 'square':
          int size = rect.width < rect.height ? rect.width.toInt() : rect.height.toInt();
          int squareStartX = (rect.center.dx - size / 2).toInt();
          int squareStartY = (rect.center.dy - size / 2).toInt();
          int squareEndX = (rect.center.dx + size / 2).toInt();
          int squareEndY = (rect.center.dy + size / 2).toInt();
          img.drawRect(image, squareStartX + i, squareStartY + i, squareEndX - i, squareEndY - i, color);
          break;
      }
    }
  }
}

class ShapePainter extends CustomPainter {
  final _DrawnShape shape;

  ShapePainter(this.shape);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke;

    if (shape.shape == 'line') {
      canvas.drawLine(shape.startPosition, shape.endPosition, paint);
    } else if (shape.shape == 'rectangle') {
      canvas.drawRect(
        Rect.fromPoints(shape.startPosition, shape.endPosition),
        paint,
      );
    } else if (shape.shape == 'circle') {
      final radius = (shape.endPosition - shape.startPosition).distance / 2;
      final center = (shape.startPosition + shape.endPosition) / 2;
      canvas.drawCircle(center, radius, paint);
    } else if (shape.shape == 'square') {
      final size = (shape.endPosition - shape.startPosition).distance;
      final center = (shape.startPosition + shape.endPosition) / 2;
      final squareRect = Rect.fromCenter(center: center, width: size, height: size);
      canvas.drawRect(squareRect, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
