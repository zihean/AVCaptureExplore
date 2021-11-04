//
//  DeviceInfo.swift
//  Camera
//
//  Created by bytedance on 2021/11/1.
//

import UIKit

class DeviceInfo {
    public static func isiPhoneX() -> Bool {
        guard UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone else {
            return false
        }
        var iPhoneXSeries = false
        if #available(iOS 12.0, *) {
            if let delegate = UIApplication.shared.delegate, let window = delegate.window, window?.responds(to: #selector(getter: UIWindow.safeAreaInsets)) ?? false, let safeAreaInsets = window?.safeAreaInsets {
                iPhoneXSeries = safeAreaInsets.bottom > 0
            }
        } else if #available(iOS 11.0, *) {
            // fix iOS11 上面的crash
            let XS_MAX_HEIGHT: CGFloat = 2688
            let XS_HEIGHT: CGFloat = 2436
            let XR_HEIGHT: CGFloat = 1792
            let X_HEIGHT: CGFloat = 1624
            let iphoneXSizes: [CGFloat] = [XS_MAX_HEIGHT, XS_HEIGHT, XR_HEIGHT, X_HEIGHT]
            let screenHeight = UIScreen.main.nativeBounds.size.height
            iPhoneXSeries = iphoneXSizes.contains(screenHeight)
        }
        return iPhoneXSeries
    }
    
    public static var statusBarHeight: CGFloat {
        return DeviceInfo.isiPhoneX() ? 44.0 : 20.0
    }
    
    public static var safeAreaBottom: CGFloat {
        var bottom: CGFloat = 0
        if #available(iOS 11.0, *) {
            bottom = UIApplication.shared.windows.last?.safeAreaInsets.bottom ?? 0
        }
        return bottom
    }
}
