//
// HomeCoordinator+InAppNotification.swift
// Proton Pass - Created on 07/11/2024.
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
import Screens
import SwiftUI

extension HomepageCoordinator {
    func refreshInAppNotifications() {
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await inAppNotificationManager.fetchNotifications()
                if let notification = try await inAppNotificationManager.getNotificationToDisplay() {
                    displayNotification(notification)
                }
            } catch {
                handle(error: error)
            }
        }
    }

    func displayNotification(_ notification: InAppNotification) {
        addTelemetryEvent(with: .notificationDisplayNotification(notificationKey: notification
                .notificationKey))

        switch notification.displayType {
        case .banner:
            let view = InAppBannerView(notification: notification,
                                       onTap: { [weak self] notification in
                                           guard let self else { return }
                                           ctaFlow(notification)
                                       },
                                       onClose: { [weak self] notification in
                                           guard let self else { return }
                                           close(notification)
                                       })
            let viewController = UIHostingController(rootView: view)
            if let view = viewController.view {
                updateFloatingView(floatingView: view, shouldAdd: true)
            }
        case .modal:
            let view = InAppModalView(notification: notification,
                                      onTap: { [weak self] notification in
                                          guard let self else { return }
                                          ctaFlow(notification)
                                      }, onClose: { [weak self] notification in
                                          guard let self else { return }
                                          close(notification)
                                      })
            let viewController = UIHostingController(rootView: view)
            viewController.setDetentType(.custom(CGFloat(490)),
                                         parentViewController: rootViewController)
            present(viewController)
        }
    }

    private func close(_ notification: InAppNotification) {
        Task { [weak self] in
            guard let self else { return }
            if notification.displayType == .banner {
                updateFloatingView(floatingView: nil, shouldAdd: false)
            }
            do {
                try await inAppNotificationManager.updateNotificationState(notificationId: notification.id,
                                                                           newState: notification.removedState)
                addTelemetryEvent(with: .notificationChangeNotificationStatus(notificationKey: notification
                        .notificationKey,
                    notificationStatus: notification
                        .removedState.rawValue))
            } catch {
                logger.error(error)
            }
        }
    }

    private func ctaFlow(_ notification: InAppNotification) {
        Task { [weak self] in
            guard let self else { return }
            do {
                if notification.displayType == .banner {
                    updateFloatingView(floatingView: nil, shouldAdd: false)
                }
                addTelemetryEvent(with: .notificationNotificationCtaClick(notificationKey: notification
                        .notificationKey))
                try await inAppNotificationManager.updateNotificationState(notificationId: notification.id,
                                                                           newState: notification.removedState)

                if case let .externalNavigation(url) = notification.cta, let url {
                    urlOpener.open(urlString: url)
                }
            } catch {
                handle(error: error)
            }
        }
    }
}
