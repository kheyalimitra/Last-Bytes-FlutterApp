import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';


class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return new _CameraExampleHomeState();
  }
}

/// Returns a suitable camera icon for [direction].
IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw new ArgumentError('Unknown lens direction');
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class _CameraExampleHomeState extends State<CameraExampleHome> {
  CameraController controller;
  String imagePath;

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: _scaffoldKey,
      appBar: new AppBar(
        title: const Text('Last Bytes - Mobile v1'),
      ),
      body: new Column(
        children: <Widget>[
          new Expanded(
            child: new Container(
              child: new Padding(
                padding: const EdgeInsets.all(1.0),
                child: new Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
              decoration: new BoxDecoration(
                color: Colors.black,
                border: new Border.all(
                  color: controller != null
                      ? Colors.redAccent
                      : Colors.grey,
                  width: 3.0,
                ),
              ),
            ),
          ),
          _captureControlRowWidget(),
          new Padding(
            padding: const EdgeInsets.all(5.0),
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                _cameraTogglesRowWidget()
//                _thumbnailWidget()
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return new AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: new CameraPreview(controller),
      );
    }
  }

  /// Display the thumbnail of the captured image or video.
  Widget _thumbnailWidget() {
    return new Expanded(
      child: new Align(
        alignment: Alignment.centerRight,
        child: imagePath == null ? null
            : new SizedBox(
          child:
          new Image.file(new File(imagePath)),
          width: 350.0,
          height: 350.0,
        ),
      ),
    );
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    return new Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        new IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          onPressed: controller != null &&
              controller.value.isInitialized &&
              !controller.value.isRecordingVideo
              ? onTakePictureButtonPressed
              : null,
        )
      ],
    );
  }

  /// Display a row of toggle to select the camera (or a message if no camera is available).
  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    if (cameras.isEmpty) {
      return const Text('No camera found');
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(
          new SizedBox(
            width: 90.0,
            child: new RadioListTile<CameraDescription>(
              title:
              new Icon(getCameraLensIcon(cameraDescription.lensDirection)),
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged: controller != null && controller.value.isRecordingVideo
                  ? null
                  : onNewCameraSelected,
            ),
          ),
        );
      }
    }

    return new Row(children: toggles);
  }


  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState
        .showSnackBar(new SnackBar(content: new Text(message)));
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = new CameraController(cameraDescription, ResolutionPreset.high);

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {
          imagePath = filePath;
        });
       if (filePath != null) {
         classifyAndDisplay(filePath);
       }
      }
    });
  }

  Future<String> classifyAndDisplay(filePath) async {
    Response<String> response = await _getClassifiedResult(filePath);
     List<String> classificationList = parseResponseToGetBinName(response);
    String binImageName = getBinImageName (classificationList);
    _generateResultScreen(binImageName, classificationList[0]);
  }

  Future<Response<String>> _getClassifiedResult(filePath) async {
    Map<String, dynamic> reqHeaders = new Map<String, dynamic>();
    Map<String, dynamic> uploadFile = new Map<String, dynamic>();

    String username = 'Ask Kheyali for credential';
    String password = 'Ask Kheyali for credential';
    String base64Encoded = 'Basic ' +  base64.encode(utf8.encode("${username}:${password}"));
    uploadFile["image"] = new UploadFileInfo(new File(filePath), "image.jpg");
    reqHeaders["authorization"] =  base64Encoded;
    Options reqOptions =new Options(
        headers: reqHeaders
    );
    FormData formData = new FormData.from(uploadFile);
    Dio dio = new Dio();
    Response<String> response = await dio.post("https://waste-classifier-cs.cfapps.sap.hana.ondemand.com/classify",
        data: formData,
        options: reqOptions
    );
    return response;
  }

  void _generateResultScreen(String binImageName, String label) {
    Navigator.of(context).push(
        new MaterialPageRoute(builder: (context) {
          return new Scaffold(
            appBar:  new AppBar(title : new Text( label + " goes to ..")
            ),
            body: new Column(
              children: <Widget>[
                new Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: new Row(
                    children: <Widget>[
                      _thumbnailWidget(),
                      new Image.asset('assets/arrow.png', scale: 3.0, width: 50.0, height:50.0),
                      new Image.asset('assets/'+binImageName, scale: 3.0, width: 200.0, height: 200.0)
                    ],
                  ),
                ),
              ],
            ),
          );
        })
    );
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await new Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}


  /// A function that will convert a response body into a List<ClassifiedObject> and then map the image name
  List<String> parseResponseToGetBinName(Response responseBody) {
    List<String> classificationList = new List();
    Map parsedJsonObj = jsonDecode(responseBody.data);
    for (var entry in parsedJsonObj["result"]) {
        classificationList.add(entry.values.first);
    }
    return classificationList;

}

String getBinImageName (classificationList) {

//  for (String label in classificationList) {
   switch(classificationList[0]) {
     case "cardboard carton" :
     case "paper":
     case "newspapers":
     case "napkin":
     case "paper cup":
     case "paper roll":
     case "paper":
     case  "paper box":
     case "shredded papers":
     case "tissue paper":
     case"calendar":
      return "paper.png";


     case "plastic bag":
     case "plastic cup":
     case "plastic box":
     case "plastic container":
     case "plastic utensils":
     case "plastic lid":
     case "plastic bottle":
     case "refundable bottle":
     case "milk jug":
       return "plastic.png";

     case "glass":
     case "glass bottle":
       return "glass.png";

     case "metal can":
     case "aluminum can":
     case "refundable can":
     case "aluminum tray":
       return "metal.png";

     case "chopsticks":
     case "food scraps":
     case "tea bag":
       return "foodscrape.png";

     case "candy wrappers":
     case "styrofoam box":
     case "tetra pack":
     default:
       return "landfill.jpg";
   }
//  }
}


class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new CameraExampleHome(), debugShowCheckedModeBanner: false // helps to stop showing "Debug banner in screen"
    );
  }
}

List<CameraDescription> cameras;

Future<Null> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(new CameraApp());
}
