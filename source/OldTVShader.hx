package;

import flixel.math.FlxMath;
import flixel.system.FlxAssets.FlxShader;
import haxe.Timer;

class OldTVShader extends FlxShader
{
	@:glFragmentSource('
#pragma header

#define PI 3.141592653
#define TAU 6.283185306

uniform float iTime;

// ------------------------------------------------------------
// Cheap PRNG
// ------------------------------------------------------------

#define HASH_K 1103515245U

vec3 hash(uvec3 x)
{
    x = ((x >> 8U) ^ x.yzx) * HASH_K;
    x = ((x >> 8U) ^ x.yzx) * HASH_K;
    x = ((x >> 8U) ^ x.yzx) * HASH_K;

    return vec3(x) * (1.0 / 4294967295.0);
}

// ------------------------------------------------------------
// Main
// ------------------------------------------------------------

void main()
{
    vec2 uv = openfl_TextureCoordv.xy;

    bool flag = false;
    bool flag2 = false;

    // --------------------------------------------------------
    // Horizontal picture offset / tracking line
    // --------------------------------------------------------

    float timeMod = 2.5;
    float repeatTime = 1.25;

    float lineSize = 50.0;
    float offsetMul = 0.01;

    float updateRate = 50.0;
    float lineYMultiplier = 100.0;

    float realSize =
        lineSize / openfl_TextureSize.y * 0.5;

    float position =
        mod(iTime, timeMod) / 2.0;

    float position2 = -1.0;

    if (iTime > repeatTime)
    {
        position2 =
            mod(iTime - repeatTime, timeMod) / 2.0;
    }

    bool inLine =
        abs(uv.y - position) <= realSize;

    if (!inLine && position2 >= 0.0)
    {
        inLine =
            abs(uv.y - position2) <= realSize;
    }

    if (inLine)
    {
        float glitch =
            hash(
                uvec3(
                    0U,
                    uint(uv.y * lineYMultiplier),
                    uint(iTime * updateRate)
                )
            ).x;

        uv.x -= glitch * offsetMul;

        flag = true;
    }

    // --------------------------------------------------------
    // Base image
    // --------------------------------------------------------

    vec4 col =
        flixel_texture2D(bitmap, uv);

    // --------------------------------------------------------
    // Cheap blur / glow
    //
    // Original:
    // 16 directions × 3 quality = 48 samples
    //
    // New:
    // 4 directions × 2 samples = 8 samples
    // --------------------------------------------------------

    float size = 4.0;

    vec2 radius =
        size / openfl_TextureSize;

    col += flixel_texture2D(
        bitmap,
        uv + vec2(radius.x, 0.0)
    );

    col += flixel_texture2D(
        bitmap,
        uv - vec2(radius.x, 0.0)
    );

    col += flixel_texture2D(
        bitmap,
        uv + vec2(0.0, radius.y)
    );

    col += flixel_texture2D(
        bitmap,
        uv - vec2(0.0, radius.y)
    );

    col += flixel_texture2D(
        bitmap,
        uv + radius
    );

    col += flixel_texture2D(
        bitmap,
        uv - radius
    );

    col += flixel_texture2D(
        bitmap,
        uv + vec2(radius.x, -radius.y)
    );

    col += flixel_texture2D(
        bitmap,
        uv + vec2(-radius.x, radius.y)
    );

    col /= 9.0;

    // --------------------------------------------------------
    // Black region on the left
    // --------------------------------------------------------

    if (uv.x < 0.0)
    {
        col = vec4(0.0);
        flag = false;
        flag2 = true;
    }

    // --------------------------------------------------------
    // Random black glitches / splotches
    // --------------------------------------------------------

    float blackNoise =
        hash(
            uvec3(
                uint(uv.y * 100.0),
                0U,
                uint(iTime * 100.0)
            )
        ).x;

    if (blackNoise > 0.92)
    {
        float width =
            (blackNoise - 0.92)
            * 0.0875;

        if (uv.x < width)
        {
            col = vec4(0.0);
            flag2 = true;
        }
        else
        {
            flag = true;
        }
    }

    // --------------------------------------------------------
    // Static
    // --------------------------------------------------------

    if (!flag2)
    {
        float staticNoise =
            hash(
                uvec3(
                    uint(uv.x * openfl_TextureSize.x),
                    uint(uv.y * openfl_TextureSize.y),
                    uint(iTime * 100.0)
                )
            ).x;

        col.rgb =
            mix(
                col.rgb,
                vec3(staticNoise),
                0.05
            );
    }

    // --------------------------------------------------------
    // White splotches
    // --------------------------------------------------------

    if (flag)
    {
        float val =
            hash(
                uvec3(
                    uint(uv.x * 20.0),
                    uint(uv.y * 400.0),
                    uint(iTime * 75.0)
                )
            ).x;

        if (val > 0.95)
        {
            float offset =
                hash(
                    uvec3(
                        uint(uv.y * 400.0),
                        uint(uv.x * 20.0),
                        uint(iTime * 75.0)
                    )
                ).x;

            float strength =
                (val - 0.95) * 14.0;

            strength -=
                abs(
                    (
                        uv.x * 20.0
                        - (
                            floor(uv.x * 20.0)
                            + offset
                        )
                    ) * 0.7
                );

            strength =
                clamp(strength, 0.0, 1.0);

            col.rgb =
                mix(
                    col.rgb,
                    vec3(1.0),
                    strength
                );
        }
    }

    gl_FragColor = col;
}
    ')
	public function new()
	{
		super();
		iTime.value = [Timer.stamp()];
	}

	public function update(elapsed:Float)
	{
		iTime.value[0] += elapsed;
	}
}
