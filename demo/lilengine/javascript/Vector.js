class Vec2 {
    constructor() {
        this.x = this.y = 0
    }

    constructor(val) {
        this.x = this.y = val
    }

    constructor(x, y) {
        this.x = x
        this.y = y
    }
}

class Vec3 extends Vec2 {
    constructor() {
        super()
        this.z = 0
    }

    constructor(val) {
        super(val)
        this.z = val
    }

    constructor(x, y, z) {
        super(x, y)
        this.z = z
    }
}

class Vec4 extends Vec3 {
    constructor() {
        super()
        this.a = 0
    }

    constructor(val) {
        super(val)
        this.a = val
    }

    constructor(x, y, z, a) {
        super(x, y, z)
        this.a = a
    }
}