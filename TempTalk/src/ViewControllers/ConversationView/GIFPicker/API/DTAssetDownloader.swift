//
//  DTAssetDownloader.swift
//  TempTalk
//
//  Downloads GIF assets via the shared proxied-content downloader.
//

import Foundation
import CoreServices
import TTServiceKit

class DTAssetDownloader: ProxiedContentDownloader {
    // Persist GIFs on disk so a previously downloaded GIF is served from the cache on later
    // launches instead of being re-downloaded.
    public static let gifDownloader = DTAssetDownloader(downloadFolderName: "GIFs", isPersistent: true)
}

class DTAssetDescription: ProxiedContentAssetDescription {
    enum FileType: Equatable {
        case jpg, gif, mp4, webp

        var `extension`: String {
            switch self {
            case .jpg: return "jpg"
            case .gif: return "gif"
            case .mp4: return "mp4"
            case .webp: return "webp"
            }
        }

        var utiType: String {
            switch self {
            case .jpg: return kUTTypeJPEG as String
            case .gif: return kUTTypeGIF as String
            case .mp4: return kUTTypeMPEG4 as String
            case .webp: return "org.webmproject.webp"
            }
        }
    }

    let fileType: FileType

    init?(urlString: String) {
        guard let url = URL(string: urlString) else {
            return nil
        }
        switch url.pathExtension.lowercased() {
        case "jpg": self.fileType = .jpg
        case "gif": self.fileType = .gif
        case "mp4": self.fileType = .mp4
        case "webp": self.fileType = .webp
        default:
            return nil
        }
        super.init(url: url as NSURL, fileExtension: fileType.extension)
    }
}
