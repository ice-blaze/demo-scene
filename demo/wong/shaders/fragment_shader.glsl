precision highp float;
varying vec2 vScreenSize;
varying float vGlobalTime;

const int MAX_MARCHING_STEPS = 63000; // can't go higher because of android
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

float boxRepSDF(vec3 p, vec3 size, vec3 repetition){
  vec3 q = mod(p,repetition)-0.5*repetition;
  return boxSDF(q, size);
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

float sceneSDF2(vec3 samplePoint){
  float res = 100000.;
  return unionSDF(res, displaceSDF(samplePoint, vec2(4.,.5), vec3(7., 5., 20.)));
}

float sceneSDF(vec3 samplePoint) {
  // vec3 cubePoint = (rotateY(-vGlobalTime) * samplePoint).xyz;
  vec3 v3Unit = vec3(1., 1., 1.);
  vec3 v3offset = vec3(10.,0.,0.);
  float res = 100000.;
  // vec3 c = vec3(60.,10.,60.);
  // samplePoint = mod(samplePoint,c)-0.5*c;
  // res = unionSDF(res, twistSDF(samplePoint + vec3(0.,0.,10.)));
  // res = unionSDF(res, boxSDF(samplePoint-vec3(0.,-5.,0.), vec3(1000.,1.,1000.)));
  res = unionSDF(res, boxRepSDF(samplePoint+vec3(10.,5.,1.), v3Unit, vec3(10.,0.,10.)));
  // res = unionSDF(res, roundBoxSDF(samplePoint, v3Unit, .2));
  // samplePoint += v3offset;
  // res = unionSDF(res, torusSDF(samplePoint, vec2(1.,0.2)));
  // samplePoint += v3offset;
  // res = unionSDF(res, cylinderSDF(samplePoint, v3Unit));
  // res = unionSDF(res, coneSDF(samplePoint, vec2(0.1,0.01)));
  // res = unionSDF(res, planeSDF(samplePoint, vec4(0.,1.,0.,0.)));
  res = unionSDF(res, planeSDF(samplePoint+vec3(7.0)));
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
  // res = unionSDF(res, opRep(samplePoint, vec2(1.,2.), vec3(10., 5., 10.)));
  // res = unionSDF(res, displaceSDF(samplePoint, vec2(4.,.5), vec3(7., 5., 20.)));
  // res = unionSDF(res, blendSDF(samplePoint));
  // samplePoint += v3offset;

  // res = unionSDF(res, cheapBendSDF(samplePoint + vec3(0.,-3.7,0.)));
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

float shadow( vec3 ro, vec3 rd, float mint, float maxt ) {
  float res = 1.0;
  float t = mint;
  for( int i=0; i<16; i++ )
  {
  float h = sceneSDF( ro + rd*t) ;
      res = min( res, 8.0*h/t );
      t += clamp( h, 0.02, 0.10 );
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

vec3 illumination(vec3 eye, vec3 worldDir, float dist) {
  vec3 color = vec3(0.6);
  vec3 pos = eye + dist * worldDir;
  vec3 nor = estimateNormal(pos);
  vec3 ref = reflect( worldDir, nor );
  // color = nor;

  // float occ = calcAmbientOcclusion( pos, nor );
  float occ = 1.0;
  vec3  lig = normalize( vec3(0., 1., 0.) );
  float amb = clamp( 0.5+0.5*nor.y, 0.0, 1.0 );
  float dif = clamp( dot( nor, lig ), 0.0, 1. );
  float bac = clamp( dot( nor, normalize(vec3(-lig.x,0.0,-lig.z))), 0.0, 1.0 )*clamp( 1.0-pos.y,0.0,1.0);
  float dom = smoothstep( -0.1, 0.1, ref.y );
  float fre = pow( clamp(1.0+dot(nor,worldDir),0.0,1.0), 2.0 );
  float spe = pow(clamp( dot( ref, lig ), 0.0, 1.0 ),16.0);

  // shadows
  dif *= shadow(pos, lig, .02, 2.5);
  vec3 lin = vec3(0.0);
  lin += 1.20*dif*vec3(1.00,0.85,0.55);
  lin += 1.20*spe*vec3(1.00,0.85,0.55)*dif;
  lin += 0.20*amb*vec3(0.50,0.70,1.00)*occ;
  lin += 0.30*dom*vec3(0.50,0.70,1.00)*occ;
  lin += 0.30*bac*vec3(0.25,0.25,0.25)*occ;
  lin += 0.40*fre*vec3(1.00,1.00,1.00)*occ;
  color = color*lin;


  color = pow( color, vec3(0.4545) );
  color *= 10./dist;
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

  if (dist > MAX_DIST - EPSILON) {
    // Didn't hit anything
    return vec3(0.);
  }

  vec3 color = illumination(eye, worldDir, dist);

  return color;
}

void main(void) {
  vec3 viewDir = rayDirection(140.0, vScreenSize.xy, gl_FragCoord.xy);
  // vec3 eye = vec3(8.0+vGlobalTime, 5.0 * sin(0.2 * vGlobalTime), 10.0 * sin(0.2 * vGlobalTime));
  // vec3 eye = vec3(10.0*vGlobalTime, 10.0 * sin(vGlobalTime), 0.); // torus displacement
  vec3 eye = vec3(5.0*vGlobalTime, max(-6.8, 10.0 * sin(vGlobalTime)), 0.); // boxes
  // vec3 eye = vec3(1.0, 0.0, 0.);

  mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0., 1.0, 0.));
  vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

  vec3 color = render(eye, worldDir);

  gl_FragColor = vec4(color, 1.0);
  // gl_FragColor = vec4(dist, 0.0, 0.0, 1.0);
}
