uniform mat4 mvpMatrix;   // 最终的 MVP 变换矩阵
attribute vec4 position;  // 顶点位置
 
attribute vec2 attributeTextureCoordinates; // 纹理坐标 attribute
varying vec2 varyingTextureCoordinates; // 纹理坐标 varying 会传递給片段着色器，与 fsh 的 varying 属性命名一致

void main() {
    gl_Position = mvpMatrix * position;
    varyingTextureCoordinates = attributeTextureCoordinates;
}
