precision highp float;

uniform float global_time_in;
uniform vec2 screen_size_in;

const int MAX_MARCHING_STEPS = 6000; // can't go higher because of android
const float MIN_DIST = 0.0;
const float MAX_DIST = 455.0;
const float EPSILON = 0.0001;

const vec3 SKY_YELLOWISH = vec3(1.0,0.9,0.7);
const vec3 SKY_BLUISH = vec3(1.,1.,1.);
vec3 SUN_DIRECTION = normalize(vec3(1.,1.,0.));

float unionSDF(float distA, float distB) {
	return min(distA, distB);
}

float plane( vec3 p, float h) {
	return p.y - h;
}

float boxSDF( vec3 p, vec3 b, float r )
{
  return length(max(abs(p)-b,0.0))-r;
}

const int iters = 12;
const float SCALE = 3.;
float sceneSDF(vec3 position) {
	float MR2 =  0.15 + abs(sin(global_time_in*.25))*.75;//.5*.5;
	// only display one 'cube'
	if (
		// position.z > 1.0 || position.z < -1.0 ||
		position.y > 1.0 || position.y < -1.0
	) return 10000.0;

	//mandlebox
	vec4 scalevec = vec4(SCALE, SCALE, SCALE, abs(SCALE)) / MR2;
	float C1 = abs(SCALE-1.0), C2 = pow(abs(SCALE), float(1-iters));

	// distance estimate
	vec4 p = vec4(position.xyz, 1.0), p0 = vec4(position.xyz, 1.0);  // p.w is knighty's DEfactor
	for (int i=0; i<iters; i++) {
		p.xyz = clamp(p.xyz, -1.0, 1.0) * 2.0 - p.xyz;  // box fold: min3, max3, mad3
		float r2 = dot(p.xyz, p.xyz);  // dp3
		p.xyzw *= clamp(max(MR2/r2, MR2), 0.0, 1.0);  // sphere fold: div1, max1.sat, mul4
		p.xyzw = p*scalevec + p0;  // mad4
	}
	return (length(p.xyz) - C1) / p.w - C2;
}

float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
	float depth = start;
	for (int i = 0; i < MAX_MARCHING_STEPS; ++i) {
		float dist = sceneSDF(eye + depth * marchingDirection);
		if (dist < EPSILON) {
			return depth;
		}
		depth += dist/4.;
		if (depth >= end) {
			return end;
		}
	}
	return end;
}

vec3 estimateNormal(vec3 p) {
	return normalize(vec3(
		sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
		sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
		sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
	));
}

float shadow( vec3 ro, vec3 rd, float mint, float maxt ) {
	float res = 1.0;
	float t = mint;
	for( int i=0; i<128; i++ )
	{
		float h = sceneSDF( ro + rd*t) ;
		res = min( res, 8.0*h/t );
		t += clamp( h, 0.002, 0.1 );
		if( h<0.001 || t>maxt ) break;
	}
	return clamp( res, 0.0, 1.0 );
}

const float MAX_OCC_ITER = 4.0;
float calcAmbientOcclusion( vec3 pos, vec3 nor ) {
	float occ = 0.0;
	float sca = 1.0;
	for( int i=0; i<=int(MAX_OCC_ITER); i++ ) {
		float hr = 0.01 + 0.12*float(i)/MAX_OCC_ITER;
		vec3 aopos =  nor * hr + pos;
		float dd = sceneSDF( aopos );
		occ += -(dd-hr)*sca;
		sca *= 0.95;
	}
	return clamp( 1.0 - 3.0*occ, 0.0, 1.0 );
}

vec3 applyFog(
	const vec3  rgb,      // original color of the pixel
	const float distance, // camera to point distance
	const vec3 rayOri,
	const vec3 rayDir
){
	float distance_fog_value = .118;
	float fogAmount = 1.0 - exp( -distance*distance_fog_value );

	float b = .45;
	float c = .015;

	//create a sun effect, yellow when in the sun direction, blueish otherwise
	float sunAmount = max( dot( rayDir, SUN_DIRECTION ), 0.0 );
	vec3  fogColor  = mix(
		SKY_BLUISH,
		SKY_YELLOWISH,
		pow(sunAmount,10.0)
	);
	return mix( rgb, fogColor, fogAmount);
}

vec3 illumination(vec3 eye, vec3 worldDir, float dist) {
	vec3 color = vec3(1.,.8, .0);

	vec3 pixel_pos = eye + dist * worldDir;
	vec3 nor = estimateNormal(pixel_pos);
	vec3 ref = reflect( worldDir, nor );

	vec3 lightPosition = vec3(10.,100.,0.);
	vec3 surfaceToLight = lightPosition - pixel_pos;
	float brightness = dot(nor, SUN_DIRECTION) / (length(SUN_DIRECTION) * length(nor));
	brightness = clamp(brightness, 0., 1.);
	brightness *= shadow(pixel_pos, SUN_DIRECTION, 0.01, 40.);
	// brightness = 0.;
	float ao = calcAmbientOcclusion(pixel_pos, nor);
	color *= brightness;
	color *= ao;
	color = applyFog(color, dist, eye, worldDir);
	return color;
}

vec3 rayDirection(float fieldOfView, vec2 screen_size, vec2 fragCoord) {
	vec2 xy = fragCoord - screen_size / 2.0;
	float z = screen_size.y / tan(radians(fieldOfView) / 2.0);
	return normalize(vec3(xy, -z));
}

mat4 viewMatrix(vec3 eye, vec3 center, vec3 up) {
	// Based on gluLookAt man page
	vec3 f = normalize(center - eye);
	vec3 s = cross(f, up);
	vec3 u = cross(s, f);
	return mat4(
		vec4(s, 0.0),
		vec4(u, 0.0),
		vec4(-f, 0.0),
		vec4(0.0, 0.0, 0.0, 1)
	);
}

vec3 render(vec3 eye, vec3 worldDir, out float dist) {
	dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);
	// vec3 sky_color = vec3(0.6, 0.8, 0.9);
	vec3 sky_color = vec3(0.5,0.6,0.7);
	// sky_color = vec3(1.);

	if (dist > MAX_DIST - EPSILON) {
		// Didn't hit anything
		// return SKY_BLUISH;
		return applyFog(sky_color, dist, eye, worldDir);
	}

	vec3 color = illumination(eye, worldDir, dist);
	color =  applyFog(color, dist, eye, worldDir);
	return color;
}

vec3 generate_color(vec3 eye, vec3 viewDir){
	mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0., 1.0, 0.));
	vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
	float test = 0.;
	return render(eye, worldDir, test);
}

const float BLUR_STEP = .015;
void main(void) {
	vec3 viewDir = rayDirection(140.0, screen_size_in.xy, gl_FragCoord.xy);
	vec3 eye = vec3(.87,.85,2.);
	// vec3 eye = vec3(4.2,.5+.5*sin((global_time_in-BLUR_STEP)/1.),2. * sin((global_time_in-BLUR_STEP*2.)/1.));
	mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 1.0, 2.0), vec3(0., 1.0, 0.));
	vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
	float dist = 0.;
	vec3 color = render(eye, worldDir, dist);

	// // The naive way of doing blur, but very performance consuming
	// // One optimization is to keep the old color frames and only recalculate
	// // the future color
	// // Another way but only filming is to wait x frames befor rendering and
	// // then blur
	// vec3 eye;
	// vec3 color;
	// // eye = vec3(4.2,.5+.5*sin((global_time_in-BLUR_STEP)/8.),2. * sin((global_time_in-BLUR_STEP*2.)/8.));
	// // color = generate_color(eye, viewDir);
	// eye = vec3(4.2,.5+.5*sin((global_time_in-BLUR_STEP)/8.),2. * sin((global_time_in-BLUR_STEP)/8.));
	// color = mix(color, generate_color(eye, viewDir), 0.5);
	// eye = vec3(4.2,.5+.5*sin(global_time_in/8.),2. * sin(global_time_in/8.));
	// color = mix(color, generate_color(eye, viewDir), 0.5);
	// eye = vec3(4.2,.5+.5*sin((global_time_in+BLUR_STEP)/8.),2. * sin((global_time_in+BLUR_STEP)/8.));
	// color = mix(color, generate_color(eye, viewDir), 0.5);
	// // eye = vec3(4.2,.5+.5*sin((global_time_in+BLUR_STEP)/8.),2. * sin((global_time_in+BLUR_STEP*2.)/8.));
	// // color = mix(color, generate_color(eye, viewDir), 0.5);

	// // vec3 eye = vec3(1.*(-global_time_in), 5.8, 0.); // boxes
	// // SUN_DIRECTION = normalize(vec3(1.* cos(global_time_in),1.,1.* sin(global_time_in)));

	gl_FragColor = vec4(color, dist);
}
