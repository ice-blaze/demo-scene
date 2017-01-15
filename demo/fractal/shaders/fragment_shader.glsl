precision highp float;
precision highp int;
varying vec2 vScreenSize;
varying float vGlobalTime;

const float max_iterations = 3.0;

uniform ivec2 min_re;
uniform ivec2 max_re;
uniform ivec2 min_im;
uniform ivec2 max_im;

int iabs(int v){
	if(v < 0){
		return -v;
	}
	return v;
}

int mod(int a, int b){
	for(int k=0; k<10000; ++k){
		if ( a - k*b < b ){
			return a - k*b;
			break;
		}
	}
	return -1;
}

int gcd(ivec2 vec) {
	vec.x = iabs(vec.x);
	vec.y = iabs(vec.y);
	if (vec.x == 0) return vec.y;  // 0 is error value
	if (vec.y == 0) return vec.x;
	int t;
	for (int i=0; i<10000; ++i) {
		if(vec.y < 0){
			break;
		}
		t = mod(vec.x, vec.y);  // take "-" to the extreme
		vec.x = vec.y;
		vec.y = t;
	}
	return vec.x;
}

ivec2 f_fix(ivec2 vec){
	if (vec.x == 0) {
		vec.y = 1;
	} else {
		if (vec.y < 0) {
			vec.x = -vec.x;
			vec.y = -vec.y;
		}
		int g = gcd(vec);
		if (g != 1) { // remove gcd
			vec.x = vec.x/g;
			vec.y = vec.y/g;
		}
	}
	return vec;
}

ivec2 simplify(ivec2 vec){
	return vec;
}

bool f_equals( ivec2 a, ivec2 b ) {
	return (a.x == b.x && a.y == b.y);
}
bool f_greaterThan( ivec2 a, ivec2 b ) {
	return (a.x * b.y > a.y * b.x);
}
ivec2 f_minus( ivec2 a, ivec2 b ) {
	return ivec2(
		a.x * b.y - b.x * a.y,
		a.y * b.y
	);
}
ivec2 f_plus( ivec2 a, ivec2 b ) {
	return ivec2(
		a.x * b.y + b.x * a.y,
		a.y * b.y
	);
}
ivec2 f_times( ivec2 a, ivec2 b ) {
	return ivec2(a.x * b.x, a.y * b.y);
}
ivec2 f_dividedBy( ivec2 a, ivec2 b ) {
	return ivec2(a.x * b.y, a.y * b.x);
}

float f_res(ivec2 a){
	return float(a.x)/float(a.y);
}

void main(void) {
	ivec2 re_factor = f_dividedBy(f_minus(max_re, min_re), ivec2(int(vScreenSize.x)-1, 1));
	ivec2 im_factor = f_dividedBy(f_minus(max_im, min_im), ivec2(int(vScreenSize.y)-1, 1));
	ivec2 c_im = f_minus(max_im, f_times(ivec2(gl_FragCoord.y, 1), im_factor));
	ivec2 c_re = f_plus (min_re, f_times(ivec2(gl_FragCoord.x, 1), re_factor));

	ivec2 z_re = f_fix(c_re);
	ivec2 z_im = f_fix(c_im);
	// ivec2 z_im = c_im;
	bool isInside = true;
	for(float n=0.; n<max_iterations; n++){
		ivec2 z_re2 = ivec2(f_res(z_re)*f_res(z_re)*100000., 100000) ;
		ivec2 z_im2 = ivec2(f_res(z_im)*f_res(z_im)*100000., 100000) ;
		if(f_res(z_re2) + f_res(z_im2) > 4.)
		{
			gl_FragColor = vec4(vec3(1.-n/max_iterations),1.);
			return;
		}
		z_im = f_plus(f_times(f_times(ivec2(2, 1), z_re), z_im), c_im);
		// z_im = 2.*z_re*z_im + f_res(c_im);
		z_re = f_plus(f_minus(z_re2, z_im2), c_re);
		// z_re = f_res(z_re2) - f_res(z_im2) + f_res(c_re);
	}
	// ivec2 re_factor = f_dividedBy(f_minus(max_re, min_re), ivec2(int(vScreenSize.x)-1, 1));
	// ivec2 im_factor = f_dividedBy(f_minus(max_im, min_im), ivec2(int(vScreenSize.y)-1, 1));
	// ivec2 c_im = f_minus(max_im, f_times(ivec2(gl_FragCoord.y, 1), im_factor));
	// ivec2 c_re = f_plus(min_re, f_times(ivec2(gl_FragCoord.x, 1), re_factor));

	// ivec2 z_re = c_re;
	// ivec2 z_im = c_im;
	// bool isInside = true;
	// for(float n=0.; n<max_iterations; n++){
	// 	ivec2 z_re2 = f_times(z_re, z_re);
	// 	ivec2 z_im2 = f_times(z_im, z_im);
	// 	if(f_greaterThan(f_plus(z_re2, z_im2), ivec2(4, 1)))
	// 	{
	// 		gl_FragColor = vec4(vec3(1.-n/max_iterations),1.);
	// 		return;
	// 	}
	// 	z_im = f_plus(f_times(f_times(ivec2(2, 1),z_re),z_im), c_im);
	// 	z_re = f_plus(f_minus(z_re2, z_im2), c_re);
	// }
	ivec2 toto = ivec2(4, 10);
	toto = f_times(toto, ivec2(2, 1));
	gl_FragColor = vec4(vec3(toto.x/toto.y),1.);
}
