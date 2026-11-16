// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#include "qrimageprovider.h"

#include <QPainter>
#include <QUrl>

#include "qrcodegen.hpp"

QImage QrImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QByteArray text = QUrl::fromPercentEncoding(id.toUtf8()).toUtf8();
    const qrcodegen::QrCode qr = qrcodegen::QrCode::encodeText(text.constData(), qrcodegen::QrCode::Ecc::MEDIUM);
    const int quiet = 4;
    const int modules = qr.getSize() + quiet * 2;
    const int target = requestedSize.width() > 0 ? requestedSize.width() : modules * 8;
    const int scale = qMax(1, target / modules);
    QImage image(modules * scale, modules * scale, QImage::Format_RGB32);
    image.fill(Qt::white);
    QPainter painter(&image);
    for (int y = 0; y < qr.getSize(); ++y)
        for (int x = 0; x < qr.getSize(); ++x)
            if (qr.getModule(x, y))
                painter.fillRect((x + quiet) * scale, (y + quiet) * scale, scale, scale, QColor(0x10, 0x11, 0x16));
    painter.end();
    if (size)
        *size = image.size();
    return image;
}
