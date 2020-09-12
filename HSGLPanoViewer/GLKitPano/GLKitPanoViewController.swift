//
//  GLKitPanoViewController.swift
//  OpenPano
//
//  Created by Hanson on 2020/6/16.
//  Copyright © 2020 HansonStudio. All rights reserved.
//

import UIKit
import GLKit
import CoreMotion

class GLKitPanoViewController: GLKViewController, GLKViewControllerDelegate {
    private var context: EAGLContext?
    private var baseEffect = GLKBaseEffect()
    
    // 顶点坐标缓存标记
    private var vertexBufferID = GLuint()
    // 顶点索引坐标缓存标记
    private var vertexIndicesBufferID = GLuint()
    // 纹理坐标缓存标记
    private var textureCoordID = GLuint()
    
    private var vertices = [GLfloat]()
    private var textures = [GLfloat]()
    // ⚠️ 注意是 GLushort 类型,UInt16
    private var vertexIndices = [GLushort]()
    
    private var xAxisRotate: Float = 0 // 绕 X 轴旋转角度
    private var yAxisRotate: Float = 0 // 绕 Y 轴旋转角度
    
    private var panoViewType: PanoViewType = .sphere
    
    private var segmentControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGL()
        generateSphereVertices(slice: 200, radius: 1.0)
        loadVerticesData()
        loadTexture(name: "pano-4096-2048.jpg")
        setupSegmentControl()
    }
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClearColor(1, 1, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glClear(GLbitfield(GL_DEPTH_BUFFER_BIT))
        // 开启深度测试，不然球滑动的时候会看到背面
        glEnable(GLenum(GL_DEPTH_TEST))
        baseEffect.prepareToDraw()
        glDrawElements(GLenum(GL_TRIANGLES), GLsizei(vertexIndices.count), GLenum(GL_UNSIGNED_SHORT), nil)
    }
    
    // update 方法现在不会调用了，使用 delegate = self 触发此方法调用；此方法会在每次刷新屏幕帧调用
    func glkViewControllerUpdate(_ controller: GLKViewController) {
        var modelViewMatrix = GLKMatrix4Identity
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, xAxisRotate)
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, yAxisRotate)
        modelViewMatrix = GLKMatrix4Multiply(panoViewType.viewTransform.viewMatrix, modelViewMatrix)
        // print("---xAxisRotate: \(xAxisRotate)")
        
        let width = view.frame.size.width * UIScreen.main.scale
        let height = view.frame.size.height * UIScreen.main.scale
        let aspect = GLfloat(width / height)
        let projectionMatrix = panoViewType.viewTransform.projectionMatrix(aspect: aspect)
        
        baseEffect.transform.modelviewMatrix = modelViewMatrix
        baseEffect.transform.projectionMatrix = projectionMatrix
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: touch.view)
        let previousLocation = touch.previousLocation(in: touch.view)
        var diffX = Float(location.x - previousLocation.x)
        var diffY = Float(location.y - previousLocation.y)
        
        // 定义每移动的一个像素点则旋转 0.006 弧度
        let radiansPerPoint: Float = 0.006
        
        // 转换成手指移动量的弧度值
        if panoViewType == .sphere {
            diffX *= radiansPerPoint
            diffY *= radiansPerPoint
        } else {
            // 视角在球中心时，注意拖动的值是相反的
            diffX *= -radiansPerPoint
            diffY *= -radiansPerPoint
        }
        
        // 注意手指在屏幕左右滑动，绕的是 Y 轴旋转，上下滑动绕的是 X 轴
        xAxisRotate += diffY
        yAxisRotate += diffX
        
        if panoViewType == .sphere || panoViewType == .pano {
            // 控制不让拖动球绕过顶部底部
            let roundRadian = GLKMathDegreesToRadians(360)
            let ninetyRadian = GLKMathDegreesToRadians(90)
            if xAxisRotate.truncatingRemainder(dividingBy: roundRadian) > ninetyRadian {
                xAxisRotate = ninetyRadian
            }
            if xAxisRotate.truncatingRemainder(dividingBy: roundRadian) < -ninetyRadian {
                xAxisRotate = -ninetyRadian
            }
        }
    }
    
    private func setupGL() {
        context = EAGLContext(api: .openGLES2)
        EAGLContext.setCurrent(context)
        
        self.delegate = self
        if let glView = self.view as? GLKView, let context = context {
            glView.context = context
            // 配置颜色缓冲区的格式
            glView.drawableColorFormat = GLKViewDrawableColorFormat.RGBA8888
            // 配置深度缓冲区的格式
            glView.drawableDepthFormat = GLKViewDrawableDepthFormat.format24
            // 错误做法，应该直接 self.delegate = self
            // glView.delegate = self
        }
    }
    
    private func loadVerticesData() {
        // 顶点
        glGenBuffers(1, &vertexBufferID)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBufferID)
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.size(), vertices, GLenum(GL_STATIC_DRAW))
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
        let vertiesStrideSize = MemoryLayout<GLfloat>.stride * 3 // 注意取的类型
        glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(vertiesStrideSize), nil)
        
        // 顶点索引
        glGenBuffers(1, &vertexIndicesBufferID)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), vertexIndicesBufferID)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), vertexIndices.size(), vertexIndices, GLenum(GL_STATIC_DRAW))
        
        // 纹理
        glGenBuffers(1, &textureCoordID)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), textureCoordID)
        glBufferData(GLenum(GL_ARRAY_BUFFER), textures.size(), textures, GLenum(GL_DYNAMIC_DRAW))
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.texCoord0.rawValue))
        let texturesStrideSize = MemoryLayout<GLfloat>.stride * 2 // 注意取的类型
        glVertexAttribPointer(GLuint(GLKVertexAttrib.texCoord0.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(texturesStrideSize), nil)
    }
    
    private func loadTexture(name: String) {
        guard let path = Bundle.main.path(forResource: name, ofType: nil)
            , let image = UIImage(contentsOfFile: path)
            , let textureImage = image.cgImage else {
                print("--- 加载全景图纹理失败 ---")
                return
        }
        do {
            // 为 true 时, 图片会在加载之前进行翻转（处理纹理坐标系原点不一样问题）
            let options = [GLKTextureLoaderOriginBottomLeft: NSNumber(value: true) ]
            let textureInfo = try GLKTextureLoader.texture(with: textureImage, options: options)
            baseEffect.texture2d0.target = GLKTextureTarget(rawValue: textureInfo.target) ?? .target2D
            baseEffect.texture2d0.name = textureInfo.name
            // 默认纹理 texture2d0 是默认 enable 的
            // baseEffect.texture2d0.enabled = GLboolean(GL_TRUE)
        } catch {
            print("---LoadTexture Error:", String(describing: error))
        }
    }
        
    private func generateSphereVertices(slice: Int, radius: Float) {
        let parallelsNum = slice / 2
        // 顶点数量
        let verticesNum = (parallelsNum + 1) * (slice + 1)
        // 索引数量
        let indicesNum = parallelsNum * slice * 6
        // 角度步进值得
        let angleStep = (2 * Float(3.1415926)) / Float(slice)
        
        // 顶点坐标数组 (verticesNum * 3 意思是 x, y, z 三个分量的值)
        var vertexArray: [GLfloat] = Array(repeating: 0, count: verticesNum * 3)
        // 纹理坐标数组 (verticesNum * 2 意思 x, y 两个分量的值)
        var textureArray: [GLfloat] = Array(repeating: 0, count: verticesNum * 2)
        // 顶点坐标索引数组
        var vertexIndexArray: [Int] = Array(repeating: 0, count: indicesNum)
        
        print("slices: \(slice), parallelNum: \(parallelsNum), verticesNum: \(verticesNum), indicesNum: \(indicesNum)")
        
        /* 顶点坐标公式
         x = r * sin α * sin β
         y = r * cos α
         z = r * sin α * cos β
         */
        for i in 0..<(parallelsNum + 1) {
            for j in 0..<(slice + 1) {
                let vertexIndex = (i * (slice + 1) + j) * 3
                vertexArray[vertexIndex + 0] = (radius * sinf(angleStep * Float(i)) * sinf(angleStep * Float(j)))
                vertexArray[vertexIndex + 1] = (radius * cosf(angleStep * Float(i)))
                vertexArray[vertexIndex + 2] = (radius * sinf(angleStep * Float(i)) * cosf(angleStep * Float(j)))
                
                let textureIndex = (i * (slice + 1) + j) * 2
                textureArray[textureIndex + 0] = Float(j) / Float(slice)
                textureArray[textureIndex + 1] = 1.0 - (Float(i) / Float(parallelsNum))
            }
        }
        
        var vertexIndexTemp = 0
        for i in 0..<parallelsNum {
            for j in 0..<slice {
                vertexIndexArray[0 + vertexIndexTemp] = i * (slice + 1) + j
                vertexIndexArray[1 + vertexIndexTemp] = (i + 1) * (slice + 1) + j
                vertexIndexArray[2 + vertexIndexTemp] = (i + 1) * (slice + 1) + (j + 1)
                
                vertexIndexArray[3 + vertexIndexTemp] = i * (slice + 1) + j
                vertexIndexArray[4 + vertexIndexTemp] = (i + 1) * (slice + 1) + (j + 1)
                vertexIndexArray[5 + vertexIndexTemp] = i * (slice + 1) + (j + 1)
                
                vertexIndexTemp += 6
            }
        }

        self.vertices = vertexArray
        self.textures = textureArray
        self.vertexIndices = vertexIndexArray.map { GLushort($0) }
    }
    
    private func setupSegmentControl() {
        segmentControl = UISegmentedControl(items: PanoViewType.allCases.map { $0.description })
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(self, action: #selector(changeViewType), for: .valueChanged)
        view.addSubview(segmentControl)
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        let bottom = segmentControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        let centerX = segmentControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        let height = segmentControl.heightAnchor.constraint(equalToConstant: 35)
        let width = segmentControl.widthAnchor.constraint(equalToConstant: 150)
        NSLayoutConstraint.activate([bottom, centerX, height, width])
        
    }
    
    @objc private func changeViewType() {
        let currentIndex = segmentControl.selectedSegmentIndex
        panoViewType = PanoViewType(rawValue: currentIndex) ?? .sphere
    }
}

