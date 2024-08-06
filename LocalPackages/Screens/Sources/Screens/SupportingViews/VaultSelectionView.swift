//
// VaultSelectionView.swift
// Proton Pass - Created on 06/08/2024.
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

import DesignSystem
import Entities
import ProtonCoreUIFoundations
import SwiftUI

public struct VaultSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedVault: VaultListUiModel?
    public let vaults: [VaultListUiModel]

    public init(selectedVault: Binding<VaultListUiModel?>, vaults: [VaultListUiModel]) {
        _selectedVault = selectedVault
        self.vaults = vaults
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vaults, id: \.vault.id) { vault in
                        let isSelected = vault == selectedVault
                        Button(action: {
                            selectedVault = vault
                            dismiss()
                        }, label: {
                            VaultRow(thumbnail: { VaultThumbnail(vault: vault.vault) },
                                     title: vault.vault.name,
                                     itemCount: vault.itemCount,
                                     isShared: vault.vault.shared,
                                     isSelected: isSelected,
                                     height: 74)
                                .padding(.horizontal)
                        })
                        .buttonStyle(.plain)
                    }

//                    // Gimmick view to take up space
//                    closeButton
//                        .opacity(0)
//                        .padding()
//                        .disabled(true)
                }
            }

//                closeButton
//                    .padding()
//            }
            .background(PassColor.backgroundWeak.toColor)
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: selectedVault)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select a default vault for aliases sync")
                        .adaptiveForegroundStyle(PassColor.textNorm.toColor)
                }
            }
        }
    }

    private var closeButton: some View {
        Button(action: dismiss.callAsFunction) {
            Text("Close")
                .foregroundStyle(PassColor.textNorm.toColor)
        }
    }
}
