//
//  ViewTransform.swift
//  HSGLPanoViewer
//
//  Created by Hanson on 2020/9/12.
//  Copyright © 2020 Hanson. All rights reserved.
//

import GLKit

struct ViewTransform {
    var type: PanoViewType
    
    /// 投影矩阵的视角(单位: 度)
    var projectionFov: Float
    
    /// 相机位置 X
    var camEyeX: Float
    /// 相机位置 Y
    var camEyeY: Float
    /// 相机位置 Z
    var camEyeZ: Float
    
    /// 相机朝向点 X
    var camCenterX: Float
    /// 相机朝向点 Y
    var camCenterY: Float
    /// 相机朝向点 Z
    var camCenterZ: Float
    
    /// 相机上向量 X
    var camUpX: Float
    /// 相机上向量 Y
    var camUpY: Float
    /// 相机上向量 Z
    var camUpZ: Float
    
    init(type: PanoViewType) {
        self.type = type
        switch type {
        case .sphere:
            projectionFov = 65
            // 相机Z位置需要大于 1(球半径)，这样才完整看到球体
            camEyeX = 0; camEyeY = 0; camEyeZ = 4
            camCenterX = 0; camCenterY = 0; camCenterZ = 0
            camUpX = 0; camUpY = 1; camUpZ = 0
        case .pano:
            projectionFov = 65
            // 远近平面距离为 [0.1, 100]，球半径为 1，这里定相机位置要小于 1 才能在球内
            camEyeX = 0; camEyeY = 0; camEyeZ = 0.5
            camCenterX = 0; camCenterY = 0; camCenterZ = 0
            camUpX = 0; camUpY = 1; camUpZ = 0
        case .asteroid:
            projectionFov = 140
            // 相机位置放置到球体的边缘，camEyeZ 值为球体的半径
            camEyeX = 0; camEyeY = 0; camEyeZ = 1
            camCenterX = 0; camCenterY = 0; camCenterZ = 0;
            camUpX = 0; camUpY = 1; camUpZ = 0
        }
    }
    
    func projectionMatrix(aspect: Float, nearZ: Float = 0.1, farZ: Float = 100) -> GLKMatrix4 {
        return GLKMatrix4MakePerspective(GLKMathDegreesToRadians(projectionFov), aspect, nearZ, farZ)
    }
    
    var viewMatrix: GLKMatrix4 {
        if type == .asteroid {
            // 调试而得的 X 轴 和 Y 轴的旋转弧度，能让小行星更明显
            var matrix = GLKMatrix4RotateX(GLKMatrix4Identity, 1.2690004)
            matrix = GLKMatrix4RotateY(matrix, -0.138)
            let viewMatrix = GLKMatrix4MakeLookAt(camEyeX, camEyeY, camEyeZ, camCenterX, camCenterY, camCenterZ, camUpX, camUpY, camUpZ)
            return GLKMatrix4Multiply(viewMatrix, matrix)
        } else {
            return GLKMatrix4MakeLookAt(camEyeX, camEyeY, camEyeZ, camCenterX, camCenterY, camCenterZ, camUpX, camUpY, camUpZ)
        }
    }
}
