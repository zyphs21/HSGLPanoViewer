precision highp float;
 
uniform sampler2D textureSampler; // 纹理采样器
varying vec2 varyingTextureCoordinates; // 纹理坐标
 
void main() {
    gl_FragColor = texture2D(textureSampler, varyingTextureCoordinates); // 纹理采样
}
