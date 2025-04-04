//
// FileAttachmentPreviewModel.swift
// Proton Pass - Created on 23/12/2024.
// Copyright (c) 2024 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.
//

import Client
import Core
import Entities
import Foundation

public protocol FileAttachmentPreviewHandler: Sendable {
    func downloadAndDecrypt(file: ItemFile) async throws
        -> AsyncThrowingStream<ProgressEvent<URL>, any Error>
}

public enum FileAttachmentPreviewPostDownloadAction: String, Identifiable, Sendable {
    case none, save, share

    public var id: String { rawValue }
}

public enum FileAttachmentPreviewMode: Sendable, Identifiable {
    case pending(URL)
    case item(ItemFile,
              any FileAttachmentPreviewHandler,
              FileAttachmentPreviewPostDownloadAction)

    public var id: String {
        switch self {
        case let .pending(url):
            url.path()
        case let .item(item, _, _):
            item.fileID
        }
    }
}

@MainActor
final class FileAttachmentPreviewModel: ObservableObject {
    @Published private(set) var url: FetchableObject<URL> = .fetching
    @Published private(set) var progress: Float = 0.0
    @Published var urlToSave: URL?
    @Published var urlToShare: URL?
    private let mode: FileAttachmentPreviewMode
    private let formatter: ByteCountFormatter

    var fileName: String? {
        if case let .item(itemFile, _, _) = mode {
            itemFile.name
        } else {
            nil
        }
    }

    var progressDetail: String? {
        guard case let .item(itemFile, _, _) = mode else {
            return nil
        }
        let total = formatter.string(fromByteCount: Int64(itemFile.size))
        let downloadedBytes = Int64(progress * Float(itemFile.size))
        let downloaded = formatter.string(fromByteCount: downloadedBytes)
        return "\(Int(progress * 100))% (\(downloaded) / \(total))"
    }

    init(mode: FileAttachmentPreviewMode,
         formatter: ByteCountFormatter = Constants.Attachment.formatter) {
        self.mode = mode
        self.formatter = formatter
    }
}

extension FileAttachmentPreviewModel {
    func fetchFile() async {
        switch mode {
        case let .pending(url):
            self.url = .fetched(url)

        case let .item(itemFile, handler, action):
            do {
                if url.isError {
                    url = .fetching
                }

                let stream = try await handler.downloadAndDecrypt(file: itemFile)

                for try await event in stream {
                    switch event {
                    case let .progress(value):
                        progress = value

                    case let .result(value):
                        url = .fetched(value)
                        switch action {
                        case .none:
                            break
                        case .save:
                            urlToSave = value
                        case .share:
                            urlToShare = value
                        }
                    }
                }
            } catch {
                url = .error(error)
            }
        }
    }
}
