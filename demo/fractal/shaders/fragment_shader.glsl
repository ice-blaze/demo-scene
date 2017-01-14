precision highp float;
varying vec2 vScreenSize;
varying float vGlobalTime;

uniform float min_re;
uniform float max_re;
uniform float min_im;

const float max_iterations = 1650.0;

void main(void) {
	float max_im = min_im+(max_re-min_re)*vScreenSize.y/vScreenSize.x;
	float re_factor = (max_re-min_re)/(vScreenSize.x-1.);
	float im_factor = (max_im-min_im)/(vScreenSize.y-1.);
	float c_im = max_im - gl_FragCoord.y*im_factor;
	float c_re = min_re + gl_FragCoord.x*re_factor;

	float z_re = c_re;
	float z_im = c_im;
	bool isInside = true;
	for(float n=0.; n<max_iterations; n++){
		float z_re2 = z_re*z_re;
		float z_im2 = z_im*z_im;
		if(z_re2 + z_im2 > 4.)
		{
			gl_FragColor = vec4(vec3(1.-n/max_iterations),1.);
			return;
		}
		z_im = 2.*z_re*z_im + c_im;
		z_re = z_re2 - z_im2 + c_re;
	}
	gl_FragColor = vec4(vec3(0.),1.);
}
