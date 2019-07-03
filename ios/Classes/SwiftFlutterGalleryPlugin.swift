import Flutter
import UIKit
import Photos

public class SwiftFlutterGalleryPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let stream = FlutterEventChannel(name: "flutter_gallery_plugin/paths", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterGalleryPlugin()
        stream.setStreamHandler(instance)
    }

    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        let args = arguments as! [String: Double]
        let startDate = Date(timeIntervalSince1970: args["startPeriod"]! / 1000)
        let endDate = Date(timeIntervalSince1970: args["endPeriod"]! / 1000)

        self.getPhotoPaths(startDate: startDate, endDate: endDate)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func onPhotoData(photoData: [String: Any?]) {
        guard let eventSink = eventSink else {
            return
        }

        eventSink(photoData)
    }

    public func closeSink() {
        guard let eventSink = eventSink else {
            return
        }

        eventSink(nil)
    }

    func getPhotoPaths(startDate: Date, endDate: Date) {
        let group = DispatchGroup()
        group.enter()

        DispatchQueue.main.async {
            let assets = self.fetchPhotos()
            if (assets.count == 0) {
                group.leave()
            } else {
                assets.enumerateObjects({
                    (asset, index, stop) in
                    if (asset.creationDate! < startDate) {
                        group.leave()
                        stop.pointee = true
                    }

                    if (asset.creationDate! >= startDate && asset.creationDate! <= endDate) {
                        group.enter()
                        self.getPhotoData(
                            asset: asset,
                            callback: {
                                (photoData) in
                                self.onPhotoData(photoData: photoData)
                                group.leave()
                        }
                        )
                    }
                })
            }
        }

        group.notify(queue: .main) {
            self.closeSink()
        }
    }

    func fetchPhotos() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
    }

    func getPhotoData(asset: PHAsset, callback: @escaping ([String: Any?])->()) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()

        options.deliveryMode = .fastFormat
        options.resizeMode = .exact
        options.version = .original

        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 512, height: 512),
            contentMode: .aspectFit,
            options: options,
            resultHandler: {
                (image, _) in
                let thumbPath = self.storeThumbnail(image: image);
                imageManager.requestImageData(
                    for: asset,
                    options: options,
                    resultHandler: {
                        (imageData, _, _, _) in
                        guard let data = imageData else {
                            callback(["path": thumbPath, "metadata": nil])
                            return
                        }

                        let metadata = self.fetchPhotoMetadata(data: data)
                        callback(["path": thumbPath, "metadata": metadata])
                    }
                )
            }
        )
    }

    func storeThumbnail(image: UIImage?) -> String {
        let fileName = String(format: "%@.jpg", ProcessInfo.processInfo.globallyUniqueString)
        let filePath = NSString.path(withComponents: [NSTemporaryDirectory(), fileName])

        FileManager.default.createFile(
            atPath: filePath,
            contents: image?.jpegData(compressionQuality: CGFloat(0.8)),
            attributes: [:]
        )

        return filePath
    }

    func fetchPhotoMetadata(data: Data) -> [String: Any]? {
        guard let selectedImageSourceRef = CGImageSourceCreateWithData(data as CFData, nil),
            let imagePropertiesDictionary = CGImageSourceCopyPropertiesAtIndex(selectedImageSourceRef, 0, nil) as? [String: Any] else {
                return nil
        }

        return imagePropertiesDictionary
    }
}
