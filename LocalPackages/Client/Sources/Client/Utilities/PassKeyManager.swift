//
// PassKeyManager.swift
// Proton Pass - Created on 24/02/2023.
// Copyright (c) 2023 Proton Technologies AG
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

import Core
@preconcurrency import CryptoKit
import Entities
import Foundation
import ProtonCoreLogin

public protocol ShareKeyProtocol: Hashable, Sendable {
    var keyRotation: Int64 { get }
    var keyData: Data { get }
}

public struct DecryptedShareKey: ShareKeyProtocol {
    public let shareId: String
    public let keyRotation: Int64
    public let keyData: Data

    public init(shareId: String, keyRotation: Int64, keyData: Data) {
        self.shareId = shareId
        self.keyRotation = keyRotation
        self.keyData = keyData
    }
}

public struct DecryptedItemKey: ShareKeyProtocol {
    public let shareId: String
    public let itemId: String
    public let keyRotation: Int64
    public let keyData: Data

    public init(shareId: String, itemId: String, keyRotation: Int64, keyData: Data) {
        self.shareId = shareId
        self.itemId = itemId
        self.keyRotation = keyRotation
        self.keyData = keyData
    }
}

// sourcery: AutoMockable
public protocol PassKeyManagerProtocol: Sendable, AnyObject {
    /// Get share key of a given key rotation to decrypt share content
    func getShareKey(userId: String, shareId: String, keyRotation: Int64) async throws -> DecryptedShareKey

    /// Get share key with latest rotation
    func getLatestShareKey(userId: String, shareId: String) async throws -> DecryptedShareKey

    /// Get all share keys
    func getShareKeys(userId: String,
                      share: Share,
                      item: any ItemIdentifiable) async throws -> [any ShareKeyProtocol]

    /// Get the latest key of an item to encrypt item content
    func getLatestItemKey(userId: String, shareId: String, itemId: String) async throws -> DecryptedItemKey

    /// Get all decrypted item keys
    func getItemKeys(userId: String, shareId: String, itemId: String) async throws -> [DecryptedItemKey]

    func getItemKey(userId: String,
                    shareId: String,
                    itemId: String,
                    keyRotation: Int64) async throws -> DecryptedItemKey
}

public actor PassKeyManager: PassKeyManagerProtocol {
    private var decryptedShareKeys = Set<DecryptedShareKey>()
    private let userManager: any UserManagerProtocol
    private let shareKeyRepository: any ShareKeyRepositoryProtocol
    private let itemKeyDatasource: any RemoteItemKeyDatasourceProtocol
    private let logger: Logger
    private let symmetricKeyProvider: any SymmetricKeyProvider

    public init(shareKeyRepository: any ShareKeyRepositoryProtocol,
                itemKeyDatasource: any RemoteItemKeyDatasourceProtocol,
                userManager: any UserManagerProtocol,
                logManager: any LogManagerProtocol,
                symmetricKeyProvider: any SymmetricKeyProvider) {
        self.shareKeyRepository = shareKeyRepository
        self.itemKeyDatasource = itemKeyDatasource
        self.userManager = userManager
        logger = .init(manager: logManager)
        self.symmetricKeyProvider = symmetricKeyProvider
    }
}

public extension PassKeyManager {
    func getShareKey(userId: String,
                     shareId: String,
                     keyRotation: Int64) async throws -> DecryptedShareKey {
        // ⚠️ Do not add logs to this function because it's supposed to be called all the time
        // when decrypting items. As IO operations caused by the log system take time
        // this will slow down dramatically the decryping process
        if let cachedKey = decryptedShareKeys.first(where: {
            $0.shareId == shareId && $0.keyRotation == keyRotation
        }) {
            return cachedKey
        }

        let allEncryptedShareKeys = try await shareKeyRepository.getKeys(userId: userId, shareId: shareId)
        guard let encryptedShareKey = allEncryptedShareKeys.first(where: { $0.shareId == shareId }) else {
            throw PassError.keysNotFound(shareID: shareId)
        }
        return try await decryptAndCache(encryptedShareKey)
    }

    func getLatestShareKey(userId: String, shareId: String) async throws -> DecryptedShareKey {
        let allEncryptedShareKeys = try await shareKeyRepository.getKeys(userId: userId, shareId: shareId)
        let latestShareKey = try allEncryptedShareKeys.latestKey()
        return try await decryptAndCache(latestShareKey)
    }

    func getShareKeys(userId: String,
                      share: Share,
                      item: any ItemIdentifiable) async throws -> [any ShareKeyProtocol] {
        switch share.shareType {
        case .vault:
            return try await getItemKeys(userId: userId,
                                         shareId: item.shareId,
                                         itemId: item.itemId)

        case .item:
            let allEncryptedShareKeys = try await shareKeyRepository.getKeys(userId: userId,
                                                                             shareId: item.shareId)

            var decryptedKeys = [DecryptedShareKey]()
            for encryptedKey in allEncryptedShareKeys {
                let decryptedKey = try await decryptAndCache(encryptedKey)
                decryptedKeys.append(decryptedKey)
            }
            return decryptedKeys

        case .unknown:
            throw PassError.unknownShareType
        }
    }

    func getLatestItemKey(userId: String,
                          shareId: String,
                          itemId: String) async throws -> DecryptedItemKey {
        let keyDescription = "shareId \"\(shareId)\", itemId: \"\(itemId)\""
        logger.trace("Getting latest item key \(keyDescription)")
        let latestItemKey = try await itemKeyDatasource.getLatestKey(userId: userId,
                                                                     shareId: shareId,
                                                                     itemId: itemId)

        logger.trace("Decrypting latest item key \(keyDescription)")
        let decryptedItemKey = try await decrypt(itemKey: latestItemKey,
                                                 userId: userId,
                                                 shareId: shareId,
                                                 itemId: itemId)
        logger.trace("Decrypted latest item key \(keyDescription)")
        return decryptedItemKey
    }

    func getItemKeys(userId: String,
                     shareId: String,
                     itemId: String) async throws -> [DecryptedItemKey] {
        logger.trace("Getting all item keys itemId \(itemId), shareId \(shareId)")
        let encryptedKeys = try await itemKeyDatasource.getAllKeys(userId: userId,
                                                                   shareId: shareId,
                                                                   itemId: itemId)
        logger.trace("Decrypting \(encryptedKeys.count) item keys itemId \(itemId), shareId \(shareId)")
        var decryptedKeys = [DecryptedItemKey]()
        for encryptedKey in encryptedKeys {
            let decryptedKey = try await decrypt(itemKey: encryptedKey,
                                                 userId: userId,
                                                 shareId: shareId,
                                                 itemId: itemId)
            decryptedKeys.append(decryptedKey)
        }
        logger.trace("Decrypted \(encryptedKeys.count) item keys itemId \(itemId), shareId \(shareId)")
        return decryptedKeys
    }

    func getItemKey(userId: String,
                    shareId: String,
                    itemId: String,
                    keyRotation: Int64) async throws -> DecryptedItemKey {
        guard let key = try await getItemKeys(userId: userId, shareId: shareId, itemId: itemId)
            .first(where: { $0.keyRotation == keyRotation }) else {
            throw PassError.keysNotFound(shareID: shareId)
        }
        return key
    }
}

private extension PassKeyManager {
    func decryptAndCache(_ encryptedShareKey: SymmetricallyEncryptedShareKey) async throws -> DecryptedShareKey {
        let shareId = encryptedShareKey.shareId
        let keyRotation = encryptedShareKey.shareKey.keyRotation
        let keyDescription = "share id \(shareId), keyRotation: \(keyRotation)"
        logger.trace("Decrypting share key \(keyDescription)")

        let decryptedKey = try await symmetricKeyProvider.getSymmetricKey().decrypt(encryptedShareKey.encryptedKey)
        guard let decryptedKeyData = try decryptedKey.base64Decode() else {
            throw PassError.crypto(.failedToBase64Decode)
        }
        let decryptedShareKey = DecryptedShareKey(shareId: encryptedShareKey.shareId,
                                                  keyRotation: encryptedShareKey.shareKey.keyRotation,
                                                  keyData: decryptedKeyData)
        decryptedShareKeys.insert(decryptedShareKey)

        logger.info("Decrypted & cached share key share \(keyDescription)")
        return decryptedShareKey
    }

    func decrypt(itemKey: ItemKey,
                 userId: String,
                 shareId: String,
                 itemId: String) async throws -> DecryptedItemKey {
        let vaultKey = try await getShareKey(userId: userId,
                                             shareId: shareId,
                                             keyRotation: itemKey.keyRotation)

        guard let encryptedItemKeyData = try itemKey.key.base64Decode() else {
            throw PassError.crypto(.failedToBase64Decode)
        }

        let decryptedItemKeyData = try AES.GCM.open(encryptedItemKeyData,
                                                    key: vaultKey.keyData,
                                                    associatedData: .itemKey)

        return .init(shareId: shareId,
                     itemId: itemId,
                     keyRotation: itemKey.keyRotation,
                     keyData: decryptedItemKeyData)
    }
}
