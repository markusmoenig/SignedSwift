//
//  Render.metal
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

#include <metal_stdlib>
using namespace metal;

#import "../Bridge.h"

// For the visual bounding box of the 3D texture
// Box Frame - exact   (https://www.shadertoy.com/view/3ljcRh)

float sdBoxFrame(float3 p, float3 b, float e)
{
  p = abs(p  )-b;
  float3 q = abs(p+e)-e;
  return min(min(
      length(max(float3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
      length(max(float3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
      length(max(float3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}

// MARK: Disney Start

// Based on the Disney BSDF Pathtracer at https://github.com/knightcrawler25/GLSL-PathTracer

/*
 * MIT License
 *
 * Copyright(c) 2019-2021 Asif Ali
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this softwareand associated documentation files(the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions :
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

// globals.glsl

#define PI        3.14159265358979323
#define TWO_PI    6.28318530717958648
//#define INFINITY  1000000.0
#define EPS       0.0001

#define QUAD_LIGHT 0
#define SPHERE_LIGHT 1
#define DISTANT_LIGHT 2

struct Ray
{
    float3 origin;
    float3 direction;
};

struct Camera
{
    float3 up;
    float3 right;
    float3 forward;
    float3 position;
    float fov;
    float focalDist;
    float aperture;
};

struct State
{
    int depth;
    float eta;
    float hitDist;

    float3 fhp;
    float3 normal;
    float3 ffnormal;
    float3 tangent;
    float3 bitangent;

    bool isEmitter;
    bool specularBounce;

    float2 texCoord;
    float3 bary;
    //ivec3 triID;
    int matID;
    Material mat;
};

struct BsdfSampleRec
{
    float3 L;
    float3 f;
    float pdf;
};

struct LightSampleRec
{
    float3 normal;
    float3 emission;
    float3 direction;
    float dist;
    float pdf;
};

float rand(thread DataIn &dataIn)
{
    dataIn.seed -= dataIn.randomVector.xy;
    return fract(sin(dot(dataIn.seed, float2(12.9898, 78.233))) * 43758.5453);
}

float3 FaceForward(float3 a, float3 b)
{
    return dot(a, b) < 0.0 ? -b : b;
}

// intersect.glsl

//-----------------------------------------------------------------------
float SphereIntersect(float rad, float3 pos, Ray r)
//-----------------------------------------------------------------------
{
    float3 op = pos - r.origin;
    float eps = 0.001;
    float b = dot(op, r.direction);
    float det = b * b - dot(op, op) + rad * rad;
    if (det < 0.0)
        return INFINITY;

    det = sqrt(det);
    float t1 = b - det;
    if (t1 > eps)
        return t1;

    float t2 = b + det;
    if (t2 > eps)
        return t2;

    return INFINITY;
}

//-----------------------------------------------------------------------
float RectIntersect(float3 pos, float3 u, float3 v, float4 plane, Ray r)
//-----------------------------------------------------------------------
{
    float3 n = float3(plane);
    float dt = dot(r.direction, n);
    float t = (plane.w - dot(n, r.origin)) / dt;
    if (t > EPS)
    {
        float3 p = r.origin + r.direction * t;
        float3 vi = p - pos;
        float a1 = dot(u, vi);
        if (a1 >= 0. && a1 <= 1.)
        {
            float a2 = dot(v, vi);
            if (a2 >= 0. && a2 <= 1.)
                return t;
        }
    }

    return INFINITY;
}

// sampling.glsl

//----------------------------------------------------------------------
float3 ImportanceSampleGTR1(float rgh, float r1, float r2)
//----------------------------------------------------------------------
{
   float a = max(0.001, rgh);
   float a2 = a * a;

   float phi = r1 * TWO_PI;

   float cosTheta = sqrt((1.0 - pow(a2, 1.0 - r1)) / (1.0 - a2));
   float sinTheta = clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0);
   float sinPhi = sin(phi);
   float cosPhi = cos(phi);

   return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
}

//----------------------------------------------------------------------
float3 ImportanceSampleGTR2_aniso(float ax, float ay, float r1, float r2)
//----------------------------------------------------------------------
{
   float phi = r1 * TWO_PI;

   float sinPhi = ay * sin(phi);
   float cosPhi = ax * cos(phi);
   float tanTheta = sqrt(r2 / (1 - r2));

   return float3(tanTheta * cosPhi, tanTheta * sinPhi, 1.0);
}

//----------------------------------------------------------------------
float3 ImportanceSampleGTR2(float rgh, float r1, float r2)
//----------------------------------------------------------------------
{
   float a = max(0.001, rgh);

   float phi = r1 * TWO_PI;

   float cosTheta = sqrt((1.0 - r2) / (1.0 + (a * a - 1.0) * r2));
   float sinTheta = clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0);
   float sinPhi = sin(phi);
   float cosPhi = cos(phi);

   return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
}

//-----------------------------------------------------------------------
float SchlickFresnel(float u)
//-----------------------------------------------------------------------
{
   float m = clamp(1.0 - u, 0.0, 1.0);
   float m2 = m * m;
   return m2 * m2 * m; // pow(m,5)
}

//-----------------------------------------------------------------------
float DielectricFresnel(float cos_theta_i, float eta)
//-----------------------------------------------------------------------
{
   float sinThetaTSq = eta * eta * (1.0f - cos_theta_i * cos_theta_i);

   // Total internal reflection
   if (sinThetaTSq > 1.0)
       return 1.0;

   float cos_theta_t = sqrt(max(1.0 - sinThetaTSq, 0.0));

   float rs = (eta * cos_theta_t - cos_theta_i) / (eta * cos_theta_t + cos_theta_i);
   float rp = (eta * cos_theta_i - cos_theta_t) / (eta * cos_theta_i + cos_theta_t);

   return 0.5f * (rs * rs + rp * rp);
}

//-----------------------------------------------------------------------
float GTR1(float NDotH, float a)
//-----------------------------------------------------------------------
{
   if (a >= 1.0)
       return (1.0 / PI);
   float a2 = a * a;
   float t = 1.0 + (a2 - 1.0) * NDotH * NDotH;
   return (a2 - 1.0) / (PI * log(a2) * t);
}

//-----------------------------------------------------------------------
float GTR2(float NDotH, float a)
//-----------------------------------------------------------------------
{
   float a2 = a * a;
   float t = 1.0 + (a2 - 1.0) * NDotH * NDotH;
   return a2 / (PI * t * t);
}

//-----------------------------------------------------------------------
float GTR2_aniso(float NDotH, float HDotX, float HDotY, float ax, float ay)
//-----------------------------------------------------------------------
{
   float a = HDotX / ax;
   float b = HDotY / ay;
   float c = a * a + b * b + NDotH * NDotH;
   return 1.0 / (PI * ax * ay * c * c);
}

//-----------------------------------------------------------------------
float SmithG_GGX(float NDotV, float alphaG)
//-----------------------------------------------------------------------
{
   float a = alphaG * alphaG;
   float b = NDotV * NDotV;
   return 1.0 / (NDotV + sqrt(a + b - a * b));
}

//-----------------------------------------------------------------------
float SmithG_GGX_aniso(float NDotV, float VDotX, float VDotY, float ax, float ay)
//-----------------------------------------------------------------------
{
   float a = VDotX * ax;
   float b = VDotY * ay;
   float c = NDotV;
   return 1.0 / (NDotV + sqrt(a * a + b * b + c * c));
}

//-----------------------------------------------------------------------
float3 CosineSampleHemisphere(float r1, float r2)
//-----------------------------------------------------------------------
{
    float3 dir;
   float r = sqrt(r1);
   float phi = TWO_PI * r2;
   dir.x = r * cos(phi);
   dir.y = r * sin(phi);
   dir.z = sqrt(max(0.0, 1.0 - dir.x * dir.x - dir.y * dir.y));

   return dir;
}

//-----------------------------------------------------------------------
float3 UniformSampleHemisphere(float r1, float r2)
//-----------------------------------------------------------------------
{
   float r = sqrt(max(0.0, 1.0 - r1 * r1));
   float phi = TWO_PI * r2;

   return float3(r * cos(phi), r * sin(phi), r1);
}

//-----------------------------------------------------------------------
float3 UniformSampleSphere(float r1, float r2)
//-----------------------------------------------------------------------
{
   float z = 1.0 - 2.0 * r1;
   float r = sqrt(max(0.0, 1.0 - z * z));
   float phi = TWO_PI * r2;

   return float3(r * cos(phi), r * sin(phi), z);
}

//-----------------------------------------------------------------------
float powerHeuristic(float a, float b)
//-----------------------------------------------------------------------
{
   float t = a * a;
   return t / (b * b + t);
}

//-----------------------------------------------------------------------
void sampleSphereLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   // TODO: Pick a point only on the visible surface of the sphere

   float r1 = rand(dataIn);
   float r2 = rand(dataIn);

   float3 lightSurfacePos = light.position + UniformSampleSphere(r1, r2) * light.radius;
   lightSampleRec.direction = lightSurfacePos - surfacePos;
   lightSampleRec.dist = length(lightSampleRec.direction);
   float distSq = lightSampleRec.dist * lightSampleRec.dist;
   lightSampleRec.direction /= lightSampleRec.dist;
   lightSampleRec.normal = normalize(lightSurfacePos - light.position);
   lightSampleRec.emission = light.emission * float(dataIn.numOfLights);
   lightSampleRec.pdf = distSq / (light.area * abs(dot(lightSampleRec.normal, lightSampleRec.direction)));
}

//-----------------------------------------------------------------------
void sampleRectLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   float r1 = rand(dataIn);
   float r2 = rand(dataIn);

    float3 lightSurfacePos = light.position + light.u * r1 + light.v * r2;
   lightSampleRec.direction = lightSurfacePos - surfacePos;
   lightSampleRec.dist = length(lightSampleRec.direction);
   float distSq = lightSampleRec.dist * lightSampleRec.dist;
   lightSampleRec.direction /= lightSampleRec.dist;
   lightSampleRec.normal = normalize(cross(light.u, light.v));
   lightSampleRec.emission = light.emission * float(dataIn.numOfLights);
   lightSampleRec.pdf = distSq / (light.area * abs(dot(lightSampleRec.normal, lightSampleRec.direction)));
}

//-----------------------------------------------------------------------
void sampleDistantLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   lightSampleRec.direction = normalize(light.position - surfacePos);
   lightSampleRec.normal = normalize(surfacePos - light.position);
   lightSampleRec.emission = light.emission * float(dataIn.numOfLights);
   lightSampleRec.dist = INFINITY;
   lightSampleRec.pdf = 1.0;
}

//-----------------------------------------------------------------------
void sampleOneLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   int type = int(light.type);

   if (type == QUAD_LIGHT)
       sampleRectLight(light, surfacePos, lightSampleRec, dataIn);
   else if (type == SPHERE_LIGHT)
       sampleSphereLight(light, surfacePos, lightSampleRec, dataIn);
   else
       sampleDistantLight(light, surfacePos, lightSampleRec, dataIn);
}

#ifdef ENVMAP
#ifndef CONSTANT_BG

//-----------------------------------------------------------------------
float EnvPdf(in Ray r)
//-----------------------------------------------------------------------
{
   float theta = acos(clamp(r.direction.y, -1.0, 1.0));
   vec2 uv = vec2((PI + atan(r.direction.z, r.direction.x)) * (1.0 / TWO_PI), theta * (1.0 / PI));
   float pdf = texture(hdrCondDistTex, uv).y * texture(hdrMarginalDistTex, vec2(uv.y, 0.)).y;
   return (pdf * hdrResolution) / (2.0 * PI * PI * sin(theta));
}

//-----------------------------------------------------------------------
vec4 EnvSample(inout vec3 color)
//-----------------------------------------------------------------------
{
   float r1 = rand();
   float r2 = rand();

   float v = texture(hdrMarginalDistTex, vec2(r1, 0.)).x;
   float u = texture(hdrCondDistTex, vec2(r2, v)).x;

   color = texture(hdrTex, vec2(u, v)).xyz * hdrMultiplier;
   float pdf = texture(hdrCondDistTex, vec2(u, v)).y * texture(hdrMarginalDistTex, vec2(v, 0.)).y;

   float phi = u * TWO_PI;
   float theta = v * PI;

   if (sin(theta) == 0.0)
       pdf = 0.0;

   return vec4(-sin(theta) * cos(phi), cos(theta), -sin(theta) * sin(phi), (pdf * hdrResolution) / (2.0 * PI * PI * sin(theta)));
}

#endif
#endif

//-----------------------------------------------------------------------
float3 EmitterSample(Ray r, State state, LightSampleRec lightSampleRec, BsdfSampleRec bsdfSampleRec)
//-----------------------------------------------------------------------
{
   float3 Le;

   if (state.depth == 0 || state.specularBounce)
       Le = lightSampleRec.emission;
   else
       Le = powerHeuristic(bsdfSampleRec.pdf, lightSampleRec.pdf) * lightSampleRec.emission;

   return Le;
}

// disney.glsl

//-----------------------------------------------------------------------
float3 EvalDielectricReflection(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    float F = DielectricFresnel(dot(V, H), state.eta);
    float D = GTR2(dot(N, H), state.mat.roughness);
    
    pdf = D * dot(N, H) * F / (4.0 * abs(dot(V, H)));

    float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(abs(dot(N, V)), state.mat.roughness);
    return state.mat.albedo * F * D * G;
}

//-----------------------------------------------------------------------
float3 EvalDielectricRefraction(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) >= 0.0)
        return float3(0.0);

    float F = DielectricFresnel(abs(dot(V, H)), state.eta);
    float D = GTR2(dot(N, H), state.mat.roughness);

    float denomSqrt = dot(L, H) + dot(V, H) * state.eta;
    pdf = D * dot(N, H) * (1.0 - F) * abs(dot(L, H)) / (denomSqrt * denomSqrt);

    float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(abs(dot(N, V)), state.mat.roughness);
    return state.mat.albedo * (1.0 - F) * D * G * abs(dot(V, H)) * abs(dot(L, H)) * 4.0 * state.eta * state.eta / (denomSqrt * denomSqrt);
}

//-----------------------------------------------------------------------
float3 EvalSpecular(State state, float3 Cspec0, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    float D = GTR2(dot(N, H), state.mat.roughness);
    pdf = D * dot(N, H) / (4.0 * dot(V, H));

    float FH = SchlickFresnel(dot(L, H));
    float3 F = mix(Cspec0, float3(1.0), FH);
    float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(abs(dot(N, V)), state.mat.roughness);
    return F * D * G;
}

//-----------------------------------------------------------------------
float3 EvalClearcoat(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    float D = GTR1(dot(N, H), mix(0.1, 0.001, state.mat.clearcoatGloss));
    pdf = D * dot(N, H) / (4.0 * dot(V, H));

    float FH = SchlickFresnel(dot(L, H));
    float F = mix(0.04, 1.0, FH);
    float G = SmithG_GGX(dot(N, L), 0.25) * SmithG_GGX(dot(N, V), 0.25);
    return float3(0.25 * state.mat.clearcoat * F * D * G);
}

//-----------------------------------------------------------------------
float3 EvalDiffuse(State state, float3 Csheen, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    pdf = dot(N, L) * (1.0 / PI);

    // Diffuse
    float FL = SchlickFresnel(dot(N, L));
    float FV = SchlickFresnel(dot(N, V));
    float FH = SchlickFresnel(dot(L, H));
    float Fd90 = 0.5 + 2.0 * dot(L, H) * dot(L, H) * state.mat.roughness;
    float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);

    // Fake Subsurface TODO: Replace with volumetric scattering
    float Fss90 = dot(L, H) * dot(L, H) * state.mat.roughness;
    float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
    float ss = 1.25 * (Fss * (1.0 / (dot(N, L) + dot(N, V)) - 0.5) + 0.5);

    float3 Fsheen = FH * state.mat.sheen * Csheen;
    return ((1.0 / PI) * mix(Fd, ss, state.mat.subsurface) * state.mat.albedo + Fsheen) * (1.0 - state.mat.metallic);
}

//-----------------------------------------------------------------------
float3 DisneySample(thread State &state, float3 V, float3 N, thread float3 &L, thread float &pdf, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    float3 f = float3(0.0);

    float r1 = rand(dataIn);
    float r2 = rand(dataIn);

    float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);
    float transWeight = (1.0 - state.mat.metallic) * state.mat.specTrans;

    float3 Cdlin = state.mat.albedo;
    float Cdlum = 0.3 * Cdlin.x + 0.6 * Cdlin.y + 0.1 * Cdlin.z; // luminance approx.

    float3 Ctint = Cdlum > 0.0 ? Cdlin / Cdlum : float3(1.0f); // normalize lum. to isolate hue+sat
    float3 Cspec0 = mix(state.mat.specular * 0.08 * mix(float3(1.0), Ctint, state.mat.specularTint), Cdlin, state.mat.metallic);
    float3 Csheen = mix(float3(1.0), Ctint, state.mat.sheenTint);

    // TODO: Reuse random numbers and reduce so many calls to rand()
    if (rand(dataIn) < transWeight)
    {
        float3 H = ImportanceSampleGTR2(state.mat.roughness, r1, r2);
        H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

        if (dot(V, H) < 0.0)
            H = -H;

        float3 R = reflect(-V, H);
        float F = DielectricFresnel(abs(dot(R, H)), state.eta);

        // Reflection/Total internal reflection
        if (rand(dataIn) < F)
        {
            L = normalize(R);
            f = EvalDielectricReflection(state, V, N, L, H, pdf);
        }
        else // Transmission
        {
            L = normalize(refract(-V, H, state.eta));
            f = EvalDielectricRefraction(state, V, N, L, H, pdf);
        }

        f *= transWeight;
        pdf *= transWeight;
    }
    else
    {
        if (rand(dataIn) < diffuseRatio)
        {
            L = CosineSampleHemisphere(r1, r2);
            L = state.tangent * L.x + state.bitangent * L.y + N * L.z;

            float3 H = normalize(L + V);

            f = EvalDiffuse(state, Csheen, V, N, L, H, pdf);
            pdf *= diffuseRatio;
        }
        else // Specular
        {
            float primarySpecRatio = 1.0 / (1.0 + state.mat.clearcoat);
            
            // Sample primary specular lobe
            if (rand(dataIn) < primarySpecRatio)
            {
                // TODO: Implement http://jcgt.org/published/0007/04/01/
                float3 H = ImportanceSampleGTR2(state.mat.roughness, r1, r2);
                H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

                if (dot(V, H) < 0.0)
                    H = -H;

                L = normalize(reflect(-V, H));

                f = EvalSpecular(state, Cspec0, V, N, L, H, pdf);
                pdf *= primarySpecRatio * (1.0 - diffuseRatio);
            }
            else // Sample clearcoat lobe
            {
                float3 H = ImportanceSampleGTR1(mix(0.1, 0.001, state.mat.clearcoatGloss), r1, r2);
                H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

                if (dot(V, H) < 0.0)
                    H = -H;

                L = normalize(reflect(-V, H));

                f = EvalClearcoat(state, V, N, L, H, pdf);
                pdf *= (1.0 - primarySpecRatio) * (1.0 - diffuseRatio);
            }
        }

        f *= (1.0 - transWeight);
        pdf *= (1.0 - transWeight);
    }
    return f;
}

//-----------------------------------------------------------------------
float3 DisneyEval(State state, float3 V, float3 N, float3 L, thread float &pdf)
//-----------------------------------------------------------------------
{
    float3 H;
    bool refl = dot(N, L) > 0.0;

    if (refl)
        H = normalize(L + V);
    else
        H = normalize(L + V * state.eta);

    if (dot(V, H) < 0.0)
        H = -H;

    float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);
    float primarySpecRatio = 1.0 / (1.0 + state.mat.clearcoat);
    float transWeight = (1.0 - state.mat.metallic) * state.mat.specTrans;

    float3 brdf = float3(0.0);
    float3 bsdf = float3(0.0);
    float brdfPdf = 0.0;
    float bsdfPdf = 0.0;

    if (transWeight > 0.0)
    {
        // Reflection
        if (refl)
        {
            bsdf = EvalDielectricReflection(state, V, N, L, H, bsdfPdf);
        }
        else // Transmission
        {
            bsdf = EvalDielectricRefraction(state, V, N, L, H, bsdfPdf);
        }
    }

    float m_pdf;

    if (transWeight < 1.0)
    {
        float3 Cdlin = state.mat.albedo;
        float Cdlum = 0.3 * Cdlin.x + 0.6 * Cdlin.y + 0.1 * Cdlin.z; // luminance approx.

        float3 Ctint = Cdlum > 0.0 ? Cdlin / Cdlum : float3(1.0f); // normalize lum. to isolate hue+sat
        float3 Cspec0 = mix(state.mat.specular * 0.08 * mix(float3(1.0), Ctint, state.mat.specularTint), Cdlin, state.mat.metallic);
        float3 Csheen = mix(float3(1.0), Ctint, state.mat.sheenTint);

        // Diffuse
        brdf += EvalDiffuse(state, Csheen, V, N, L, H, m_pdf);
        brdfPdf += m_pdf * diffuseRatio;
            
        // Specular
        brdf += EvalSpecular(state, Cspec0, V, N, L, H, m_pdf);
        brdfPdf += m_pdf * primarySpecRatio * (1.0 - diffuseRatio);
            
        // Clearcoat
        brdf += EvalClearcoat(state, V, N, L, H, m_pdf);
        brdfPdf += m_pdf * (1.0 - primarySpecRatio) * (1.0 - diffuseRatio);
    }

    pdf = mix(brdfPdf, bsdfPdf, transWeight);
    return mix(brdf, bsdf, transWeight);
}

//-----------------------------------------------------------------------
void Onb(float3 N, thread float3 &T, thread float3 &B)
//-----------------------------------------------------------------------
{
    float3 UpVector = abs(N.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    T = normalize(cross(UpVector, N));
    B = cross(N, T);
}

// MARK: Disney End

// https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
float2 boxIntersection(float3 ro, float3 rd, float3 boxSize, thread float3 &outNormal )
{
    float3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    float3 n = m*ro;   // can precompute if traversing a set of aligned boxes
    float3 k = abs(m)*boxSize;
    float3 t1 = -n - k;
    float3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    if( tN>tF || tF<0.0) return float2(-1.0); // no intersection
    outNormal = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
    return float2( tN, tF );
}

float3 getCamerayRay(float2 uv, float3 ro, float3 rd, float fov, float2 size, thread DataIn &dataIn) {

    float3 position = ro;
    float3 pivot = rd;
    
    float focalDist = 0.1;
    float aperture = 0;
    
    float3 dir = normalize(pivot - position);
    float pitch = asin(dir.y);
    float yaw = atan2(dir.z, dir.x);

    float radius = distance(position, pivot);

    float3 forward_temp = float3();
    
    forward_temp.x = cos(yaw) * cos(pitch);
    forward_temp.y = sin(pitch);
    forward_temp.z = sin(yaw) * cos(pitch);

    float3 worldUp = float3(0,1,0);
    float3 forward = normalize(forward_temp);
    position = pivot + (forward * -1.0) * radius;

    float3 right = normalize(cross(forward, worldUp));
    float3 up = normalize(cross(right, forward));

    float2 r2D = 2.0 * float2(rand(dataIn), rand(dataIn));

    float2 jitter = float2();
    jitter.x = r2D.x < 1.0 ? sqrt(r2D.x) - 1.0 : 1.0 - sqrt(2.0 - r2D.x);
    jitter.y = r2D.y < 1.0 ? sqrt(r2D.y) - 1.0 : 1.0 - sqrt(2.0 - r2D.y);

    jitter /= (size * 0.5);
    float2 d = (2.0 * uv - 1.0) + jitter;

    float scale = tan(fov * 0.5);
    d.y *= size.y / size.x * scale;
    d.x *= scale;
    float3 rayDir = normalize(d.x * right + d.y * up + forward);

    float3 focalPoint = focalDist * rayDir;
    float cam_r1 = rand(dataIn) * M_2_PI_F;
    float cam_r2 = rand(dataIn) * aperture;
    float3 randomAperturePos = (cos(cam_r1) * right + sin(cam_r1) * up) * sqrt(cam_r2);
    float3 finalRayDir = normalize(focalPoint - randomAperturePos);
    
    return finalRayDir;
}

float applyModelerData(float3 uv, float dist, constant ModelerUniform &mData, float scal, thread float &materialMixValue);
void computeModelerMaterial(float3 uv, constant ModelerUniform &mData, float scale, thread Material &material, float globalMaterialScale);
Material mixMaterials(Material materialA, Material materialB, float k);

/// Gets the distance at the given point
float getDistance(float3 p, texture3d<float> modelTexture, constant ModelerUniform &mData, thread bool &editHit, thread float &materialMixValue, float scale = 1.0)
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    editHit = false;
    
    float d = modelTexture.sample(textureSampler, clamp((p / scale + float3(0.5)), 0., 1.)).x * scale;
    
    float editingDist = applyModelerData(p, d, mData, scale, materialMixValue);
    
    if (d != editingDist) {
        editHit = true;
    }
    
    d = editingDist;

    return d;
}

/// Gets the distance at the given point
float getDistance(float3 p, texture3d<float> modelTexture, float scale = 1.0)
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    return modelTexture.sample(textureSampler, clamp((p / scale + float3(0.5)), 0., 1.)).x * scale;
}

/// Reads material data
float4 getMaterialData(float3 p, texture3d<float, access::read_write> materialTexture, float scale = 1.0)
{
    float3 size = float3(materialTexture.get_width() - 1, materialTexture.get_height() - 1, materialTexture.get_depth() - 1);
    
    float4 color = materialTexture.read(ushort3(clamp(p / scale + float3(0.5), 0., 1.) * size));
    return color;
}

/// Writes material data
void setMaterialData(float3 p, float4 value, texture3d<float, access::read_write> materialTexture, float scale = 1.0)
{
    float3 size = float3(materialTexture.get_width() - 1, materialTexture.get_height() - 1, materialTexture.get_depth() - 1);

    materialTexture.write(value, ushort3((p / scale + float3(0.5)) * size));
}

/// Calculates the normal at the given point
float3 getNormal(float3 p, texture3d<float> modelTexture, constant ModelerUniform  &mData, float scale = 1.0)
{
    float3 epsilon = float3(0.001, 0., 0.);
    
    bool editHit; float materialMixValue;

    float3 n = float3(getDistance(p + epsilon.xyy, modelTexture, mData, editHit, materialMixValue, scale) - getDistance(p - epsilon.xyy, modelTexture, mData, editHit, materialMixValue, scale),
                      getDistance(p + epsilon.yxy, modelTexture, mData, editHit, materialMixValue, scale) - getDistance(p - epsilon.yxy, modelTexture, mData, editHit, materialMixValue, scale),
                      getDistance(p + epsilon.yyx, modelTexture, mData, editHit, materialMixValue, scale) - getDistance(p - epsilon.yyx, modelTexture, mData, editHit, materialMixValue, scale));

    return normalize(n);
}

/// Calculates the normal at the given point
float3 getNormal(float3 p, texture3d<float> modelTexture, float scale = 1.0)
{
    float3 epsilon = float3(0.001, 0., 0.);

    float3 n = float3(getDistance(p + epsilon.xyy, modelTexture, scale) - getDistance(p - epsilon.xyy, modelTexture, scale),
                      getDistance(p + epsilon.yxy, modelTexture, scale) - getDistance(p - epsilon.yxy, modelTexture, scale),
                      getDistance(p + epsilon.yyx, modelTexture, scale) - getDistance(p - epsilon.yyx, modelTexture, scale));

    return normalize(n);
}

bool insideHit(Ray ray, thread float &distance, constant ModelerUniform &mData, texture3d<float> modelTexture, texture3d<float, access::read_write> materialTexture3, float scale = 1.0) {

    float t = EPS;
    bool hit = false;

    float maxDistance = INFINITY;
    
    float r = 0.5 * scale; float3 rectNormal;
    float2 bbox = boxIntersection(ray.origin, ray.direction, float3(r, r, r), rectNormal);
    if (bbox.x > 0) return false;
    else maxDistance = bbox.y;

    for(int i = 0; i < 260; ++i)
    {
        float3 p = ray.origin + ray.direction * t;
        float d = getDistance(p, modelTexture, scale);
        
        if (abs(d) < (0.0001*t*scale)) {
            float transmission = getMaterialData(p, materialTexture3, scale).y;
            if (transmission < 0.01) {
                hit = true;
                break;
            }
        }
        
        t += abs(d);

        if (t >= maxDistance)
            break;
    }
    
    distance = t;
    
    return hit;
}

//-----------------------------------------------------------------------
float3 DirectLight(Ray ray, State state, thread DataIn &dataIn, constant RenderUniform &renderData, constant ModelerUniform  &mData, texture3d<float> modelTexture, texture3d<float, access::read_write> materialTexture3, float scale = 1.0)
//-----------------------------------------------------------------------
{
    float3 Li = float3(0.0);
    float3 surfacePos = state.fhp + state.normal * EPS;

    BsdfSampleRec bsdfSampleRec;

    // Environment Light
#ifdef ENVMAP
#ifndef CONSTANT_BG
    {
        vec3 color;
        vec4 dirPdf = EnvSample(color);
        vec3 lightDir = dirPdf.xyz;
        float lightPdf = dirPdf.w;

        Ray shadowRay = Ray(surfacePos, lightDir);
        bool inShadow = AnyHit(shadowRay, INFINITY - EPS);

        if (!inShadow)
        {
            bsdfSampleRec.f = DisneyEval(state, -r.direction, state.ffnormal, lightDir, bsdfSampleRec.pdf);

            if (bsdfSampleRec.pdf > 0.0)
            {
                float misWeight = powerHeuristic(lightPdf, bsdfSampleRec.pdf);
                if (misWeight > 0.0)
                    Li += misWeight * bsdfSampleRec.f * abs(dot(lightDir, state.ffnormal)) * color / lightPdf;
            }
        }
    }
#endif
#endif

    // Analytic Lights
//#ifdef LIGHTS
    {
        LightSampleRec lightSampleRec;

        //Pick a light to sample
        int index = int(rand(dataIn) * float(dataIn.numOfLights)) * 5;

        Light light = renderData.lights[index];

        // Fetch light Data
        /*
        vec3 position = texelFetch(lightsTex, ivec2(index + 0, 0), 0).xyz;
        vec3 emission = texelFetch(lightsTex, ivec2(index + 1, 0), 0).xyz;
        vec3 u        = texelFetch(lightsTex, ivec2(index + 2, 0), 0).xyz; // u vector for rect
        vec3 v        = texelFetch(lightsTex, ivec2(index + 3, 0), 0).xyz; // v vector for rect
        vec3 params   = texelFetch(lightsTex, ivec2(index + 4, 0), 0).xyz;
        float radius  = params.x;
        float area    = params.y;
        float type    = params.z; // 0->Rect, 1->Sphere, 2->Distant
        */

        float3 params   = light.params;//texelFetch(lightsTex, ivec2(index + 4, 0), 0).xyz;
        light.radius  = params.x;
        light.area    = params.y;
        light.type    = params.z; // 0->Rect, 1->Sphere, 2->Distant
        
        //light = Light(position, emission, u, v, radius, area, type);
        sampleOneLight(light, surfacePos, lightSampleRec, dataIn);
        
        if (dot(lightSampleRec.direction, lightSampleRec.normal) < 0.0)
        {
            //Ray shadowRay = Ray(surfacePos, lightSampleRec.direction);
            bool inShadow = false;//AnyHit(shadowRay, lightSampleRec.dist - EPS);
            
            if (renderData.noShadows == 0) {
                Ray lightRay;
                lightRay.origin = surfacePos;
                lightRay.direction = lightSampleRec.direction;
                float t;
                
                if (insideHit(lightRay, t, mData, modelTexture, materialTexture3, scale)) {
                    inShadow = true;
                }
            }

            if (inShadow == false) {
                bsdfSampleRec.f = DisneyEval(state, -ray.direction, state.ffnormal, lightSampleRec.direction, bsdfSampleRec.pdf);

                float weight = 1.0;
                if(light.area > 0.0)
                    weight = powerHeuristic(lightSampleRec.pdf, bsdfSampleRec.pdf);

                if (bsdfSampleRec.pdf > 0.0)
                    Li += weight * bsdfSampleRec.f * abs(dot(state.ffnormal, lightSampleRec.direction)) * lightSampleRec.emission / lightSampleRec.pdf;
            }
        }
    }
//#endif

    return Li;
}

// MARK: Render Entry Point
kernel void renderBSDF(        constant RenderUniform               &renderData [[ buffer(0) ]],
                               constant ModelerUniform              &mData [[ buffer(1) ]],
                               texture3d<float>                     modelTexture [[ texture(2) ]],
                               texture3d<float, access::read_write> colorTexture [[ texture(3) ]],
                               texture3d<float, access::read_write> materialTexture1 [[ texture(4) ]],
                               texture3d<float, access::read_write> materialTexture2 [[ texture(5) ]],
                               texture3d<float, access::read_write> materialTexture3 [[ texture(6) ]],
                               texture3d<float, access::read_write> materialTexture4 [[ texture(7) ]],
                               texture2d<float, access::write>      sampleTexture [[ texture(8) ]],
                               uint2 gid                            [[thread_position_in_grid]])

{
    //float2 uv = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y);
    float2 size = float2(sampleTexture.get_width(), sampleTexture.get_height());
    float2 uv = float2(gid) / size;// - float3(0.5);

    float3 ro = renderData.cameraOrigin;
    float3 rd = renderData.cameraLookAt;
    float scale = renderData.scale;

    struct DataIn dataIn;
    
    dataIn.seed = uv;
    dataIn.randomVector = renderData.randomVector;
    dataIn.numOfLights = renderData.numOfLights;

    rd = getCamerayRay(uv, ro, rd, renderData.cameraFov, size, dataIn);
        
    float3 radiance = float3(0.0);
    float3 throughput = float3(1.0);
    State state;
    LightSampleRec lightSampleRec;
    BsdfSampleRec bsdfSampleRec;
    float3 absorption = float3(0.0);
    state.specularBounce = false;
    state.isEmitter = false;
    
    Ray ray;
    ray.origin = ro;
    ray.direction = rd;
    
    bool editHit; float materialMixValue;
    
    int maxDepth = renderData.maxDepth;
    bool didHitBBox = false;

    for (int depth = 0; depth < maxDepth; depth++)
    {
        state.depth = depth;
     
        float r = 0.5 * scale; float3 rectNormal;
        float2 bbox = boxIntersection(ray.origin, ray.direction, float3(r, r, r), rectNormal);

        float t = INFINITY;
        
        if (bbox.y > 0.0) {
                    
            //float outside = 1.0;

            if (depth == 0) {
                t = max(bbox.x, 0.000);
                didHitBBox = true;
            }
            else {
                t = 0.000;
                //outside = dot(state.normal, state.ffnormal) > 0.0 ? 1.0 : -1.0;
            }
            
            bool hit = false;
            bool needsNormal = true;
            
            // Check for border hit
            float3 p = ray.origin + ray.direction * t;
            float d = getDistance(p, modelTexture, mData, editHit, materialMixValue, scale);
            if (d < 0.) {
                hit = true;
                state.normal = rectNormal;
                needsNormal = false;
            } else {
                for(int i = 0; i < 260; ++i)
                {
                    float3 p = ray.origin + ray.direction * t;
                    float d = getDistance(p, modelTexture, mData, editHit, materialMixValue, scale);
                    
                    // --- Visual Bounding Box, only test on the first pass
                    
//                    if (renderData.showBBox == 1 && i == 0) {
//                        bd = sdBoxFrame(p, float(r), 0.004);
//                        d = min(d, bd);
//                    }
                    
                    // ---

                    if (abs(d) < (0.0001*t*scale)) {
                        hit = true;
//                        if (didHitBBox && i == 0 && d == bd) didHitBBox = true;
                        break;
                    }
                    
                    t += abs(d);// * outside;

                    if (t >= bbox.y)
                        break;
                }
            }
            
            if (hit == true) {
                float3 position = ray.origin + ray.direction * t;
                if (needsNormal) {
                    float3 normal = getNormal(position, modelTexture, mData, scale);
                    state.normal = normal;
                }
                state.fhp = position;
                state.ffnormal = dot(state.normal, ray.direction) <= 0.0 ? state.normal : state.normal * -1.0;
            } else {
                t = INFINITY;
            }
        }
        
        // Lights
        /*
        for (int i = 0; i < renderData.numOfLights; i++)
        {
            Light light = renderData.lights[i];
            
            // Intersect rectangular area light
            if (light.params.z == 0.)
            {
                float3 u = light.u;
                float3 v = light.v;
                float3 normal = normalize(cross(light.u, light.v));
                if (dot(normal, ray.direction) > 0.) // Hide backfacing quad light
                    continue;
                float4 plane = float4(normal, dot(normal, light.position));
                u *= 1.0f / dot(u, u);
                v *= 1.0f / dot(v, v);

                float d = RectIntersect(light.position, u, v, plane, ray);
                if (d < 0.)
                    d = INFINITY;
                if (d < t)
                {
                    t = d;
                    float cosTheta = dot(-ray.direction, normal);
                    float pdf = (t * t) / (light.params.y * cosTheta);
                    lightSampleRec.emission = light.emission;
                    lightSampleRec.pdf = pdf;
                    state.isEmitter = true;
                }
            } else
            // Intersect spherical area light
            if (light.params.z == 1.0)
            {
                float d = SphereIntersect(light.params.x, light.position, ray);
                if (d < 0.)
                    d = INFINITY;
                if (d < t)
                {
                    t = d;
                    float pdf = (t * t) / light.params.y;
                    lightSampleRec.emission = light.emission;
                    lightSampleRec.pdf = pdf;
                    state.isEmitter = true;
                }
            }
        }*/
        
        if (t == INFINITY) {
            if (true) {
                radiance += pow(renderData.backgroundColor.xyz, 2.2) * throughput;
                if (didHitBBox) radiance += float3(0.01, 0.01, 0.01);
            } else {
                float cSize = 2;
                
                if ( fmod( floor( uv.x * 100 / cSize ), 2.0 ) == 0.0 ) {
                    if ( fmod( floor( uv.y * 100 / cSize ), 2.0 ) != 0.0 ) radiance += float3(0) * throughput;
                } else {
                    if ( fmod( floor( uv.y * 100 / cSize ), 2.0 ) == 0.0 ) radiance += float3(1) * throughput;
                }
            }
            sampleTexture.write(float4(radiance, renderData.backgroundColor.w), gid);
            return;
        }
        
        Onb(state.normal, state.tangent, state.bitangent);
            
        float4 colorAndRoughness = getMaterialData(state.fhp, colorTexture, scale);
        float4 specularMetallicSubsurfaceClearcoat = getMaterialData(state.fhp, materialTexture1, scale);
        float4 anisotropicSpecularTintSheenSheenTint = getMaterialData(state.fhp, materialTexture2, scale);
        float4 clearcoatGlossSpecTransIor = getMaterialData(state.fhp, materialTexture3, scale);
        float4 emissionId = getMaterialData(state.fhp, materialTexture4, scale);
        
        state.mat.albedo = colorAndRoughness.xyz;
        state.mat.specular = specularMetallicSubsurfaceClearcoat.x;
        state.mat.anisotropic = anisotropicSpecularTintSheenSheenTint.x;
        state.mat.metallic = specularMetallicSubsurfaceClearcoat.y;
        state.mat.roughness = colorAndRoughness.w;
        state.mat.subsurface = specularMetallicSubsurfaceClearcoat.z;
        state.mat.specularTint = anisotropicSpecularTintSheenSheenTint.y;
        state.mat.sheen = anisotropicSpecularTintSheenSheenTint.z;
        state.mat.sheenTint = anisotropicSpecularTintSheenSheenTint.w;
        state.mat.clearcoat = specularMetallicSubsurfaceClearcoat.w;
        state.mat.clearcoatGloss = clearcoatGlossSpecTransIor.x;
        state.mat.specTrans = clearcoatGlossSpecTransIor.y;
        state.mat.ior = clearcoatGlossSpecTransIor.z;
        state.mat.emission = emissionId.x * colorAndRoughness.xyz;
        //int id = int(emissionId.w);
        state.mat.atDistance = 1.0;
        
        Material material = mData.material;
        
        if (mData.roleType == Modeler_GeometryAndMaterial) {
            // Geometry preview material blending
            state.mat = mixMaterials(state.mat, material, smoothstep(0.0, 1.0, 1.0 - materialMixValue));
        }
        
        state.mat.roughness = max(state.mat.roughness, 0.001);

        state.eta = dot(state.normal, state.ffnormal) > 0.0 ? (1.0 / state.mat.ior) : state.mat.ior;

        // Reset absorption when ray is going out of surface
        if (dot(state.normal, state.ffnormal) > 0.0)
            absorption = float3(0.0);

        radiance += state.mat.emission * throughput;

//#ifdef LIGHTS
        if (state.isEmitter)
        {
            radiance += EmitterSample(ray, state, lightSampleRec, bsdfSampleRec) * throughput;
            break;
        }
//#endif
        
        // Add absoption
        throughput *= exp(-absorption * t);

        radiance += DirectLight(ray, state, dataIn, renderData, mData, modelTexture, materialTexture3, scale) * throughput;

        bsdfSampleRec.f = DisneySample(state, -ray.direction, state.ffnormal, bsdfSampleRec.L, bsdfSampleRec.pdf, dataIn);

        // Set absorption only if the ray is currently inside the object.
        if (dot(state.ffnormal, bsdfSampleRec.L) < 0.0)
            absorption = -log(state.mat.extinction) / state.mat.atDistance;

        if (bsdfSampleRec.pdf > 0.0)
            throughput *= bsdfSampleRec.f * abs(dot(state.ffnormal, bsdfSampleRec.L)) / bsdfSampleRec.pdf;
        else
            break;

#ifdef RR
        // Russian roulette
        if (depth >= RR_DEPTH)
        {
            float q = min(max(throughput.x, max(throughput.y, throughput.z)) + 0.001, 0.95);
            if (rand() > q)
                break;
            throughput /= q;
        }
#endif

        ray.direction = bsdfSampleRec.L;
        ray.origin = state.fhp + ray.direction * (EPS + 0.01 * scale);
    }

    sampleTexture.write(float4(radiance, 1.0), gid);
}

//------------------------------------------------------------------------------
// BRDF
//------------------------------------------------------------------------------

float pow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

float D_GGX(float linearRoughness, float NoH, const float3 h) {
    // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"
    float oneMinusNoHSquared = 1.0 - NoH * NoH;
    float a = NoH * linearRoughness;
    float k = linearRoughness / (oneMinusNoHSquared + a * a);
    float d = k * k * (1.0 / PI);
    return d;
}

float V_SmithGGXCorrelated(float linearRoughness, float NoV, float NoL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    float a2 = linearRoughness * linearRoughness;
    float GGXV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2);
    float GGXL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2);
    return 0.5 / (GGXV + GGXL);
}

float3 F_Schlick(const float3 f0, float VoH) {
    // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
    return f0 + (float3(1.0) - f0) * pow5(1.0 - VoH);
}

float F_Schlick(float f0, float f90, float VoH) {
    return f0 + (f90 - f0) * pow5(1.0 - VoH);
}

float Fd_Burley(float linearRoughness, float NoV, float NoL, float LoH) {
    // Burley 2012, "Physically-Based Shading at Disney"
    float f90 = 0.5 + 2.0 * linearRoughness * LoH * LoH;
    float lightScatter = F_Schlick(1.0, f90, NoL);
    float viewScatter  = F_Schlick(1.0, f90, NoV);
    return lightScatter * viewScatter * (1.0 / PI);
}

float Fd_Lambert() {
    return 1.0 / PI;
}

//------------------------------------------------------------------------------
// Indirect lighting
//------------------------------------------------------------------------------

float3 Irradiance_SphericalHarmonics(const float3 n) {
    // Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
    return max(
          float3( 0.754554516862612,  0.748542953903366,  0.790921515418539)
        + float3(-0.083856548007422,  0.092533500963210,  0.322764661032516) * (n.y)
        + float3( 0.308152705331738,  0.366796330467391,  0.466698181299906) * (n.z)
        + float3(-0.188884931542396, -0.277402551592231, -0.377844212327557) * (n.x)
        , 0.0);
}

float2 PrefilteredDFG_Karis(float roughness, float NoV) {
    // Karis 2014, "Physically Based Material on Mobile"
    const float4 c0 = float4(-1.0, -0.0275, -0.572,  0.022);
    const float4 c1 = float4( 1.0,  0.0425,  1.040, -0.040);

    float4 r = roughness * c0 + c1;
    float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;

    return float2(-1.04, 1.04) * a004 + r.zw;
}

float3 Tonemap_ACES(const float3 x) {
    // Narkowicz 2015, "ACES Filmic Tone Mapping Curve"
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

float3 OECF_sRGBFast(const float3 linear) {
    return pow(linear, float3(1.0 / 2.2));
}

float shadow(float3 origin, float3 direction, constant ModelerUniform  &mData, texture3d<float> modelTexture, float scale = 1.0) {
    float hit = 1.0;
    float t = EPS;
    
    bool editHit; float materialMixValue;
        
    for (int i = 0; i < 1000; i++) {
        float h = getDistance(origin + direction * t, modelTexture, mData, editHit, materialMixValue, scale);
        if (h < 0.001) return 0.0;
        t += h;
        hit = min(hit, 10.0 * h / t);
        if (t >= 2.5) break;
    }

    return clamp(hit, 0.0, 1.0);
}

// MARK: Render Entry Point
kernel void renderPBR(         constant RenderUniform               &renderData [[ buffer(0) ]],
                               constant ModelerUniform              &mData [[ buffer(1) ]],
                               texture3d<float>                     modelTexture [[ texture(2) ]],
                               texture3d<float, access::read_write> colorTexture [[ texture(3) ]],
                               texture3d<float, access::read_write> materialTexture1 [[ texture(4) ]],
                               texture3d<float, access::read_write> materialTexture2 [[ texture(5) ]],
                               texture3d<float, access::read_write> materialTexture3 [[ texture(6) ]],
                               texture3d<float, access::read_write> materialTexture4 [[ texture(7) ]],
                               texture2d<float, access::write>      sampleTexture [[ texture(8) ]],
                               uint2 gid                            [[thread_position_in_grid]])

{
    //float2 uv = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y);
    float2 size = float2(sampleTexture.get_width(), sampleTexture.get_height());
    float2 uv = float2(gid) / size;// - float3(0.5);

    float3 ro = renderData.cameraOrigin;
    float3 rd = renderData.cameraLookAt;
    float scale = renderData.scale;

    struct DataIn dataIn;
    
    dataIn.seed = uv;
    dataIn.randomVector = renderData.randomVector;
    dataIn.numOfLights = renderData.numOfLights;

    rd = getCamerayRay(uv, ro, rd, renderData.cameraFov, size, dataIn);
        
    Ray ray;
    ray.origin = ro;
    ray.direction = rd;
    
    float3 radiance = float3(0.0);

    bool editHit; float materialMixValue;
    
    bool didHitBBox = false;
     
    float r = 0.5 * scale; float3 rectNormal;
    float2 bbox = boxIntersection(ray.origin, ray.direction, float3(r, r, r), rectNormal);

    float t = INFINITY;
    float3 normal;
    float3 hp;
    
    if (bbox.y > 0.0) {
                
        //float outside = 1.0;

        t = max(bbox.x, 0.000);

        
        bool hit = false;
        bool needsNormal = true;
        didHitBBox = true;
        
        // Check for border hit
        float3 p = ray.origin + ray.direction * t;
        float d = getDistance(p, modelTexture, mData, editHit, materialMixValue, scale);
        if (d < 0.) {
            hit = true;
            normal = rectNormal;
            needsNormal = false;
        } else {
            for(int i = 0; i < 260; ++i)
            {
                float3 p = ray.origin + ray.direction * t;
                float d = getDistance(p, modelTexture, mData, editHit, materialMixValue, scale);
                
                // ---

                if (abs(d) < (0.0001*t*scale)) {
                    hit = true;
                    break;
                }
                
                t += abs(d);// * outside;

                if (t >= bbox.y)
                    break;
            }
        }
        
        if (hit == true) {
            float3 position = ray.origin + ray.direction * t;
            if (needsNormal) {
                normal = getNormal(position, modelTexture, mData, scale);
            }
            hp = position;
        } else {
            t = INFINITY;
        }
    }
    
    if (t == INFINITY) {
        radiance += pow(renderData.backgroundColor.xyz, 2.2);
        if (didHitBBox) {
            radiance += pow(renderData.backgroundColor.xyz, 2.2);
            radiance += float3(0.001, 0.001, 0.001);
        }
        /*
        else {
            float cSize = 2;
            
            if ( fmod( floor( uv.x * 100 / cSize ), 2.0 ) == 0.0 ) {
                if ( fmod( floor( uv.y * 100 / cSize ), 2.0 ) != 0.0 ) radiance += float3(0) * throughput;
            } else {
                if ( fmod( floor( uv.y * 100 / cSize ), 2.0 ) == 0.0 ) radiance += float3(1) * throughput;
            }
        }
        */
        sampleTexture.write(float4(radiance, renderData.backgroundColor.w), gid);
        return;
    }

    float4 colorAndRoughness = getMaterialData(hp, colorTexture, scale);
    float4 specularMetallicSubsurfaceClearcoat = getMaterialData(hp, materialTexture1, scale);
    float4 anisotropicSpecularTintSheenSheenTint = getMaterialData(hp, materialTexture2, scale);
    float4 clearcoatGlossSpecTransIor = getMaterialData(hp, materialTexture3, scale);
    float4 emissionId = getMaterialData(hp, materialTexture4, scale);
    
    Material hitMaterial;

    hitMaterial.albedo = colorAndRoughness.xyz;
    hitMaterial.specular = specularMetallicSubsurfaceClearcoat.x;
    hitMaterial.anisotropic = anisotropicSpecularTintSheenSheenTint.x;
    hitMaterial.metallic = specularMetallicSubsurfaceClearcoat.y;
    hitMaterial.roughness = colorAndRoughness.w;
    hitMaterial.subsurface = specularMetallicSubsurfaceClearcoat.z;
    hitMaterial.specularTint = anisotropicSpecularTintSheenSheenTint.y;
    hitMaterial.sheen = anisotropicSpecularTintSheenSheenTint.z;
    hitMaterial.sheenTint = anisotropicSpecularTintSheenSheenTint.w;
    hitMaterial.clearcoat = specularMetallicSubsurfaceClearcoat.w;
    hitMaterial.clearcoatGloss = clearcoatGlossSpecTransIor.x;
    hitMaterial.specTrans = clearcoatGlossSpecTransIor.y;
    hitMaterial.ior = clearcoatGlossSpecTransIor.z;
    hitMaterial.emission = emissionId.xyz;
    //int id = int(emissionId.w);
    //state.mat.atDistance = 1.0;
    
    Material material = mData.material;
    
    if (mData.roleType == Modeler_GeometryAndMaterial) {
        // Geometry preview material blending
        hitMaterial = mixMaterials(hitMaterial, material, smoothstep(0.0, 1.0, 1.0 - materialMixValue));
    }
    
    hitMaterial.roughness = max(hitMaterial.roughness, 0.001);

    float3 position = hp;
    float3 direction = ray.direction;

    Light light = renderData.lights[0];
    
    float3 v = normalize(-direction);
    float3 n = normal;
    float3 l = normalize( light.position - position );
    float3 h = normalize(v + l);
    float3 ref = normalize(reflect(direction, n));

    float NoV = abs(dot(n, v)) + 1e-5;
    float NoL = saturate(dot(n, l));
    float NoH = saturate(dot(n, h));
    float LoH = saturate(dot(l, h));

    float3 baseColor = hitMaterial.albedo;
    float roughness = hitMaterial.roughness;
    float metallic = hitMaterial.metallic;

    float intensity = 3.0; // 2
    float indirectIntensity = 0.6; // 0.64
    
    float linearRoughness = roughness * roughness;
    float3 diffuseColor = (1.0 - metallic) * baseColor.rgb;
    float3 f0 = 0.04 * (1.0 - metallic) + baseColor.rgb * metallic;

    float attenuation = 1;shadow(position, l, mData, modelTexture, scale);
    
    Ray lightRay;
    lightRay.origin = position;
    lightRay.direction = l;
    
    if (insideHit(lightRay, t, mData, modelTexture, materialTexture3, scale)) {
        attenuation = 0;
    }

    // specular BRDF
    float D = D_GGX(linearRoughness, NoH, h);
    float V = V_SmithGGXCorrelated(linearRoughness, NoV, NoL);
    float3 F = F_Schlick(f0, LoH);
    float3 Fr = (D * V) * F;

    // diffuse BRDF
    float3 Fd = diffuseColor * Fd_Burley(linearRoughness, NoV, NoL, LoH);

    radiance = Fd + Fr;
    radiance *= (intensity * attenuation * NoL) * float3(0.98, 0.92, 0.89);

    // diffuse indirect
    float3 indirectDiffuse = Irradiance_SphericalHarmonics(n) * Fd_Lambert();
    float3 indirectSpecular = pow(renderData.backgroundColor.xyz, 2.2);//float3(0.65, 0.85, 1.0) + ref.y * 0.72;

    Ray refRay;
    refRay.origin = position;
    refRay.direction = ref;
        
    if (insideHit(refRay, t, mData, modelTexture, materialTexture3, scale)) {
        indirectSpecular = getMaterialData(refRay.origin + refRay.direction * t, colorTexture, scale).xyz;
    }

    // indirect contribution
    float2 dfg = PrefilteredDFG_Karis(roughness, NoV);
    float3 specularColor = f0 * dfg.x + dfg.y;
    float3 ibl = diffuseColor * indirectDiffuse + indirectSpecular * specularColor;

    radiance += ibl * indirectIntensity;
        
    sampleTexture.write(float4(radiance, 1.0), gid);
}


// MARK: Hit Scene Entry Point
kernel void modelerHitScene(constant ModelerHitUniform           &mData [[ buffer(0) ]],
                            texture3d<float>                     modelTexture [[ texture(1) ]],
                            texture3d<float, access::read_write> materialTexture4 [[ texture(2) ]],
                            device float4 *out                   [[ buffer(3) ]],
                            uint gid                             [[thread_position_in_grid]])
{
    float3 ro = mData.cameraOrigin;
    float3 rd = mData.cameraLookAt;
    
    struct DataIn dataIn;
    
    dataIn.seed = mData.uv;
    dataIn.randomVector = mData.randomVector;
    
    rd = getCamerayRay(mData.uv, ro, rd, mData.cameraFov, mData.size, dataIn);
    
    float scale = mData.scale;

    float r = 0.5 * scale; float3 rectNormal;
    float2 bbox = boxIntersection(ro, rd, float3(r, r, r), rectNormal);
    
    float4 result1 = float4(-1);
    float4 result2 = float4(-1);

    if (bbox.y > 0.0) {

        // Raymarch into the texture
        bool hit = false;
        
        float t = bbox.x;
        for(int i = 0; i < 120; ++i)
        {
            float3 p = ro + rd * t;
            float d = getDistance(p, modelTexture, scale);

            if (abs(d) < (0.0001*t)) {
                hit = true;
                break;
            }
            
            t += d;

            if (t >= bbox.y)
                break;
        }
        
        if (hit == true) {
            result1.x = t;
            float3 p = ro + rd * t;
            result1.yzw = getNormal(p, modelTexture, scale);
            result2.xyz = p;
            
            float4 emissionId = getMaterialData(p, materialTexture4, scale);
            result2.w = emissionId.w;
        }
    }
    
    out[gid] = float4(result1);
    out[gid+1] = float4(result2);
}

// MARK: Accumulation Entry Point
kernel void renderAccum(constant AccumUniform                       &accumData [[ buffer(0) ]],
                         texture2d<float>                           sampleTexture [[texture(1)]],
                         texture2d<float, access::read_write>       finalTexture [[texture(2)]],
                         uint2 gid                                  [[thread_position_in_grid]])
{
    float4 sample = sampleTexture.read(gid);
    float4 final = finalTexture.read(gid);

    sample = clamp(sample, 0, 5);
    
    float k = accumData.samples + 1;
    final = mix(final, sample, 1.0/k);// final * (1.0 - 1.0/k) + sample * (1.0/k);

    finalTexture.write(final, gid);
}

