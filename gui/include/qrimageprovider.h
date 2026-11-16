// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#ifndef CHIAKI_QRIMAGEPROVIDER_H
#define CHIAKI_QRIMAGEPROVIDER_H

#include <QQuickImageProvider>

// image://qr/<percent-encoded text>: a QR code generated locally (Nayuki qrcodegen, MIT).
// Dark modules on white with a quiet zone, scaled with sharp edges to the requested size.
class QrImageProvider : public QQuickImageProvider
{
public:
    QrImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};

#endif // CHIAKI_QRIMAGEPROVIDER_H
