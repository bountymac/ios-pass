//
// ItemFile.swift
// Proton Pass - Created on 03/12/2024.
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

import Foundation

public struct ItemFile: Decodable, Sendable, Equatable {
    public let fileID: String
    public let size: Int
    public let metadata: String
    public let fileKey: String
    public let itemKeyRotation: Int
    public let chunks: [FileChunk]
    public let revisionAdded: Int
    public let revisionRemoved: Int?
    public let createTime: Int
    public let modifyTime: Int

    // To be filled up once metadata is decrypted
    public var name: String?
    public var mimeType: String?

    public init(fileID: String,
                size: Int,
                metadata: String,
                fileKey: String,
                itemKeyRotation: Int,
                chunks: [FileChunk],
                revisionAdded: Int,
                revisionRemoved: Int,
                createTime: Int,
                modifyTime: Int) {
        self.fileID = fileID
        self.size = size
        self.metadata = metadata
        self.fileKey = fileKey
        self.itemKeyRotation = itemKeyRotation
        self.chunks = chunks
        self.revisionAdded = revisionAdded
        self.revisionRemoved = revisionRemoved
        self.createTime = createTime
        self.modifyTime = modifyTime
    }
}

public struct FileChunk: Decodable, Sendable, Equatable {
    public let chunkID: String
    public let index: Int
    public let size: Int
}

public enum ItemFileAction: Sendable, Identifiable {
    case preview(URL)
    case save(URL)
    case share(URL)

    public var id: String {
        switch self {
        case let .preview(url):
            "preview" + url.path()
        case let .save(url):
            "save" + url.path()
        case let .share(url):
            "share" + url.path()
        }
    }
}
