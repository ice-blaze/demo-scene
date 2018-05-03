class GameObject {
    constructor(){
        this.childs = []
        this.parent = null
        this.vertex = []//new Float32Array()
        this.normal = []//new Float32Array()
        this.color = Vec3(0.)
        this.u = Vec2(0.)
        this.v = Vec2(0.)
        this.transpose = Vec3(0.)
        this.rotate = Vec3(0.)
        this.scale = Vec3(1.)
    }
}