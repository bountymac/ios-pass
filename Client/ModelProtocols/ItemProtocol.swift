//
// ItemProtocol.swift
// Proton Pass - Created on 09/08/2022.
// Copyright (c) 2022 Proton Technologies AG
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

import Foundation

public enum ItemContentType {
    case alias
    case login
    case note
}

public enum ItemContent {
    case alias
    case login(ItemLoginProtocol)
    case note
}

public protocol ItemProtocol {
    var itemMetadata: ItemMetadataProtocol { get }
    var itemContent: ItemContent { get }
}

public protocol ItemMetadataProtocol {
    var name: String { get }
    var note: String { get }
}

public protocol ItemNoteProtocol {}

public protocol ItemLoginProtocol {
    var username: String { get }
    var password: String { get }
    var urls: [String] { get }
}

public protocol ItemAliasProtocol {}

typealias ItemProtobuf = ProtonPassItemV1_Item
typealias ItemMetadataProtobuf = ProtonPassItemV1_Metadata
typealias ItemContentProtobuf = ProtonPassItemV1_Content
typealias ItemNoteProtobuf = ProtonPassItemV1_ItemNote
typealias ItemLoginProtobuf = ProtonPassItemV1_ItemLogin
typealias ItemAliasProtobuf = ProtonPassItemV1_ItemAlias

extension ItemMetadataProtobuf: ItemMetadataProtocol {}
extension ItemNoteProtobuf: ItemNoteProtocol {}
extension ItemAliasProtobuf: ItemAliasProtocol {}
extension ItemLoginProtobuf: ItemLoginProtocol {}

extension ItemProtobuf: ItemProtocol {
    public var itemMetadata: ItemMetadataProtocol { metadata }

    public var itemContent: ItemContent {
        switch content.content {
        case .alias:
            return .alias
        case .note:
            return .note
        case .login(let login):
            return .login(login)
        case .none:
            return .note
        }
    }
}

public extension Array where Element == ItemProtocol {
    func filter(by contentType: ItemContentType) -> [Element] {
        filter { element in
            switch element.itemContent {
            case .alias:
                return contentType == .alias
            case .login:
                return contentType == .login
            case .note:
                return contentType == .note
            }
        }
    }
}
