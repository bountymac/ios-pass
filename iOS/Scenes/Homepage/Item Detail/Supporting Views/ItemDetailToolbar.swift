//
// ItemDetailToolbar.swift
// Proton Pass - Created on 08/02/2023.
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

import DesignSystem
import Entities
import Macro
import ProtonCoreUIFoundations
import SwiftUI

@MainActor
struct ItemDetailToolbar: ToolbarContent {
    @ObservedObject var viewModel: BaseItemDetailViewModel

    private var itemContentType: ItemContentType {
        viewModel.itemContent.type
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CircleButton(icon: viewModel.isShownAsSheet ? IconProvider.chevronDown : IconProvider.chevronLeft,
                         iconColor: itemContentType.normMajor2Color,
                         backgroundColor: itemContentType.normMinor1Color,
                         accessibilityLabel: "Close") {
                viewModel.goBack()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            switch viewModel.itemContent.item.itemState {
            case .active:
                HStack(spacing: 0) {
                    CapsuleLabelButton(icon: IconProvider.pencil,
                                       title: #localized("Edit"),
                                       titleColor: PassColor.textInvert,
                                       backgroundColor: itemContentType.normMajor1Color,
                                       isDisabled: !viewModel.isAllowedToEdit) {
                        viewModel.edit()
                    }

                    if viewModel.isAllowedToShare {
                        CircleButton(icon: IconProvider.usersPlus,
                                     iconColor: itemContentType.normMajor2Color,
                                     backgroundColor: itemContentType.normMinor1Color,
                                     accessibilityLabel: "Share") {
                            viewModel.share()
                        }
                    }

                    Menu(content: {
                        Button { viewModel.moveToAnotherVault() }
                            label: { Label(title: { Text("Move to another vault") },
                                           icon: { Image(uiImage: IconProvider.folderArrowIn) }) }
                            .hidden(!viewModel.isAllowedToEdit)

                        if viewModel.isPublicLinkActive {
                            Button { viewModel.publicLinkSharing() }
                                label: { Label(title: { Text(verbatim: "Share with public link") },
                                               icon: { Image(systemName: "square.and.arrow.up") }) }
                        }

                        Button { viewModel.toggleItemPinning() }
                            label: {
                                Label(title: { Text(viewModel.itemContent.item.pinTitle) },
                                      icon: { Image(uiImage: viewModel.itemContent.item.pinIcon) })
                            }

                        if viewModel.itemContent.type == .note {
                            Button { viewModel.copyNoteContent() }
                                label: { Label(title: { Text("Copy note content") },
                                               icon: { Image(uiImage: IconProvider.note) }) }
                        }

                        if viewModel.itemContent.type != .alias {
                            Button(action: { viewModel.clone() }, label: {
                                Label(title: { Text("Clone") },
                                      icon: { Image(uiImage: IconProvider.squares) })
                            })
                        }

                        if viewModel.itemContent.type == .login {
                            let title = viewModel.isMonitored ?
                                #localized("Exclude from monitoring") :
                                #localized("Include for monitoring")
                            let icon: UIImage = viewModel.isMonitored ? IconProvider.eyeSlash : IconProvider.eye

                            Button(action: { viewModel.toggleMonitoring() },
                                   label: { Label(title: { Text(title) },
                                                  icon: { Image(uiImage: icon) }) })
                        }

                        Divider()

                        Button(role: .destructive,
                               action: { viewModel.moveToTrash() },
                               label: { Label(title: { Text("Move to trash") },
                                              icon: { Image(uiImage: IconProvider.trash) }) })
                            .hidden(!viewModel.isAllowedToEdit)
                    }, label: {
                        CircleButton(icon: IconProvider.threeDotsVertical,
                                     iconColor: itemContentType.normMajor2Color,
                                     backgroundColor: itemContentType.normMinor1Color,
                                     accessibilityLabel: "Item's action Menu")
                    })
                }

            case .trashed:
                Menu(content: {
                    Button { viewModel.restore() }
                        label: { Label(title: { Text("Restore") },
                                       icon: { Image(uiImage: IconProvider.clockRotateLeft) }) }

                    Divider()

                    Button(role: .destructive,
                           action: { viewModel.showingDeleteAlert.toggle() },
                           label: { Label(title: { Text("Delete permanently") },
                                          icon: { Image(uiImage: IconProvider.trashCross) }) })
                }, label: {
                    CircleButton(icon: IconProvider.threeDotsVertical,
                                 iconColor: itemContentType.normMajor2Color,
                                 backgroundColor: itemContentType.normMinor1Color)
                })
                .disabled(!viewModel.isAllowedToEdit)
            }
        }
    }
}
