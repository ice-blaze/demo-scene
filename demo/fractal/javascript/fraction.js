class Fraction {
	constructor(n, d) {
		let g
		if (d == 0) {
			console.log('ERROR FRACTION')
		}
		if (n == 0) {
			this.num = 0
			this.denom = 1
		} else {
			if (d < 0) {
				n = -n
				d = -d
			}
			g = Fraction.gcd(n, d)
			if (g != 1) { // remove gcd
				n = Math.floor(n/g)
				d = Math.floor(d/g)
			}
			this.num = n
			this.denom = d
		}
	}

	static gcd( a,  b) {
		a = Math.abs(a)
		b = Math.abs(b)
		if (a == 0) return b  // 0 is error value
		if (b == 0) return a
		let t
		while (b > 0) {
			t = a % b  // take "-" to the extreme
			a = b
			b = t
		}
		return a
	}

	isZero() {
		return (denom == 1 && this.num == 0)
	}
	isInt() {
		return (denom == 1)
	}
	abs() {
		if(this.num < 0){
			return new Fraction(-this.num, this.denom)
		} else {
			return this
		}
	}
	equals(otherFraction) {
		return (this.num == otherFraction.num && this.denom == otherFraction.denom)
	}
	greaterThan( otherFraction) {
		return (this.num * otherFraction.denom > this.denom * otherFraction.num)
	}
	minus( otherFraction) {
		return new Fraction(
			this.num * otherFraction.denom - otherFraction.num * this.denom,
			this.denom * otherFraction.denom
		)
	}
	plus(otherFraction) {
		return new Fraction(
			this.num * otherFraction.denom + otherFraction.num * this.denom,
			this.denom * otherFraction.denom
		)
	}
	times(otherFraction) {
		return new Fraction(this.num * otherFraction.num, this.denom * otherFraction.denom)
	}
	dividedBy(otherFraction) {
		return new Fraction(this.num * otherFraction.denom, this.denom * otherFraction.num)
	}
}