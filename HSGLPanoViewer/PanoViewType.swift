//
//  PanoViewType.swift
//  HSGLPanoViewer
//
//  Created by Hanson on 2020/9/12.
//  Copyright © 2020 Hanson. All rights reserved.
//

import Foundation
import GLKit

enum PanoViewType: Int, CaseIterable {
    case sphere
    case pano
    case asteroid
    
    var description: String {
        switch self {
        case .sphere:
            return "球体"
        case .pano:
            return "全景"
        case .asteroid:
            return "小行星"
        }
    }
    
    var viewTransform: ViewTransform {
        return ViewTransform(type: self)
    }
}
