import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver/gallery_saver.dart';

enum ShapeType { Line, Ellipse, Circle, Square, Rectangle }

class ImageEditorScreen extends StatefulWidget {
  final File image;
  final String imageName;
  final bool? readOnly;

  ImageEditorScreen({
    required this.image,
    required this.imageName,
    this.readOnly,
  });

  @override
  _ImageEditorScreenState createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  ui.Image? _image;
  bool _isLoaded = false;
  final GlobalKey _globalKey = GlobalKey();
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  ShapeType? _selectedShapeType;
  String? _selectedTool;
  Shape? _currentShape;
  Shape? _selectedShape;
  Offset? _dragStart;
  bool _isDragging = false;
  List<Shape> _shapes = [];
  List<Stroke> _strokes = [];
  List<_DrawnText> _texts = [];
  _DrawnText? _selectedText;
  Offset? _dragStartText;
  List<EditAction> _actions = [];
  double _scaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.imageName == 'transparent_image') {
      final width = 1080;
      final height = 1920;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder,
          Rect.fromPoints(
              Offset(0, 0), Offset(width.toDouble(), height.toDouble())));
      final paint = Paint()..color = Colors.transparent;
      canvas.drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);

      setState(() {
        _image = image;
        _isLoaded = true;
      });
    } else {
      final data = await widget.image.readAsBytes();
      final image = await decodeImageFromList(data);
      setState(() {
        _image = image;
        _isLoaded = true;
        _scaleFactor = _calculateScaleFactor(
            image.width.toDouble(), image.height.toDouble());
      });
    }
  }

  double _calculateScaleFactor(double imageWidth, double imageHeight) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height -
        200; // Adjust as needed for toolbar and other UI elements

    final widthFactor = screenWidth / imageWidth;
    final heightFactor = screenHeight / imageHeight;

    return widthFactor < heightFactor ? widthFactor : heightFactor;
  }

  Offset _scalePosition(Offset position) {
    return position / _scaleFactor!;
  }

  Future<String> _getUniqueFilePath(String baseName, String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    int counter = 1;
    String filePath;
    do {
      filePath = path.join(directory.path,
          '$baseName${counter.toString().padLeft(6, '0')}.$extension');
      counter++;
    } while (await File(filePath).exists());
    return filePath;
  }

  Future<void> _saveImage() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Save Image'),
        content: Text(
            "Once Saved, you can't edit it again. Do you want to continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
            },
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (result == true) {
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final imagePath = await _getUniqueFilePath(widget.imageName, 'png');
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      if (await Permission.storage.request().isGranted) {
        if (Platform.isAndroid) {
          await GallerySaver.saveImage(imageFile.path,
              albumName: "DDC Drawing");
        } else if (Platform.isIOS) {
          await GallerySaver.saveImage(imageFile.path);
        }

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Success'),
            content: Text('Image Saved Successfully'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved to $imagePath')),
      );

      Navigator.pop(context, imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Image'),
        leading: Tooltip(
          message: 'Back',
          child: MouseRegion(
            onEnter: (_) => setState(() {}),
            onExit: (_) => setState(() {}),
            child: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Unsaved Changes'),
                    content:
                        Text('Do you want to discard your changes and exit?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text('Yes'),
                      ),
                    ],
                  ),
                );

                if (result == true) {
                  Navigator.of(context).pop();
                }
              },
              hoverColor: Colors.blue[200], // Change color on hover
            ),
          ),
        ),
        actions: [
          Tooltip(
            message: 'Save',
            child: MouseRegion(
              onEnter: (_) => setState(() {}),
              onExit: (_) => setState(() {}),
              child: IconButton(
                icon: Icon(Icons.save),
                onPressed: _saveImage,
                hoverColor: Colors.blue[200], // Change color on hover
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _isLoaded
                  ? Listener(
                      onPointerDown: (details) {
                        if (_selectedTool == 'brush') {
                          _addStroke(details.localPosition);
                        } else if (_selectedTool == 'shape') {
                          _selectShape(details.localPosition);
                        } else if (_selectedTool == 'text') {
                          _selectText(details.localPosition);
                        }
                      },
                      onPointerMove: (details) {
                        if (_selectedTool == 'brush') {
                          _addStroke(details.localPosition);
                        } else if (_selectedTool == 'shape') {
                          if (_currentShape != null) {
                            _updateShape(details.localPosition);
                          } else if (_isDragging) {
                            _moveShape(details.localPosition);
                          }
                        } else if (_isDragging) {
                          _moveShape(details.localPosition);
                        } else if (_selectedText != null) {
                          _moveText(details.localPosition);
                        }
                      },
                      onPointerUp: (details) {
                        if (_selectedTool == 'brush') {
                          setState(() {
                            _strokes.add(Stroke(
                                color: _selectedColor,
                                strokeWidth: _strokeWidth));
                          });
                        } else if (_selectedTool == 'shape') {
                          _endShape();
                        } else {
                          setState(() {
                            _isDragging = false;
                            _dragStartText = null;
                          });
                        }
                      },
                      child: GestureDetector(
                        onTapUp: (details) {
                          _onTap(details.localPosition);
                        },
                        child: ClipRect(
                          child: RepaintBoundary(
                            key: _globalKey,
                            child: CustomPaint(
                              painter: ImagePainter(
                                image: _image!,
                                strokes: _strokes,
                                color: _selectedColor,
                                strokeWidth: _strokeWidth,
                                shapes: _shapes,
                                texts: _texts,
                                selectedShape: _selectedShape,
                                selectedText: _selectedText,
                                scaleFactor: _scaleFactor,
                                isSaving: false,
                              ),
                              child: Container(
                                width: _image!.width.toDouble() * _scaleFactor!,
                                height:
                                    _image!.height.toDouble() * _scaleFactor!,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : CircularProgressIndicator(),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  void _clearAll() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All'),
        content: Text('Do you really want to discard all changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        _strokes.clear();
        _shapes.clear();
        _texts.clear();
        _actions.clear();
      });
    }
  }

  void _selectTool(String? tool) {
    setState(() {
      _selectedTool = tool;
      if (tool != 'shape') {
        _selectedShapeType = null; // Deselect shape when changing tool
      }
      _selectedShape = null; // Deselect shape when changing tool
      _selectedText = null; // Deselect text when changing tool
    });
  }

  void _selectShapeType(ShapeType? type) {
    setState(() {
      _selectedShapeType = type;
      _selectTool('shape');
    });
  }

  void _startShape(Offset start) {
    if (_selectedShapeType != null) {
      setState(() {
        _currentShape = Shape(
          type: _selectedShapeType!,
          start: _scalePosition(start),
          end: _scalePosition(start),
          color: _selectedColor,
          strokeWidth: _strokeWidth,
        );
        _shapes.add(_currentShape!);
        _actions.add(EditAction(type: "shape", object: _currentShape!));
      });
    }
  }

  void _updateShape(Offset current) {
    setState(() {
      if (_currentShape != null) {
        _currentShape!.end = _scalePosition(current);
      }
    });
  }

  void _endShape() {
    setState(() {
      _currentShape = null;
    });
  }

  void _addStroke(Offset point) {
    setState(() {
      if (_strokes.isEmpty || _strokes.last.points.isEmpty) {
        _strokes.add(Stroke(color: _selectedColor, strokeWidth: _strokeWidth));
        _actions.add(EditAction(type: "stroke", object: _strokes.last));
      }
      _strokes.last.points.add(_scalePosition(point));
    });
  }

  void _selectShape(Offset position) {
    for (var shape in _shapes) {
      if (shape.contains(_scalePosition(position))) {
        setState(() {
          _selectedShape = shape;
          _dragStart = _scalePosition(position);
          _isDragging = true;
        });
        return;
      }
    }

    // If no shape was selected, add new shape
    if (_selectedTool == 'shape' && _selectedShapeType != null) {
      _startShape(position);
    }
  }

  void _moveShape(Offset position) {
    if (_selectedShape != null && _dragStart != null) {
      setState(() {
        Offset offset = _scalePosition(position) - _dragStart!;
        _selectedShape!.start += offset;
        _selectedShape!.end += offset;
        _dragStart = _scalePosition(position);
      });
    }
  }

  void _deselectShape() {
    setState(() {
      _selectedShape = null;
    });
  }

  void _addText(Offset position) {
    final newText = _DrawnText(
      text: "New Text",
      color: _selectedColor,
      position: _scalePosition(position),
      size: Size(300, 75),
      fontSize: 20.0,
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

    List<String> fonts = [
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
          scrollable: true,
          title: Text('Edit Text'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.max,
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
                    items: fonts.map((String font) {
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
                    items: [
                      16.0,
                      18.0,
                      20.0,
                      24.0,
                      30.0,
                      36.0,
                      48.0,
                      60.0,
                      72.0
                    ].map((double size) {
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
                  _texts.remove(text);
                });
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
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
          ],
        );
      },
    );
  }

  void _selectText(Offset position) {
    for (var text in _texts) {
      if (text.contains(_scalePosition(position))) {
        setState(() {
          _selectedText = text;
          _dragStartText = _scalePosition(position);
        });
        return;
      }
    }

    // If no text was selected, add new text
    if (_selectedTool == 'text') {
      _addText(position);
    }
  }

  void _moveText(Offset position) {
    if (_selectedText != null && _dragStartText != null) {
      setState(() {
        Offset offset = _scalePosition(position) - _dragStartText!;
        _selectedText!.position += offset;
        _dragStartText = _scalePosition(position);
      });
    }
  }

  void _selectColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
            },
            availableColors: [
              Colors.red,
              Colors.pink,
              Colors.purple,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.lightBlue,
              Colors.cyan,
              Colors.teal,
              Colors.green,
              Colors.lightGreen,
              Colors.lime,
              Colors.yellow,
              Colors.amber,
              Colors.orange,
              Colors.deepOrange,
              Colors.brown,
              Colors.grey,
              Colors.blueGrey,
              Colors.black,
              Colors.white, // Adding white color here
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showStrokeWidthDialog() {
    double tempStrokeWidth = _strokeWidth;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Pick stroke width'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: tempStrokeWidth,
                    min: 0.5, // Adjust as needed
                    max: 10.0,
                    divisions: 19, // More divisions for finer control
                    label: tempStrokeWidth.toString(),
                    onChanged: (value) {
                      setState(() {
                        tempStrokeWidth = value;
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _strokeWidth = tempStrokeWidth;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Icon _getShapeIcon(ShapeType type) {
    switch (type) {
      case ShapeType.Line:
        return Icon(Icons.show_chart);
      case ShapeType.Circle:
        return Icon(Icons.circle);
      case ShapeType.Rectangle:
        return Icon(Icons.crop_16_9);
      case ShapeType.Square:
        return Icon(Icons.crop_square);
      case ShapeType.Ellipse:
        return Icon(Icons.crop_7_5); // Updated icon for ellipse
      default:
        return Icon(Icons.crop_square);
    }
  }

  void _undo() {
    setState(() {
      if (_actions.isNotEmpty) {
        final lastAction = _actions.removeLast();
        if (lastAction.type == "stroke") {
          _strokes.remove(lastAction.object);
        } else if (lastAction.type == "shape") {
          _shapes.remove(lastAction.object);
        } else if (lastAction.type == "text") {
          _texts.remove(lastAction.object);
        }
      }
    });
  }

  void _onTap(Offset position) {
    for (var text in _texts) {
      if (text.contains(_scalePosition(position))) {
        _editText(text);
        return;
      }
    }

    // Add new text if text tool is selected and no existing text is tapped
    if (_selectedTool == 'text') {
      _addText(position);
    }
  }

  Widget _buildToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToolButton(
          icon: Icons.color_lens,
          onPressed: _selectColor,
          toolName: 'Color Picker',
          isSelected: _selectedTool == 'color',
        ),
        _buildToolButton(
          icon: Icons.brush,
          onPressed: () => _selectTool('brush'),
          toolName: 'Brush',
          isSelected: _selectedTool == 'brush',
        ),
        _buildToolButton(
          icon: Icons.line_weight,
          onPressed: _showStrokeWidthDialog,
          toolName: 'Stroke Width',
          isSelected: _selectedTool == 'strokeWidth',
        ),
        DropdownButton<ShapeType>(
          value: _selectedShapeType,
          hint: Icon(
            Icons.crop_square,
            color: _selectedTool == 'shape'
                ? Colors.blue
                : null, // Ensure the hint icon color reflects the selection state
          ),
          items: ShapeType.values.map((ShapeType type) {
            return DropdownMenuItem<ShapeType>(
              value: type,
              child: Row(
                children: [
                  Icon(
                    _getShapeIcon(type).icon,
                    color: _selectedShapeType == type
                        ? Colors.blue
                        : null, // Change color if selected
                  ),
                  SizedBox(width: 10),
                  Text(type.toString().split('.').last),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            _selectShapeType(value);
            _selectTool(
                'shape'); // Ensure shape tool is selected when a shape is chosen
          },
        ),
        _buildToolButton(
          icon: Icons.text_fields,
          onPressed: () => _selectTool('text'),
          toolName: 'Text',
          isSelected: _selectedTool == 'text',
        ),
        _buildToolButton(
          icon: Icons.clear,
          onPressed: _clearAll,
          toolName: 'Clear All',
          isSelected: _selectedTool == 'clearAll',
        ),
        _buildToolButton(
          icon: Icons.undo,
          onPressed: _undo,
          toolName: 'Undo',
          isSelected: _selectedTool == 'undo',
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String toolName,
    required bool isSelected,
  }) {
    return Tooltip(
      message: toolName,
      child: MouseRegion(
        onEnter: (_) => setState(() {}),
        onExit: (_) => setState(() {}),
        child: IconButton(
          icon: Icon(icon),
          color: isSelected ? Colors.blue : null,
          onPressed: onPressed,
          hoverColor: Colors.blue[200], // Change color on hover
        ),
      ),
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final List<Stroke> strokes;
  final Color color;
  final double strokeWidth;
  final List<Shape> shapes;
  final List<_DrawnText> texts;
  final Shape? selectedShape;
  final _DrawnText? selectedText;
  final double scaleFactor;
  final bool isSaving;

  ImagePainter({
    required this.image,
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    required this.shapes,
    required this.texts,
    required this.selectedShape,
    required this.selectedText,
    required this.scaleFactor,
    required this.isSaving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scaleFactor, scaleFactor);
    canvas.drawImage(image, Offset.zero, Paint());

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth / scaleFactor;

    for (var stroke in strokes) {
      final strokePaint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.strokeWidth / scaleFactor;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        if (stroke.points[i] != Offset.zero &&
            stroke.points[i + 1] != Offset.zero) {
          canvas.drawLine(stroke.points[i], stroke.points[i + 1], strokePaint);
        }
      }
    }

    for (var shape in shapes) {
      final shapePaint = Paint()
        ..color = shape.color
        ..strokeWidth = shape.strokeWidth / scaleFactor
        ..style = PaintingStyle.stroke;

      final Offset start = shape.start;
      final Offset end = shape.end;

      switch (shape.type) {
        case ShapeType.Line:
          canvas.drawLine(start, end, shapePaint);
          break;
        case ShapeType.Ellipse:
          Rect rect = Rect.fromPoints(start, end);
          canvas.drawOval(rect, shapePaint);
          break;
        case ShapeType.Circle:
          double radius = (start - end).distance / 2;
          Offset center =
              Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
          canvas.drawCircle(center, radius, shapePaint);
          break;
        case ShapeType.Square:
          double side = (end - start).dx.abs();
          Rect rect = Rect.fromLTWH(start.dx, start.dy, side, side);
          canvas.drawRect(rect, shapePaint);
          break;
        case ShapeType.Rectangle:
          Rect rect = Rect.fromPoints(start, end);
          canvas.drawRect(rect, shapePaint);
          break;
      }
    }

    for (var text in texts) {
      final textSize = text.calculateSize();
      final textPainter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: GoogleFonts.getFont(text.fontFamily).copyWith(
            color: text.color,
            fontSize: text.fontSize / scaleFactor,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout(minWidth: 0, maxWidth: double.infinity);
      textPainter.paint(canvas, text.position);

      if (selectedText == text && !isSaving) {
        final handlePaint = Paint()..color = Colors.blue;
        final handleSize = 10.0 / scaleFactor;
        final handleRect = Rect.fromLTWH(
          text.position.dx + textSize.width - handleSize / 2,
          text.position.dy + textSize.height - handleSize / 2,
          handleSize,
          handleSize,
        );
        canvas.drawRect(handleRect, handlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class EditAction {
  String type;
  dynamic object;

  EditAction({
    required this.type,
    required this.object,
  });
}

class Stroke {
  List<Offset> points;
  Color color;
  double strokeWidth;

  Stroke({
    required this.color,
    required this.strokeWidth,
  }) : points = [];
}

class Shape {
  final ShapeType type;
  Offset start;
  Offset end;
  final Color color;
  final double strokeWidth;

  Shape({
    required this.type,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  bool contains(Offset point) {
    Rect bounds = Rect.fromPoints(start, end);
    return bounds.contains(point);
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
    this.fontFamily = 'Roboto',
    this.fontSize = 20.0, // Default font size
  });

  // Method to calculate the size of the text bounding box
  Size calculateSize() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.getFont(fontFamily).copyWith(
          color: color,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: double.infinity);
    return Size(textPainter.width, textPainter.height);
  }

  bool contains(Offset point) {
    final textSize = calculateSize();
    final rect = Rect.fromLTWH(
        position.dx, position.dy, textSize.width, textSize.height);
    return rect.contains(point);
  }
}
