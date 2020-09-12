//
//  GLSLPanoView.swift
//  HSGLPanoViewer
//
//  Created by Hanson on 2020/9/12.
//  Copyright © 2020 Hanson. All rights reserved.
//

import Foundation
import GLKit

class GLSLPanoView: UIView, GLViewable {
    var eaglLayer: CAEAGLLayer!
    var eaglContext: EAGLContext!
    
    var renderBuffer = GLuint()
    var frameBuffer = GLuint()

    var shaderProgram = GLuint()
    
    private var vertices = [GLfloat]()
    private var indices = [GLushort]()
    
    // 顶点坐标缓存指针
    private var vbo = GLuint()
    // 顶点索引坐标缓存指针
    private var ebo = GLuint()
    
    private var projectionMatrix: GLKMatrix4 = GLKMatrix4Identity
    
    private var panoViewType: PanoViewType = .sphere
    private var xAxisRotate: Float = 0 // 绕 X 轴旋转角度
    private var yAxisRotate: Float = 0 // 绕 Y 轴旋转角度
    
    private var segmentControl: UISegmentedControl!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
        setupContext()
        
        setupSegmentControl()
        
        generateSphereVertices(slice: 200, radius: 1.0)
        setupShaderProgram(name: "Pano")
        setupVBO()
        setupEBO()
        
        clearRenderAndFrameBuffer()
        setupRenderBuffer()
        setupFrameBuffer()
        
        render()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        glDeleteProgram(shaderProgram)
        glDeleteBuffers(1, &vbo)
        glDeleteBuffers(1, &ebo)
    }
    
    override class var layerClass: AnyClass {
        return CAEAGLLayer.self
    }
    
    private func setupLayer() {
        // 注意先 override layerClass，将返回的图层从 CALayer 替换成 CAEAGLLayer
        eaglLayer = self.layer as? CAEAGLLayer
        contentScaleFactor = UIScreen.main.scale
        eaglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking: false, // 绘图完之后是否保留状态(类似核心动画)
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8 // 颜色缓冲区格式
        ]
    }
    
    private func setupContext() {
        eaglContext = EAGLContext(api: .openGLES3)!
        EAGLContext.setCurrent(eaglContext)
    }
    
    private func setupViewPort() {
        let scale = UIScreen.main.scale
        let x = frame.origin.x * scale
        let y = frame.origin.y * scale
        let width = frame.size.width * scale
        let height = frame.size.height * scale
        // 设置视口大小
        glViewport(GLint(x), GLint(y), GLsizei(width), GLsizei(height))
    }
    
    private func setupVBO() {
        glGenBuffers(1, &vbo)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        // 将顶点数组复制到 GPU 中的顶点缓存区
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.size(), vertices, GLenum(GL_STATIC_DRAW))
    }
    
    private func setupEBO() {
        glGenBuffers(1, &ebo)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), ebo)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), indices.size(), indices, GLenum(GL_STATIC_DRAW))
    }
    
    private func clearRenderAndFrameBuffer() {
        glDeleteBuffers(1, &renderBuffer)
        renderBuffer = 0
        glDeleteBuffers(1, &frameBuffer)
        frameBuffer = 0
    }
    
    private func setupRenderBuffer() {
        glGenRenderbuffers(1, &renderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), renderBuffer)
        eaglContext.renderbufferStorage(Int(GL_RENDERBUFFER), from: eaglLayer)
    }
    
    private func setupFrameBuffer() {
        glGenFramebuffers(1, &frameBuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), renderBuffer)
    }
    
    private func setupShaderProgram(name: String) {
        guard let vertexFile = Bundle.main.path(forResource: name, ofType: "vsh")
            , let fragmentFile = Bundle.main.path(forResource: name, ofType: "fsh") else {
                print("---找不到着色器文件---")
                return
        }
        shaderProgram = loadShader(vertexFile: vertexFile, fragmentFile: fragmentFile)
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
        
        update()
    }
    
    private func update() {
        glClearColor(0, 0, 0, 0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        updateMVPMatrix()
        
        glEnable(GLenum(GL_DEPTH_TEST))
        if panoViewType == .sphere {
            glEnable(GLenum(GL_CULL_FACE))
        } else {
            glDisable(GLenum(GL_CULL_FACE))
        }
        
        glDrawElements(GLenum(GL_TRIANGLES), GLsizei(indices.count), GLenum(GL_UNSIGNED_SHORT), nil)
        eaglContext.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    private func render() {
        glClearColor(0, 0, 0, 0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        setupViewPort()
        
        glUseProgram(shaderProgram)
        
        let texture = loadTexture(name: "pano-4096-2048.jpg")
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        glUniform1i(glGetUniformLocation(shaderProgram, "textureSampler"), 0)
        
        updateMVPMatrix()
        
        let position = glGetAttribLocation(shaderProgram, "position")
        glEnableVertexAttribArray(GLuint(position))
        let strideSize = MemoryLayout<GLfloat>.stride * 5
        glVertexAttribPointer(GLuint(position), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(strideSize), nil)
        
        let textureCoord = glGetAttribLocation(shaderProgram, "attributeTextureCoordinates")
        glEnableVertexAttribArray(GLuint(textureCoord))
        let texturesStrideSize = MemoryLayout<GLfloat>.stride * 5
        let textureOffset = MemoryLayout<GLfloat>.stride * 3
        let textureOffsetPointer = UnsafeRawPointer(bitPattern: textureOffset)
        glVertexAttribPointer(GLuint(textureCoord), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(texturesStrideSize), textureOffsetPointer)
        
        // 深度测试
        glEnable(GLenum(GL_DEPTH_TEST))
        if panoViewType == .sphere {
            // 球体视角时，执行面剔除
            glEnable(GLenum(GL_CULL_FACE))
        } else {
            glDisable(GLenum(GL_CULL_FACE))
        }
        
        glDrawElements(GLenum(GL_TRIANGLES), GLsizei(indices.count), GLenum(GL_UNSIGNED_SHORT), nil)
        
        // 从渲染缓冲区显示到屏幕上
        self.eaglContext.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    private func updateMVPMatrix() {
        var modelViewMatrix = GLKMatrix4Identity
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, xAxisRotate)
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, yAxisRotate)
        modelViewMatrix = GLKMatrix4Multiply(panoViewType.viewTransform.viewMatrix, modelViewMatrix)
        
        let width = frame.size.width * UIScreen.main.scale
        let height = frame.size.height * UIScreen.main.scale
        let aspect = GLfloat(width / height)
        let projectionMatrix = panoViewType.viewTransform.projectionMatrix(aspect: aspect)
        
        // 最终的 MVP 矩阵
        var mvpMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
        
        // 这里取出 mvpMatrix.m 的指针操作
        let components = MemoryLayout.size(ofValue: mvpMatrix.m) / MemoryLayout.size(ofValue: mvpMatrix.m.0)
        withUnsafePointer(to: &mvpMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: components) {
                glUniformMatrix4fv(glGetUniformLocation(shaderProgram, "mvpMatrix"), 1, GLboolean(GL_FALSE), $0)
            }
        }
    }
    
    private func loadTexture(name: String = "pano-2048-1024.jpg") -> GLuint {
        guard let path = Bundle.main.path(forResource: name, ofType: nil)
            , let image = UIImage(contentsOfFile: path)
            , let textureImage = image.cgImage else {
                print("--- 加载全景图纹理失败 ---")
                return GLuint()
        }
        return generateTexture(from: textureImage)
    }
    
    private func generateSphereVertices(slice: Int, radius: Float) {
        let parallelsNum = slice / 2
        let verticesNum = (parallelsNum + 1) * (slice + 1)
        let indicesNum = parallelsNum * slice * 6
        let angleStep = (2 * Float.pi) / Float(slice)

        // 顶点坐标和纹理坐标
        var vertexArray: [GLfloat] = Array(repeating: 0, count: verticesNum * 5)
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
                let vertexIndex = (i * (slice + 1) + j) * 5
                vertexArray[vertexIndex + 0] = (radius * sinf(angleStep * Float(i)) * sinf(angleStep * Float(j)))
                vertexArray[vertexIndex + 1] = (radius * cosf(angleStep * Float(i)))
                vertexArray[vertexIndex + 2] = (radius * sinf(angleStep * Float(i)) * cosf(angleStep * Float(j)))
                
                vertexArray[vertexIndex + 3] = Float(j) / Float(slice)
                vertexArray[vertexIndex + 4] = Float(1.0) - (Float(i) / Float(parallelsNum))
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
        self.indices = vertexIndexArray.map { GLushort($0) }
    }
    
    private func setupSegmentControl() {
        segmentControl = UISegmentedControl(items: PanoViewType.allCases.map { $0.description })
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(self, action: #selector(changeViewType), for: .valueChanged)
        addSubview(segmentControl)
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        let bottom = segmentControl.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -40)
        let centerX = segmentControl.centerXAnchor.constraint(equalTo: centerXAnchor)
        let height = segmentControl.heightAnchor.constraint(equalToConstant: 35)
        let width = segmentControl.widthAnchor.constraint(equalToConstant: 150)
        NSLayoutConstraint.activate([bottom, centerX, height, width])
    }
    
    @objc private func changeViewType() {
        let currentIndex = segmentControl.selectedSegmentIndex
        panoViewType = PanoViewType(rawValue: currentIndex) ?? .sphere
        xAxisRotate = 0
        yAxisRotate = 0
        update()
    }
}
