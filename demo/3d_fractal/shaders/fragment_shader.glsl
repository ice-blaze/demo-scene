precision highp float;
varying vec2 vScreenSize;
varying float vGlobalTime;

const int MAX_MARCHING_STEPS = 6000; // can't go higher because of android
const float MIN_DIST = 0.0;
const float MAX_DIST = 255.0;
const float EPSILON = 0.0001;
const int NUM_OCTAVES = 6;

const vec3 SKY_YELLOWISH = vec3(1.0,0.9,0.7);
const vec3 SKY_BLUISH = vec3(0.5,0.6,0.7);
vec3 SUN_DIRECTION = normalize(vec3(1.,1.,0.));


float unionSDF(float distA, float distB) {
	return min(distA, distB);
}

float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 n) {
	n /= 5.;
	const vec2 d = vec2(0.0, 1.0);
	vec2 b = floor(n), f = smoothstep(vec2(0.0), vec2(1.0), fract(n));
	return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
}

float fbm(vec2 x) {
	float v = 0.0;
	float a = 4.5;
	vec2 shift = vec2(100);
	// Rotate to reduce axial bias
	float stretch = 1.0;
	mat2 rot = mat2(
		 cos(0.5)*stretch,
		 sin(0.5)*stretch,
		-sin(0.5)*stretch,
		 cos(0.50)*stretch)
	;
	for (int i = 0; i < NUM_OCTAVES; ++i) {
		v += a * noise(x);
		x = rot * x * 1.8 + shift;
		a *= 0.5;
	}
	return v;
}

const int Iterations = 12;
const float Scale = 3.0;
const float FoldingLimit = 100.0;
float MandleBox(vec3 pos)
{
	float MinRad2 = 0.15 + abs(sin(vGlobalTime*.25))*.75;
	vec4 scale = vec4(Scale, Scale, Scale, abs(Scale)) / MinRad2;
	float AbsScalem1 = abs(Scale - 1.0);
	float AbsScaleRaisedTo1mIters = pow(abs(Scale), float(1-Iterations));
   vec4 p = vec4(pos,1.0), p0 = p;  // p.w is the distance estimate

   for (int i=0; i<Iterations; i++)
   {
      p.xyz = clamp(p.xyz, -1.0, 1.0) * 2.0 - p.xyz;
      float r2 = dot(p.xyz, p.xyz);
      p *= clamp(max(MinRad2/r2, MinRad2), 0.0, 1.0);
      p = p*scale + p0;
      if (r2>FoldingLimit) break;
   }
   return ((length(p.xyz) - AbsScalem1) / p.w - AbsScaleRaisedTo1mIters);
}

float plane( vec3 p ) {
	return p.y+fbm(vec2(p.x, p.z));
}

float terrain( vec3 p ) {
	return p.y+fbm(vec2(p.x, p.z));
}

float boxSDF( vec3 p, vec3 b, float r )
{
  return length(max(abs(p)-b,0.0))-r;
}

float sceneSDF(vec3 samplePoint) {
	if (samplePoint.y > 1.0) return 10000.0;
	return MandleBox(samplePoint);
	// return  unionSDF(terrain(samplePoint), boxSDF(samplePoint/vec3(3.,.2,1.), vec3(2.), 0.3));
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

float calcAmbientOcclusion( vec3 pos, vec3 nor ) {
	float occ = 0.0;
	float sca = 1.0;
	for( int i=0; i<5; i++ ) {
		float hr = 0.01 + 0.12*float(i)/4.0;
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
	float distance_fog_value = .018;
	float distance_fog = 1.0 - exp( -distance*distance_fog_value );

	float b = .45;
	float c = .015;
	float height_fog = c * exp(-rayOri.y*b) * (1.0-exp( -distance*rayDir.y*b ))/rayDir.y;
	height_fog = min(1., height_fog); //height can be higher than 1 and it creates artefacts

	// want to merge two types of fog (distance or height)
	float fogAmount = max(distance_fog, height_fog);

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
	vec3 color = vec3(.63,.45, .3);

	vec3 pixel_pos = eye + dist * worldDir;
	vec3 nor = estimateNormal(pixel_pos);
	// vec3 ref = reflect( worldDir, nor );

	vec3 lightPosition = vec3(10.,100.,0.);
	vec3 surfaceToLight = lightPosition - pixel_pos;
	float brightness = dot(nor, SUN_DIRECTION) / (length(SUN_DIRECTION) * length(nor));
	// brightness = clamp(brightness, 0., 1.);
	brightness *= shadow(pixel_pos, SUN_DIRECTION, 0.01, 40.);
	// brightness = 0.;
	color *= brightness;
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

vec3 render(vec3 eye, vec3 worldDir) {
	float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);
	// vec3 sky_color = vec3(0.6, 0.8, 0.9);
	vec3 sky_color = vec3(0.5,0.6,0.7);
	// sky_color = vec3(1.);

	if (dist > MAX_DIST - EPSILON) {
		// Didn't hit anything
		return applyFog(sky_color, dist, eye, worldDir);
	}

	vec3 color = illumination(eye, worldDir, dist);
	// color =  applyFog(color, dist, eye, worldDir);
	return color;
}

void main(void) {
	vec3 viewDir = rayDirection(140.0, vScreenSize.xy, gl_FragCoord.xy);
	vec3 eye = vec3(1.*(-vGlobalTime), 5.8, 0.); // boxes
	// SUN_DIRECTION = normalize(vec3(1.* cos(vGlobalTime),1.,1.* sin(vGlobalTime)));
	// SUN_DIRECTION = normalize(vec3(cos(vGlobalTime),max(sin(vGlobalTime),0.0),sin(vGlobalTime)));
	// SUN_DIRECTION = normalize(vec3(cos(vGlobalTime),0.0,sin(vGlobalTime)));
	eye = vec3(2.,1.,2.);
	// eye = vec3(5.*sin(vGlobalTime/8.),0.,5.*cos(vGlobalTime/8.));

	mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0., 1.0, 0.));
	vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

	vec3 color = render(eye, worldDir);

	gl_FragColor = vec4(color, 1.0);
}
