import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_config.dart';
import 'ambient_background.dart';

class GalleryPhoto {
  final String path;
  final String thumbnail;
  GalleryPhoto(this.path, this.thumbnail);
  Map<String, dynamic> toJson() => {'path':path,'thumbnail':thumbnail};
}
Map<String, dynamic> compressBackground(Map<String, dynamic> args) {
  final original = img.decodeImage(args['bytes'] as Uint8List);
  if (original == null) throw const FormatException('无法读取这张图片，请使用 JPEG、PNG 或 WebP。');
  final oriented = img.bakeOrientation(original);
  final crop = (args['crop'] as List).cast<double>();
  final x=(crop[0]*oriented.width).round().clamp(0,oriented.width-1);
  final y=(crop[1]*oriented.height).round().clamp(0,oriented.height-1);
  final width=(crop[2]*oriented.width).round().clamp(1,oriented.width-x);
  final height=(crop[3]*oriented.height).round().clamp(1,oriented.height-y);
  var result=img.copyCrop(oriented,x:x,y:y,width:width,height:height);
  final limit=args['maxSide'] as int;
  if(result.width>limit || result.height>limit) {
    result=img.copyResize(result,width:result.width>=result.height?limit:null,height:result.height>result.width?limit:null,interpolation:img.Interpolation.average);
  }
  final thumbLimit=args['thumbnailSide'] as int;
  final thumbnail=img.copyResize(result,width:result.width>=result.height?thumbLimit:null,height:result.height>result.width?thumbLimit:null,interpolation:img.Interpolation.average);
  final quality=args['quality'] as int;
  return {'image':Uint8List.fromList(img.encodeJpg(result,quality:quality)),
    'thumbnail':Uint8List.fromList(img.encodeJpg(thumbnail,quality:quality)),'width':result.width,'height':result.height};
}
Map<String,dynamic> prepareBackgroundPreview(Map<String,dynamic> args) {
  final decoded = img.decodeImage(args['bytes'] as Uint8List);
  if (decoded == null) throw const FormatException('无法读取图片');
  final oriented = img.bakeOrientation(decoded);
  final limit = args['maxSide'] as int;
  final preview = oriented.width > limit || oriented.height > limit
      ? img.copyResize(oriented, width: oriented.width >= oriented.height ? limit : null,
          height: oriented.height > oriented.width ? limit : null)
      : oriented;
  return {'bytes':Uint8List.fromList(img.encodeJpg(preview,quality:args['quality'] as int)),
    'width':oriented.width,'height':oriented.height};
}
class BackgroundLibrary {
  static Future<List<GalleryPhoto>> load() async {
    final preferences=await SharedPreferences.getInstance();
    final records=jsonDecode(preferences.getString('background_gallery')??'[]') as List;
    return records.map((row)=>GalleryPhoto(row['path'] as String,row['thumbnail'] as String)).toList();
  }
  static Future<void> save(List<GalleryPhoto> photos) async {
    final preferences=await SharedPreferences.getInstance();
    await preferences.setString('background_gallery',jsonEncode(photos.map((p)=>p.toJson()).toList()));
  }
  static Future<GalleryPhoto?> import(BuildContext context) async {
    final picked=await ImagePicker().pickImage(source:ImageSource.gallery);
    if(picked==null)return null;
    final bytes=await picked.readAsBytes();
    if(bytes.length>ThemeConfig.number('gallery','maxBytes'))throw const FormatException('图片过大，请选择较小的照片。');
    final preview=await compute(prepareBackgroundPreview,{'bytes':bytes,
      'maxSide':ThemeConfig.number('gallery','maxSide').round(),'quality':ThemeConfig.number('gallery','quality').round()});
    if(!context.mounted)return null;
    final rect=await showDialog<Rect>(context:context,builder:(_)=>_CropDialog(
      bytes:preview['bytes'] as Uint8List,aspect:(preview['width'] as int)/(preview['height'] as int)));
    if(rect==null)return null;
    final encoded=await compute(compressBackground,{'bytes':bytes,'crop':[rect.left,rect.top,rect.width,rect.height],
      'maxSide':ThemeConfig.number('gallery','maxSide').round(),'thumbnailSide':ThemeConfig.number('gallery','thumbnailSide').round(),'quality':ThemeConfig.number('gallery','quality').round()});
    final root=await getApplicationDocumentsDirectory();
    final directory=Directory('${root.path}/xinghui-backgrounds');await directory.create(recursive:true);
    final name=DateTime.now().microsecondsSinceEpoch;
    final photo=GalleryPhoto('${directory.path}/photo-$name.jpg','${directory.path}/thumb-$name.jpg');
    await File(photo.path).writeAsBytes(encoded['image'] as Uint8List,flush:true);
    await File(photo.thumbnail).writeAsBytes(encoded['thumbnail'] as Uint8List,flush:true);
    return photo;
  }
  static Future<void> delete(GalleryPhoto photo) async {
    final root=await getApplicationDocumentsDirectory();
    final folder=Directory('${root.path}/xinghui-backgrounds');if(!await folder.exists())return;
    final directory=await folder.resolveSymbolicLinks();
    for(final name in [photo.path,photo.thumbnail]) {
      final file=File(name).absolute;
      if(await file.exists() && await file.parent.resolveSymbolicLinks()==directory)await file.delete();
    }
  }
}
class _CropDialog extends StatefulWidget {
  final Uint8List bytes;
  final double aspect;
  const _CropDialog({required this.bytes,required this.aspect});
  @override
  State<_CropDialog> createState()=>_CropDialogState();
}
class _CropDialogState extends State<_CropDialog> {
  Offset? start;
  Rect crop=const Rect.fromLTWH(0,0,1,1);
  @override
  Widget build(BuildContext context)=>AlertDialog(title:const Text('裁剪背景'),
    content:SizedBox(width:ThemeConfig.number('gallery','cropWidth'),height:ThemeConfig.number('gallery','cropHeight'),
      child:Column(children:[const Text('拖动框选要保留的部分，不框选就使用整张照片。'),Expanded(child:Center(child:AspectRatio(aspectRatio:widget.aspect,
        child:LayoutBuilder(builder:(context,box)=>GestureDetector(onPanStart:(event){start=Offset((event.localPosition.dx/box.maxWidth).clamp(0,1),(event.localPosition.dy/box.maxHeight).clamp(0,1));},
          onPanUpdate:(event){if(start!=null)setState(()=>crop=Rect.fromPoints(start!,Offset((event.localPosition.dx/box.maxWidth).clamp(0,1),(event.localPosition.dy/box.maxHeight).clamp(0,1))));},
          child:Stack(fit:StackFit.expand,children:[Image.memory(widget.bytes,fit:BoxFit.fill),IgnorePointer(child:CustomPaint(painter:_CropPainter(crop)))]))))))])),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('取消')),FilledButton(onPressed:crop.width>0&&crop.height>0?()=>Navigator.pop(context,crop):null,child:const Text('使用这张'))]);
}
class _CropPainter extends CustomPainter {
  final Rect crop;
  _CropPainter(this.crop);
  @override
  void paint(Canvas canvas,Size size){
    final rect=Rect.fromLTWH(crop.left*size.width,crop.top*size.height,crop.width*size.width,crop.height*size.height);
    final color=configuredColor(ThemeConfig.values['gallery']['cropColor'] as String);
    final outside=Path()..fillType=PathFillType.evenOdd..addRect(Offset.zero&size)..addRect(rect);
    canvas.drawPath(outside,Paint()..color=color.withOpacity(ThemeConfig.number('gallery','cropOpacity')));
    canvas.drawRect(rect,Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=ThemeConfig.number('gallery','cropBorderWidth'));
  }
  @override
  bool shouldRepaint(covariant _CropPainter old)=>old.crop!=crop;
}
