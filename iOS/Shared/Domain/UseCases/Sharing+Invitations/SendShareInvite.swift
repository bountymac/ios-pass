//
//
// SendShareInvite.swift
// Proton Pass - Created on 21/07/2023.
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
//

import Client
import Core
import CryptoKit
import Entities
import ProtonCoreCrypto
import ProtonCoreLogin
import UseCases

/// Make an invitation and return the shared `Vault`
protocol SendVaultShareInviteUseCase: Sendable {
    func execute(with infos: SharingInfos) async throws -> Vault
}

extension SendVaultShareInviteUseCase {
    func callAsFunction(with infos: SharingInfos) async throws -> Vault {
        try await execute(with: infos)
    }
}

final class SendVaultShareInvite: @unchecked Sendable, SendVaultShareInviteUseCase {
    private let createAndMoveItemToNewVault: CreateAndMoveItemToNewVaultUseCase
    private let shareInviteService: ShareInviteServiceProtocol
    private let passKeyManager: PassKeyManagerProtocol
    private let shareInviteRepository: ShareInviteRepositoryProtocol
    private let userData: UserData
    private let syncEventLoop: SyncEventLoopProtocol

    init(createAndMoveItemToNewVault: CreateAndMoveItemToNewVaultUseCase,
         shareInviteService: ShareInviteServiceProtocol,
         passKeyManager: PassKeyManagerProtocol,
         shareInviteRepository: ShareInviteRepositoryProtocol,
         userData: UserData,
         syncEventLoop: SyncEventLoopProtocol) {
        self.createAndMoveItemToNewVault = createAndMoveItemToNewVault
        self.shareInviteService = shareInviteService
        self.passKeyManager = passKeyManager
        self.shareInviteRepository = shareInviteRepository
        self.userData = userData
        self.syncEventLoop = syncEventLoop
    }

    func execute(with infos: SharingInfos) async throws -> Vault {
        guard let role = infos.role else {
            throw SharingError.incompleteInformation
        }

        let vault = try await getVault(from: infos)
        let vaultKey = try await passKeyManager.getLatestShareKey(shareId: vault.shareId)
        let inviteeData = try generateInviteeData(from: infos, vault: vault, vaultKey: vaultKey)
        let invited = try await shareInviteRepository.sendInvite(shareId: vault.shareId,
                                                                 inviteeData: inviteeData,
                                                                 targetType: .vault,
                                                                 shareRole: role)

        if invited {
            syncEventLoop.forceSync()
            shareInviteService.resetShareInviteInformations()
            return vault
        }

        throw SharingError.failedToInvite
    }
}

private extension SendVaultShareInvite {
    func getVault(from info: SharingInfos) async throws -> Vault {
        switch info.vault {
        case let .existing(vault):
            vault
        case let .new(vaultProtobuf, itemContent):
            try await createAndMoveItemToNewVault(vault: vaultProtobuf, itemContent: itemContent)
        default:
            throw SharingError.incompleteInformation
        }
    }

    func generateInviteeData(from info: SharingInfos,
                             vault: Vault,
                             vaultKey: DecryptedShareKey) throws -> InviteeData {
        guard let email = info.email else {
            throw SharingError.incompleteInformation
        }

        if let key = info.receiverPublicKeys?.first {
            let signedKey = try encryptKeys(addressId: vault.addressId,
                                            publicReceiverKey: key.value,
                                            userData: userData,
                                            vaultKey: vaultKey)
            return .proton(email: email, keys: [signedKey])
        } else {
            let signature = try createAndSignSignature(vaultKey: vaultKey, email: email)
            return .external(email: email, signature: signature)
        }
    }

    func encryptKeys(addressId: String,
                     publicReceiverKey: String,
                     userData: UserData,
                     vaultKey: DecryptedShareKey) throws -> ItemKey {
        guard let addressKey = try CryptoUtils.unlockAddressKeys(addressID: addressId,
                                                                 userData: userData).first else {
            throw PPClientError.crypto(.addressNotFound(addressID: addressId))
        }

        let publicKey = ArmoredKey(value: publicReceiverKey)
        let signerKey = SigningKey(privateKey: addressKey.privateKey,
                                   passphrase: addressKey.passphrase)
        let context = SignatureContext(value: Constants.existingUserSharingSignatureContext,
                                       isCritical: true)

        let encryptedVaultKeyString = try Encryptor.encrypt(publicKey: publicKey,
                                                            clearData: vaultKey.keyData,
                                                            signerKey: signerKey,
                                                            signatureContext: context)
            .unArmor().value.base64EncodedString()

        return ItemKey(key: encryptedVaultKeyString, keyRotation: vaultKey.keyRotation)
    }

    func createAndSignSignature(vaultKey: DecryptedShareKey, email: String) throws -> String {
        ""
    }
}
