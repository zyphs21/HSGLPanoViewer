# HSGLPanoViewer
A Panorama Browser using Swift and OpenGLES

最近在学习 OpenGLES，其实也就学到纹理那里，所以想着做个小项目来巩固一下知识。而一个全景浏览器正好囊括顶点坐标，纹理坐标，索引绘图，MVP 矩阵变换等等知识，是一个很不错的练手项目。我选择用 Swift 来写，当然用 Swift 会相对麻烦一点，特别是在处理指针方面。我同时写了两种实现方式，一种是基于 iOS 封装的 GLKit，一种则是用 GLSL 来写，具体实现请查看[源码-HSGLPanoViewer](https://github.com/zyphs21/HSGLPanoViewer)。

<img src="https://cdn.jsdelivr.net/gh/zhenwanping/cdn-assets@master/photo/20200912200148.jpg" alt="ScreentShot" style="zoom:50%;" />



## 全景浏览器实现思路

实现思路其实挺简单的，首先我们需要计算出一个球的顶点坐标（这里还包括纹理坐标和索引数组的计算），然后把全景图以纹理的形式贴在这个球上，剩下的事情都是 MVP 矩阵的魔法了。

### 球的顶点坐标，纹理坐标，索引数组

对于一个球，通过圆柱投影方式我们可以把它剥开成一个长方形，然后对其进行切割成一块一块的小长方形，而这些长方形的顶点则相当于组成球的坐标。

<img src="https://cdn.jsdelivr.net/gh/zhenwanping/cdn-assets@master/photo/20200912191614.png" alt="image-20200912191316204" style="zoom: 33%;" />



OpenGLES 里只能通过三角形来绘制，一个长方形可以以对角线分成两个三角形，而当为了便于绘制，需要有一个索引数组来表示哪几个点是组成一个三角形。

<img src="https://cdn.jsdelivr.net/gh/zhenwanping/cdn-assets@master/photo/20200912191630.png" alt="image-20200912191415072" style="zoom:50%;" />

关于这块的计算我们可以参考 [《OpenGL ES 3.0 Programming Guide》](https://book.douban.com/subject/25845921/) 里有关于球坐标的[示例代码-esShapes.c](https://github.com/danginsburg/opengles3-book/blob/master/Common/Source/esShapes.c)，这里贴一下我用 Swift 的实现代码：

```swift
private var vertices = [GLfloat]() // 顶点坐标，包含纹理坐标
private var indices = [GLushort]() // 索引坐标

private func generateSphereVertices(slice: Int, radius: Float) {
        let parallelsNum = slice / 2
        let verticesNum = (parallelsNum + 1) * (slice + 1)
        let indicesNum = parallelsNum * slice * 6
        let angleStep = (2 * Float.pi) / Float(slice)

        // 顶点坐标和纹理坐标，乘以 5 代表顶点坐标 x,y,z 分量和纹理坐标的 u,v 分量
        var vertexArray: [GLfloat] = Array(repeating: 0, count: verticesNum * 5)
        // 顶点坐标索引数组
        var vertexIndexArray: [Int] = Array(repeating: 0, count: indicesNum)
        
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
```

### MVP 矩阵

MVP 矩阵即：

- 模型矩阵（Model Matrix）
- 视图矩阵（View Matrix）
- 投影矩阵（Projection Matrix）

通过这三个矩阵，就能实现全景球、360度浏览和小行星三种视角。首先我们得知道 OpenGLES 是右手坐标系，我们面向手机屏幕，X轴正方向在右边，Y轴正方向在上边，原点在手机屏幕中心，而 Z 轴的正方向从屏幕中心指向我们自己。

<img src="https://cdn.jsdelivr.net/gh/zhenwanping/cdn-assets@master/photo/20200912191907.png" alt="image-20200912180100001" style="zoom: 33%;" />

1. 全景球

   全景球是最简单的，我们只需要把球体放置在坐标系原点，然后我们的视角(即相机位置)，放置在 z 轴上，同时需要大于球的半径，就能看到完整的球体。

2. 360度浏览

   要想实现 360度环绕浏览，全景球还是放置在原点，把我们的视角放置在球体里面，那么我们就能 360 度环绕查看全景图了。所以我们的相机位置放在 z 轴上比球的半径小即可。

3. 小行星

   小行星的效果需要与投影矩阵配合，当然上面的两种方式也需要投影矩阵配合，只是在小行星效果这里，投影的 FOV 比前两种的大，有种贴近球体看的感觉，所以我们的摄像机视角需要放置在刚刚好球的半径上。可以想象成我们在球体挖了个小孔，眼睛往里面看的样子。

>  具体实现可以查看源码里的 [ViewTransform.swift](https://github.com/zyphs21/HSGLPanoViewer/blob/master/HSGLPanoViewer/ViewTransform.swift)

## 经验和踩坑分享

### 去除 GLKit API 弃用警告

> 'GLKViewController' was deprecated in iOS 12.0: OpenGLES API deprecated. (Define GLES_SILENCE_DEPRECATION to silence these warnings)

`GLKit` 相关的 API 从 iOS12 之后就已经标记为`弃用`了。

为了避免 Xcode 满屏的黄色警告⚠️，我们在 `Project--Build Settings` 里找到 `Preprocessor Macros` ，然后配置 `GLES_SILENCE_DEPRECATION=1` 即可把 OpenGLES 相关的弃用 API 警告去掉。这样 Xcode 的编辑界面就清爽很多了。

![image-20200912114634891](https://cdn.jsdelivr.net/gh/zhenwanping/cdn-assets@master/photo/20200912191829.png)



### 注意索引数组类型

在最后让 OpenGLES 进行绘图时，都会调用 `glDrawElements` 方法:

```swift
glDrawElements(GLenum(GL_TRIANGLES), GLsizei(vertexIndices.count), GLenum(GL_UNSIGNED_SHORT), nil)
```

这个方法的第三个参数是告诉 OpenGLES 当前索引数组的类型，比如上面指定的是 `GL_UNSIGNED_SHORT` 类型，所以我们的索引数组必须定义成是 `[GLushort]` 即数组里面的元素是 `UInt16` ，我们可以点击 GLushort 的定义是 `public typealias GLushort = UInt16）`

这里我当初很傻地犯了一个错误是：我点击 `GL_UNSIGNED_SHORT` 进去查看它的定义是 `public var GL_UNSIGNED_SHORT: Int32 { get }` ，然后下意识认为索引数组的元素类型是 `Int32` ，结果导致最后效果怎么都不对，最后才发现是这里被绕晕了。



### 数组所占内存大小

OpenGLES 里有些方法是需要传递数值所占的内存大小。比如：

```swift
// 将顶点数组复制到 GPU 中的顶点缓存区
glBufferData(GLenum(GL_ARRAY_BUFFER), vertices.size(), vertices, GLenum(GL_STATIC_DRAW))
```

这里我给 Array 添加了一个扩展方法，能够比较方便地获取到数组实际所占内存的大小：

```swift
extension Array {
    /// 根据数组类型和长度获取数组实际内存空间大小(Bytes)
    public func size() -> Int {
        return MemoryLayout<Element>.stride * self.count
    }
}

```

### 矩阵的构建

矩阵的构建和计算是一个较为复杂的部分，所以最好是把它交给程序。

GLKit 中提供了不少便捷的类和方法，比如 

- `GLKMatrix4MakeLookAt` ：构建摄像机视图矩阵

- `GLKMatrix4MakePerspective` : 构建投影视图矩阵

- `GLKMatrix4Multiply` : 用于矩阵的相乘

- `GLKMatrix4RotateX` : 绕 x 轴旋转的旋转矩阵

  ……



利用这些方法在 GLKit 的实现中很方便，但是如何扩展利用在 GLSL 的实现呢？这里贴一下更新 MVP 矩阵的代码: 

```swift
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
```

从上面的代码可以看到，我们通过 `GLKMatrix4` 的 `m` 属性拿到矩阵的数组数据，然后用 `withUnsafePointer`  的方式拿到数组的指针，以完成 `glUniformMatrix4fv` 的调用。

## 参考资料

- [OpenGL-Tutorial-矩阵](http://www.opengl-tutorial.org/cn/beginners-tutorials/tutorial-3-matrices/)
- [How to Create a 360 Video Player](https://medium.com/@hanton.yang/how-to-create-a-360-video-player-with-opengl-es-3-0-and-glkit-360-3f29a9cfac88)
- [OpenGLES3-Book](https://github.com/danginsburg/opengles3-book)
