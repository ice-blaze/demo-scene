precision highp float;
varying vec2 screen_size_out;
varying float global_time_out;

const int MAX_MARCHING_STEPS = 10000;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.00001;

float sphereSDF(vec3 samplePoint) {
  vec2 t = vec2(1.0,1.0);
  vec2 q = vec2(length(samplePoint.xz)-t.x,samplePoint.y);
  return length(q)-t.y;
  return length(samplePoint) - 1.0;
}

float sceneSDF(vec3 samplePoint) {
  return sphereSDF(samplePoint);
}

float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(eye + depth * marchingDirection);
        if (dist < EPSILON) {
          return depth;
        }
        depth += dist;
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

    vec3 light1Pos = vec3(4.0 * sin(global_time_out),
                          2.0,
                          4.0 * cos(global_time_out));
    vec3 light1Intensity = vec3(0.4, 0.4, 0.4);

    color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                  light1Pos,
                                  light1Intensity);

    vec3 light2Pos = vec3(2.0 * sin(0.37 * global_time_out),
                          2.0 * cos(0.37 * global_time_out),
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

void main(void) {
  vec3 dir = rayDirection(75.0, screen_size_out.xy, gl_FragCoord.xy);
  vec3 eye = vec3(0.0, 2.0, 15.0);
  float dist = shortestDistanceToSurface(eye, dir, MIN_DIST, MAX_DIST);

  vec3 p = eye + dist * dir;

  vec3 K_a = vec3(0.2, 0.2, 0.2);
  vec3 K_d = vec3(0.7, 0.2, 0.2);
  vec3 K_s = vec3(1.0, 1.0, 1.0);
  float shininess = 10.0;

  vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, eye);

  gl_FragColor = vec4(color, 1.0);
}
