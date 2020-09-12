//
//  GLViewable.swift
//  OpenPano
//
//  Created by Hanson on 2020/9/6.
//  Copyright © 2020 HansonStudio. All rights reserved.
//

import Foundation
import GLKit

public protocol GLViewable {
    var eaglLayer: CAEAGLLayer! { get set }
    var eaglContext: EAGLContext! { get set }
    
    var renderBuffer: GLuint { get set }
    var frameBuffer: GLuint { get set }

    var shaderProgram: GLuint { get set }
}

extension GLViewable {
    /// 通过图片生成纹理
    public func generateTexture(from cgImage: CGImage) -> GLuint {
        let width = cgImage.width
        let height = cgImage.height
        let imageRect = CGRect(x: 0, y: 0, width: width, height: height)
        let colorSpace = CGColorSpaceCreateDeviceRGB() // cgImage.colorSpace!
        // 计算图片所占字节大小 (width * height * rgba)
        let imageData = calloc(width * height * 4, MemoryLayout<GLubyte>.size)
        
        let context = CGContext(data: imageData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width * 4,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        // print("---imageRect: \(imageRect)")
        // 上下翻转图片
        context?.translateBy(x: 0, y: imageRect.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.draw(cgImage, in: imageRect)
        
        // 创建纹理
        var texture = GLuint()
        glGenTextures(1, &texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        
        // 设置纹素映射成像素的方式
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        
        // 加载纹理数据，写入缓存中
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GL_RGBA,
                     GLsizei(width),
                     GLsizei(height),
                     0,
                     GLenum(GL_RGBA),
                     GLenum(GL_UNSIGNED_BYTE),
                     imageData)
        
        // 将2D纹理绑定到默认的纹理，相当于解绑。
        // 打破之前的纹理绑定关系，使OpenGL的纹理绑定状态恢复到默认状态。（OpenGL Context 是个状态机）
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        
        // 'CGContextRelease' is unavailable: Core Foundation objects are automatically memory managed
        // CGContextRelease(context)
        free(imageData)
        
        return texture
    }
    
    /// 加载着色器程序
    public func loadShader(vertexFile: String, fragmentFile: String) -> GLuint {
        var vertexShader = GLuint()
        var fragmentShader = GLuint()
        var program = glCreateProgram()
        
        // 编译
        compileShader(&vertexShader, type: GLenum(GL_VERTEX_SHADER), filePath: vertexFile)
        compileShader(&fragmentShader, type: GLenum(GL_FRAGMENT_SHADER), filePath: fragmentFile)
        
        // 装载
        glAttachShader(program, vertexShader)
        glAttachShader(program, fragmentShader)
        
        // 链接
        glLinkProgram(program)
        logLinkProgramStatus(program: &program) // 打印链接状态
        
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)
        
        return program
    }
    
    /// 编译着色器
    public func compileShader(_ shader: inout GLuint, type: GLenum, filePath: String) {
        let sourceContent = try? String(contentsOfFile: filePath, encoding: .utf8)
        let cStringContent = sourceContent?.cString(using: .utf8)
        var sourcePointer = UnsafePointer<GLchar>(cStringContent)
        
        shader = glCreateShader(type) // 创建着色器对象
        glShaderSource(shader, 1, &sourcePointer, nil) // 将着色器源码赋给 shader 对象
        
        glCompileShader(shader) // 编译着色器代码
        
        logShaderCompileStatus(shader: &shader) // 打印编译状态
    }
    
    // 打印 Compile Shader 状态
    func logShaderCompileStatus(shader: inout GLuint) {
        var status = GLint()
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == GL_FALSE {
            var infoLog = [GLchar](repeating: 0, count: 512)
            glGetShaderInfoLog(shader, GLsizei(infoLog.size()), nil, &infoLog)
            let info = String(cString: infoLog, encoding: .utf8)
            print("--- Compile Shader Error: \(String(describing: info)) ---")
        } else {
            print("--- Compile Shader Success ---")
        }
    }
    
    // 打印 Link Program 状态
    func logLinkProgramStatus(program: inout GLuint) {
        var status = GLint()
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
        if status == GL_FALSE {
            var infoLog = [GLchar](repeating: 0, count: 512)
            glGetProgramInfoLog(program, GLsizei(infoLog.size()), nil, &infoLog)
            let info = String(cString: infoLog, encoding: .utf8)
            print("--- Link Program Error: \(String(describing: info)) ---")
        } else {
            print("--- Link Program Success ---")
        }
    }
}
