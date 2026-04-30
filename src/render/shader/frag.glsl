#version 330 core
in vec2 vTexCoord;
in vec3 vNormal;
in vec3 vFragPos;

out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec3 uSunPos;
uniform vec3 uFlashlightPos;
uniform vec3 uViewPos;
uniform vec3 uLightColor;
uniform int uFlashlightOn;

vec3 calcLight(vec3 lightPos, vec3 normal, vec3 viewDir, vec3 lightColor) {
    vec3 lightDir = normalize(lightPos - vFragPos);
    float diff    = max(dot(normal, lightDir), 0.0);
    vec3 diffuse  = diff * lightColor;

    vec3 reflectDir = reflect(-lightDir, normal);
    float spec      = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    vec3 specular   = 0.5 * spec * lightColor;

    return diffuse + specular;
}

void main() {
    vec3 texColor = texture(uTexture, vTexCoord).rgb;
    vec3 normal   = normalize(vNormal);
    vec3 viewDir  = normalize(uViewPos - vFragPos);

    // ambient
    vec3 result = 0.15 * uLightColor;

    // sun
    result += calcLight(uSunPos, normal, viewDir, uLightColor);

    // flashlight
    if (uFlashlightOn != 0) {
        result += calcLight(uFlashlightPos, normal, viewDir, uLightColor);
    }

    result *= texColor;
    FragColor = vec4(result, 1.0);
}