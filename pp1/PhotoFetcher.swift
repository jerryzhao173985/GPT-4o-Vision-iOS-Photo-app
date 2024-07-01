import Photos
import SwiftUI

class PhotoFetcher: ObservableObject {
    @Published var photos: [UIImage] = []
    @Published var fetchCount: Int = 10
    @Published var includeScreenshotsOnly: Bool = true

    init() {
        // Request authorization on initialization
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.fetchPhotos()
                case .denied, .restricted, .notDetermined:
                    print("Photo Library access denied or restricted.")
                @unknown default:
                    print("Unknown authorization status.")
                }
            }
        }
    }

    func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = fetchCount

        var assetCollection: PHAssetCollection?
        if includeScreenshotsOnly {
            assetCollection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil).firstObject
        } else {
            assetCollection = nil
        }

        let assets: PHFetchResult<PHAsset>
        if let collection = assetCollection {
            assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        } else {
            assets = PHAsset.fetchAssets(with: fetchOptions)
        }

        let imageManager = PHCachingImageManager()
        var images: [UIImage] = []
        assets.enumerateObjects { asset, _, _ in
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.deliveryMode = .highQualityFormat

            imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { image, _ in
                if let img = image {
                    images.append(img)
                } else {
                    print("Failed to get image for asset: \(asset)")
                }
            }
        }
        DispatchQueue.main.async {
            self.photos = images
        }
    }

    func base64Encode(image: UIImage) -> String? {
        return image.jpegData(compressionQuality: 1)?.base64EncodedString()
    }
}

