
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

float sdfPlane(vec3 pos) {
  return pos.y;
}

// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org/
//
// https://www.shadertoy.com/view/lsf3WH
// SimonDev: Renamed function to "Math_Random" from "hash"
float Math_Random(vec2 p)  // replace this by something better
{
  p  = 50.0*fract( p*0.3183099 + vec2(0.71,0.113));
  return -1.0+2.0*fract( p.x*p.y*(p.x+p.y) );
}

float noise(vec2 coords) {
  vec2 texSize = vec2(1.0);
  vec2 pc = coords * texSize;
  vec2 base = floor(pc);

  float s1 = Math_Random((base + vec2(0.0, 0.0)) / texSize);
  float s2 = Math_Random((base + vec2(1.0, 0.0)) / texSize);
  float s3 = Math_Random((base + vec2(0.0, 1.0)) / texSize);
  float s4 = Math_Random((base + vec2(1.0, 1.0)) / texSize);

  vec2 f = smoothstep(0.0, 1.0, fract(pc));

  float px1 = mix(s1, s2, f.x);
  float px2 = mix(s3, s4, f.x);
  float result = mix(px1, px2, f.y);
  return result;
}

float noiseFBM(vec2 p, int octaves, float persistence, float lacunarity) {
  float amplitude = 0.5;
  float total = 0.0;

  for (int i = 0; i < octaves; ++i) {
    float noiseValue = noise(p);
    total += noiseValue * amplitude;
    amplitude *= persistence;
    p = p * lacunarity;
  }

  return total;
}

struct MaterialData {
  vec3 colour;
  float dist;
};

vec3 RED = vec3(1.0, 0.0, 0.0);
vec3 BLUE = vec3(0.0, 0.0, 1.0);
vec3 GREEN = vec3(0.0, 1.0, 0.0);
vec3 GRAY = vec3(0.5);
vec3 WHITE = vec3(1.0);

MaterialData opU(MaterialData a, MaterialData b) {
  if (a.dist < b.dist) {
    return a;
  }
  return b;
}

// The map function calculates the overall SDF.
// Maybe a better name would be calculateSceneSDF().
MaterialData map(vec3 pos) {
  float curNoiseSample = noiseFBM(pos.xz / 2.0, 1, 0.5, 2.0);
  curNoiseSample = abs(curNoiseSample);
  curNoiseSample *= 1.5;
  curNoiseSample += 0.1 * noiseFBM(pos.xz * 4.0, 6, 0.5, 2.0);

  float WATER_LEVEL = 0.45;
  vec3 landColour = vec3(0.498, 0.435, 0.396);
  landColour = mix(
      landColour,
      landColour * 0.25,
      smoothstep(WATER_LEVEL - 0.1, WATER_LEVEL, curNoiseSample));
  MaterialData result = MaterialData(
      landColour, pos.y + curNoiseSample);

  vec3 shallowColour = vec3(0.25, 0.25, 0.75);
  vec3 deepColour = vec3(0.025, 0.025, 0.15);
  vec3 waterColour = mix(
      shallowColour,
      deepColour,
      smoothstep(WATER_LEVEL, WATER_LEVEL + 0.1, curNoiseSample));
  waterColour = mix(
      waterColour,
      WHITE,
      smoothstep(WATER_LEVEL + 0.0125, WATER_LEVEL, curNoiseSample));

  MaterialData waterMaterial = MaterialData(
      waterColour, pos.y + WATER_LEVEL);

  result = opU(result, waterMaterial);

  return result;
}

vec3 CalculateNormal(vec3 pos) {
  const float EPS = 0.0001;
  vec3 n = vec3(
    map(pos + vec3(EPS, 0.0, 0.0)).dist - map(pos - vec3(EPS, 0.0, 0.0)).dist,
    map(pos + vec3(0.0, EPS, 0.0)).dist - map(pos - vec3(0.0, EPS, 0.0)).dist,
    map(pos + vec3(0.0, 0.0, EPS)).dist - map(pos - vec3(0.0, 0.0, EPS)).dist
  );
  return normalize(n);
}

vec3 CalculateLighting(vec3 pos, vec3 normal, vec3 lightColour, vec3 lightDir) {
  float dp = saturate(dot(normal, lightDir));

  return lightColour * dp;
}

const int NUM_STEPS = 256;
const float MAX_DIST = 1000.0;
const float MIN_DIST = 0.00001;

MaterialData RayCast(vec3 cameraOrigin,
                     vec3 cameraDir,
                     int numSteps,
                     float startDist,
                     float maxDist) {

  MaterialData material = MaterialData(vec3(0.0), startDist);
  MaterialData defaultMaterial = MaterialData(vec3(0.0), -1.0);

  for (int i = 0; i < NUM_STEPS; ++i) {
    vec3 pos = cameraOrigin + material.dist * cameraDir;

    MaterialData result = map(pos);

    // Case 1: distToScene < 0, intersected scene
    // BREAK
    if (abs(result.dist) < MIN_DIST * material.dist) {
      break;
    }
    material.dist += result.dist;
    material.colour = result.colour;

    // Case 2: dist > MAX_DIST, out of the scene entirely
    // RETURN
    if (material.dist > maxDist) {
      return defaultMaterial;
    }

    // Case 3: Loop around, in reality, do nothing.
  }

  // Finished loop
  return material;
}

float CalculateShadow(vec3 pos, vec3 lightDir) {
  MaterialData result = RayCast(pos, lightDir, 64, 0.01, 10.0);

  if (result.dist >= 0.0) {
    return 0.0;
  }

  return 1.0;
}

float CalculateAO(vec3 pos, vec3 normal) {
  float ao = 0.0;
  float stepSize = 0.1;

  for (float i = 0.0; i < 5.0; ++i) {
    float distFactor = 1.0 / pow(2.0, i);

    ao += distFactor * (i * stepSize - map(pos + normal * i * stepSize).dist);
  }

  return 1.0 - ao;
}


// Performs sphere tracing for the scene.
vec3 RayMarch(vec3 cameraOrigin, vec3 cameraDir) {

  MaterialData material = RayCast(cameraOrigin, cameraDir, NUM_STEPS, 1.0, MAX_DIST);

  vec3 lightDir = normalize(vec3(-0.5, 0.2, -0.6));
  float skyT = exp(saturate(cameraDir.y) * -40.0);
  float sunFactor = pow(saturate(dot(lightDir, cameraDir)), 8.0);
  vec3 skyColour = mix(vec3(0.025, 0.065, 0.5), vec3(0.4, 0.5, 1.0), skyT);
  vec3 fogColour = mix(skyColour, vec3(1.0, 0.9, 0.65), sunFactor);
  if (material.dist < 0.0) {
    return fogColour;
  }

  vec3 pos = cameraOrigin + material.dist * cameraDir;

  vec3 lightColour = WHITE;
  vec3 normal = CalculateNormal(pos);
  float shadowed = CalculateShadow(pos, lightDir);
  vec3 lighting = CalculateLighting(pos, normal, lightColour, lightDir);
  lighting *= shadowed;
  vec3 colour = material.colour * lighting;

  float fogDist = distance(cameraOrigin, pos);
  float inscatter = 1.0 - exp(-fogDist * fogDist * mix(0.0005, 0.001, sunFactor));
  float extinction = exp(-fogDist * fogDist * 0.01);

  colour = colour * extinction * 1.0 + fogColour * inscatter * 1.0;

  return colour;
}

mat3 makeCameraMatrix(vec3 cameraOrigin, vec3 cameraLookAt, vec3 cameraUp) {
  vec3 z = normalize(cameraLookAt - cameraOrigin);
  vec3 x = normalize(cross(z, cameraUp));
  vec3 y = cross(x, z);
  return mat3(x, y, z);
}

void main() {
  vec2 pixelCoords = (vUvs - 0.5) * resolution;

  float t = time * 0.0;
  vec3 rayDir = normalize(vec3(pixelCoords * 2.0 / resolution.y, 1.0));
  vec3 rayOrigin = vec3(3.0, 0.75, -3.0) * vec3(cos(t), 1.0, sin(t));
  vec3 rayLookAt = vec3(0.0);
  mat3 camera = makeCameraMatrix(rayOrigin, rayLookAt, vec3(0.0, 1.0, 0.0));

  vec3 colour = RayMarch(rayOrigin, camera * rayDir);

  gl_FragColor = vec4(pow(colour, vec3(1.0 / 2.2)), 1.0);
}
