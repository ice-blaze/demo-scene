precision highp float;
varying vec2 vScreenSize;
varying float vGlobalTime;

const int MAX_MARCHING_STEPS = 1000000;
const float MIN_DIST = 0.0;
const float MAX_DIST = 255.0;
const float EPSILON = 0.0001;

const int E_BOX      = 1;
const int E_SPHERE   = 2;
const int E_CYLINDER = 3;

// float det(mat3 mat){
//   return mat[0][0] * (mat[2][2] * mat[1][1] - mat[1][2] * mat[2][1])
//        + mat[0][1] * (mat[1][2] * mat[2][0] - mat[2][2] * mat[1][0])
//        + mat[0][2] * (mat[2][1] * mat[1][0] - mat[1][1] * mat[2][0]);
// }
//
// mat3 inverse(mat3 mat){
//   float invDet = 1.0/det(mat);
//   mat3 res;
//   // res[0][0] =  (mat[1][1]*mat[2][2]-mat[2][1]*mat[1][2])*invDet;
//   // res[1][0] = -(mat[0][1]*mat[2][2]-mat[0][2]*mat[2][1])*invDet;
//   // res[2][0] =  (mat[0][1]*mat[1][2]-mat[0][2]*mat[1][1])*invDet;
//   // res[0][1] = -(mat[1][0]*mat[2][2]-mat[1][2]*mat[2][0])*invDet;
//   // res[1][1] =  (mat[0][0]*mat[2][2]-mat[0][2]*mat[2][0])*invDet;
//   // res[2][1] = -(mat[0][0]*mat[1][2]-mat[1][0]*mat[0][2])*invDet;
//   // res[0][2] =  (mat[1][0]*mat[2][1]-mat[2][0]*mat[1][1])*invDet;
//   // res[1][2] = -(mat[0][0]*mat[2][1]-mat[2][0]*mat[0][1])*invDet;
//   // res[2][2] =  (mat[0][0]*mat[1][1]-mat[1][0]*mat[0][1])*invDet;
//   return res;
// }

mat3 rotateX(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat3(
    vec3(1., 0., 0.),
    vec3(0., c, -s),
    vec3(0., s, c)
  );
}

mat3 rotateY(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat3(
    vec3(c, 0., s),
    vec3(0., 1., 0.),
    vec3(-s, 0., c)
  );
}

mat3 rotateZ(float theta) {
  float c = cos(theta);
  float s = sin(theta);
  return mat3(
    vec3(c, -s, 0.),
    vec3(s, c, 0.),
    vec3(0., 0., 1.)
  );
}

// when as parameter we have two floats, it's better to use vector, they are optimized in memory use
float intersectSDF(float distA, float distB) {
  return max(distA, distB);
}

float unionSDF(float distA, float distB) {
  return min(distA, distB);
}

float differenceSDF(float distA, float distB) {
  return max(distA, -distB);
}

float sphereSDF( vec3 p, float s ) {
  return length(p)-s;
}

float roundBoxSDF( vec3 p, vec3 b, float r ) {
  return length(max(abs(p)-b,0.0))-r;
}

float torusSDF( vec3 p, vec2 t ) {
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

float cylinderSDF( vec3 p, vec3 c ) {
  return length(p.xz-c.xy)-c.z;
}

float coneSDF( vec3 p, vec2 c ) {
  // c must be normalized
  float q = length(p.xy);
  return dot(c,vec2(q,p.z));
}

// float planeSDF( vec3 p, vec4 n ) {
float planeSDF( vec3 p ) {
  // n must be normalized
  return p.y;
  // return dot(p,n.xyz) + n.w;
}

float hexPrismSDF( vec3 p, vec2 h ) {
  vec3 q = abs(p);
  return max(q.z-h.y,max((q.x*0.866025+q.y*0.5),q.y)-h.x);
}

float triPrismSDF( vec3 p, vec2 h ) {
  vec3 q = abs(p);
  return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

float capsuleSDF( vec3 p, vec3 a, vec3 b, float r ) {
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float capCylinderSDF( vec3 p, vec2 h ) {
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

// not that well working
float capConeSDF( in vec3 p, in vec3 c ) {
  vec2 q = vec2( length(p.xz), p.y );
  vec2 v = vec2( c.z*c.y/c.x, -c.z );
  vec2 w = v - q;
  vec2 vv = vec2( dot(v,v), v.x*v.x );
  vec2 qv = vec2( dot(v,w), v.x*w.x );
  vec2 d = max(qv,0.0)*qv/vv;
  return sqrt( dot(w,w) - max(d.x,d.y) ) * sign(max(q.y*v.x-q.x*v.y,w.y));
}

float ellipsoidSDF( in vec3 p, in vec3 r ) {
  return (length( p/r ) - 1.0) * min(min(r.x,r.y),r.z);
}

float dot2( in vec3 v ) { return dot(v,v); }
float triangleSDF( vec3 p, vec3 a, vec3 b, vec3 c ) {
  vec3 ba = b - a; vec3 pa = p - a;
  vec3 cb = c - b; vec3 pb = p - b;
  vec3 ac = a - c; vec3 pc = p - c;
  vec3 nor = cross( ba, ac );

  return sqrt(
  (sign(dot(cross(ba,nor),pa)) +
   sign(dot(cross(cb,nor),pb)) +
   sign(dot(cross(ac,nor),pc))<2.0)
   ?
   min( min(
   dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.0,1.0)-pa),
   dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.0,1.0)-pb) ),
   dot2(ac*clamp(dot(ac,pc)/dot2(ac),0.0,1.0)-pc) )
   :
   dot(nor,pa)*dot(nor,pa)/dot2(nor) );
}

float quadSDF( vec3 p, vec3 a, vec3 b, vec3 c, vec3 d ) {
  vec3 ba = b - a; vec3 pa = p - a;
  vec3 cb = c - b; vec3 pb = p - b;
  vec3 dc = d - c; vec3 pc = p - c;
  vec3 ad = a - d; vec3 pd = p - d;
  vec3 nor = cross( ba, ad );

  return sqrt(
  (sign(dot(cross(ba,nor),pa)) +
   sign(dot(cross(cb,nor),pb)) +
   sign(dot(cross(dc,nor),pc)) +
   sign(dot(cross(ad,nor),pd))<3.0)
   ?
   min( min( min(
   dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.0,1.0)-pa) ,
   dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.0,1.0)-pb) ),
   dot2(dc*clamp(dot(dc,pc)/dot2(dc),0.0,1.0)-pc) ),
   dot2(ad*clamp(dot(ad,pd)/dot2(ad),0.0,1.0)-pd) )
   :
   dot(nor,pa)*dot(nor,pa)/dot2(nor) );
}

float boxSDF( vec3 p, vec3 b ) {
  return length(max(abs(p)-b,0.0));
}

float opScale2( vec3 p, vec3 b, float s ) {
    return boxSDF(p/s, b)*s;
}

float opRep( vec3 p, vec2 b, vec3 c) {
  vec3 q = mod(p,c)-0.5*c;
  return torusSDF(q, b);
}

float lengthPow(vec2 p, float power) {
  return pow(pow(p.x,power)+pow(p.y,power),1./power);
}

float squareTorusSDF( vec3 p, vec2 t, float power ) {
  vec2 q = vec2(lengthPow(p.xz,power)-t.x,p.y);
  return lengthPow(q,power)-t.y;
}

float displacement(vec3 p){
  return sin(4.*p.x)*sin(1.*p.y)*sin(1.*p.z);
}

float displaceSDF( vec3 p, vec2 b, vec3 c ) {
  float d1 = opRep(p, b, c);
  float d2 = displacement(p);
  return d1+d2;
}

float smin( float a, float b, float k ) {
  float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
  return mix( b, a, h ) - k*h*(1.0-h);
}

float blendSDF( vec3 p ) {
  float d1 = boxSDF(p, vec3(7., 0.4, 0.2));
  float d2 = torusSDF(p, vec2(4., 1.));
  return smin( d1, d2, .6 );
}

float twistSDF( vec3 p ) {
  float c = cos(1.*p.y);
  float s = sin(1.*p.y);
  mat2  m = mat2(c,-s,s,c);
  vec3  q = vec3(m*p.xz,p.y);
  return  torusSDF(q, vec2(4., 1.));;
}

float cheapBendSDF( vec3 p ) {
    float c = cos(.3*p.y);
    float s = sin(.3*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xy,p.z);
    return boxSDF(q, vec3(2., 3., 1.));
}

float sceneSDF(vec3 samplePoint) {
  // vec3 cubePoint = (rotateY(-vGlobalTime) * samplePoint).xyz;
  vec3 v3Unit = vec3(1., 1., 1.);
  vec3 v3offset = vec3(10.,0.,0.);
  float res = 100000.;
  // vec3 c = vec3(60.,10.,60.);
  // samplePoint = mod(samplePoint,c)-0.5*c;
  res = unionSDF(res, twistSDF(samplePoint + vec3(0.,0.,10.)));
  // res = unionSDF(res, boxSDF(samplePoint-vec3(0.,-5.,0.), vec3(1000.,1.,1000.)));
  // res = unionSDF(res, boxSDF(samplePoint, v3Unit));
  // samplePoint += v3offset;
  // res = unionSDF(res, roundBoxSDF(samplePoint, v3Unit, .2));
  // samplePoint += v3offset;
  // res = unionSDF(res, torusSDF(samplePoint, vec2(1.,0.2)));
  // samplePoint += v3offset;
  // res = unionSDF(res, cylinderSDF(samplePoint, v3Unit));
  // res = unionSDF(res, coneSDF(samplePoint, vec2(0.1,0.01)));
  // res = unionSDF(res, planeSDF(samplePoint, vec4(0.,1.,1.,0.)));
  // res = unionSDF(res, planeSDF(samplePoint+vec3(30.0)));
  // res = unionSDF(res, hexPrismSDF(samplePoint, vec2(1.,1.)));
  // samplePoint -= v3offset*3.;
  // samplePoint += vec3(0.,0.,8.);
  // res = unionSDF(res, triPrismSDF(samplePoint, vec2(1.,1.)));
  // samplePoint += v3offset;
  // res = unionSDF(res, capsuleSDF(samplePoint, v3Unit, vec3(1.,1.,2.), 1.));
  // samplePoint += v3offset;
  // res = unionSDF(res, capCylinderSDF(samplePoint, vec2(1.,1.)));
  // samplePoint += v3offset;
  // res = unionSDF(res, capConeSDF(samplePoint, vec3(1.,2., 3.)));
  // res = unionSDF(res, ellipsoidSDF(samplePoint, vec3(1.,2.,3.)));
  // samplePoint += v3offset;
  // res = unionSDF(res, triangleSDF(samplePoint, vec3(1.,0.,0.),vec3(0.,1.,0.),vec3(0.,1.,1.)));
  // res = unionSDF(res, quadSDF(samplePoint, vec3(1.,0.,0.),vec3(0.,1.,0.),vec3(0.,10.,1.),vec3(1.,1.,0.)));
  // res = unionSDF(res, squareTorusSDF( samplePoint, vec2(1.,.2), 8. ));
  // samplePoint += v3offset;
  // res = unionSDF(res, opRep(samplePoint, vec2(1.,2.), vec3(8., 4., 4.)));
  res = unionSDF(res, displaceSDF(samplePoint, vec2(4.,.5), vec3(15., 30., 30.)));
  res = unionSDF(res, blendSDF(samplePoint));
  // samplePoint += v3offset;

  res = unionSDF(res, cheapBendSDF(samplePoint));
  samplePoint += v3offset;
  return res;
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

vec3 phongContribForLight(vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye,
                          vec3 lightPos, vec3 lightIntensity) {
  vec3 N = estimateNormal(p);
  vec3 L = normalize(lightPos - p);
  vec3 V = normalize(eye - p);
  vec3 R = normalize(reflect(-L, N));

  float dotLN = dot(L, N);
  float dotRV = dot(R, V);

  if (dotLN < 0.0) {
    // Light not visible from this point on the surface
    return vec3(0.0, 0.0, 0.0);
  }

  if (dotRV < 0.0) {
    // Light reflection in opposite direction as viewer, apply only diffuse
    // component
    return lightIntensity * (k_d * dotLN);
  }
  return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
}

vec3 phongIllumination(vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye) {
  const vec3 ambientLight = 0.5 * vec3(1.0, 1.0, 1.0);
  vec3 color = ambientLight * k_a;

  vec3 light1Pos = vec3(4.0 * sin(vGlobalTime),
                        2.0,
                        4.0 * cos(vGlobalTime));
  vec3 light1Intensity = vec3(0.4, 0.4, 0.4);

  color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                light1Pos,
                                light1Intensity);

  vec3 light2Pos = vec3(2.0 * sin(0.37 * vGlobalTime),
                        2.0 * cos(0.37 * vGlobalTime),
                        2.0);
  vec3 light2Intensity = vec3(0.4, 0.4, 0.4);

  color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                light2Pos,
                                light2Intensity);
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


void main(void) {
  vec3 viewDir = rayDirection(145.0, vScreenSize.xy, gl_FragCoord.xy);
  // vec3 eye = vec3(8.0+vGlobalTime, 5.0 * sin(0.2 * vGlobalTime), 10.0 * sin(0.2 * vGlobalTime));
  vec3 eye = vec3(10.0, 3.0 + sin(0.2 * vGlobalTime), -10.0 * sin(0.2 * vGlobalTime));

  mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0));
  vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

  float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);

  // could be an optimisation, but need to be tested
  if (dist > MAX_DIST - EPSILON) {
    // Didn't hit anything
    gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }

  vec3 p = eye + dist * worldDir;

  vec3 K_a = (estimateNormal(p) + vec3(1.0)) / 2.0;
  // vec3 K_a = (vec3(1.0)) / 2.0;
  vec3 K_d = K_a;
  vec3 K_s = vec3(.6, .6, .6);
  // vec3 K_s = vec3(0.0, 0.0, 0.0);
  float shininess = 10.0;

  vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, eye);

  color = pow( color, vec3(0.8) );

  gl_FragColor = vec4(color, 1.0);
  // gl_FragColor = vec4(dist, 0.0, 0.0, 1.0);
}
