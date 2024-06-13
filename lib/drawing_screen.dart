import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scribble/scribble.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class DrawingScreen extends StatefulWidget {
  final File? image;

  DrawingScreen({this.image});

  @override
  _DrawingScreenState createState() => _DrawingScreenState();
}

List<EditAction> _actions = [];

class EditAction {
  final String type; // "text", "shape", or "brush"
  final dynamic object; // The actual text, shape, or brush stroke

  EditAction({required this.type, required this.object});
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
  final GlobalKey _repaintKey = GlobalKey();

  List<_DrawnText> _texts = [];
  List<_DrawnShape> _shapes = [];
  List<Offset> _currentBrushStroke = [];
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
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
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
            child: BlockPicker(
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
              availableColors: [
                Color(0xFF484848), // tundora
                Color(0xFFC51A1F), // thunderbird
                Color(0xFFF69F1C), // buttercup
                Color(0xFFFFAA00), // subCard1
                Color(0xFFA31AC5), // subCard3
                Color(0xFF1AC5C5), // subCard4
                Color(0xFFBE029F), // flirt
                Color(0xFFAF23FF), // electricViolet
                Color(0xFF4E3AFF), // electricBlue
                Color(0xFF00B14D), // jade
                Color(0xFF1AAEC5), // java
                Color(0xFF08E200), // greenLight
                Color(0xFFA4DE00), // rioGrande
                Color(0xFFBFC51A), // keyLimePie
                Color(0xFFC58C1A), // geebung
                Color(0xFF973800), // brownLight
                Color(0xFF00568F), // orient
                Color(0xFFA9A9A9), // silverChalice
              ],
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

  double _temporaryStrokeWidth = 3.0;

  void _pickStrokeWidth() {
    _temporaryStrokeWidth = _strokeWidth;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick stroke width'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Slider(
                value: _temporaryStrokeWidth,
                min: 1.0,
                max: 10.0,
                divisions: 9,
                label: _temporaryStrokeWidth.round().toString(),
                onChanged: (value) {
                  setState(() {
                    _temporaryStrokeWidth = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _strokeWidth = _temporaryStrokeWidth;
                  _scribbleNotifier.setStrokeWidth(_strokeWidth);
                  if (_currentShapeInstance != null) {
                    _currentShapeInstance!.strokeWidth = _strokeWidth;
                  }
                });
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
    if (_actions.isNotEmpty) {
      final lastAction = _actions.removeLast();

      setState(() {
        switch (lastAction.type) {
          case "text":
            _texts.remove(lastAction.object);
            break;
          case "shape":
            _shapes.remove(lastAction.object);
            break;
          case "brush":
            final lastShape = lastAction.object as _DrawnShape;
            _shapes.remove(lastShape);
            break;
        }
      });
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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

  Future<void> _saveImage({required bool isTransparent}) async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        // Get temporary directory
        final dir = await getTemporaryDirectory();
        final filename = '${dir.path}/image.png';
        final file = File(filename);
        await file.writeAsBytes(pngBytes);

        img.Image finalImage;

        if (isTransparent) {
          // Create a blank transparent image with the same size
          final img.Image originalImage = img.decodeImage(pngBytes)!;
          final img.Image transparentImage = img.Image(
              originalImage.width, originalImage.height,
              channels: img.Channels.rgba);
          img.fill(transparentImage,
              img.getColor(0, 0, 0, 0)); // Make it transparent
          img.copyInto(transparentImage, originalImage);

          // Add text entries to the transparent image
          for (var textEntry in _texts) {
            final TextStyle style =
                GoogleFonts.getFont(textEntry.fontFamily).copyWith(
              fontSize: textEntry.fontSize,
              color: textEntry.color,
            );
            final recorder = PictureRecorder();
            final canvas = Canvas(recorder);
            final textPainter = TextPainter(
              text: TextSpan(text: textEntry.text, style: style),
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            final offset = Offset(
                textEntry.position.dx, textEntry.position.dy); // Apply position
            textPainter.paint(canvas, offset);
            final picture = recorder.endRecording();
            final uiImage = await picture.toImage(
                (textPainter.width + offset.dx).toInt(),
                (textPainter.height + offset.dy).toInt());
            final byteData =
                await uiImage.toByteData(format: ImageByteFormat.png);
            final textImage = img.decodeImage(byteData!.buffer.asUint8List())!;
            img.copyInto(transparentImage, textImage,
                dstX: (offset.dx * 3).toInt(),
                dstY: (offset.dy * 3).toInt()); // Apply position
          }

          finalImage = transparentImage;
        } else if (_image != null) {
          // Combine the original image with the edited parts
          final img.Image originalImage =
              img.decodeImage(await _image!.readAsBytes())!;
          final img.Image annotatedImage = img.decodeImage(pngBytes)!;
          img.copyInto(originalImage, annotatedImage, blend: true);

          // Add text entries to the annotated image
          for (var textEntry in _texts) {
            final TextStyle style =
                GoogleFonts.getFont(textEntry.fontFamily).copyWith(
              fontSize: textEntry.fontSize,
              color: textEntry.color,
            );
            final recorder = PictureRecorder();
            final canvas = Canvas(recorder);
            final textPainter = TextPainter(
              text: TextSpan(text: textEntry.text, style: style),
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            final offset = Offset(
                textEntry.position.dx, textEntry.position.dy); // Apply position
            textPainter.paint(canvas, offset);
            final picture = recorder.endRecording();
            final uiImage = await picture.toImage(
                (textPainter.width + offset.dx).toInt(),
                (textPainter.height + offset.dy).toInt());
            final byteData =
                await uiImage.toByteData(format: ImageByteFormat.png);
            final textImage = img.decodeImage(byteData!.buffer.asUint8List())!;
            img.copyInto(originalImage, textImage,
                dstX: (offset.dx * 3).toInt(),
                dstY: (offset.dy * 3).toInt()); // Apply position
          }

          // Add shape entries to the image
          for (var shape in _shapes) {
            shape.paintShape(
              originalImage,
              img.getColor(
                  shape.color.red, shape.color.green, shape.color.blue),
              1.0, // Assuming no scaling is needed
              1.0, // Assuming no scaling is needed
            );
          }

          finalImage = originalImage;
        } else {
          final img.Image annotatedImage = img.decodeImage(pngBytes)!;
          finalImage = annotatedImage;
        }

        final finalBytes = Uint8List.fromList(img.encodePng(finalImage));
        await file.writeAsBytes(finalBytes);

        // Save to gallery
        final result = await ImageGallerySaver.saveFile(file.path);

        _showDialog(
            'Success',
            result['isSuccess']
                ? 'Image saved to gallery!'
                : 'Failed to save image');
      }
    } catch (e) {
      _showDialog('Error', 'An error occurred while saving the image');
    }
  }

  void _showSaveOptions() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Save As'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveImage(isTransparent: false); // Save annotated image
              },
              child: Text('Annotated Image'),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveImage(isTransparent: true); // Save transparent image
              },
              child: Text('Transparent Image'),
            ),
          ],
        );
      },
    );
  }

  void _addText(Offset position) {
    final newText = _DrawnText(
      text: "New Text",
      color: _currentColor,
      position: position, // Default position
      size: Size(200, 50), // Default size
    );

    setState(() {
      _texts.add(newText);
      _actions.add(EditAction(type: "text", object: newText));
    });
  }

  void _editText(_DrawnText text) {
    TextEditingController textController =
        TextEditingController(text: text.text);
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
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
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
                    items: [16.0, 18.0, 20.0, 24.0, 30.0, 36.0, 48.0]
                        .map((double size) {
                      return DropdownMenuItem<double>(
                        value: size,
                        child: Text(size.toString()),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
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
    final newShape = _DrawnShape(
      shape: shape,
      color: _currentColor,
      startPosition: startPosition,
      endPosition: startPosition,
      strokeWidth: _strokeWidth,
    );

    setState(() {
      _currentShapeInstance = newShape;
      _shapes.add(newShape);
      _actions.add(EditAction(
          type: "shape", object: newShape)); // Record the shape action
    });
  }

  void _clearAll() {
    setState(() {
      _scribbleNotifier.clear();
      _texts.clear();
      _shapes.clear();
      _currentBrushStroke.clear();
      _actions.clear();
    });
  }

  void _onTapOutside() {
    setState(() {
      _currentShapeInstance =
          null; // Stop adjusting shapes when clicking outside
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
            if (_image != null) Center(child: Image.file(_image!)),
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) {
                  if (_isShapeMode) {
                    _addShape(_currentShape, details.localPosition);
                  } else if (_isDrawingMode) {
                    setState(() {
                      _currentBrushStroke = [details.localPosition];
                    });
                  }
                },
                onPanUpdate: (details) {
                  if (_isShapeMode && _currentShapeInstance != null) {
                    setState(() {
                      _currentShapeInstance!.endPosition =
                          details.localPosition;
                    });
                  } else if (_isDrawingMode) {
                    setState(() {
                      _currentBrushStroke.add(details.localPosition);
                    });
                  }
                },
                onPanEnd: (details) {
                  if (_isDrawingMode) {
                    setState(() {
                      _shapes.add(_DrawnShape(
                        shape:
                            'line', // Using 'line' to represent freehand brush strokes
                        color: _currentColor,
                        startPosition: _currentBrushStroke.first,
                        endPosition: _currentBrushStroke.last,
                        strokeWidth: _strokeWidth,
                        points: _currentBrushStroke,
                      ));
                      _currentBrushStroke = [];
                      _actions
                          .add(EditAction(type: "brush", object: _shapes.last));
                    });
                  }
                },
                onTapUp: (details) {
                  if (_isTextMode) {
                    _addText(details.localPosition);
                  }
                },
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: CustomPaint(
                    painter: ShapePainter(
                      shapes: _shapes,
                      currentShape: _currentShapeInstance,
                      currentBrushStroke: _currentBrushStroke,
                      strokeColor: _currentColor,
                      strokeWidth: _strokeWidth,
                    ),
                    child: Container(),
                  ),
                ),
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
  List<Offset>? points;

  _DrawnShape({
    required this.shape,
    required this.color,
    required this.startPosition,
    required this.endPosition,
    required this.strokeWidth,
    this.points,
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
          if (points != null) {
            for (int i = 0; i < points!.length - 1; i++) {
              img.drawLine(image, points![i].dx.toInt(), points![i].dy.toInt(),
                  points![i + 1].dx.toInt(), points![i + 1].dy.toInt(), color);
            }
          }
          break;
        case 'circle':
          img.drawCircle(image, centerX, centerY, radius + i, color);
          break;
        case 'rectangle':
          img.drawRect(image, scaledStartX + i, scaledStartY + i,
              scaledEndX - i, scaledEndY - i, color);
          break;
        case 'square':
          int size = rect.width < rect.height
              ? rect.width.toInt()
              : rect.height.toInt();
          int squareStartX = (rect.center.dx - size / 2).toInt();
          int squareStartY = (rect.center.dy - size / 2).toInt();
          int squareEndX = (rect.center.dx + size / 2).toInt();
          int squareEndY = (rect.center.dy + size / 2).toInt();
          img.drawRect(image, squareStartX + i, squareStartY + i,
              squareEndX - i, squareEndY - i, color);
          break;
      }
    }
  }
}

class ShapePainter extends CustomPainter {
  final List<_DrawnShape> shapes;
  final _DrawnShape? currentShape;
  final List<Offset> currentBrushStroke;
  final Color strokeColor;
  final double strokeWidth;

  ShapePainter({
    required this.shapes,
    this.currentShape,
    required this.currentBrushStroke,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final shape in shapes) {
      final shapePaint = Paint()
        ..color = shape.color
        ..strokeWidth = shape.strokeWidth
        ..style = PaintingStyle.stroke;

      final rect = Rect.fromPoints(shape.startPosition, shape.endPosition);

      switch (shape.shape) {
        case 'line':
          if (shape.points != null) {
            final path = Path()
              ..moveTo(shape.points!.first.dx, shape.points!.first.dy);
            for (final point in shape.points!) {
              path.lineTo(point.dx, point.dy);
            }
            canvas.drawPath(path, shapePaint);
          } else {
            canvas.drawLine(shape.startPosition, shape.endPosition, shapePaint);
          }
          break;
        case 'circle':
          final radius = (shape.endPosition - shape.startPosition).distance / 2;
          final center = (shape.startPosition + shape.endPosition) / 2;
          canvas.drawCircle(center, radius, shapePaint);
          break;
        case 'rectangle':
          canvas.drawRect(rect, shapePaint);
          break;
        case 'square':
          final size = (shape.endPosition - shape.startPosition).distance;
          final center = (shape.startPosition + shape.endPosition) / 2;
          final squareRect =
              Rect.fromCenter(center: center, width: size, height: size);
          canvas.drawRect(squareRect, shapePaint);
          break;
      }
    }

    if (currentShape != null) {
      final rect = Rect.fromPoints(
          currentShape!.startPosition, currentShape!.endPosition);

      switch (currentShape!.shape) {
        case 'line':
          canvas.drawLine(
              currentShape!.startPosition, currentShape!.endPosition, paint);
          break;
        case 'circle':
          final radius =
              (currentShape!.endPosition - currentShape!.startPosition)
                      .distance /
                  2;
          final center =
              (currentShape!.startPosition + currentShape!.endPosition) / 2;
          canvas.drawCircle(center, radius, paint);
          break;
        case 'rectangle':
          canvas.drawRect(rect, paint);
          break;
        case 'square':
          final size = (currentShape!.endPosition - currentShape!.startPosition)
              .distance;
          final center =
              (currentShape!.startPosition + currentShape!.endPosition) / 2;
          final squareRect =
              Rect.fromCenter(center: center, width: size, height: size);
          canvas.drawRect(squareRect, paint);
          break;
      }
    }

    if (currentBrushStroke.isNotEmpty) {
      final path = Path()
        ..moveTo(currentBrushStroke.first.dx, currentBrushStroke.first.dy);
      for (final point in currentBrushStroke) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
