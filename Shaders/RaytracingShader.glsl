#[compute]
#version 450

struct Ray {
	vec3 Origin;
	vec3 Direction;
    vec3 Inverse_Dir;
};

struct Material {
    vec3 Albedo;
    float Roughness;
    float Metallic;
    vec3 EmissionColor;
    float EmissionPower;
    float specularProbability;
    float isGlass;
    float ior;
    float absorptionStrength;
    vec3 absorption;
};

struct Model {
    uint index_offset;
    uint triangle_count;
    mat4 model_matrix;
    mat4 inverse_matrix;
    int material_id;
};

struct Sphere {
    vec3 Position;        
    float Radius;         
    float MaterialIndex;       
};

struct HitPayload {
    float HitDistance;
    vec3 WorldPosition;
    vec3 WorldNormal;
    int ObjectIndex;
    int HitType;
    bool isBackface;
};

struct LightPayload {
    vec3 reflectDir;
    vec3 refractDir;
    float reflectWeight;
    float refractWeight;
};

struct Cube {
    vec3 Position;
    vec3 Size;
    vec3 Rotation;
    float MaterialIndex;
};

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(set = 1, binding = 0, std430) restrict buffer CameraData {
	mat4 ProjectionMatrix;
    mat4 viewMatrix;
	mat4 cameraTransform;
	vec4 cameraPosition;
} camera_data;

layout(set = 2, binding = 0, std430) buffer RayBuffer {
	vec4 ray_directions[];
} ray_directions;

layout(set = 3, binding = 0, std430) buffer Spheres {
	Sphere spheres[];
} spheres;

layout(set = 4, binding = 0, std430) buffer Materials {
	Material materials[];
} materials;

layout(set = 5, binding = 0, std430) buffer AccumBuffer {
	vec4 accum_colors[];
};

layout(set = 6, binding = 0, std430) buffer CubeBuffer {
    Cube cubes[];
};

// Our push constant
layout(push_constant, std430) uniform Params {
    vec2 raster_size;
    vec2 reserved;
    float frameIndex;
    float sphereCount;
    float materialCount;
    float raysPerPixel;
    float maxBounces;
    float camera_changed;
    vec3 skyColor;
    float cubeCount;
} params;

uint PCG_Hash(uint seed) {
    uint state = seed * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float randomFloat(inout uint seed) {
    seed = PCG_Hash(seed);
    return float(seed) / 4294967295.0;
}

vec3 vectorInUnitSphere(inout uint seed) {
    return normalize(vec3(
        randomFloat(seed) * 2.0 - 1.0,
        randomFloat(seed) * 2.0 - 1.0,
        randomFloat(seed) * 2.0 - 1.0
    ));
}

vec3 randomOnHemisphere(inout uint seed, vec3 normal) {
    vec3 onUnitSphere = vectorInUnitSphere(seed);
    if (dot(onUnitSphere, normal) > 0.0) {
        return onUnitSphere;
    }
    else {
        return -onUnitSphere;
    }
}

vec3 RandomVec3(inout uint seed) {
    return vec3(
        randomFloat(seed) - 0.5,
        randomFloat(seed) - 0.5,
        randomFloat(seed) - 0.5
    );
}

float RandomValueNormalDistribution(inout uint seed) {
    float theta = 2 * 3.1415926 * randomFloat(seed);
    float rho = sqrt(-2 * log(randomFloat(seed)));
    return rho * cos(theta);
}

mat3 rotationMatrix(vec3 euler) {
    float cx = cos(euler.x), sx = sin(euler.x);
    float cy = cos(euler.y), sy = sin(euler.y);
    float cz = cos(euler.z), sz = sin(euler.z);
    mat3 rx = mat3(
        1.0, 0.0, 0.0,  
        0.0, cx, sx, 
        0.0, -sx, cx
    );
    mat3 ry = mat3(
        cy, 0.0, -sy,
        0.0, 1.0, 0.0, 
        sy, 0.0, cy 
    );
    mat3 rz = mat3(
        cz, sz, 0.0, 
        -sz, cz, 0.0,  
        0.0, 0.0, 1.0 
    );
    return rz * ry * rx;
}

vec3 RandomDirection(inout uint seed) {
    float x = RandomValueNormalDistribution(seed);
	float y = RandomValueNormalDistribution(seed);
	float z = RandomValueNormalDistribution(seed);
    return normalize(vec3(x, y, z));
}


void calculateCameraData(int x, int y) {
    if (params.camera_changed == 0) {return;}
    vec2 coord = vec2(float(x) / float(params.raster_size.x), float(y) / float(params.raster_size.y));
    coord = coord * float(2.0) - float(1.0);
    vec4 target = inverse(camera_data.ProjectionMatrix) * vec4(coord.x, coord.y, 1, 1);
    vec3 rayDirection = vec3(inverse(camera_data.viewMatrix) * vec4(normalize(vec3(target) / target.w), 0));
    ray_directions.ray_directions[x + y * int(params.raster_size.x)] = vec4(rayDirection, 0);
}

vec3 GetAABBNormal(vec3 hitPos, vec3 boxMin, vec3 boxMax) {
    // Distances to planes
    float dxMin = abs(hitPos.x - boxMin.x);
    float dxMax = abs(hitPos.x - boxMax.x);
    float dyMin = abs(hitPos.y - boxMin.y);
    float dyMax = abs(hitPos.y - boxMax.y);
    float dzMin = abs(hitPos.z - boxMin.z);
    float dzMax = abs(hitPos.z - boxMax.z);

    float minDist = dxMin;
    vec3 normal = vec3(-1.0, 0.0, 0.0);

    if (dxMax < minDist) { minDist = dxMax; normal = vec3(1.0, 0.0, 0.0); }
    if (dyMin < minDist) { minDist = dyMin; normal = vec3(0.0, -1.0, 0.0); }
    if (dyMax < minDist) { minDist = dyMax; normal = vec3(0.0, 1.0, 0.0); }
    if (dzMin < minDist) { minDist = dzMin; normal = vec3(0.0, 0.0, -1.0); }
    if (dzMax < minDist) { minDist = dzMax; normal = vec3(0.0, 0.0, 1.0); }

    return normal;
}

vec3 GetOBBNormal(vec3 hitPosWorld, Cube cube) {
    mat3 R  = rotationMatrix(cube.Rotation);
    mat3 RT = transpose(R);

    vec3 hitLocal = RT * (hitPosWorld - cube.Position);

    float eps = 1e-4;
    vec3 nLocal = GetAABBNormal(hitLocal, -cube.Size - eps, cube.Size + eps);

    return normalize(R * nLocal);
}

float CalculateReflectance(vec3 inDir, vec3 normal, float iorA, float iorB) {
    float refractRatio = iorA / iorB;
    float cosAngleIn = -dot(inDir, normal);
    float sinSqrAngleOfRefraction = refractRatio * refractRatio * (1.0 - cosAngleIn * cosAngleIn);


    if (sinSqrAngleOfRefraction >= 1.0)
        return 1.0;

    float cosAngleOfRefraction = sqrt(1.0 - sinSqrAngleOfRefraction);

    float denominatorPerpendicular = iorA * cosAngleIn + iorB * cosAngleOfRefraction;
    float denominatorParallel     = iorA * cosAngleIn + iorB * cosAngleOfRefraction;

    if (min(denominatorPerpendicular, denominatorParallel) < 1e-8)
        return 1.0;

    // Perpendicular polarization
    float rPerpendicular = (iorA * cosAngleIn - iorB * cosAngleOfRefraction) / denominatorPerpendicular;
    rPerpendicular *= rPerpendicular;

    // Parallel polarization
    float rParallel = (iorB * cosAngleIn - iorA * cosAngleOfRefraction) / denominatorParallel;
    rParallel *= rParallel;

    // Average of both
    return 0.5 * (rPerpendicular + rParallel);
}

HitPayload Miss(Ray ray) {
    HitPayload payload;
    payload.HitDistance = -1.0;
    payload.HitType = -1;
    return payload;
}

HitPayload ClosestHit(Ray ray, float hitDistance, int ObjectIndex, int hitType, bool isBackface) {
    HitPayload payload;
    payload.HitDistance = hitDistance;
    payload.ObjectIndex = ObjectIndex;
    payload.HitType = hitType;
    payload.isBackface = isBackface;
    bool isGlass = false;

    vec3 hitPos = ray.Origin + ray.Direction * hitDistance;
    payload.WorldPosition = hitPos;

    if (hitType == 0) {
        Sphere sphere = spheres.spheres[ObjectIndex];
        isGlass = materials.materials[int(sphere.MaterialIndex)].isGlass != 0.0;
        vec3 v = hitPos - sphere.Position;
        float invLen = inversesqrt(dot(v, v));
        payload.WorldNormal = v * invLen;
    }
    else if (hitType == 1) {
        Cube cube = cubes[ObjectIndex];
        isGlass = materials.materials[int(cube.MaterialIndex)].isGlass != 0.0;
        payload.WorldNormal = GetOBBNormal(hitPos, cube);
    }
    else {
        // Fallback normal if unknown hit type
        payload.WorldNormal = vec3(0.0, 0.0, 0.0);
    }

    if (isGlass) {
        if (dot(payload.WorldNormal, ray.Direction) > 0.0) {
            payload.WorldNormal = -payload.WorldNormal;
        }
    }
    return payload;
}


LightPayload CalculateReflectionAndRefraction(vec3 inDir, vec3 normal, float iorA, float iorB) {
    LightPayload res;

    res.reflectDir = reflect(inDir, normal);
    res.refractDir = refract(inDir, normal, iorA / iorB);

    res.reflectWeight = CalculateReflectance(inDir, normal, iorA, iorB);
    res.refractWeight = 1 - res.reflectWeight;

    return res;
}

float sgnNonZero(float x) { return x >= 0.0 ? 1.0 : -1.0; }

bool IntersectCube(Ray ray, Cube cube, out float tHit, out vec3 hitNormal, bool cullBackfaces) {
    // Rotate ray into cube-local space
    mat3 rot    = rotationMatrix(cube.Rotation);
    mat3 invRot = transpose(rot);

    vec3 localOrigin = invRot * (ray.Origin - cube.Position);
    vec3 localDir    = invRot * ray.Direction;
    vec3 invDir      = 1.0 / localDir;

    // Slabs
    vec3 t0 = (-cube.Size - localOrigin) * invDir; // near
    vec3 t1 = ( cube.Size - localOrigin) * invDir; // far

    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);

    float tEnter = max(max(tmin.x, tmin.y), tmin.z);
    float tExit  = min(min(tmax.x, tmax.y), tmax.z);

    if (tEnter > tExit || tExit < 0.0)
        return false;

    // Choose the actual hit
    bool useEnter = (tEnter > 0.0);
    tHit = useEnter ? tEnter : tExit;

    // --- Normal from tHit (NOT always from tEnter) ---
    vec3 nLocal = vec3(0.0);
    if (useEnter) {
        // entering face: outward normal opposes ray direction on the dominant tmin axis
        if (tmin.x >= tmin.y && tmin.x >= tmin.z) nLocal = vec3(-sgnNonZero(localDir.x), 0.0, 0.0);
        else if (tmin.y >= tmin.z)                nLocal = vec3(0.0, -sgnNonZero(localDir.y), 0.0);
        else                                      nLocal = vec3(0.0, 0.0, -sgnNonZero(localDir.z));
    } else {
        // exiting face: outward normal aligns with ray direction on the dominant tmax axis
        if (tmax.x <= tmax.y && tmax.x <= tmax.z) nLocal = vec3( sgnNonZero(localDir.x), 0.0, 0.0);
        else if (tmax.y <= tmax.z)                nLocal = vec3(0.0,  sgnNonZero(localDir.y), 0.0);
        else                                      nLocal = vec3(0.0, 0.0,  sgnNonZero(localDir.z));
    }

    vec3 worldNormal = normalize(rot * nLocal);

    // Correct backface culling: cull when ray goes WITH the outward normal
    if (cullBackfaces && dot(worldNormal, ray.Direction) > 0.0)
        return false;

    hitNormal = worldNormal;
    return true;
}


HitPayload TraceRay(Ray ray) {
    int closestIndex = -1;
    float hitDistance = 3.402823466e+38;
    int hitType = -1;
    vec3 hitNormal;
    for (int i = 0; i < params.sphereCount; i++) {
        Sphere sphere = spheres.spheres[i];

        vec3 origin = ray.Origin - sphere.Position;

        float a = dot(ray.Direction, ray.Direction);
        float b = 2.0 * dot(origin, ray.Direction);
        float c = dot(origin, origin) - sphere.Radius * sphere.Radius;
        float discriminant = b * b - 4.0 * a * c;

        if (discriminant < 0.0) {
            continue;
        }

        float t0 = (-b - sqrt(discriminant)) / (2.0 * a);
        float t1 = (-b + sqrt(discriminant)) / (2.0 * a);

        if (t0 > t1) { float tmp = t0; t0 = t1; t1 = tmp; } // swap
        float closestT = (t0 > 0.0) ? t0 : t1;


        // float t0 = (-b + sqrt(discriminant)) / (2.0 * a);
        if (closestT > 0.0 && closestT < hitDistance) {
            vec3 hitPoint = ray.Origin + ray.Direction * closestT;
            vec3 tempNormal = normalize(hitPoint - sphere.Position);
            bool isGlass = materials.materials[int(sphere.MaterialIndex)].isGlass != 0.0;
            
            if (!isGlass && dot(tempNormal, ray.Direction) > 0.0) {
                continue;
            }

            hitDistance = closestT;
            closestIndex = i;
            hitType = 0;
            hitNormal = tempNormal;
        }
    }
    // handle cubes
    for (int i = 0; i < params.cubeCount; i++) {
        Cube cube = cubes[i];
        bool isGlass = materials.materials[int(cube.MaterialIndex)].isGlass != 0.0;
        float rayHit;
        vec3 tempNormal;
        //!isGlass because we dont want to cull when the material is glass
        if (IntersectCube(ray, cube, rayHit, tempNormal, !isGlass)) {
            if (rayHit > 0.0 && rayHit < hitDistance) {
                hitDistance = rayHit;
                closestIndex = i;
                hitType = 1;
                hitNormal = tempNormal;
            }
        }
    }

    if (closestIndex < 0) {
        return Miss(ray);
    }
    bool is_backface = dot(hitNormal, ray.Direction) > 0.0;

    return ClosestHit(ray, hitDistance, closestIndex, hitType, is_backface);
}


vec4 PerPixel(int x, int y) {
    Ray ray;
    ray.Origin = camera_data.cameraPosition.xyz;
    ray.Direction = ray_directions.ray_directions[x + y * int(params.raster_size.x)].xyz;
    ray.Inverse_Dir = 1.0 / ray.Direction;
    vec3 light = vec3(0.0);
    vec3 throughput = vec3(1.0);

    uint seed = uint(x + y * int(params.raster_size.x));
    seed *= uint(params.frameIndex.x);

    for (int i = 0; i < int(params.maxBounces); i++) {
        seed += i;

        HitPayload payload = TraceRay(ray);
        if (payload.HitDistance < 0.0f || payload.HitType == -1) {
            //vec3 skyColor = vec3(0.6941, 0.5882, 1.0);
            light += params.skyColor * throughput;
            break;
        }
        Material material;
        if (payload.HitType == 0) {
            Sphere sphere = spheres.spheres[int(payload.ObjectIndex)];
            material = materials.materials[int(sphere.MaterialIndex)];
        }
        else if(payload.HitType == 1) {
            Cube cube = cubes[int(payload.ObjectIndex)];
            material = materials.materials[int(cube.MaterialIndex)];
        }
        bool isGlass = material.isGlass != 0.0;
        float eps = 1e-4 * max(1.0, abs(payload.HitDistance));
        if (!isGlass) {
            bool isSpecularBounce = material.specularProbability >= randomFloat(seed);
            ray.Origin = payload.WorldPosition + payload.WorldNormal * eps;
            vec3 diffuseDir = normalize(payload.WorldNormal + RandomDirection(seed));
            vec3 specularDir = reflect(ray.Direction, payload.WorldNormal);
            
            ray.Direction = normalize(mix(diffuseDir, specularDir, (1.0 - material.Roughness) * float(isSpecularBounce)));

            vec3 emittedLight = material.EmissionColor * material.EmissionPower;
            light += emittedLight * throughput;
            throughput *= mix(material.Albedo, vec3(1.0, 1.0, 1.0), float(isSpecularBounce));
        }
        else if (isGlass) {
            if (payload.isBackface) {
                throughput *= exp(-payload.HitDistance * material.absorption * material.absorptionStrength);
            }
            float iorCurrent = payload.isBackface ? material.ior : 1.0;
            float iorNext = payload.isBackface ? 1.0 : material.ior;
            LightPayload lp = CalculateReflectionAndRefraction(ray.Direction, payload.WorldNormal, iorCurrent, iorNext);
            vec3 diffuseDir = normalize(payload.WorldNormal + RandomDirection(seed));
            lp.reflectDir = normalize(mix(diffuseDir, lp.reflectDir, material.specularProbability));
            lp.refractDir = normalize(mix(-diffuseDir, lp.refractDir, 1.0 - material.Roughness));
            bool followReflection = randomFloat(seed) <= lp.reflectWeight;
            ray.Direction = followReflection ? lp.reflectDir : lp.refractDir;
            ray.Origin = payload.WorldPosition + eps * payload.WorldNormal * sign(dot(payload.WorldNormal, ray.Direction));
        }
        
        if (i >= 2) {
            float p = clamp(max(throughput.r, max(throughput.g, throughput.b)), 0.1, 1.0);
            if (randomFloat(seed) > p) {
                break;
            }
        }
    }

    return vec4(light, 1.0);
}

void emptyAccumulationData(int x, int y) {
    if (params.frameIndex <= 1.0) {
        accum_colors[x + y * int(params.raster_size.x)] = vec4(0);
    }
    return;
}

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = ivec2(params.raster_size);

    uv.y = size.y - uv.y - 1;
    if (uv.x >= size.x || uv.y >= size.y) {
        return;
    }


    calculateCameraData(uv.x, uv.y);
    emptyAccumulationData(uv.x, uv.y);
    
    vec4 color = vec4(0.0);
    for (uint i = 0u; i < int(params.raysPerPixel); i++) {
        color = PerPixel(uv.x, uv.y);
    }
    accum_colors[uv.x + uv.y * size.x] += color;
    
    vec4 accumulatedColor = accum_colors[uv.x + uv.y * size.x];
    accumulatedColor /= float(params.frameIndex);
    accumulatedColor = clamp(accumulatedColor, vec4(0.0), vec4(1.0));


    imageStore(color_image, uv,  vec4(accumulatedColor.rgb, 1.0));
}

