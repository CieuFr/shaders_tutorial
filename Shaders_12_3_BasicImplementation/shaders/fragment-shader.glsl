
varying vec2 vUvs;
uniform vec2 resolution;
uniform float time;

float inverseLerp(float v, float minValue, float maxValue) {
  return (v - minValue) / (maxValue - minValue);
}

float remap(float v, float inMin, float inMax, float outMin, float outMax) {
  float t = inverseLerp(v, inMin, inMax);
  return mix(outMin, outMax, t);
}

float saturate(float x) {
  return clamp(x, 0.0, 1.0);
}

float sdfSphere(vec3 p, float r) {
  return length(p) - r;
}

float sdfBox( vec3 p, vec3 b ) {
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdTorus( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);
  return length(q)-t.y;
}

// The map function calculates the overall SDF.
// Maybe a better name would be calculateSceneSDF().
float map(vec3 pos) {
  float dist = sdTorus(pos - vec3(0.0, 0.0, 5.0), vec2(0.5, 0.2));

  return dist;
}

const int NUM_STEPS = 256;
const float MAX_DIST = 1000.0;

// Performs sphere tracing for the scene.
vec3 RayMarch(vec3 cameraOrigin, vec3 cameraDir) {

  vec3 pos;
  float dist = 0.0;

  for (int i = 0; i < NUM_STEPS; ++i) {
    pos = cameraOrigin + dist * cameraDir;

    float distToScene = map(pos);

    // Case 1: distToScene < 0, intersected scene
    // BREAK
    if (distToScene < 0.001) {
      break;
    }
    dist += distToScene;

    // Case 2: dist > MAX_DIST, out of the scene entirely
    // RETURN
    if (dist > MAX_DIST) {
      return vec3(0.0);
    }

    // Case 3: Loop around, in reality, do nothing.
  }

  // Finished loop
  return vec3(1.0);
}

void main() {
  vec2 pixelCoords = (vUvs - 0.5) * resolution;

  vec3 rayDir = normalize(vec3(pixelCoords * 2.0 / resolution.y, 1.0));
  vec3 rayOrigin = vec3(0.0);

  vec3 colour = RayMarch(rayOrigin, rayDir);

  gl_FragColor = vec4(pow(colour, vec3(1.0 / 2.2)), 1.0);
}
